import http from 'node:http';
import path from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const names = ['learning', 'progress', 'ai'];
const name = process.argv[2];
if (!names.includes(name)) throw new Error('Choose learning, progress or ai.');
const { default: handler } = await import(
  pathToFileURL(path.join(root, `services/${name}/dist/function.mjs`))
);
const port = Number(process.env.PORT ?? 4301 + names.indexOf(name));
if (!Number.isInteger(port) || port < 1024 || port > 65535) throw new Error('Invalid PORT.');
const server = http.createServer(async (req, res) => {
  req.resume();
  const headers = Object.fromEntries(
    Object.entries(req.headers).map(([key, value]) => [
      key,
      Array.isArray(value) ? value[0] : value,
    ]),
  );
  await handler({
    req: {
      method: req.method ?? 'GET',
      path: new URL(req.url ?? '/', 'http://127.0.0.1').pathname,
      headers,
    },
    res: {
      json: (body, status = 200, responseHeaders = {}) => {
        res.writeHead(status, { 'Content-Type': 'application/json', ...responseHeaders });
        res.end(JSON.stringify(body));
      },
    },
  });
});
server.listen(port, '127.0.0.1', () =>
  console.log(`${name} scaffold: http://127.0.0.1:${port}/health; business adapters disabled`),
);
for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => server.close());
