'use server';

import { LESSON_IMAGE_SIZE, isAdtsAac, webpSize } from '@/cms/media-format';
import type { MediaSpec } from '@/cms/media';
import { assertSafeId, courseAssets, writeMediaFile } from '../media-service';
import { recordAudit } from '../audit';
import { assertAdmin } from '../session';

/** A lesson clip is a few kilobytes; the caps are there to stop one mistaken movie file filling the repo. */
const MAX_BYTES = { audio: 8 * 1024 * 1024, image: 4 * 1024 * 1024 };

export interface SavedMedia {
  fileId: string;
  bytes: number;
  sha256: string;
  overwritten: boolean;
}

export interface UploadBatchResult {
  ok: boolean;
  saved: SavedMedia[];
  rejected: { name: string; message: string }[];
  message?: string;
  warning?: string;
}

interface Check {
  ok: boolean;
  message?: string;
}

/** Refuse bytes that are not what the bundle claims, before they land next to real assets. */
function checkFormat(spec: MediaSpec, bytes: Uint8Array): Check {
  if (bytes.byteLength === 0) return { ok: false, message: 'File rỗng.' };
  if (bytes.byteLength > MAX_BYTES[spec.kind])
    return {
      ok: false,
      message: `File lớn ${(bytes.byteLength / 1024 / 1024).toFixed(1)} MB, vượt trần ${MAX_BYTES[spec.kind] / 1024 / 1024} MB cho ${spec.kind === 'audio' ? 'clip' : 'ảnh'}.`,
    };
  if (spec.kind === 'audio')
    return isAdtsAac(bytes)
      ? { ok: true }
      : { ok: false, message: 'Không phải AAC/ADTS — app phát mime `audio/aac` như audio-manifest.' };
  const size = webpSize(bytes);
  if (!size) return { ok: false, message: 'Không phải ảnh WebP (thiếu RIFF/WEBP).' };
  if (size.width !== LESSON_IMAGE_SIZE || size.height !== LESSON_IMAGE_SIZE)
    return {
      ok: false,
      message: `Ảnh ${size.width}×${size.height}, trong khi bộ dựng khai mọi ảnh là ${LESSON_IMAGE_SIZE}×${LESSON_IMAGE_SIZE} (build-course.mjs:216) — render lại bằng tools/content/lesson_art/render.py.`,
    };
  return { ok: true };
}

/**
 * Files one batch of media into `content/<courseId>/media/`, the tree publish uploads from. The slot a
 * file fills comes from its own name, and only names the units of this course actually ask for are
 * accepted, so an upload cannot invent a media id — and after a reorder the old number is no longer in
 * the index, which is exactly when the maintainer needs to be told the clip moved.
 *
 * The browser sends several small files at a time and one call at a time, so the action reads the asset
 * index once per batch and the body never nears `serverActions.bodySizeLimit`.
 */
export async function uploadMedia(
  courseId: string,
  form: FormData,
): Promise<UploadBatchResult> {
  const actor = await assertAdmin();
  const files = form.getAll('files').filter((f): f is File => f instanceof File && f.size >= 0);
  if (!files.length) return { ok: false, saved: [], rejected: [], message: 'Chưa chọn file nào.' };
  const overwrite = form.get('overwrite') === '1';
  let index: Map<string, MediaSpec>;
  try {
    index = await courseAssets(assertSafeId(courseId, 'courseId'));
  } catch (error) {
    return {
      ok: false,
      saved: [],
      rejected: [],
      message: error instanceof Error ? error.message : 'Không mở được kho media của khóa.',
    };
  }

  const saved: SavedMedia[] = [];
  const rejected: UploadBatchResult['rejected'] = [];
  for (const file of files) {
    const name = (file.name ?? '').trim();
    const lower = name.toLowerCase();
    const dot = lower.lastIndexOf('.');
    const base = dot > 0 ? lower.slice(0, dot) : lower;
    const spec = index.get(base);
    if (!spec) {
      rejected.push({
        name,
        message: 'Không phải tài nguyên khóa này hỏi (kiểu a.<uNN>.<dòng>.n/.s, a.w.<từ>.n, i.<uNN>.<từ>).',
      });
      continue;
    }
    if (dot <= 0 || lower.slice(dot + 1) !== spec.ext) {
      rejected.push({ name, message: `Tên phải là ${spec.fileId}.${spec.ext}.` });
      continue;
    }
    const bytes = new Uint8Array(await file.arrayBuffer());
    const format = checkFormat(spec, bytes);
    if (!format.ok) {
      rejected.push({ name, message: format.message ?? 'File không hợp lệ.' });
      continue;
    }
    try {
      const written = await writeMediaFile(courseId, spec, bytes, overwrite);
      saved.push({
        fileId: written.fileId,
        bytes: written.bytes,
        sha256: written.sha256,
        overwritten: written.overwritten,
      });
    } catch (error) {
      rejected.push({ name, message: error instanceof Error ? error.message : 'Không ghi được file.' });
    }
  }

  const warning = saved.length
    ? await recordAudit({
        actorId: actor.userId,
        operation: 'media.upload',
        targetId: `${courseId}/${saved[0].fileId}`,
        afterJson: JSON.stringify(saved),
      })
    : null;
  return { ok: rejected.length === 0, saved, rejected, warning: warning ?? undefined };
}
