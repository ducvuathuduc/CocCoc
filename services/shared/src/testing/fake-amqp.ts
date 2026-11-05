// FAKE_AMQP_BROKER — LOCAL TEST FIXTURE ONLY (never bundled into a hosted artifact; asserted by
// services/shared/test/event-cache-ports.test.mjs). An in-process model of the RabbitMQ
// behaviour the ADR-0018 fault matrix depends on: topic routing, mandatory returns, publisher
// confirms (including lost confirms), quorum delivery count + x-delivery-limit, dead-lettering
// with at-least-once retention when the DLX target is missing, reject-publish overflow,
// prefetch, requeue of unacked deliveries when a connection dies, persistence across restart
// and connection.blocked during a resource alarm. It is not a broker conformance claim; the
// real-broker checks run in tools/scripts/container-check.mjs against the pinned image.
import { EventEmitter } from 'node:events';
import type {
  AmqpChannel,
  AmqpConfirmChannel,
  AmqpConnection,
  AmqpMessage,
} from '../amqp-transport.js';

interface StoredMessage {
  content: Buffer;
  routingKey: string;
  exchange: string;
  messageId: string | undefined;
  correlationId: string | undefined;
  persistent: boolean;
  deliveryCount: number;
  redelivered: boolean;
  headers: Record<string, unknown>;
}
interface Queue {
  name: string;
  args: Record<string, unknown>;
  ready: StoredMessage[];
  /** at-least-once dead letters whose DLX target is unroutable: retained, never dropped. */
  pendingDeadLetters: StoredMessage[];
  limit?: number;
}
interface Consumer {
  channel: FakeChannel;
  tag: string;
  queue: string;
  onMessage: (message: AmqpMessage | null) => void;
}

function topicMatch(pattern: string, key: string): boolean {
  const p = pattern.split('.');
  const k = key.split('.');
  const walk = (i: number, j: number): boolean => {
    if (i === p.length) return j === k.length;
    if (p[i] === '#') {
      for (let skip = j; skip <= k.length; skip++) if (walk(i + 1, skip)) return true;
      return false;
    }
    if (j === k.length) return false;
    return (p[i] === '*' || p[i] === k[j]) && walk(i + 1, j + 1);
  };
  return walk(0, 0);
}

export class FakeAmqpBroker {
  readonly exchanges = new Map<string, string>();
  readonly queues = new Map<string, Queue>();
  readonly bindings: Array<{ queue: string; exchange: string; pattern: string }> = [];
  readonly connections = new Set<FakeConnection>();
  readonly consumers: Consumer[] = [];
  /** Broker unreachable: connect() rejects. */
  down = false;
  /** The next N publishes are enqueued but their confirm is never sent (ambiguous outcome). */
  dropConfirms = 0;
  /** Resource alarm: connections are blocked and publishes stall. */
  alarm = false;
  published = 0;
  lostMessages = 0;
  private tagSeq = 0;

  connect = async (_url: string): Promise<AmqpConnection> => {
    if (this.down) throw new Error('ECONNREFUSED');
    const connection = new FakeConnection(this);
    this.connections.add(connection);
    if (this.alarm) setImmediate(() => connection.emit('blocked', 'disk'));
    return connection;
  };

  queue(name: string): Queue {
    const queue = this.queues.get(name);
    if (!queue) throw new Error(`NOT_FOUND - no queue '${name}'`);
    return queue;
  }
  depth(name: string): number {
    return this.queues.get(name)?.ready.length ?? 0;
  }
  unacked(): number {
    let total = 0;
    for (const connection of this.connections) {
      for (const channel of connection.channels) total += channel.unacked.size;
    }
    return total;
  }
  setQueueLimit(name: string, limit: number) {
    this.queue(name).limit = limit;
  }

  route(exchange: string, routingKey: string): Queue[] {
    return this.bindings
      .filter((b) => b.exchange === exchange && topicMatch(b.pattern, routingKey))
      .map((b) => this.queue(b.queue));
  }

  enqueue(queue: Queue, message: StoredMessage): boolean {
    if (queue.limit !== undefined && queue.ready.length >= queue.limit) {
      if (queue.args['x-overflow'] === 'reject-publish') return false;
      queue.ready.shift();
      this.lostMessages++;
    }
    queue.ready.push(message);
    return true;
  }

  deadLetter(queue: Queue, message: StoredMessage, reason: string) {
    const dlx = queue.args['x-dead-letter-exchange'];
    if (typeof dlx !== 'string') {
      this.lostMessages++;
      return;
    }
    const targets = this.route(dlx, message.routingKey);
    const lettered: StoredMessage = {
      ...message,
      redelivered: false,
      deliveryCount: 0,
      headers: { ...message.headers, 'x-death': [{ queue: queue.name, reason }] },
    };
    if (!targets.length) {
      if (queue.args['x-dead-letter-strategy'] === 'at-least-once') {
        queue.pendingDeadLetters.push(lettered);
      } else this.lostMessages++;
      return;
    }
    for (const target of targets) this.enqueue(target, { ...lettered });
  }

  /** Re-attempt retained at-least-once dead letters (e.g. after the DLX target was bound). */
  retryDeadLetters() {
    for (const queue of this.queues.values()) {
      const pending = queue.pendingDeadLetters.splice(0);
      for (const message of pending) this.deadLetter(queue, message, 'rejected');
    }
    this.pump();
  }

  setAlarm(on: boolean) {
    this.alarm = on;
    for (const connection of this.connections)
      connection.emit(on ? 'blocked' : 'unblocked', 'disk');
    if (!on) for (const connection of this.connections) connection.flushStalled();
  }

  /** Kill one connection: unacked deliveries return to their queues; confirms are lost. */
  kill(connection: FakeConnection) {
    if (!this.connections.has(connection)) return;
    this.connections.delete(connection);
    for (const channel of connection.channels) channel.die();
    this.consumers.splice(
      0,
      this.consumers.length,
      ...this.consumers.filter((c) => c.channel.connection !== connection),
    );
    connection.emit('close', new Error('CONNECTION_FORCED'));
    this.pump();
  }
  /** Broker restart: every connection dies; transient messages are lost, persistent survive. */
  restart() {
    for (const connection of [...this.connections]) this.kill(connection);
    for (const queue of this.queues.values()) {
      const before = queue.ready.length;
      queue.ready = queue.ready.filter((m) => m.persistent);
      this.lostMessages += before - queue.ready.length;
    }
  }

  addConsumer(consumer: Omit<Consumer, 'tag'>): string {
    const tag = `ctag-${++this.tagSeq}`;
    this.consumers.push({ ...consumer, tag });
    this.pump();
    return tag;
  }
  removeConsumer(tag: string) {
    const index = this.consumers.findIndex((c) => c.tag === tag);
    if (index >= 0) this.consumers.splice(index, 1);
  }

  private pumping = false;
  pump() {
    if (this.pumping) return;
    this.pumping = true;
    setImmediate(() => {
      this.pumping = false;
      for (const consumer of [...this.consumers]) {
        const queue = this.queues.get(consumer.queue);
        if (!queue) continue;
        while (queue.ready.length && consumer.channel.canDeliver()) {
          const message = queue.ready.shift() as StoredMessage;
          consumer.channel.deliver(consumer, message);
        }
      }
    });
  }
}

class FakeConnection extends EventEmitter implements AmqpConnection {
  readonly channels = new Set<FakeChannel>();
  private stalled: Array<() => void> = [];
  constructor(readonly broker: FakeAmqpBroker) {
    super();
  }
  async createChannel(): Promise<AmqpChannel> {
    return this.open(false);
  }
  async createConfirmChannel(): Promise<AmqpConfirmChannel> {
    return this.open(true);
  }
  private open(confirm: boolean): FakeChannel {
    if (!this.broker.connections.has(this)) throw new Error('CONNECTION_CLOSED');
    const channel = new FakeChannel(this, confirm);
    this.channels.add(channel);
    return channel;
  }
  stall(run: () => void) {
    this.stalled.push(run);
  }
  flushStalled() {
    const runs = this.stalled.splice(0);
    for (const run of runs) run();
  }
  async close(): Promise<void> {
    this.broker.kill(this);
  }
}

class FakeChannel extends EventEmitter implements AmqpConfirmChannel {
  readonly unacked = new Map<number, { message: StoredMessage; queue: string }>();
  private prefetchCount = 0;
  private seq = 0;
  private open = true;
  constructor(
    readonly connection: FakeConnection,
    readonly confirm: boolean,
  ) {
    super();
  }
  private get broker() {
    return this.connection.broker;
  }
  private ensureOpen() {
    if (!this.open) throw new Error('Channel closed');
  }
  async assertExchange(name: string, type: string): Promise<unknown> {
    this.ensureOpen();
    const existing = this.broker.exchanges.get(name);
    if (existing && existing !== type) throw new Error('PRECONDITION_FAILED');
    this.broker.exchanges.set(name, type);
    return { exchange: name };
  }
  async assertQueue(name: string, options: Record<string, unknown>): Promise<unknown> {
    this.ensureOpen();
    const args = (options['arguments'] ?? {}) as Record<string, unknown>;
    const existing = this.broker.queues.get(name);
    if (existing) {
      if (JSON.stringify(existing.args) !== JSON.stringify(args)) {
        throw new Error('PRECONDITION_FAILED - inequivalent arg');
      }
    } else {
      if (args['x-queue-type'] === 'quorum' && options['durable'] !== true) {
        throw new Error('PRECONDITION_FAILED - quorum queues must be durable');
      }
      this.broker.queues.set(name, { name, args, ready: [], pendingDeadLetters: [] });
    }
    return { queue: name };
  }
  async bindQueue(queue: string, exchange: string, pattern: string): Promise<unknown> {
    this.ensureOpen();
    this.broker.queue(queue);
    if (!this.broker.exchanges.has(exchange)) throw new Error('NOT_FOUND - no exchange');
    if (
      !this.broker.bindings.some(
        (b) => b.queue === queue && b.exchange === exchange && b.pattern === pattern,
      )
    ) {
      this.broker.bindings.push({ queue, exchange, pattern });
    }
    return {};
  }
  async prefetch(count: number): Promise<unknown> {
    this.prefetchCount = count;
    return {};
  }
  publish(
    exchange: string,
    routingKey: string,
    content: Buffer,
    options: Record<string, unknown>,
    callback: (err: unknown) => void,
  ): boolean {
    this.ensureOpen();
    const run = () => {
      if (!this.open) return;
      this.broker.published++;
      const targets = this.broker.route(exchange, routingKey);
      const message: StoredMessage = {
        content: Buffer.from(content),
        routingKey,
        exchange,
        messageId: options['messageId'] as string | undefined,
        correlationId: options['correlationId'] as string | undefined,
        persistent: options['persistent'] === true,
        deliveryCount: 0,
        redelivered: false,
        headers: {},
      };
      let rejected = false;
      for (const queue of targets) if (!this.broker.enqueue(queue, { ...message })) rejected = true;
      this.broker.pump();
      if (!targets.length && options['mandatory'] === true) {
        this.emit('return', {
          content: message.content,
          fields: { deliveryTag: 0, redelivered: false, routingKey, exchange },
          properties: {
            ...(message.messageId ? { messageId: message.messageId } : {}),
            ...(message.correlationId ? { correlationId: message.correlationId } : {}),
            headers: {},
          },
        } satisfies AmqpMessage);
      }
      if (this.broker.dropConfirms > 0) {
        this.broker.dropConfirms--;
        return;
      }
      setImmediate(() => {
        if (this.open) callback(rejected ? new Error('nack') : null);
      });
    };
    if (this.broker.alarm) this.connection.stall(run);
    else run();
    return true;
  }
  async consume(
    queue: string,
    onMessage: (message: AmqpMessage | null) => void,
  ): Promise<{ consumerTag: string }> {
    this.ensureOpen();
    this.broker.queue(queue);
    return { consumerTag: this.broker.addConsumer({ channel: this, queue, onMessage }) };
  }
  async cancel(consumerTag: string): Promise<unknown> {
    this.broker.removeConsumer(consumerTag);
    return {};
  }
  canDeliver(): boolean {
    return this.open && (this.prefetchCount === 0 || this.unacked.size < this.prefetchCount);
  }
  deliver(consumer: Consumer, message: StoredMessage) {
    const tag = ++this.seq;
    this.unacked.set(tag, { message, queue: consumer.queue });
    const headers: Record<string, unknown> = { ...message.headers };
    if (message.deliveryCount > 0) headers['x-delivery-count'] = message.deliveryCount;
    const delivered: AmqpMessage = {
      content: message.content,
      fields: {
        deliveryTag: tag,
        redelivered: message.redelivered,
        routingKey: message.routingKey,
        exchange: message.exchange,
      },
      properties: { ...(message.messageId ? { messageId: message.messageId } : {}), headers },
    };
    setImmediate(() => consumer.onMessage(delivered));
  }
  private settle(message: AmqpMessage) {
    this.ensureOpen();
    const entry = this.unacked.get(message.fields.deliveryTag);
    if (!entry) throw new Error('PRECONDITION_FAILED - unknown delivery tag');
    this.unacked.delete(message.fields.deliveryTag);
    return entry;
  }
  ack(message: AmqpMessage): void {
    this.settle(message);
    this.broker.pump();
  }
  nack(message: AmqpMessage, _allUpTo: boolean, requeue: boolean): void {
    const { message: stored, queue: queueName } = this.settle(message);
    const queue = this.broker.queue(queueName);
    if (requeue) {
      const next = { ...stored, deliveryCount: stored.deliveryCount + 1, redelivered: true };
      const limit = queue.args['x-delivery-limit'];
      if (typeof limit === 'number' && next.deliveryCount > limit) {
        this.broker.deadLetter(queue, next, 'delivery_limit');
      } else queue.ready.push(next);
    } else this.broker.deadLetter(queue, stored, 'rejected');
    this.broker.pump();
  }
  /** Connection death: unacked deliveries go back to the queue (redelivered). */
  die() {
    if (!this.open) return;
    this.open = false;
    for (const { message, queue } of this.unacked.values()) {
      this.broker.queues.get(queue)?.ready.unshift({ ...message, redelivered: true });
    }
    this.unacked.clear();
    this.emit('close');
  }
  async close(): Promise<void> {
    if (!this.open) return;
    for (const consumer of this.broker.consumers.filter((c) => c.channel === this)) {
      this.broker.removeConsumer(consumer.tag);
    }
    this.die();
    this.connection.channels.delete(this);
    this.broker.pump();
  }
}
