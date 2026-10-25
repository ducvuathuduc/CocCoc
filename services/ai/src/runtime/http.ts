import main from '../index.js';
import { runHttpProcess } from '../../../shared/src/runtime-http.js';

await runHttpProcess(main, { service: 'ai' });
