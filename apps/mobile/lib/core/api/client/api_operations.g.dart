// GENERATED CODE - DO NOT EDIT BY HAND.
// Source: docs/api/openapi.yaml (sha256 64f4993f049da84184d4fac4c0d5ad558907061d2ca688aff6a4f919b12a7c00).
// Generator: apps/mobile/tool/gen_api_operations.py

import 'api_operation.dart';

/// Client-callable OpenAPI operations (Appwrite JWT), keyed by operationId.
abstract final class ApiOperations {
  static const abandonSession = ApiOperation(
    'abandonSession',
    'POST',
    '/v1/sessions/{sessionId}/abandon',
    ApiService.learning,
    idempotent: true,
  );
  static const activateBoost = ApiOperation(
    'activateBoost',
    'POST',
    '/v1/me/boosts',
    ApiService.progress,
    idempotent: true,
  );
  static const blockUser = ApiOperation(
    'blockUser',
    'POST',
    '/v1/blocks',
    ApiService.progress,
    idempotent: true,
  );
  static const buyFreeze = ApiOperation(
    'buyFreeze',
    'POST',
    '/v1/me/freezes',
    ApiService.progress,
    idempotent: true,
  );
  static const buyItem = ApiOperation(
    'buyItem',
    'POST',
    '/v1/shop/purchases',
    ApiService.progress,
    idempotent: true,
  );
  static const cancelSubscription = ApiOperation(
    'cancelSubscription',
    'POST',
    '/v1/billing/subscription/cancel',
    ApiService.progress,
    idempotent: true,
  );
  static const claimQuest = ApiOperation(
    'claimQuest',
    'POST',
    '/v1/quests/{questId}/claim',
    ApiService.progress,
    idempotent: true,
  );
  static const closeVoiceSession = ApiOperation(
    'closeVoiceSession',
    'POST',
    '/v1/voice-sessions/{sessionId}/close',
    ApiService.ai,
    idempotent: false,
  );
  static const completeConversation = ApiOperation(
    'completeConversation',
    'POST',
    '/v1/conversations/{conversationId}/complete',
    ApiService.ai,
    idempotent: true,
  );
  static const completeSession = ApiOperation(
    'completeSession',
    'POST',
    '/v1/sessions/{sessionId}/complete',
    ApiService.learning,
    idempotent: true,
  );
  static const createAssessment = ApiOperation(
    'createAssessment',
    'POST',
    '/v1/assessment-jobs',
    ApiService.ai,
    idempotent: true,
  );
  static const createFamily = ApiOperation(
    'createFamily',
    'POST',
    '/v1/family',
    ApiService.progress,
    idempotent: true,
  );
  static const createReport = ApiOperation(
    'createReport',
    'POST',
    '/v1/reports',
    ApiService.learning,
    idempotent: true,
  );
  static const createVoiceSession = ApiOperation(
    'createVoiceSession',
    'POST',
    '/v1/voice-sessions',
    ApiService.ai,
    idempotent: true,
  );
  static const deleteAccount = ApiOperation(
    'deleteAccount',
    'POST',
    '/v1/me/deletion',
    ApiService.progress,
    idempotent: true,
  );
  static const enrollCourse = ApiOperation(
    'enrollCourse',
    'POST',
    '/v1/enrollments',
    ApiService.learning,
    idempotent: true,
  );
  static const followUser = ApiOperation(
    'followUser',
    'POST',
    '/v1/follows',
    ApiService.progress,
    idempotent: true,
  );
  static const getAssessment = ApiOperation(
    'getAssessment',
    'GET',
    '/v1/assessment-jobs/{jobId}',
    ApiService.ai,
    idempotent: false,
  );
  static const getBundle = ApiOperation(
    'getBundle',
    'GET',
    '/v1/lessons/{lessonId}/bundle',
    ApiService.learning,
    idempotent: false,
  );
  static const getCapabilities = ApiOperation(
    'getCapabilities',
    'GET',
    '/v1/ai/capabilities',
    ApiService.ai,
    idempotent: false,
  );
  static const getEnergy = ApiOperation(
    'getEnergy',
    'GET',
    '/v1/me/energy',
    ApiService.learning,
    idempotent: false,
  );
  static const getEntitlement = ApiOperation(
    'getEntitlement',
    'GET',
    '/v1/me/entitlement',
    ApiService.progress,
    idempotent: false,
  );
  static const getLeague = ApiOperation(
    'getLeague',
    'GET',
    '/v1/league',
    ApiService.progress,
    idempotent: false,
  );
  static const getLeagueResult = ApiOperation(
    'getLeagueResult',
    'GET',
    '/v1/league/result',
    ApiService.progress,
    idempotent: false,
  );
  static const getLearningStats = ApiOperation(
    'getLearningStats',
    'GET',
    '/v1/me/learning-stats',
    ApiService.progress,
    idempotent: false,
  );
  static const getManifest = ApiOperation(
    'getManifest',
    'GET',
    '/v1/courses/{courseId}/manifest',
    ApiService.learning,
    idempotent: false,
  );
  static const getMe = ApiOperation(
    'getMe',
    'GET',
    '/v1/me',
    ApiService.progress,
    idempotent: false,
  );
  static const getPath = ApiOperation(
    'getPath',
    'GET',
    '/v1/courses/{courseId}/path',
    ApiService.learning,
    idempotent: false,
  );
  static const getPreferences = ApiOperation(
    'getPreferences',
    'GET',
    '/v1/me/preferences',
    ApiService.progress,
    idempotent: false,
  );
  static const getPublicProfile = ApiOperation(
    'getPublicProfile',
    'GET',
    '/v1/profiles/{userId}',
    ApiService.progress,
    idempotent: false,
  );
  static const getPurchase = ApiOperation(
    'getPurchase',
    'GET',
    '/v1/billing/purchases/{purchaseId}',
    ApiService.progress,
    idempotent: false,
  );
  static const getReferral = ApiOperation(
    'getReferral',
    'GET',
    '/v1/me/referral',
    ApiService.progress,
    idempotent: false,
  );
  static const getReview = ApiOperation(
    'getReview',
    'GET',
    '/v1/review',
    ApiService.learning,
    idempotent: false,
  );
  static const getRewards = ApiOperation(
    'getRewards',
    'GET',
    '/v1/me/rewards',
    ApiService.progress,
    idempotent: false,
  );
  static const getSession = ApiOperation(
    'getSession',
    'GET',
    '/v1/sessions/{sessionId}',
    ApiService.learning,
    idempotent: false,
  );
  static const getYearReview = ApiOperation(
    'getYearReview',
    'GET',
    '/v1/me/year-review/{year}',
    ApiService.progress,
    idempotent: false,
  );
  static const heartbeatVoiceSession = ApiOperation(
    'heartbeatVoiceSession',
    'POST',
    '/v1/voice-sessions/{sessionId}/heartbeat',
    ApiService.ai,
    idempotent: false,
  );
  static const initializeProfile = ApiOperation(
    'initializeProfile',
    'POST',
    '/v1/me/initialize',
    ApiService.progress,
    idempotent: true,
  );
  static const inviteFriendStreak = ApiOperation(
    'inviteFriendStreak',
    'POST',
    '/v1/friend-streaks',
    ApiService.progress,
    idempotent: true,
  );
  static const joinClassroom = ApiOperation(
    'joinClassroom',
    'POST',
    '/v1/classrooms/join',
    ApiService.progress,
    idempotent: true,
  );
  static const joinFamily = ApiOperation(
    'joinFamily',
    'POST',
    '/v1/family/{groupId}/members',
    ApiService.progress,
    idempotent: true,
  );
  static const joinLeague = ApiOperation(
    'joinLeague',
    'POST',
    '/v1/league/join',
    ApiService.progress,
    idempotent: true,
  );
  static const leaveClassroom = ApiOperation(
    'leaveClassroom',
    'DELETE',
    '/v1/classrooms/{classroomId}/membership',
    ApiService.progress,
    idempotent: true,
  );
  static const listActivity = ApiOperation(
    'listActivity',
    'GET',
    '/v1/activity',
    ApiService.progress,
    idempotent: false,
  );
  static const listActivityProgress = ApiOperation(
    'listActivityProgress',
    'GET',
    '/v1/activities',
    ApiService.learning,
    idempotent: false,
  );
  static const listConversations = ApiOperation(
    'listConversations',
    'GET',
    '/v1/conversations',
    ApiService.ai,
    idempotent: false,
  );
  static const listCourses = ApiOperation(
    'listCourses',
    'GET',
    '/v1/courses',
    ApiService.learning,
    idempotent: false,
  );
  static const listFriendStreaks = ApiOperation(
    'listFriendStreaks',
    'GET',
    '/v1/friend-streaks',
    ApiService.progress,
    idempotent: false,
  );
  static const listFriends = ApiOperation(
    'listFriends',
    'GET',
    '/v1/friends',
    ApiService.progress,
    idempotent: false,
  );
  static const listMistakes = ApiOperation(
    'listMistakes',
    'GET',
    '/v1/mistakes',
    ApiService.learning,
    idempotent: false,
  );
  static const listQuests = ApiOperation(
    'listQuests',
    'GET',
    '/v1/quests',
    ApiService.progress,
    idempotent: false,
  );
  static const listShop = ApiOperation(
    'listShop',
    'GET',
    '/v1/shop',
    ApiService.progress,
    idempotent: false,
  );
  static const listWords = ApiOperation(
    'listWords',
    'GET',
    '/v1/words',
    ApiService.learning,
    idempotent: false,
  );
  static const markLeagueResultSeen = ApiOperation(
    'markLeagueResultSeen',
    'POST',
    '/v1/league/result/seen',
    ApiService.progress,
    idempotent: true,
  );
  static const optInFriendQuest = ApiOperation(
    'optInFriendQuest',
    'POST',
    '/v1/friend-quests/opt-in',
    ApiService.progress,
    idempotent: true,
  );
  static const recordAdEvent = ApiOperation(
    'recordAdEvent',
    'POST',
    '/v1/ad-events',
    ApiService.progress,
    idempotent: true,
  );
  static const redeemGift = ApiOperation(
    'redeemGift',
    'POST',
    '/v1/gifts/{giftId}/redeem',
    ApiService.progress,
    idempotent: true,
  );
  static const redeemPromoCode = ApiOperation(
    'redeemPromoCode',
    'POST',
    '/v1/promo-codes/redeem',
    ApiService.progress,
    idempotent: true,
  );
  static const redeemReferral = ApiOperation(
    'redeemReferral',
    'POST',
    '/v1/referrals/redeem',
    ApiService.progress,
    idempotent: true,
  );
  static const removeCourse = ApiOperation(
    'removeCourse',
    'DELETE',
    '/v1/enrollments/{courseId}',
    ApiService.learning,
    idempotent: true,
  );
  static const removeFamilyMember = ApiOperation(
    'removeFamilyMember',
    'DELETE',
    '/v1/family/{groupId}/members/{userId}',
    ApiService.progress,
    idempotent: true,
  );
  static const repairStreak = ApiOperation(
    'repairStreak',
    'POST',
    '/v1/me/streak-repair',
    ApiService.progress,
    idempotent: true,
  );
  static const reportUser = ApiOperation(
    'reportUser',
    'POST',
    '/v1/user-reports',
    ApiService.progress,
    idempotent: true,
  );
  static const resetCourse = ApiOperation(
    'resetCourse',
    'POST',
    '/v1/enrollments/{courseId}/reset',
    ApiService.learning,
    idempotent: true,
  );
  static const respondFriendStreak = ApiOperation(
    'respondFriendStreak',
    'POST',
    '/v1/friend-streaks/{pairId}/respond',
    ApiService.progress,
    idempotent: true,
  );
  static const sendFeedback = ApiOperation(
    'sendFeedback',
    'POST',
    '/v1/feedback',
    ApiService.progress,
    idempotent: true,
  );
  static const sendGift = ApiOperation(
    'sendGift',
    'POST',
    '/v1/gifts',
    ApiService.progress,
    idempotent: true,
  );
  static const sendInteraction = ApiOperation(
    'sendInteraction',
    'POST',
    '/v1/interactions',
    ApiService.progress,
    idempotent: true,
  );
  static const startConversation = ApiOperation(
    'startConversation',
    'POST',
    '/v1/conversations',
    ApiService.ai,
    idempotent: true,
  );
  static const startSession = ApiOperation(
    'startSession',
    'POST',
    '/v1/sessions',
    ApiService.learning,
    idempotent: true,
  );
  static const submitAnswer = ApiOperation(
    'submitAnswer',
    'POST',
    '/v1/sessions/{sessionId}/answers',
    ApiService.learning,
    idempotent: true,
  );
  static const submitVoiceTurn = ApiOperation(
    'submitVoiceTurn',
    'POST',
    '/v1/voice-sessions/{sessionId}/turns',
    ApiService.ai,
    idempotent: true,
  );
  static const switchCourse = ApiOperation(
    'switchCourse',
    'POST',
    '/v1/enrollments/{courseId}/activate',
    ApiService.learning,
    idempotent: true,
  );
  static const syncOfflineCompletion = ApiOperation(
    'syncOfflineCompletion',
    'POST',
    '/v1/offline-completions',
    ApiService.learning,
    idempotent: true,
  );
  static const tutorFeedback = ApiOperation(
    'tutorFeedback',
    'POST',
    '/v1/tutor',
    ApiService.ai,
    idempotent: true,
  );
  static const unblockUser = ApiOperation(
    'unblockUser',
    'DELETE',
    '/v1/blocks/{userId}',
    ApiService.progress,
    idempotent: true,
  );
  static const unfollowUser = ApiOperation(
    'unfollowUser',
    'DELETE',
    '/v1/follows/{userId}',
    ApiService.progress,
    idempotent: true,
  );
  static const updateMe = ApiOperation(
    'updateMe',
    'PATCH',
    '/v1/me',
    ApiService.progress,
    idempotent: true,
  );
  static const updatePreferences = ApiOperation(
    'updatePreferences',
    'PATCH',
    '/v1/me/preferences',
    ApiService.progress,
    idempotent: true,
  );
  static const verifyPurchase = ApiOperation(
    'verifyPurchase',
    'POST',
    '/v1/billing/purchases',
    ApiService.progress,
    idempotent: true,
  );

  static const all = <ApiOperation>[
    abandonSession,
    activateBoost,
    blockUser,
    buyFreeze,
    buyItem,
    cancelSubscription,
    claimQuest,
    closeVoiceSession,
    completeConversation,
    completeSession,
    createAssessment,
    createFamily,
    createReport,
    createVoiceSession,
    deleteAccount,
    enrollCourse,
    followUser,
    getAssessment,
    getBundle,
    getCapabilities,
    getEnergy,
    getEntitlement,
    getLeague,
    getLeagueResult,
    getLearningStats,
    getManifest,
    getMe,
    getPath,
    getPreferences,
    getPublicProfile,
    getPurchase,
    getReferral,
    getReview,
    getRewards,
    getSession,
    getYearReview,
    heartbeatVoiceSession,
    initializeProfile,
    inviteFriendStreak,
    joinClassroom,
    joinFamily,
    joinLeague,
    leaveClassroom,
    listActivity,
    listActivityProgress,
    listConversations,
    listCourses,
    listFriendStreaks,
    listFriends,
    listMistakes,
    listQuests,
    listShop,
    listWords,
    markLeagueResultSeen,
    optInFriendQuest,
    recordAdEvent,
    redeemGift,
    redeemPromoCode,
    redeemReferral,
    removeCourse,
    removeFamilyMember,
    repairStreak,
    reportUser,
    resetCourse,
    respondFriendStreak,
    sendFeedback,
    sendGift,
    sendInteraction,
    startConversation,
    startSession,
    submitAnswer,
    submitVoiceTurn,
    switchCourse,
    syncOfflineCompletion,
    tutorFeedback,
    unblockUser,
    unfollowUser,
    updateMe,
    updatePreferences,
    verifyPurchase,
  ];
}
