import '../api_contracts.dart' as wire;
import 'api_client.dart';
import 'api_operations.g.dart';

/// Typed Learning-service operations (OpenAPI `x-owner: learning`).
final class LearningApi {
  const LearningApi(this.client);

  final ApiClient client;

  Future<wire.CoursePage> listCourses({String? cursor, int? limit}) =>
      client.call(
        ApiOperations.listCourses,
        decode: wire.CoursePage.fromJson,
        query: {'cursor': cursor, 'limit': limit},
      );

  Future<wire.CourseManifest> getManifest(String courseId, {String? version}) =>
      client.call(
        ApiOperations.getManifest,
        decode: wire.CourseManifest.fromJson,
        pathParams: {'courseId': courseId},
        query: {'version': version},
      );

  Future<wire.Enrollment> enrollCourse(
    wire.EnrollRequest request, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.enrollCourse,
    decode: wire.Enrollment.fromJson,
    body: request,
    idempotencyKey: idempotencyKey,
  );

  Future<wire.Path> getPath(String courseId, {String? cursor, int? limit}) =>
      client.call(
        ApiOperations.getPath,
        decode: wire.Path.fromJson,
        pathParams: {'courseId': courseId},
        query: {'cursor': cursor, 'limit': limit},
      );

  Future<wire.LessonBundle> getBundle(String lessonId, {String? version}) =>
      client.call(
        ApiOperations.getBundle,
        decode: wire.LessonBundle.fromJson,
        pathParams: {'lessonId': lessonId},
        query: {'version': version},
      );

  Future<wire.Session> startSession(
    wire.SessionRequest request, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.startSession,
    decode: wire.Session.fromJson,
    body: request,
    idempotencyKey: idempotencyKey,
  );

  Future<wire.Session> getSession(String sessionId) => client.call(
    ApiOperations.getSession,
    decode: wire.Session.fromJson,
    pathParams: {'sessionId': sessionId},
  );

  Future<wire.AnswerResult> submitAnswer(
    String sessionId,
    wire.AnswerRequest request, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.submitAnswer,
    decode: wire.AnswerResult.fromJson,
    pathParams: {'sessionId': sessionId},
    body: request,
    idempotencyKey: idempotencyKey,
  );

  Future<wire.Completion> completeSession(
    String sessionId,
    wire.CompleteRequest request, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.completeSession,
    decode: wire.Completion.fromJson,
    pathParams: {'sessionId': sessionId},
    body: request,
    idempotencyKey: idempotencyKey,
  );

  Future<wire.Receipt> abandonSession(
    String sessionId,
    wire.CompleteRequest request, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.abandonSession,
    decode: wire.Receipt.fromJson,
    pathParams: {'sessionId': sessionId},
    body: request,
    idempotencyKey: idempotencyKey,
  );

  Future<wire.Completion> syncOfflineCompletion(
    wire.OfflineCompletionRequest request, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.syncOfflineCompletion,
    decode: wire.Completion.fromJson,
    body: request,
    idempotencyKey: idempotencyKey ?? request.operationId,
  );

  Future<wire.ReviewPage> getReview({
    String? courseId,
    String? cursor,
    int? limit,
  }) => client.call(
    ApiOperations.getReview,
    decode: wire.ReviewPage.fromJson,
    query: {'courseId': courseId, 'cursor': cursor, 'limit': limit},
  );

  Future<wire.Receipt> createReport(
    wire.ReportRequest request, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.createReport,
    decode: wire.Receipt.fromJson,
    body: request,
    idempotencyKey: idempotencyKey,
  );
}

/// Typed Progress-service operations (OpenAPI `x-owner: progress`).
final class ProgressApi {
  const ProgressApi(this.client);

  final ApiClient client;

  Future<wire.Profile> getMe() =>
      client.call(ApiOperations.getMe, decode: wire.Profile.fromJson);

  Future<wire.Profile> updateMe(
    wire.ProfilePatch patch, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.updateMe,
    decode: wire.Profile.fromJson,
    body: patch,
    idempotencyKey: idempotencyKey,
  );

  Future<wire.Profile> initializeProfile({String? idempotencyKey}) =>
      client.call(
        ApiOperations.initializeProfile,
        decode: wire.Profile.fromJson,
        idempotencyKey: idempotencyKey,
      );

  Future<wire.Rewards> getRewards({String? completionId}) => client.call(
    ApiOperations.getRewards,
    decode: wire.Rewards.fromJson,
    query: {'completionId': completionId},
  );

  Future<wire.QuestPage> listQuests({String? cursor, int? limit}) =>
      client.call(
        ApiOperations.listQuests,
        decode: wire.QuestPage.fromJson,
        query: {'cursor': cursor, 'limit': limit},
      );

  Future<wire.Rewards> claimQuest(
    String questId,
    wire.QuestClaimRequest request, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.claimQuest,
    decode: wire.Rewards.fromJson,
    pathParams: {'questId': questId},
    body: request,
    idempotencyKey: idempotencyKey,
  );

  Future<wire.Rewards> buyFreeze({String? idempotencyKey}) => client.call(
    ApiOperations.buyFreeze,
    decode: wire.Rewards.fromJson,
    idempotencyKey: idempotencyKey,
  );

  Future<wire.PublicProfile> getPublicProfile(String userId) => client.call(
    ApiOperations.getPublicProfile,
    decode: wire.PublicProfile.fromJson,
    pathParams: {'userId': userId},
  );

  Future<wire.Receipt> followUser(
    String targetUserId, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.followUser,
    decode: wire.Receipt.fromJson,
    body: wire.FollowRequest(targetUserId: targetUserId),
    idempotencyKey: idempotencyKey,
  );

  Future<wire.Receipt> unfollowUser(String userId, {String? idempotencyKey}) =>
      client.call(
        ApiOperations.unfollowUser,
        decode: wire.Receipt.fromJson,
        pathParams: {'userId': userId},
        idempotencyKey: idempotencyKey,
      );

  Future<wire.ProfilePage> listFriends({String? cursor, int? limit}) =>
      client.call(
        ApiOperations.listFriends,
        decode: wire.ProfilePage.fromJson,
        query: {'cursor': cursor, 'limit': limit},
      );

  Future<wire.ActivityPage> listActivity({String? cursor, int? limit}) =>
      client.call(
        ApiOperations.listActivity,
        decode: wire.ActivityPage.fromJson,
        query: {'cursor': cursor, 'limit': limit},
      );

  Future<wire.League> getLeague({String? cursor, int? limit}) => client.call(
    ApiOperations.getLeague,
    decode: wire.League.fromJson,
    query: {'cursor': cursor, 'limit': limit},
  );

  Future<wire.League> joinLeague({String? idempotencyKey}) => client.call(
    ApiOperations.joinLeague,
    decode: wire.League.fromJson,
    idempotencyKey: idempotencyKey,
  );

  Future<wire.Receipt> optInFriendQuest({String? idempotencyKey}) =>
      client.call(
        ApiOperations.optInFriendQuest,
        decode: wire.Receipt.fromJson,
        idempotencyKey: idempotencyKey,
      );

  Future<wire.DeletionReceipt> deleteAccount({String? idempotencyKey}) =>
      client.call(
        ApiOperations.deleteAccount,
        decode: wire.DeletionReceipt.fromJson,
        body: const wire.DeletionRequest(),
        idempotencyKey: idempotencyKey,
      );
}

/// Typed AI-service operations (OpenAPI `x-owner: ai`).
final class AiApi {
  const AiApi(this.client);

  final ApiClient client;

  Future<wire.Capabilities> getCapabilities() => client.call(
    ApiOperations.getCapabilities,
    decode: wire.Capabilities.fromJson,
  );

  Future<wire.TutorResult> tutorFeedback(
    wire.TutorRequest request, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.tutorFeedback,
    decode: wire.TutorResult.fromJson,
    body: request,
    idempotencyKey: idempotencyKey,
  );
}
