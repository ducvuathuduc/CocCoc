// Capability manifest (GET /v1/ai/capabilities): what this deployment actually enables, no secrets.
import type { AiDeps } from './deps.js';

export function capabilities(deps: AiDeps) {
  return {
    configVersion: deps.provider.configVersion,
    textTutor: true,
    nativeLive: false,
    turnSpeech: true,
    pronunciation: false,
    offlineShadowing: true,
    nativeLiveReason: 'NATIVE_LIVE_DISABLED',
    pronunciationReason: deps.provider.azureEnabled ? null : 'AZURE_DISABLED',
    liveUiMaxSeconds: 180,
    dailyLiveSessionLimit: 0,
  };
}
