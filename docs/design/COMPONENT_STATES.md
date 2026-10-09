# Component interaction contracts

All components support default, pressed, focused and disabled when actionable. Hover applies only in desktop preview. Loading preserves dimensions; success/error uses text+icon; offline follows action classification. No enabled control may have an undefined side effect.

| Component | Selected / loading / disabled / empty | Action → validation → optimistic state → command → success / failure / retry |
|---|---|---|
| Primary TactileButton | selected not applicable; spinner after accepted press; disabled for incomplete input | tap validates VM.canExecute; busy local immediately; emits one VM command; success route/state; failure inline; retry same key for mutation |
| Choice/Image tile | selected blue stroke+check; empty options is content error | tap updates stable choiceId locally, no network; CHECK validates selection; preserve on timeout |
| WordToken / order tray | selected token moves to tray; repeated tokens distinct IDs | tap/add/remove or drag reorders locally; require authored count; no remote operation per gesture |
| PairTile | one left/right selected, matched disabled; mismatch panel | select pair locally; submit full pair set when done; matching correctness rendered from deterministic rule in cached mode and authoritative result online |
| Typed answer field | focus keyboard; inline shape error; readOnly during check | input NFC normalized at grader, never destructive display rewrite; CHECK caps512 chars; network failure retains exact input |
| LessonHeader / exit | progress original items attempted; close stays usable except atomic local write | close→SC18; pause/abandon explicit; API abandon idempotent; failed abandon retains paused session |
| CHECK / CONTINUE | CHECK disabled for invalid shape or busy; CONTINUE only feedback | CHECK→submitAnswer; after outcome CONTINUE only reducer.next; no second answer request |
| Hint / Explain | unassisted→assisted local flag; optional AI spinner | authored hint immediate; tutor call optional, fail to template; never submit/award/accept new answer key |
| Can't listen/speak | only shown for relevant media prompt | mark capability skip reason→replace with authored equivalent locally→persist; no gem/energy deduction |
| Report | category required; accepted/queued badge | createReport with exercise/bundle/category; journal when offline; retry same ID; does not block lesson |
| Feedback panel | correct/error/needs-review; inaccessible score omitted | announce outcome; Continue→next/retry; no automatic next while screen reader reading |
| Results Continue | reward pending badge; no indefinite blocking | completion already committed; read rewards→home; allow route while pending; never invoke complete again with new key |
| PathNode | locked/current/completed/mastered/practicedPending | locked→prerequisite sheet; available→lesson picker/startSession; no optimistic authoritative unlock |
| UnitBanner / guide | header palette; guide loading | getBundle guide; cached success; error retry/download; no progression mutation |
| Skill/practice tile | unavailable cloud badge; empty due state | getReview/startSession; empty→unit replay; unsupported speech→shadowing sheet |
| AudioControl | play/pause/buffering/focusLost/error | verify cached file→audio session→play; speed selects authored asset; failure text alternative; no progress on playback |
| Record button / meter | permission/capturing/processing; disabled while submitting | ask permission→capture≤15s→stop→createAssessment; reject silence; upload retry preserves file while TTL valid |
| Call button / avatar | ready/listening/responding/reconnect/unscored | createVoiceSession→transport; stop/barge-in local; close command; no long-lived provider key; failure fallback turn mode |
| ScoreWordRow | nullable scores show “not assessed”; no guessed zero | tap word plays reference; retry opens new recorded attempt; previous result immutable |
| Quest claim | incomplete disabled; pending busy; claimed disabled | server metric check→claimQuest; no optimistic gems; receipt success; conflict fetch current; same-key retry |
| Freeze buy | funds/slots validated server; busy | buyFreeze→atomic wallet; no optimistic decrement; receipt success; failed funds explicit |
| Follow / unfollow | pending; private unavailable | followUser/unfollowUser; server verifies target; success status; failure original state; idempotent request |
| League / pagination | settling/stale/empty/loadMore | getLeague cursor; stable ranking; loading retains prior rows; reset cursor on new week |
| Settings switch | local selected; server preference saving | local toggles immediately; remote updateMe expectedRevision; conflict chooser; no silent overwrite |
| Timezone picker | scheduled effective date | validate IANA+24h limit→updateMe; display effectiveAt; refresh server day; offline queued change not effective until accepted |
| Notification offer | permission denial/settings; no loader loop | explanatory sheet→OS permission→local schedule; stable key replaces prior reminder; denied no repeated prompt |
| Logout / delete | confirmation, pending-work decision | explicit choice→logout/deleteAccount; stop audio+clear private data; failed remote deletion status retained, local inaccessible |
| RetryPanel / SyncBadge | offline/pending/rejected count | command-specific retry; auth error routes login; 429 honors Retry-After; rejected sync offers repeat/export only |

Focus order follows visual order. All actionable icons have semantic labels. Disable reason appears in text when a user needs it. For disabled buttons do not silently discard a tap without the nearby explanation. No shared widget performs HTTP directly.
