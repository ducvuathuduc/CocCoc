import { unitAssets, type UnitAsset } from '@/server/media-service';
import { generatorUnitId } from '@/cms/media';
import type { UnitDraft } from '@/cms/types';
import { card, code, hint } from '@/lib/ui';
import { cn } from '@/lib/utils';
import { MediaBrowser, type MediaRow } from './media-browser';
import { MediaUpload } from './media-upload';
import { TechDetails } from './tech-details';

/**
 * Four different situations used to print as one "thiếu" number. They are not the same work: one
 * needs a file uploaded, one needs a re-record, one needs no action at all.
 */
const stateOf = (asset: UnitAsset): MediaRow['state'] => {
  if (asset.drift) return 'stale';
  if (!asset.present) return 'missing';
  if (asset.kind === 'audio' && asset.manifest !== 'real') return 'unreadable';
  if (asset.unused) return 'unused';
  if (asset.kind === 'image' && !asset.drilledWithPicture) return 'unasked';
  return 'ready';
};

const noteOf = (asset: UnitAsset, state: MediaRow['state']): string => {
  switch (state) {
    case 'stale':
      return 'Bạn đã sửa lời thoại, file thu âm vẫn là lời cũ. Cần thu lại dòng này.';
    case 'unreadable':
      return 'File đã có nhưng app chưa phát được: danh mục âm thanh của bản dựng chưa ghi dòng này. Không cần thu lại — bản dựng kế tiếp sẽ ghi nhận.';
    case 'missing':
      return 'Chưa có file nào trên máy cho dòng này.';
    case 'unused':
      return 'Ảnh đã có file, nhưng không bài tập nào của bài dùng tới. Không cần nạp thêm gì.';
    case 'unasked':
      return 'Ảnh đã có file và bài chở nó, nhưng chưa câu hỏi chọn ảnh nào đố tới từ này.';
    default:
      return 'File đã đủ và app đọc được.';
  }
};

/** The two speeds of one line are one row: an author hears "câu 7" and its turtle version together. */
function mediaRows(assets: UnitAsset[]): MediaRow[] {
  const rows = new Map<string, MediaRow>();
  for (const asset of assets) {
    if (asset.kind === 'image') {
      const state = stateOf(asset);
      rows.set(asset.fileId, {
        key: asset.fileId,
        kind: 'image',
        label: asset.label,
        text: asset.text,
        state,
        note: noteOf(asset, state),
        slow: null,
      });
      continue;
    }
    const key = asset.fileId.replace(/\.[ns]$/, '');
    const state = stateOf(asset);
    const existing = rows.get(key);
    if (!existing) {
      rows.set(key, {
        key,
        kind: 'audio',
        label: asset.label,
        text: asset.text,
        state,
        note: noteOf(asset, state),
        slow: asset.speed === 0.75 ? asset.present : null,
      });
      continue;
    }
    if (asset.speed === 0.75) existing.slow = asset.present;
    // A row is only as ready as its worst take.
    if (state !== 'ready' && existing.state === 'ready') {
      existing.state = state;
      existing.note = noteOf(asset, state);
    }
  }
  return [...rows.values()];
}

/** Exercise types the generator names, in the words an author uses. Unknown types print as they are. */
const EXERCISE_LABEL: Record<string, string> = {
  imageChoice: 'chọn ảnh',
  choice: 'chọn chữ',
  choiceViEn: 'chọn chữ (Việt → Anh)',
  choiceEnVi: 'chọn chữ (Anh → Việt)',
  dialogueTurn: 'lượt thoại',
  speakRepeat: 'lặp câu',
  listenChoice: 'nghe và chọn',
  wordBank: 'xếp từ',
  wordBankVi: 'xếp từ (Việt)',
  sentenceOrder: 'sắp xếp câu',
  fillBlank: 'điền vào chỗ trống',
  translateViEn: 'dịch Việt → Anh',
  translateEnVi: 'dịch Anh → Việt',
  matchPairs: 'nối cặp',
  dictation: 'chép chính tả',
  storyQuestion: 'hỏi truyện',
  newWord: 'từ mới',
};

export async function UnitMedia({
  courseId,
  version,
  order,
  draft,
}: {
  courseId: string;
  version: string;
  order: number;
  draft: UnitDraft;
}) {
  const genUnitId = generatorUnitId(order);
  const { assets, catalogSize, exerciseTypes } = await unitAssets(
    courseId,
    version,
    order,
    draft,
  );
  const rows = mediaRows(assets);
  const missing = rows.filter((r) => r.state === 'missing');
  const stale = rows.filter((r) => r.state === 'stale');
  const unreadable = rows.filter((r) => r.state === 'unreadable');
  const unused = rows.filter((r) => r.state === 'unused' || r.state === 'unasked');
  const fromBuild = assets.filter((a) => a.fromBuild).length;
  const builtList = Object.entries(exerciseTypes)
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .map(([type, count]) => `${EXERCISE_LABEL[type] ?? type} ${count}`)
    .join(' · ');

  return (
    <div className="space-y-3">
      <MediaBrowser courseId={courseId} rows={rows} />

      <details className={cn(card, 'px-4 py-3')}>
        <summary className="cursor-pointer text-sm font-medium">
          Nạp file âm thanh hoặc ảnh cho bài này
        </summary>
        <p className={cn(hint, 'mt-2')}>
          File nạp vào sẽ thay file cũ cùng tên. Danh sách trên đổi ngay sau khi trang tải lại.
        </p>
        <div className="mt-3">
          <MediaUpload courseId={courseId} />
        </div>
        <TechDetails title="Cách tạo file hàng loạt" className="mt-3">
          <p>
            Danh sách này do máy dựng suy ra theo quy tắc của{' '}
            <code className={code}>build-course.mjs</code> (đánh số theo vị trí) từ{' '}
            <code className={code}>{genUnitId}</code> của bản nháp đã lưu. Clip từ vựng thì khác:
            app tự suy id từ chữ trên ô bài tập, nên chỉ bản dựng mới biết hết chúng
            {fromBuild > 0 ? ` — ${fromBuild} clip từ vựng đang lấy từ bản dựng gần nhất` : ''}
            {catalogSize === 0
              ? '. Chưa có audio-catalog.json của bản dựng — transcript lấy từ nháp.'
              : '.'}
          </p>
          {builtList && (
            <p>
              Bản dựng gần nhất thực sự sinh cho bài này: {builtList}.{' '}
              <code className={code}>build-course.mjs</code> đổi dạng bài khi nội dung chưa đủ điều
              kiện — <code className={code}>imageChoice</code> thành bài chọn chữ khi chưa có 4 ảnh
              đã giới thiệu (dòng 918-925), <code className={code}>dialogueTurn</code> thành bài lặp
              câu khi chưa có 3 câu trả lời khác nhau (dòng 928-944) — nên đây là thứ app hiện ra,
              không phải thứ nháp yêu cầu.
            </p>
          )}
          {missing.length > 0 && (
            <p>
              File thiếu nằm trong <code className={code}>content/{courseId}/media/</code>. Tạo bằng{' '}
              <code className={code}>node tools/content/generate-audio.mjs --check</code> (danh sách
              clip cần TTS) và{' '}
              <code className={code}>python3 tools/content/lesson_art/render.py</code> (ảnh minh
              họa), rồi chạy lại bộ kiểm tra nội dung.
            </p>
          )}
          {unreadable.length > 0 && (
            <p>
              {unreadable.length} clip đã có file nhưng <code className={code}>
                audio-manifest.json
              </code>{' '}
              chưa ghi chúng, nên <code className={code}>build-course.mjs:117</code> không lấy được
              hash — chạy{' '}
              <code className={code}>
                node tools/content/generate-audio.mjs --only a. --course {courseId}
              </code>{' '}
              rồi dựng lại. Không cần thu âm gì thêm.
            </p>
          )}
          {stale.length > 0 && (
            <p>
              Thứ tự đúng cho {stale.length} dòng lệch lời:{' '}
              <code className={code}>node tools/content/build-course.mjs --course {courseId}</code>{' '}
              để cập nhật <code className={code}>dist/{version}/audio-catalog.json</code>, rồi{' '}
              <code className={code}>
                node tools/content/generate-audio.mjs --course {courseId} --version {version}
              </code>{' '}
              để thu lại. Bản dựng lấy sha256/độ dài clip từ{' '}
              <code className={code}>audio-manifest.json</code>{' '}
              (<code className={code}>build-course.mjs:117</code>), nên cần chạy thêm{' '}
              <code className={code}>
                node tools/content/generate-audio.mjs --only a.
              </code>{' '}
              trước khi hash thật thay placeholder.
            </p>
          )}
          {unused.length > 0 && (
            <p>
              Ảnh có file nhưng chưa câu nào đố:{' '}
              {unused
                .slice(0, 6)
                .map((r) => r.key)
                .join(', ')}
              {' — ngưỡng sinh imageChoice là build-course.mjs:918-925. Cách sửa thuộc về nội dung: '}
              thêm từ có ảnh vào bảng từ vựng rồi dựng lại khóa.
            </p>
          )}
        </TechDetails>
      </details>
    </div>
  );
}
