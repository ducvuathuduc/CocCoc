// `node content/tools/build-content.mjs [--check]` — regenerate the published course content.
// vi_en v1 (6-unit pilot) is retired; the only published version is v2, generated from
// content/vi_en/source/v2/ by tools/content/build-course.mjs into content/vi_en/dist/v2/.
// This entry point is kept so existing commands and gates keep working.
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { root } from './lib.mjs';

const run = spawnSync(
  process.execPath,
  [path.join(root, 'tools/content/build-course.mjs'), ...process.argv.slice(2)],
  { stdio: 'inherit' },
);
process.exit(run.status ?? 1);
