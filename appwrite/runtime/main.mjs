// Appwrite runtime adapter (deployed next to each service's hosted bundle as main.mjs).
// The Appwrite node runtime passes a req object with lazy getters (bodyJson throws on an empty or
// non-JSON body), so spreading or enumerating it can crash before the service router runs. This
// adapter copies only the documented plain fields into the FunctionContext shape the services expect
// (services/shared/src/transport.ts) and delegates to the unchanged bundle. No business logic here.
import handler from './function.mjs';

function field(read, fallback) {
  try {
    const value = read();
    return value === undefined || value === null ? fallback : value;
  } catch {
    return fallback;
  }
}

export default async function main(context) {
  const source = context.req;
  const req = {
    method: field(() => source.method, 'GET'),
    path: field(() => source.path, '/'),
    headers: { ...field(() => source.headers, {}) },
    bodyText: field(
      () => source.bodyText,
      field(() => source.bodyRaw, ''),
    ),
    queryString: field(() => source.queryString, ''),
    query: { ...field(() => source.query, {}) },
    host: field(() => source.host, ''),
    scheme: field(() => source.scheme, ''),
    port: field(() => source.port, 0),
    url: field(() => source.url, ''),
  };
  return handler({ req, res: context.res, log: context.log, error: context.error });
}
