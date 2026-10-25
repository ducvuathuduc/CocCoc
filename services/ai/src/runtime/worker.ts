import main from '../index.js';
import { runWorkerProcess } from '../../../shared/src/runtime-worker.js';

runWorkerProcess(main, { service: 'ai' });
