import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_exception.dart';
import 'api_endpoints.g.dart';
import 'api_providers.dart';

/// Resolves (once) the course the learner studies: the first available course
/// from `GET /v1/courses`. Shared by path, words, mistakes and conversations.
final class ActiveCourse {
  ActiveCourse(this.api, {String? fixed}) : _resolved = fixed;

  final ApiEndpoints api;
  String? _resolved;
  Future<String>? _inflight;

  Future<String> id() async {
    final known = _resolved;
    if (known != null) return known;
    return _inflight ??= _resolve().whenComplete(() => _inflight = null);
  }

  Future<String> _resolve() async {
    final page = await api.listCourses();
    final course = page.items.where((c) => c.available).firstOrNull;
    if (course == null) {
      throw const ApiException(
        code: 'NO_COURSE',
        message: 'No available course',
        statusCode: 404,
      );
    }
    return _resolved = course.courseId;
  }
}

final activeCourseProvider = Provider<ActiveCourse>(
  (ref) => ActiveCourse(ref.watch(apiEndpointsProvider)),
);
