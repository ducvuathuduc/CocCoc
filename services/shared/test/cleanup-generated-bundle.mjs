import { unlinkSync } from 'node:fs';
import path from 'node:path';

const generatedBundles = new Set();
let cleanupScheduled = false;

export function cleanupGeneratedBundleOnExit(outfile) {
  const absolutePath = path.resolve(outfile);
  if (!absolutePath.split(path.sep).includes('.cache')) {
    throw new Error('Generated test bundles must live under a .cache directory');
  }

  generatedBundles.add(absolutePath);
  if (cleanupScheduled) return;
  cleanupScheduled = true;

  process.once('exit', () => {
    for (const bundle of generatedBundles) {
      try {
        unlinkSync(bundle);
      } catch (error) {
        if (error?.code !== 'ENOENT') continue;
      }
    }
  });
}
