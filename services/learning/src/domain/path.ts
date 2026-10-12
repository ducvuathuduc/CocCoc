// Course frontier rules (FR-COURSE-002, FR-PATH-001/002). Pure functions over the manifest and
// the enrollment projection. The frontier only moves forward.
import { ServiceError } from '../../../shared/src/errors.js';
import type { ContentNode, CourseManifest } from '../content/types.js';

export type NodeState = 'locked' | 'available' | 'current' | 'completed' | 'mastered';

export interface EnrollmentView {
  frontierNodeOrder: number;
  completedLessonIds: string[];
  masteredNodeIds: string[];
}

export function sortedNodes(manifest: CourseManifest): ContentNode[] {
  return [...manifest.nodes].sort((a, b) => a.order - b.order);
}

export function nodeOfLesson(manifest: CourseManifest, lessonId: string): ContentNode | undefined {
  return manifest.nodes.find((node) => node.lessonIds.includes(lessonId));
}

export function nodeState(node: ContentNode, enrollment: EnrollmentView): NodeState {
  if (enrollment.masteredNodeIds.includes(node.nodeId)) return 'mastered';
  if (node.order < enrollment.frontierNodeOrder) return 'completed';
  if (node.order === enrollment.frontierNodeOrder) {
    return node.lessonIds.some((id) => enrollment.completedLessonIds.includes(id))
      ? 'current'
      : 'available';
  }
  return 'locked';
}

function currentNode(
  manifest: CourseManifest,
  enrollment: EnrollmentView,
): ContentNode | undefined {
  return sortedNodes(manifest).find((node) => node.order >= enrollment.frontierNodeOrder);
}

function locked(manifest: CourseManifest, enrollment: EnrollmentView): never {
  throw new ServiceError('NODE_LOCKED', {
    message: 'Complete the previous node first.',
    details: { currentNodeId: currentNode(manifest, enrollment)?.nodeId ?? null },
  });
}

/** A lesson may start when its node is behind the frontier, or it is next inside the frontier node. */
export function assertLessonUnlocked(
  manifest: CourseManifest,
  enrollment: EnrollmentView,
  lessonId: string,
): ContentNode {
  const node = nodeOfLesson(manifest, lessonId);
  if (!node) throw new ServiceError('NOT_FOUND', { details: { lessonId } });
  if (node.order < enrollment.frontierNodeOrder) return node;
  if (node.order > enrollment.frontierNodeOrder) locked(manifest, enrollment);
  const index = node.lessonIds.indexOf(lessonId);
  const earlier = node.lessonIds.slice(0, index);
  if (earlier.some((id) => !enrollment.completedLessonIds.includes(id)))
    locked(manifest, enrollment);
  return node;
}

/** Mastery challenge only on a node whose lessons are complete. */
export function assertMasteryUnlocked(
  manifest: CourseManifest,
  enrollment: EnrollmentView,
  lessonId: string,
): ContentNode {
  const node = nodeOfLesson(manifest, lessonId);
  if (!node) throw new ServiceError('NOT_FOUND', { details: { lessonId } });
  if (node.order >= enrollment.frontierNodeOrder) locked(manifest, enrollment);
  return node;
}

/** Record a completed lesson; advance the frontier past nodes whose lessons are all complete. */
export function completeLesson(
  manifest: CourseManifest,
  enrollment: EnrollmentView,
  lessonId: string,
): EnrollmentView {
  const completed = enrollment.completedLessonIds.includes(lessonId)
    ? enrollment.completedLessonIds
    : [...enrollment.completedLessonIds, lessonId];
  let frontier = enrollment.frontierNodeOrder;
  for (const node of sortedNodes(manifest)) {
    if (node.order < frontier) continue;
    if (node.order === frontier && node.lessonIds.every((id) => completed.includes(id))) {
      const next = sortedNodes(manifest).find((n) => n.order > node.order);
      frontier = next ? next.order : node.order + 1;
      continue;
    }
    break;
  }
  return {
    ...enrollment,
    completedLessonIds: completed,
    frontierNodeOrder: Math.max(frontier, enrollment.frontierNodeOrder),
  };
}

/** Frontier for a placement result: the first node of the second unit, or the start. */
export function placementFrontier(manifest: CourseManifest, passed: boolean): number {
  const nodes = sortedNodes(manifest);
  const first = nodes[0]?.order ?? 0;
  if (!passed) return first;
  const secondUnit = manifest.sections.flatMap((section) => section.unitIds)[1];
  const target = nodes.find((node) => node.unitId === secondUnit);
  return target ? target.order : first;
}
