import type { RawAppwriteContext } from './appwrite-entry.js';
import type { ServiceName } from './transport.js';
import type { HostedHandler } from './runtime-http.js';

export interface WorkerRuntime {
  start(): void;
  stop(): Promise<void>;
}

export interface WorkerRuntimeOptions {
  service: ServiceName;
  intervalMs?: number;
}

function boundedInterval(raw: string | undefined, fallback: number): number {
  const parsed = raw === undefined ? fallback : Number(raw);
  return Number.isSafeInteger(parsed) && parsed >= 1000 && parsed <= 3_600_000 ? parsed : fallback;
}

export function createWorkerRuntime(
  handler: HostedHandler,
  options: WorkerRuntimeOptions,
): WorkerRuntime {
  let stopping = false;
  let running: Promise<void> | undefined;
  let wake: (() => void) | undefined;
  let sleepTimer: NodeJS.Timeout | undefined;
  const intervalMs = options.intervalMs ?? 60_000;

  const tick = async (): Promise<void> => {
    const context: RawAppwriteContext = {
      req: {
        method: 'POST',
        path: '/',
        headers: { 'x-appwrite-trigger': 'schedule' },
        bodyText: '',
        queryString: '',
      },
      res: { json: (body) => body },
    };
    try {
      await handler(context);
    } catch {
      process.stderr.write(
        `${JSON.stringify({ service: options.service, runtime: 'worker', status: 'TICK_FAILED' })}\n`,
      );
    }
  };

  const loop = async (): Promise<void> => {
    while (!stopping) {
      await tick();
      if (stopping) break;
      await new Promise<void>((resolve) => {
        const finish = () => {
          if (sleepTimer) clearTimeout(sleepTimer);
          sleepTimer = undefined;
          wake = undefined;
          resolve();
        };
        wake = finish;
        sleepTimer = setTimeout(finish, intervalMs);
      });
    }
  };

  return {
    start() {
      running ??= loop();
    },
    async stop() {
      stopping = true;
      wake?.();
      await running;
    },
  };
}

export function runWorkerProcess(handler: HostedHandler, options: { service: ServiceName }): void {
  const runtime = createWorkerRuntime(handler, {
    service: options.service,
    intervalMs: boundedInterval(process.env['COC_WORKER_INTERVAL_MS'], 60_000),
  });
  runtime.start();
  process.stdout.write(`${JSON.stringify({ service: options.service, runtime: 'worker' })}\n`);
  let closing = false;
  const close = () => {
    if (closing) return;
    closing = true;
    void runtime.stop().then(
      () => process.exit(0),
      () => process.exit(1),
    );
  };
  process.once('SIGTERM', close);
  process.once('SIGINT', close);
}
