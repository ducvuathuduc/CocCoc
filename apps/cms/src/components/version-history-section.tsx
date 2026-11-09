import { VersionHistory } from '@/components/version-history';
import { getContentVersions } from '@/server/actions/lifecycle';
import { config } from '@/server/config';
import { hint } from '@/lib/ui';
import { cn } from '@/lib/utils';

/**
 * Server wrapper: reads the live version history from Learning (maintainer-only admin route) and
 * hands it to the interactive client list. In file mode, or when the shared project is unreachable,
 * it shows a plain note instead of an error — version history is a shared-server feature.
 */
export async function VersionHistorySection({ courseId }: { courseId: string }) {
  const publishAllowed = config().publishAllowed;
  const result = await getContentVersions(courseId);
  if (!result.ok || !result.versions) {
    return <p className={cn(hint)}>{result.message ?? 'Chưa lấy được lịch sử bản.'}</p>;
  }
  return (
    <VersionHistory
      courseId={courseId}
      versions={result.versions}
      publishAllowed={publishAllowed}
    />
  );
}
