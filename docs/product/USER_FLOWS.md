# User flows and state transitions

Rules: [SRS](SRS.md). Screens: [inventory](SCREEN_INVENTORY.md). All side effects map to [component contracts](../design/COMPONENT_STATES.md).

~~~mermaid
stateDiagram-v2
  [*] --> Boot
  Boot --> Restoring
  Restoring --> SignedOut: no/revoked session
  Restoring --> CacheOnly: network unavailable + cached user
  Restoring --> Onboarding: verified + setup incomplete
  Restoring --> Ready: verified + enrolled
  SignedOut --> Guest: demo
  SignedOut --> Authenticating: email/OAuth
  Authenticating --> SignedOut: cancel/error
  Authenticating --> Onboarding: success
  Onboarding --> Ready: enroll
  CacheOnly --> Restoring: network returns
  Ready --> SignedOut: logout/deletion/revocation
~~~

Boot never displays another user's cached profile. Offline CacheOnly is not a refreshed auth token. Guest intro can run without Appwrite; its result is local and unranked. First account creation initializes Progress profile; enrollment starts Learning frontier. Returning users bypass onboarding. OAuth callback returns to pending route only after verified session and profile.

~~~mermaid
stateDiagram-v2
  [*] --> Loading
  Loading --> Answering: bundle + session
  Loading --> RecoverableError: fetch/cache failure
  Answering --> Checking: complete input
  Checking --> Feedback: graded
  Checking --> Answering: timeout/retry same operation
  Feedback --> Answering: next/retry item
  Feedback --> Completing: all originals and retry passes done
  Answering --> Paused: exit/resume/background
  Paused --> Answering: restore
  Paused --> Abandoned: confirm quit
  Completing --> RewardPending: committed
  Completing --> Completing: uncertain commit same key
  RewardPending --> Results: reward credited or visible pending
  Results --> [*]: continue to current frontier
  RecoverableError --> Loading: retry
~~~

Course switch asks to pause/abandon active lesson; one active server session per user/course. Open current node→lesson picker→start. Guidebook opens without mutation. Locked node explains prerequisite, no API. Placement is one fixed ten-item session, no XP; unit2 start unlocks earlier units for review. Mastery uses a separate mode with no hint benefit.

Practice→select due/mistakes/listen/speak→capability check→appropriate typed lesson session. Words can use local flashcard presentation, reveal then typed recall; reveal marks assisted. Empty practice offers replay. Listening repeat does not advance progress; slow variant swaps verified asset. “Can't listen/speak” replaces current item; hint/report actions never submit an answer.

Completion route owns no award mutation. It reads the Learning receipt and polls Progress by completionId until credited or pending timeout display; returning home remains allowed. Quest claim/freeze purchase use server command receipts; no optimistic gems. League screens use an asOf snapshot and settling indicator. Follow/unfollow shows pending until server success; private/blocked profiles render generic unavailable.

Settings local toggles apply immediately; profile edits use revision confirmation. Logout stops audio then clears private cache; offline unsynced work requires explicit retain/discard choice. Deletion is an accepted asynchronous request with receipt, not a claim of immediate purge.

Speech has its own lifecycle in [AI architecture](../ai/AI_ARCHITECTURE.md). Incoming call/background stops capture and mutes playback; resuming opens a new transport epoch. Navigation away always disposes recording/session listeners.
