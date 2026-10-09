import fs from 'node:fs';
const args = process.argv.slice(2);
const report = args[0] === '--report';
if (args.length && (!report || !args[1])) throw new Error('Usage: node tools/evals/voice-harness.mjs [--report results.json]');
const rows = report ? JSON.parse(fs.readFileSync(args[1], 'utf8')) : [{ capability: 'pronunciation', provider: 'fixture', model: 'fixture', locale: 'en-US', device: 'synthetic', network: 'offline', startMs: 0, endMs: 1, outcome: 'unassessed', assessedMetrics: null }];
if (!Array.isArray(rows) || !rows.length) throw new Error('Nonempty sample array required.');
for (const row of rows) {
  for (const field of ['capability', 'provider', 'model', 'locale', 'device', 'network', 'outcome']) if (typeof row[field] !== 'string' || !row[field]) throw new Error(`Missing ${field}`);
  if (!Number.isFinite(row.startMs) || !Number.isFinite(row.endMs) || row.endMs < row.startMs) throw new Error('Invalid measured time.');
  if (row.outcome === 'unassessed' && row.assessedMetrics !== null) throw new Error('Unassessed metrics must be null.');
}
const elapsed = rows.map((row) => row.endMs - row.startMs).sort((a, b) => a - b);
const percentile = (p) => elapsed[Math.max(0, Math.ceil(elapsed.length * p) - 1)];
console.log(JSON.stringify({ status: 'PASS', mode: report ? 'USER_SUPPLIED_MEASUREMENTS' : 'FIXTURE_SCHEMA_CHECK_NOT_BENCHMARK', samples: rows.length, failedOrUnassessed: rows.filter((row) => row.outcome !== 'success').length, p50Ms: report ? percentile(0.5) : null, p95Ms: report ? percentile(0.95) : null, providerCalls: 0 }, null, 2));
