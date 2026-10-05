import http from 'node:http';
import { createReadStream, existsSync, statSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const webRoot = path.join(repositoryRoot, 'apps/mobile/build/web');
const port = Number(process.env.COC_PREVIEW_PORT ?? 4173);
const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png', '.svg': 'image/svg+xml', '.ttf': 'font/ttf', '.woff2': 'font/woff2' };
if (!existsSync(path.join(webRoot, 'index.html'))) throw new Error('Run flutter build web first.');
http.createServer((request, response) => {
  let pathname;
  try { pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname); }
  catch { response.writeHead(400).end(); return; }
  let file = path.resolve(webRoot, `.${pathname}`);
  const relative = path.relative(webRoot, file);
  if (relative.startsWith('..') || path.isAbsolute(relative)) { response.writeHead(403).end(); return; }
  if (pathname === '/') file = path.join(webRoot, 'index.html');
  if (!existsSync(file) || !statSync(file).isFile()) {
    if (path.extname(pathname)) { response.writeHead(404).end(); return; }
    file = path.join(webRoot, 'index.html');
  }
  response.writeHead(200, { 'Content-Type': types[path.extname(file)] ?? 'application/octet-stream', 'Cache-Control': 'no-store' });
  createReadStream(file).pipe(response);
}).listen(port, '127.0.0.1', () => console.log(`CocEnglish preview: http://127.0.0.1:${port}/preview.html`));
