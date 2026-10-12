import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_contracts.dart' as wire;
import '../../../core/api/client/active_course.dart';
import '../../../core/api/client/api_endpoints.g.dart';
import '../../../core/api/client/api_providers.dart';
import '../../../core/cache/snapshot_cache.dart';
import '../../../core/config/app_config.dart';
import '../domain/course_catalog.dart';

/// Node progress for the unit the path screen shows, in the screen's own
/// vocabulary (`node-<i>` ids, 8 nodes per unit, lesson index in the node).
class PathUnitProgress {
  const PathUnitProgress({
    required this.completedNodes,
    required this.currentNode,
    required this.lessonInNode,
    required this.completedLessons,
  });

  final Set<String> completedNodes;
  final int currentNode;
  final int lessonInNode;
  final int completedLessons;
}

/// Source of path progress. `null` keeps the local learning ledger (mock).
abstract interface class PathRepository {
  PathUnitProgress? unitProgress(CourseTarget target);
}

class MockPathRepository implements PathRepository {
  const MockPathRepository();

  @override
  PathUnitProgress? unitProgress(CourseTarget target) => null;
}

/// [PathRepository] over `GET /v1/courses/{courseId}/path` (P4).
///
/// Server nodes are grouped by section then unit in path order; the screen's
/// `CourseTarget(section, unit)` picks the unit-th unit of the section-th
/// section. Node states `completed`/`mastered` mark `node-<i>` complete; the
/// `current` (else first `available`) node is the screen's current node.
class ApiPathRepository implements PathRepository {
  ApiPathRepository(this.api, this.course, {SnapshotHost? host})
    : cache = SnapshotCache<List<wire.Path>>(
        key: 'path',
        host: host ?? SnapshotHost.detached(),
        decode: (json) => [
          for (final page in json['pages']! as List) wire.Path.fromJson(page),
        ],
        encode: (pages) => {
          'pages': [for (final page in pages) page.toJson()],
        },
        maxAge: const Duration(seconds: 30),
      );

  final ApiEndpoints api;
  final ActiveCourse course;
  final SnapshotCache<List<wire.Path>> cache;

  static const nodesPerUnit = 8;
  static const lessonsPerNode = 5;

  /// Every page of the path (each <= 100 nodes, as the contract allows).
  Future<List<wire.Path>> _fetch() async {
    final courseId = await course.id();
    final pages = [await api.getPath(courseId, limit: 100)];
    while (pages.last.nextCursor != null && pages.length < 20) {
      pages.add(
        await api.getPath(courseId, cursor: pages.last.nextCursor, limit: 100),
      );
    }
    return pages;
  }

  Future<void> refresh() => cache.refresh(_fetch);

  @override
  PathUnitProgress? unitProgress(CourseTarget target) {
    cache.ensureLoaded(_fetch);
    final pages = cache.value;
    if (pages == null || pages.isEmpty) return null;
    return mapUnit(pages, target);
  }

  static PathUnitProgress? mapUnit(List<wire.Path> pages, CourseTarget target) {
    final ordered = [for (final p in pages) ...p.nodes]
      ..sort((a, b) => a.order.compareTo(b.order));
    final sections = <String, List<String>>{}; // section -> unit ids in order
    final units = <String, List<wire.Node>>{};
    for (final node in ordered) {
      final list = sections.putIfAbsent(node.sectionId, () => []);
      if (!list.contains(node.unitId)) list.add(node.unitId);
      units.putIfAbsent(node.unitId, () => []).add(node);
    }
    final sectionUnits = sections.values.elementAtOrNull(target.section - 1);
    final unitId = sectionUnits?.elementAtOrNull(target.unit - 1);
    if (unitId == null) return null;
    final nodes = units[unitId]!.take(nodesPerUnit).toList();
    final done = pages.last.enrollment.completedLessonIds.toSet();
    var current = nodes.indexWhere((n) => n.state == 'current');
    if (current < 0) current = nodes.indexWhere((n) => n.state == 'available');
    if (current < 0) {
      current = nodes.every((n) => _complete(n.state)) ? nodes.length - 1 : 0;
    }
    final currentNode = nodes.isEmpty ? null : nodes[current];
    return PathUnitProgress(
      completedNodes: {
        for (var i = 0; i < nodes.length; i++)
          if (_complete(nodes[i].state)) 'node-$i',
      },
      currentNode: current.clamp(0, nodesPerUnit - 1),
      lessonInNode: (currentNode?.lessonIds.where(done.contains).length ?? 0)
          .clamp(0, lessonsPerNode - 1),
      completedLessons: done.length,
    );
  }

  static bool _complete(String state) =>
      state == 'completed' || state == 'mastered';
}

final pathRepositoryProvider = Provider<PathRepository>((ref) {
  if (!ref.watch(appConfigProvider).isApi) return const MockPathRepository();
  return ApiPathRepository(
    ref.watch(apiEndpointsProvider),
    ref.watch(activeCourseProvider),
    host: SnapshotHost.of(ref, 'path'),
  );
});
