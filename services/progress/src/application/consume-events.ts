// [VI] BỘ NHẬN EVENT CỦA PROGRESS — "hộp thư đến" nơi Progress xử lý thư từ các service khác.
// Luồng: Learning ghi event "bài học đã xong" ra outbox → relay ký HMAC gửi qua → file này xử lý.
//
// 3 loại event nhận được:
//  • lesson.completed.v1   — user xong 1 bài học. Inbox row + MỌI hiệu ứng thưởng (sổ XP,
//    streak ngày, tổng, quest, league, achievement, notification) commit trong MỘT transaction.
//    Thư bị giao 2 lần → lần 2 thấy eventId trùng trong inbox → bỏ qua (không cộng XP đôi).
//    Cùng eventId nhưng payload khác → IDEMPOTENCY_CONFLICT (báo động, không im lặng).
//  • ai.practice.completed.v1 — công PRACTICE cho 1 buổi Roleplay/Video Call xong,
//    cùng tính nguyên tử & once-per-event như trên (application/practice.ts).
//  • account.purged.v1     — ghi nhận "đã nhận lệnh xóa tài khoản"; việc xóa thật chạy
//    trong các transaction tiếp theo có giới hạn (application/deletion.ts).
import { ServiceError } from '../../../shared/src/errors.js';
import type { BusinessEvent, EventConsumer } from '../../../shared/src/ports.js';
import { validateGraded } from '../domain/lesson-xp.js';
import { PRACTICE_KINDS, PRACTICE_MAX_EVENT_XP } from '../domain/practice-xp.js';
import type { ProgressPersistence } from '../persistence/port.js';
import { purgeDeletedAccount, recordPurgeAck } from './deletion.js';
import { applyPracticeCompletion, type PracticeEvent } from './practice.js';
import { applyLessonCompletion, type CompletionEvent } from './rewards.js';

type PurgeEvent = Extract<BusinessEvent, { type: 'account.purged.v1' }>;
const ID = /^[A-Za-z0-9][A-Za-z0-9_.-]{0,35}$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const LESSON_KEYS = [
  'completionId',
  'userId',
  'courseId',
  'lessonVersion',
  'rewardIdentity',
  'source',
  'mode',
  'originalCount',
  'originalCorrect',
  'assisted',
];

function invalid(reason: string): never {
  throw new ServiceError('VALIDATION_ERROR', { details: { reason } });
}

/** [VI] Kiểm tra event bài học: payload chỉ được chứa đúng các trường đã biết —
 * xuất hiện MỘT trường lạ là từ chối toàn bộ (UNKNOWN_FIELD). Đây là strict validation:
 * với dữ liệu từ service khác, thà chặt chém còn hơn bị tấn công bằng trường bất ngờ. */
function checkLesson(event: CompletionEvent): void {
  const p = event.payload as unknown as Record<string, unknown>;
  if (Object.keys(p).some((key) => !LESSON_KEYS.includes(key))) invalid('UNKNOWN_FIELD');
  // [VI] 5 trường id phải là string hợp regex ID — chặn id rỗng / ký tự lạ / quá dài
  for (const key of ['completionId', 'userId', 'courseId', 'lessonVersion', 'rewardIdentity']) {
    if (typeof p[key] !== 'string' || !ID.test(p[key])) invalid('INVALID_IDENTIFIER');
  }
  // [VI] Nếu event khai có điểm (graded) thì validate thêm logic điểm ở domain/lesson-xp.ts
  const graded = validateGraded(event.payload);
  if (graded && !graded.ok) invalid(graded.reason);
}

const PRACTICE_KEYS = [
  'completionId',
  'userId',
  'kind',
  'courseId',
  'scenarioId',
  'xp',
  'wordsUsed',
  'stars',
];
const isInt = (value: unknown, min: number, max: number) =>
  Number.isInteger(value) && (value as number) >= min && (value as number) <= max;

/** [VI] Kiểm tra event practice (AI gửi khi user xong buổi luyện nói): cùng strict style —
 * chỉ trường đã biết, id hợp lệ, số nguyên trong khoảng cho phép (xp 0..max, stars 0..3). */
function checkPractice(event: PracticeEvent): void {
  const p = event.payload as unknown as Record<string, unknown>;
  if (!p || typeof p !== 'object') invalid('INVALID_PRACTICE');
  if (Object.keys(p).some((key) => !PRACTICE_KEYS.includes(key))) invalid('UNKNOWN_FIELD');
  for (const key of ['completionId', 'userId', 'courseId', 'scenarioId']) {
    if (typeof p[key] !== 'string' || !ID.test(p[key])) invalid('INVALID_IDENTIFIER');
  }
  // [VI] AI phải key event theo user sở hữu: userId trong payload phải trùng aggregateId
  // (aggregateId là "chủ sở hữu" của event) — chặn event ghi công nhầm người khác.
  if (p['userId'] !== event.aggregateId) invalid('AGGREGATE_MISMATCH');
  if (!(PRACTICE_KINDS as readonly unknown[]).includes(p['kind'])) invalid('INVALID_PRACTICE');
  if (
    !isInt(p['xp'], 0, PRACTICE_MAX_EVENT_XP) ||
    !isInt(p['wordsUsed'], 0, 2147483647) ||
    !isInt(p['stars'], 0, 3)
  ) {
    invalid('INVALID_PRACTICE');
  }
}

export interface ConsumerOptions {
  /** Run the purge right after the last owner acknowledgement (default true). */
  purgeAfterAck?: boolean;
}

/** [VI] Tạo consumer: hàm consume() được transport gọi cho MỖI event đến.
 * Đây là "cửa hải quan": validate chặt → rồi mới đưa vào transaction nguyên tử. */
export function createProgressEventConsumer(
  store: ProgressPersistence,
  options: ConsumerOptions = {},
): EventConsumer {
  return {
    async consume(event, context) {
      // [VI] bodyHash dùng làm "vân tay" của event: cùng eventId + khác vân tay = payload bị
      // đổi giữa chừng → inbox sẽ phát hiện và báo IDEMPOTENCY_CONFLICT.
      const entry = { eventId: event.eventId, type: event.type, bodyHash: context.bodyHash };
      if (event.type === 'lesson.completed.v1') {
        const completion = event as CompletionEvent;
        checkLesson(completion);
        // [VI] applyInboxEvent = ghi dòng inbox VÀ chạy applyLessonCompletion trong CÙNG một
        // transaction. Thành công → cả sổ thư và thưởng cùng được lưu. Thất bại → cùng rollback.
        // Thư giao lại lần 2 → thấy eventId trong inbox → replay an toàn, không cộng thưởng đôi.
        return store.applyInboxEvent(entry, (tx) => applyLessonCompletion(tx, completion));
      }
      if (event.type === 'ai.practice.completed.v1') {
        const practice = event as PracticeEvent;
        checkPractice(practice);
        return store.applyInboxEvent(entry, (tx) => applyPracticeCompletion(tx, practice));
      }
      if (event.type === 'account.purged.v1') {
        const { payload } = event as PurgeEvent;
        if (
          typeof payload?.userId !== 'string' ||
          !ID.test(payload.userId) ||
          typeof payload.requestId !== 'string' ||
          !UUID.test(payload.requestId) ||
          (payload.owner !== 'learning' && payload.owner !== 'ai') ||
          payload.owner !== event.producer
        ) {
          invalid('INVALID_PURGE_ACK');
        }
        const status = await store.applyInboxEvent(entry, (tx) => recordPurgeAck(tx, payload));
        if (options.purgeAfterAck !== false) await purgeDeletedAccount(store, payload.userId);
        return status;
      }
      throw new ServiceError('SERVICE_NOT_CONFIGURED');
    },
  };
}
