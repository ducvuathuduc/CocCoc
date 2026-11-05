// GENERATED CODE - DO NOT EDIT BY HAND.
// Source: docs/api/openapi.yaml (sha256 64f4993f049da84184d4fac4c0d5ad558907061d2ca688aff6a4f919b12a7c00).
// Generator: apps/mobile/tool/gen_api_operations.py

import '../api_contracts.dart' as wire;
import 'api_client.dart';
import 'api_operations.g.dart';

/// Typed call for every client-callable OpenAPI operation. Responses are
/// schema-validated DTOs; idempotent commands accept a caller key.
final class ApiEndpoints {
  const ApiEndpoints(this.client);

  final ApiClient client;

  /// `GET /v1/activities`
  Future<wire.ActivityProgressPage> listActivityProgress({
    String? courseId,
    String? kind,
    String? cursor,
    int? limit,
  }) => client.call(
    ApiOperations.listActivityProgress,
    decode: wire.ActivityProgressPage.fromJson,
    query: {
      'courseId': courseId,
      'kind': kind,
      'cursor': cursor,
      'limit': limit,
    },
  );

  /// `GET /v1/activity`
  Future<wire.ActivityPage> listActivity({String? cursor, int? limit}) =>
      client.call(
        ApiOperations.listActivity,
        decode: wire.ActivityPage.fromJson,
        query: {'cursor': cursor, 'limit': limit},
      );

  /// `POST /v1/ad-events`
  Future<wire.AdEvent> recordAdEvent(
    wire.AdEventRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.recordAdEvent,
    decode: wire.AdEvent.fromJson,
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `GET /v1/ai/capabilities`
  Future<wire.Capabilities> getCapabilities() => client.call(
    ApiOperations.getCapabilities,
    decode: wire.Capabilities.fromJson,
  );

  /// `POST /v1/assessment-jobs`
  Future<wire.Assessment> createAssessment(
    wire.AssessmentRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.createAssessment,
    decode: wire.Assessment.fromJson,
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `GET /v1/assessment-jobs/{jobId}`
  Future<wire.Assessment> getAssessment(String jobId) => client.call(
    ApiOperations.getAssessment,
    decode: wire.Assessment.fromJson,
    pathParams: {'jobId': jobId},
  );

  /// `POST /v1/billing/purchases`
  Future<wire.Purchase> verifyPurchase(
    wire.PurchaseRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.verifyPurchase,
    decode: wire.Purchase.fromJson,
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `GET /v1/billing/purchases/{purchaseId}`
  Future<wire.Purchase> getPurchase(String purchaseId) => client.call(
    ApiOperations.getPurchase,
    decode: wire.Purchase.fromJson,
    pathParams: {'purchaseId': purchaseId},
  );

  /// `POST /v1/billing/subscription/cancel`
  Future<wire.Entitlement> cancelSubscription({String? idempotencyKey}) =>
      client.call(
        ApiOperations.cancelSubscription,
        decode: wire.Entitlement.fromJson,
        idempotencyKey: idempotencyKey,
      );

  /// `POST /v1/blocks`
  Future<wire.Receipt> blockUser(
    wire.BlockRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.blockUser,
    decode: wire.Receipt.fromJson,
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `DELETE /v1/blocks/{userId}`
  Future<wire.Receipt> unblockUser(String userId, {String? idempotencyKey}) =>
      client.call(
        ApiOperations.unblockUser,
        decode: wire.Receipt.fromJson,
        pathParams: {'userId': userId},
        idempotencyKey: idempotencyKey,
      );

  /// `POST /v1/classrooms/join`
  Future<wire.ClassroomMembership> joinClassroom(
    wire.ClassroomJoinRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.joinClassroom,
    decode: wire.ClassroomMembership.fromJson,
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `DELETE /v1/classrooms/{classroomId}/membership`
  Future<wire.Receipt> leaveClassroom(
    String classroomId, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.leaveClassroom,
    decode: wire.Receipt.fromJson,
    pathParams: {'classroomId': classroomId},
    idempotencyKey: idempotencyKey,
  );

  /// `GET /v1/conversations`
  Future<wire.ConversationPage> listConversations({
    String? kind,
    String? scenarioId,
    String? cursor,
    int? limit,
  }) => client.call(
    ApiOperations.listConversations,
    decode: wire.ConversationPage.fromJson,
    query: {
      'kind': kind,
      'scenarioId': scenarioId,
      'cursor': cursor,
      'limit': limit,
    },
  );

  /// `POST /v1/conversations`
  Future<wire.Conversation> startConversation(
    wire.ConversationStartRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.startConversation,
    decode: wire.Conversation.fromJson,
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `POST /v1/conversations/{conversationId}/complete`
  Future<wire.Conversation> completeConversation(
    String conversationId,
    wire.ConversationCompleteRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.completeConversation,
    decode: wire.Conversation.fromJson,
    pathParams: {'conversationId': conversationId},
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `GET /v1/courses`
  Future<wire.CoursePage> listCourses({String? cursor, int? limit}) =>
      client.call(
        ApiOperations.listCourses,
        decode: wire.CoursePage.fromJson,
        query: {'cursor': cursor, 'limit': limit},
      );

  /// `GET /v1/courses/{courseId}/manifest`
  Future<wire.CourseManifest> getManifest(String courseId, {String? version}) =>
      client.call(
        ApiOperations.getManifest,
        decode: wire.CourseManifest.fromJson,
        pathParams: {'courseId': courseId},
        query: {'version': version},
      );

  /// `GET /v1/courses/{courseId}/path`
  Future<wire.Path> getPath(String courseId, {String? cursor, int? limit}) =>
      client.call(
        ApiOperations.getPath,
        decode: wire.Path.fromJson,
        pathParams: {'courseId': courseId},
        query: {'cursor': cursor, 'limit': limit},
      );

  /// `POST /v1/enrollments`
  Future<wire.Enrollment> enrollCourse(
    wire.EnrollRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.enrollCourse,
    decode: wire.Enrollment.fromJson,
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `DELETE /v1/enrollments/{courseId}`
  Future<wire.Receipt> removeCourse(
    String courseId, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.removeCourse,
    decode: wire.Receipt.fromJson,
    pathParams: {'courseId': courseId},
    idempotencyKey: idempotencyKey,
  );

  /// `POST /v1/enrollments/{courseId}/activate`
  Future<wire.Enrollment> switchCourse(
    String courseId,
    wire.EnrollmentCommandRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.switchCourse,
    decode: wire.Enrollment.fromJson,
    pathParams: {'courseId': courseId},
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `POST /v1/enrollments/{courseId}/reset`
  Future<wire.Enrollment> resetCourse(
    String courseId,
    wire.EnrollmentCommandRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.resetCourse,
    decode: wire.Enrollment.fromJson,
    pathParams: {'courseId': courseId},
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `POST /v1/family`
  Future<wire.FamilyGroup> createFamily(
    wire.FamilyCreateRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.createFamily,
    decode: wire.FamilyGroup.fromJson,
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `POST /v1/family/{groupId}/members`
  Future<wire.FamilyGroup> joinFamily(
    String groupId,
    wire.FamilyJoinRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.joinFamily,
    decode: wire.FamilyGroup.fromJson,
    pathParams: {'groupId': groupId},
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `DELETE /v1/family/{groupId}/members/{userId}`
  Future<wire.FamilyGroup> removeFamilyMember(
    String groupId,
    String userId, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.removeFamilyMember,
    decode: wire.FamilyGroup.fromJson,
    pathParams: {'groupId': groupId, 'userId': userId},
    idempotencyKey: idempotencyKey,
  );

  /// `POST /v1/feedback`
  Future<wire.Receipt> sendFeedback(
    wire.FeedbackRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.sendFeedback,
    decode: wire.Receipt.fromJson,
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `POST /v1/follows`
  Future<wire.Receipt> followUser(
    wire.FollowRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.followUser,
    decode: wire.Receipt.fromJson,
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `DELETE /v1/follows/{userId}`
  Future<wire.Receipt> unfollowUser(String userId, {String? idempotencyKey}) =>
      client.call(
        ApiOperations.unfollowUser,
        decode: wire.Receipt.fromJson,
        pathParams: {'userId': userId},
        idempotencyKey: idempotencyKey,
      );

  /// `POST /v1/friend-quests/opt-in`
  Future<wire.Receipt> optInFriendQuest({String? idempotencyKey}) =>
      client.call(
        ApiOperations.optInFriendQuest,
        decode: wire.Receipt.fromJson,
        idempotencyKey: idempotencyKey,
      );

  /// `GET /v1/friend-streaks`
  Future<wire.FriendStreakPage> listFriendStreaks({
    String? cursor,
    int? limit,
  }) => client.call(
    ApiOperations.listFriendStreaks,
    decode: wire.FriendStreakPage.fromJson,
    query: {'cursor': cursor, 'limit': limit},
  );

  /// `POST /v1/friend-streaks`
  Future<wire.FriendStreak> inviteFriendStreak(
    wire.FriendStreakInviteRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.inviteFriendStreak,
    decode: wire.FriendStreak.fromJson,
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `POST /v1/friend-streaks/{pairId}/respond`
  Future<wire.FriendStreak> respondFriendStreak(
    String pairId,
    wire.FriendStreakResponseRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.respondFriendStreak,
    decode: wire.FriendStreak.fromJson,
    pathParams: {'pairId': pairId},
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `GET /v1/friends`
  Future<wire.ProfilePage> listFriends({String? cursor, int? limit}) =>
      client.call(
        ApiOperations.listFriends,
        decode: wire.ProfilePage.fromJson,
        query: {'cursor': cursor, 'limit': limit},
      );

  /// `POST /v1/gifts`
  Future<wire.Gift> sendGift(wire.GiftRequest body, {String? idempotencyKey}) =>
      client.call(
        ApiOperations.sendGift,
        decode: wire.Gift.fromJson,
        body: body,
        idempotencyKey: idempotencyKey,
      );

  /// `POST /v1/gifts/{giftId}/redeem`
  Future<wire.Entitlement> redeemGift(
    String giftId, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.redeemGift,
    decode: wire.Entitlement.fromJson,
    pathParams: {'giftId': giftId},
    idempotencyKey: idempotencyKey,
  );

  /// `POST /v1/interactions`
  Future<wire.Interaction> sendInteraction(
    wire.InteractionRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.sendInteraction,
    decode: wire.Interaction.fromJson,
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `GET /v1/league`
  Future<wire.League> getLeague({String? cursor, int? limit}) => client.call(
    ApiOperations.getLeague,
    decode: wire.League.fromJson,
    query: {'cursor': cursor, 'limit': limit},
  );

  /// `POST /v1/league/join`
  Future<wire.League> joinLeague({String? idempotencyKey}) => client.call(
    ApiOperations.joinLeague,
    decode: wire.League.fromJson,
    idempotencyKey: idempotencyKey,
  );

  /// `GET /v1/league/result`
  Future<wire.LeagueResult> getLeagueResult() => client.call(
    ApiOperations.getLeagueResult,
    decode: wire.LeagueResult.fromJson,
  );

  /// `POST /v1/league/result/seen`
  Future<wire.Receipt> markLeagueResultSeen(
    wire.LeagueResultSeenRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.markLeagueResultSeen,
    decode: wire.Receipt.fromJson,
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `GET /v1/lessons/{lessonId}/bundle`
  Future<wire.LessonBundle> getBundle(String lessonId, {String? version}) =>
      client.call(
        ApiOperations.getBundle,
        decode: wire.LessonBundle.fromJson,
        pathParams: {'lessonId': lessonId},
        query: {'version': version},
      );

  /// `GET /v1/me`
  Future<wire.Profile> getMe() =>
      client.call(ApiOperations.getMe, decode: wire.Profile.fromJson);

  /// `PATCH /v1/me`
  Future<wire.Profile> updateMe(
    wire.ProfilePatch body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.updateMe,
    decode: wire.Profile.fromJson,
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `POST /v1/me/boosts`
  Future<wire.Boost> activateBoost(
    wire.BoostRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.activateBoost,
    decode: wire.Boost.fromJson,
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `POST /v1/me/deletion`
  Future<wire.DeletionReceipt> deleteAccount(
    wire.DeletionRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.deleteAccount,
    decode: wire.DeletionReceipt.fromJson,
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `GET /v1/me/energy`
  Future<wire.Energy> getEnergy() =>
      client.call(ApiOperations.getEnergy, decode: wire.Energy.fromJson);

  /// `GET /v1/me/entitlement`
  Future<wire.Entitlement> getEntitlement() => client.call(
    ApiOperations.getEntitlement,
    decode: wire.Entitlement.fromJson,
  );

  /// `POST /v1/me/freezes`
  Future<wire.Rewards> buyFreeze({String? idempotencyKey}) => client.call(
    ApiOperations.buyFreeze,
    decode: wire.Rewards.fromJson,
    idempotencyKey: idempotencyKey,
  );

  /// `POST /v1/me/initialize`
  Future<wire.Profile> initializeProfile({String? idempotencyKey}) =>
      client.call(
        ApiOperations.initializeProfile,
        decode: wire.Profile.fromJson,
        idempotencyKey: idempotencyKey,
      );

  /// `GET /v1/me/learning-stats`
  Future<wire.LearningStats> getLearningStats() => client.call(
    ApiOperations.getLearningStats,
    decode: wire.LearningStats.fromJson,
  );

  /// `GET /v1/me/preferences`
  Future<wire.Preferences> getPreferences() => client.call(
    ApiOperations.getPreferences,
    decode: wire.Preferences.fromJson,
  );

  /// `PATCH /v1/me/preferences`
  Future<wire.Preferences> updatePreferences(
    wire.PreferencesPatch body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.updatePreferences,
    decode: wire.Preferences.fromJson,
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `GET /v1/me/referral`
  Future<wire.Referral> getReferral() =>
      client.call(ApiOperations.getReferral, decode: wire.Referral.fromJson);

  /// `GET /v1/me/rewards`
  Future<wire.Rewards> getRewards({String? completionId}) => client.call(
    ApiOperations.getRewards,
    decode: wire.Rewards.fromJson,
    query: {'completionId': completionId},
  );

  /// `POST /v1/me/streak-repair`
  Future<wire.Rewards> repairStreak(
    wire.StreakRepairRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.repairStreak,
    decode: wire.Rewards.fromJson,
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `GET /v1/me/year-review/{year}`
  Future<wire.YearReview> getYearReview(String year) => client.call(
    ApiOperations.getYearReview,
    decode: wire.YearReview.fromJson,
    pathParams: {'year': year},
  );

  /// `GET /v1/mistakes`
  Future<wire.MistakePage> listMistakes({
    String? courseId,
    bool? includeResolved,
    String? cursor,
    int? limit,
  }) => client.call(
    ApiOperations.listMistakes,
    decode: wire.MistakePage.fromJson,
    query: {
      'courseId': courseId,
      'includeResolved': includeResolved,
      'cursor': cursor,
      'limit': limit,
    },
  );

  /// `POST /v1/offline-completions`
  Future<wire.Completion> syncOfflineCompletion(
    wire.OfflineCompletionRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.syncOfflineCompletion,
    decode: wire.Completion.fromJson,
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `GET /v1/profiles/{userId}`
  Future<wire.PublicProfile> getPublicProfile(String userId) => client.call(
    ApiOperations.getPublicProfile,
    decode: wire.PublicProfile.fromJson,
    pathParams: {'userId': userId},
  );

  /// `POST /v1/promo-codes/redeem`
  Future<wire.PromoRedemption> redeemPromoCode(
    wire.PromoRedeemRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.redeemPromoCode,
    decode: wire.PromoRedemption.fromJson,
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `GET /v1/quests`
  Future<wire.QuestPage> listQuests({String? cursor, int? limit}) =>
      client.call(
        ApiOperations.listQuests,
        decode: wire.QuestPage.fromJson,
        query: {'cursor': cursor, 'limit': limit},
      );

  /// `POST /v1/quests/{questId}/claim`
  Future<wire.Rewards> claimQuest(
    String questId,
    wire.QuestClaimRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.claimQuest,
    decode: wire.Rewards.fromJson,
    pathParams: {'questId': questId},
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `POST /v1/referrals/redeem`
  Future<wire.Receipt> redeemReferral(
    wire.ReferralRedeemRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.redeemReferral,
    decode: wire.Receipt.fromJson,
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `POST /v1/reports`
  Future<wire.Receipt> createReport(
    wire.ReportRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.createReport,
    decode: wire.Receipt.fromJson,
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `GET /v1/review`
  Future<wire.ReviewPage> getReview({
    String? cursor,
    int? limit,
    String? courseId,
  }) => client.call(
    ApiOperations.getReview,
    decode: wire.ReviewPage.fromJson,
    query: {'cursor': cursor, 'limit': limit, 'courseId': courseId},
  );

  /// `POST /v1/sessions`
  Future<wire.Session> startSession(
    wire.SessionRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.startSession,
    decode: wire.Session.fromJson,
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `GET /v1/sessions/{sessionId}`
  Future<wire.Session> getSession(String sessionId) => client.call(
    ApiOperations.getSession,
    decode: wire.Session.fromJson,
    pathParams: {'sessionId': sessionId},
  );

  /// `POST /v1/sessions/{sessionId}/abandon`
  Future<wire.Receipt> abandonSession(
    String sessionId,
    wire.CompleteRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.abandonSession,
    decode: wire.Receipt.fromJson,
    pathParams: {'sessionId': sessionId},
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `POST /v1/sessions/{sessionId}/answers`
  Future<wire.AnswerResult> submitAnswer(
    String sessionId,
    wire.AnswerRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.submitAnswer,
    decode: wire.AnswerResult.fromJson,
    pathParams: {'sessionId': sessionId},
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `POST /v1/sessions/{sessionId}/complete`
  Future<wire.Completion> completeSession(
    String sessionId,
    wire.CompleteRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.completeSession,
    decode: wire.Completion.fromJson,
    pathParams: {'sessionId': sessionId},
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `GET /v1/shop`
  Future<wire.Shop> listShop() =>
      client.call(ApiOperations.listShop, decode: wire.Shop.fromJson);

  /// `POST /v1/shop/purchases`
  Future<wire.ShopPurchase> buyItem(
    wire.ShopPurchaseRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.buyItem,
    decode: wire.ShopPurchase.fromJson,
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `POST /v1/tutor`
  Future<wire.TutorResult> tutorFeedback(
    wire.TutorRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.tutorFeedback,
    decode: wire.TutorResult.fromJson,
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `POST /v1/user-reports`
  Future<wire.Receipt> reportUser(
    wire.UserReportRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.reportUser,
    decode: wire.Receipt.fromJson,
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `POST /v1/voice-sessions`
  Future<wire.VoiceLease> createVoiceSession(
    wire.VoiceRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.createVoiceSession,
    decode: wire.VoiceLease.fromJson,
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `POST /v1/voice-sessions/{sessionId}/close`
  Future<wire.VoiceState> closeVoiceSession(String sessionId) => client.call(
    ApiOperations.closeVoiceSession,
    decode: wire.VoiceState.fromJson,
    pathParams: {'sessionId': sessionId},
  );

  /// `POST /v1/voice-sessions/{sessionId}/heartbeat`
  Future<wire.VoiceState> heartbeatVoiceSession(
    String sessionId,
    wire.VoiceHeartbeat body,
  ) => client.call(
    ApiOperations.heartbeatVoiceSession,
    decode: wire.VoiceState.fromJson,
    pathParams: {'sessionId': sessionId},
    body: body,
  );

  /// `POST /v1/voice-sessions/{sessionId}/turns`
  Future<wire.TurnResult> submitVoiceTurn(
    String sessionId,
    wire.TurnRequest body, {
    String? idempotencyKey,
  }) => client.call(
    ApiOperations.submitVoiceTurn,
    decode: wire.TurnResult.fromJson,
    pathParams: {'sessionId': sessionId},
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// `GET /v1/words`
  Future<wire.WordPage> listWords({
    String? courseId,
    String? sort,
    String? cursor,
    int? limit,
  }) => client.call(
    ApiOperations.listWords,
    decode: wire.WordPage.fromJson,
    query: {
      'courseId': courseId,
      'sort': sort,
      'cursor': cursor,
      'limit': limit,
    },
  );
}
