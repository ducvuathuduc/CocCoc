import 'dart:async';

import 'package:cocenglish/core/api/client/service_apis.dart';
import 'package:cocenglish/features/report/data/api_issue_report_repository.dart';
import 'package:cocenglish/features/report/domain/issue_report.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_api_transport.dart';

void main() {
  const route = 'POST /v1/reports';
  const report = IssueReport(
    exerciseId: 'exercise-1',
    category: 'The audio is missing.',
  );

  test('sends the current lesson version and category to Learning', () async {
    final transport = FakeApiTransport();
    transport.on(
      route,
      (request) => jsonResponse({
        'operationId': request.headers['Idempotency-Key'],
        'status': 'accepted',
        'requestId': 'request-1',
      }, status: 202),
    );
    final repo = ApiIssueReportRepository(
      LearningApi(fakeClient(transport)),
      lessonVersion: () => 'v2',
    );

    expect(await repo.submit(report), isTrue);
    expect(bodyOf(transport.requests.single), {
      'exerciseId': 'exercise-1',
      'lessonVersion': 'v2',
      'category': 'AUDIO',
      'note': 'The audio is missing.',
    });
  });

  test(
    'retries the same report with the original key and coalesces taps',
    () async {
      final transport = FakeApiTransport();
      final reply = Completer<void>();
      transport.on(route, (request) async {
        await reply.future;
        return jsonResponse(errorEnvelope('UNAVAILABLE'), status: 503);
      });
      final repo = ApiIssueReportRepository(
        LearningApi(fakeClient(transport)),
        lessonVersion: () => 'v2',
      );
      final first = repo.submit(report);
      final second = repo.submit(report);
      reply.complete();
      expect(await first, isFalse);
      expect(await second, isFalse);
      expect(transport.requests.length, 1);
      final key = transport.requests.single.headers['Idempotency-Key'];
      transport.on(
        route,
        (request) => jsonResponse({
          'operationId': request.headers['Idempotency-Key'],
          'status': 'replayed',
          'requestId': 'request-2',
        }, status: 202),
      );
      expect(await repo.submit(report), isTrue);
      expect(transport.requests.last.headers['Idempotency-Key'], key);
    },
  );

  test(
    'does not send without a known session version or known category',
    () async {
      final transport = FakeApiTransport();
      final repo = ApiIssueReportRepository(
        LearningApi(fakeClient(transport)),
        lessonVersion: () => null,
      );
      expect(await repo.submit(report), isFalse);
      expect(transport.requests, isEmpty);
    },
  );

  test(
    'rejects unknown categories and late responses after account changes',
    () async {
      final transport = FakeApiTransport();
      final gate = Completer<void>();
      var current = true;
      transport.on(route, (request) async {
        await gate.future;
        return jsonResponse({
          'operationId': request.headers['Idempotency-Key'],
          'status': 'accepted',
          'requestId': 'request-1',
        }, status: 202);
      });
      final repo = ApiIssueReportRepository(
        LearningApi(fakeClient(transport)),
        lessonVersion: () => 'v2',
        isCurrent: () => current,
      );
      expect(
        await repo.submit(
          const IssueReport(exerciseId: 'exercise-1', category: 'unknown'),
        ),
        isFalse,
      );
      expect(transport.requests, isEmpty);
      final result = repo.submit(report);
      current = false;
      gate.complete();
      expect(await result, isFalse);
    },
  );

  test('does not accept an unrelated server receipt', () async {
    final transport = FakeApiTransport();
    transport.json(route, {
      'operationId': 'other-operation',
      'status': 'accepted',
      'requestId': 'request-1',
    }, status: 202);
    final repo = ApiIssueReportRepository(
      LearningApi(fakeClient(transport)),
      lessonVersion: () => 'v2',
    );
    expect(await repo.submit(report), isFalse);
  });
}
