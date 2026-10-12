// Text tutor (FR-AI-001) on the scripted provider: authored, reference-bound, <= 120 words,
// deterministic. With a scenarioId and an active conversation the learner text is one roleplay
// turn (the script answers with the partner's next line); otherwise a deterministic fallback.
import type { ReceiptOutcome } from '../../../shared/src/ports.js';
import { scenarioById } from '../domain/scenarios.js';
import { activeConversation, applyTurn } from './conversations.js';
import type { AiDeps } from './deps.js';
import { countUsage } from './usage.js';

export interface TutorInput {
  requestId: string;
  exerciseId: string | null;
  lessonVersion: string | null;
  scenarioId: string | null;
  learnerText: string;
  level: 'A1' | 'A2';
}

export async function tutorFeedback(
  deps: AiDeps,
  userId: string,
  input: TutorInput,
  bodyHash: string,
): Promise<ReceiptOutcome> {
  return deps.persistence.commitWithReceipt(
    { userId, operation: 'tutorFeedback', key: input.requestId },
    bodyHash,
    async (tx) => {
      const now = deps.nowMs();
      await countUsage(tx, userId, now, { textRequests: 1 });
      const scenario = input.scenarioId ? scenarioById(input.scenarioId) : undefined;
      const conversation = scenario
        ? await activeConversation(deps, tx, userId, { scenarioId: scenario.id })
        : null;
      if (conversation) {
        const turn = applyTurn(tx, conversation, input.learnerText, now);
        return {
          statusCode: 200,
          response: {
            requestId: input.requestId,
            tutorText: turn.reply,
            correction: turn.onTopic ? null : turn.step.expect,
            explanation: turn.onTopic ? `Tốt lắm! ${turn.step.hintVi}` : turn.step.hintVi,
            source: 'authored',
            assessedPronunciation: false,
          },
        };
      }
      return {
        statusCode: 200,
        response: {
          requestId: input.requestId,
          tutorText: input.learnerText.trim()
            ? 'Good try! Keep your sentence short and clear, and check the example answer.'
            : 'Write a short sentence in English and I will help you.',
          correction: null,
          explanation: 'Hãy so sánh câu của bạn với đáp án mẫu trong bài học.',
          source: 'fallback',
          assessedPronunciation: false,
        },
      };
    },
  );
}
