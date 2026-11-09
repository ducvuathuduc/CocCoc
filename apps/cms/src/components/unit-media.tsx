import { unitAssets, type UnitAsset } from '@/server/media-service';
import type { UnitDraft } from '@/cms/types';
import { card, hint } from '@/lib/ui';
import { cn } from '@/lib/utils';
import { MediaBrowser, type MediaRow } from './media-browser';
import { MediaUpload } from './media-upload';

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
  const { assets } = await unitAssets(courseId, version, order, draft);
  const rows = mediaRows(assets);

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
      </details>
    </div>
  );
}
