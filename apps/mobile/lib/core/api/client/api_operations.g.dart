// GENERATED CODE - DO NOT EDIT BY HAND.
// Source: docs/api/openapi.yaml (sha256 1f0abde1778efb8d4de3aba9d38e2a218a9596574305aeb4e7dd587e8e942efc).
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
  static const buyFreeze = ApiOperation(
    'buyFreeze',
    'POST',
    '/v1/me/freezes',
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
  static const getLeague = ApiOperation(
    'getLeague',
    'GET',
    '/v1/league',
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
  static const getPublicProfile = ApiOperation(
    'getPublicProfile',
    'GET',
    '/v1/profiles/{userId}',
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
  static const joinLeague = ApiOperation(
    'joinLeague',
    'POST',
    '/v1/league/join',
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
  static const listCourses = ApiOperation(
    'listCourses',
    'GET',
    '/v1/courses',
    ApiService.learning,
    idempotent: false,
  );
  static const listFriends = ApiOperation(
    'listFriends',
    'GET',
    '/v1/friends',
    ApiService.progress,
    idempotent: false,
  );
  static const listQuests = ApiOperation(
    'listQuests',
    'GET',
    '/v1/quests',
    ApiService.progress,
    idempotent: false,
  );
  static const optInFriendQuest = ApiOperation(
    'optInFriendQuest',
    'POST',
    '/v1/friend-quests/opt-in',
    ApiService.progress,
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

  static const all = <ApiOperation>[
    abandonSession,
    buyFreeze,
    claimQuest,
    closeVoiceSession,
    completeSession,
    createAssessment,
    createReport,
    createVoiceSession,
    deleteAccount,
    enrollCourse,
    followUser,
    getAssessment,
    getBundle,
    getCapabilities,
    getLeague,
    getManifest,
    getMe,
    getPath,
    getPublicProfile,
    getReview,
    getRewards,
    getSession,
    heartbeatVoiceSession,
    initializeProfile,
    joinLeague,
    listActivity,
    listCourses,
    listFriends,
    listQuests,
    optInFriendQuest,
    startSession,
    submitAnswer,
    submitVoiceTurn,
    syncOfflineCompletion,
    tutorFeedback,
    unfollowUser,
    updateMe,
  ];
}
