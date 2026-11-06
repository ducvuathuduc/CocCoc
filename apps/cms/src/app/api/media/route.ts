import { NextResponse, type NextRequest } from 'next/server';
import { assertAdmin } from '@/server/session';
import { readMedia, type MediaPayload } from '@/server/media-service';

/**
 * Serves one repo media file to the admin preview. Content is authored against asset ids that the app
 * will later fetch from a public bucket, so the CMS shows the same bytes through its own session rather
 * than opening the bucket early.
 */
export async function GET(request: NextRequest): Promise<Response> {
  try {
    await assertAdmin();
  } catch {
    return NextResponse.json({ error: 'Cần đăng nhập để xem media.' }, { status: 401 });
  }

  const courseId = request.nextUrl.searchParams.get('course') ?? '';
  const fileId = request.nextUrl.searchParams.get('file') ?? '';
  if (!courseId || !fileId)
    return NextResponse.json({ error: 'Thiếu course hoặc file.' }, { status: 400 });

  let media: MediaPayload | null;
  try {
    media = await readMedia(courseId, fileId);
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Đường dẫn không hợp lệ.' },
      { status: 400 },
    );
  }
  if (!media) return NextResponse.json({ error: 'Không có file này trong repo.' }, { status: 404 });

  return new Response(new Blob([media.body], { type: media.mime }), {
    headers: {
      'Content-Length': String(media.body.byteLength),
      'Cache-Control': 'private, max-age=30',
      'Cross-Origin-Resource-Policy': 'same-origin',
    },
  });
}
