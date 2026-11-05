# Master prompt — hoàn thiện API CocEnglish và bộ test Postman

Bạn là kỹ sư backend phụ trách tiếp tục hoàn thiện CocEnglish, ứng dụng học ngoại ngữ cho người Việt. Hãy đọc repo, lập checklist ngắn rồi THỰC HIỆN mã nguồn và kiểm thử. Không chỉ trả lời bằng kế hoạch. Làm liên tục trong phạm vi có thể xác minh; nếu phiên làm việc kết thúc, lưu checkpoint và việc kế tiếp thật cụ thể. Không tuyên bố hoàn thành toàn bộ khi còn thiếu bằng chứng.

## Workspace và trạng thái xuất phát đã kiểm tra

- Chỉ dùng `C:\FPT\PRM193\CocCoc`. Không tạo bản `CocCoc-snapshot`, clone khác hoặc source dự phòng. Giữ nguyên thay đổi người dùng.
- Nhánh đã push: `wip/codex-20261027-hardening`; checkpoint `60728e24c42c04939d6f2eaaa42517c30a4c1f79`. Kiểm tra HEAD/status mới trước khi sửa; nếu người dùng đã cập nhật, lấy code hiện tại làm chuẩn.
- Đọc [báo cáo kiểm tra ngày 28/10](../quality/API_PROGRESS_20261028.md). Các tài liệu kiểm kê ngày 25/10 và task-status có thể cũ.
- OpenAPI hiện có 91 operations: Learning 25, Progress 55, AI 11. Đã đối chiếu với các mảng route thực và route dùng chung: 91/91 có đăng ký. Đây là bằng chứng về wiring, KHÔNG phải 91 endpoint hoàn chỉnh hay đã chạy cloud.
- Backend mới kiểm tra: 259 test tổng, 247 pass, 0 fail, 12 cloud-gated skips; TypeScript, bundle, ESLint, Prettier pass. Contracts: 157 schemas, 105 fixture cases, generated Dart khớp.
- GitHub CI đúng commit này: Backend foundation, Source secret scan và Container runtime xanh; Mobile frontend đỏ. Link run ở báo cáo đi kèm.
- App analyzer: 28 errors, 6 warnings, 2 infos. Nhóm test app gần nhất: 37 pass, 2 fail ở Mistake Review; chưa chạy toàn bộ app suite cho checkpoint này.
- Tìm kiếm lời gọi trực tiếp trong feature code chưa thấy `abandonSession`, `optInFriendQuest`, `getYearReview`. Có handler backend cho cả ba; không tạo API trùng. Tìm kiếm cú pháp không chứng minh các API còn lại đã tích hợp/kiểm thử đúng.

## Ràng buộc bắt buộc

1. Giữ nguyên UI/UX pixel-perfect: không thiết kế lại, sửa widget layout, màu, khoảng cách, tài nguyên, font, animation hoặc golden. Chỉ sửa hành vi/data/repository/controller cần thiết; nếu callback cần đổi, giữ giao diện và trạng thái được duyệt.
2. Giữ kiến trúc: Flutter manual Riverpod MVVM; backend TypeScript/Node 22; Learning sở hữu `l_*`, Progress `p_*`, AI `a_*`; Appwrite Auth/TablesDB/Storage; Drift journal. Cross-service effects qua signed events và outbox/inbox, không viết bảng service khác.
3. Redis/RabbitMQ theo ADR-0018. Không thêm service nghiệp vụ thứ tư, gateway nghiệp vụ, Kafka, Kubernetes, auth provider hay framework mới.
4. Tận dụng SDK/dependencies đã có. Không cài Android Studio, Android SDK/emulator, Docker Desktop hoặc bộ công cụ nặng trên máy. Chạy Flutter Web khi cần giao diện. Công cụ backend và test nhẹ được dùng; không tự nâng lock/dependency.
5. Không deploy, schema apply, publish, merge main, force-push, xóa/reset dữ liệu hay bật tài nguyên trả phí. Lệnh kiểm tra/dry-run không được có tác dụng ghi cloud. Push/PR chỉ khi chủ repo yêu cầu.
6. Hoàn thiện các tính năng học ngoại ngữ không cần provider trước. AI/speech/email/SMS/OAuth cần provider phải có adapter/config an toàn, trạng thái unavailable rõ ràng và test giả lập; không bịa transcript, điểm phát âm, email đã gửi hoặc thành công cloud.
7. Thanh toán tiền thật và ad network vẫn ngoài phạm vi. Không mở các hosted simulation writer chỉ để Postman trả 200.

## Đọc đúng nguồn chuẩn

Đọc `AGENTS.md`, `docs/00_START_HERE.md`, `docs/agent/IMPLEMENTATION_PLAN.md`, `EXECUTION_PLAN_20261027.md`, `PHASE_BREAKDOWN_2_8.md`; chỉ dẫn AGENTS của service đang sửa; các skill `.agents/skills/coc-service-change/SKILL.md`, `coc-flutter-feature/SKILL.md`, `coc-ai-provider/SKILL.md` khi phù hợp.

SRS sở hữu luật nghiệp vụ; `docs/api/openapi.yaml` sở hữu wire format (nội dung JSON hợp lệ YAML); DATA_MODEL/PERMISSIONS/MIGRATIONS sở hữu lưu trữ; EVENTS_ERRORS/AUTH sở hữu auth/event/error; ADR-0018 sở hữu broker/cache. Một người sửa OpenAPI, generated DTO, schema, lock hoặc shared interface tại một thời điểm. Không dùng tài liệu cũ để ghi đè code mới.

## Thứ tự thực hiện

### P0 — Làm API test được bằng Postman ngay

- Tạo inventory hiện tại cho TỪNG operation: method/path/owner, handler thật, use case, persistence, auth, idempotency, integration caller, automated tests, local HTTP proof, hosted gate. Phân biệt missing handler, handler không hoàn chỉnh, missing caller, missing contract, blocked configuration/provider, excluded.
- Sửa tính nhất quán của local test auth: Learning có `COC_DEV_AUTH=1` + `Bearer dev-<userId>`, còn Progress/AI dev composition chưa có auth port. Tạo auth dev rõ ràng cho cả ba, chỉ loopback và explicit opt-in, mặc định tắt; không lọt vào hosted/production bundles. Có test forged JWT, A/B isolation và production rejection. Không bỏ JWT verification ở runtime thật.
- Chuẩn bị lệnh chạy ba API local và seed dữ liệu synthetic. Nói rõ local memory mất khi restart, `/ready` vẫn fail vì chưa durable-admitted. Đừng gọi đó là cloud integration.
- Tạo Postman Collection v2.1 có TẤT CẢ operations theo OpenAPI hiện tại, chia theo service; nếu thêm contract thì collection phải cập nhật. Tạo hai environment public: local và TEST-template, để mọi secret rỗng.
- Biến tối thiểu: `learning_base_url`, `progress_base_url`, `ai_base_url`, token A/B, course/session/completion IDs, expected revisions, các operation keys và signing config nội bộ. User không tự đoán ID/revision.
- Request mutation dùng UUID idempotency riêng cho từng scenario; replay phải GIỮ NGUYÊN key/body, thử changed body với cùng key phải conflict. Không tạo UUID mới mỗi lần chạy request replay.
- Có scripts lưu ID/revision từ response, assert schema/status/error envelope, chuỗi positive/negative. Internal requests ký HMAC đúng raw body, canonical path/query, timestamp và sender allowlist theo `service-hmac.ts`; có test vectors đối chiếu signer Node. Không cho mobile ký internal requests.
- Thêm README Postman: cách start, import, chọn environment, lấy token dev/test, thứ tự chạy, expected results, reset dữ liệu synthetic và cách chạy collection bằng runner/CLI hiện có. Không ép cài phần mềm mới nặng.

### P1 — Hoàn chỉnh vòng học và endpoint còn thiếu hành vi

- Enroll/path, start/resume/pause/abandon, 12 loại exercise, answer/complete, review/mistakes/words, khóa học switch/reset/remove, report, energy, rewards/streak/quests/shop/boost/promo, league và các tính năng social phục vụ học.
- Nối ba caller còn thiếu nêu trên; đọc test mới thay vì xóa chúng. `learning_abandon_session_test.dart` đang đợi `AbandonableSession` và `ApiLearningRepository.abandonSession`. Failed/uncertain abandon phải giữ journal/retry identity, không làm mất câu trả lời.
- `mistake_review_pool_test.dart` đang đỏ hai case: review pool rỗng phải được xử lý đúng và pool có dữ liệu phải thực sự được đọc; không thay bằng bài mẫu.
- `practice_content_api_test.dart` có import support sai và thiếu await; `team1c/economy_wiring_test.dart` gọi một số API/controller chưa triển khai. Hoàn thiện theo contract thật, không tạo stub chỉ để compile.
- Không cho client quyết định XP, gems, pronunciation, ngày học hoặc quyền truy cập. Hoàn thành/reset/remove/offline/event phải bảo toàn receipt, revision, active slot, ledger, account boundary và transaction rollback.

### P2 — Bổ sung contract nghiệp vụ thực sự thiếu

- SessionRequest hiện chỉ có LESSON/REVIEW/MASTERY/PLACEMENT. Stories, Adventure, Radio, Side quest, Clash, Unit review, test-out/section checkpoint/rapid phải thiết kế session modes/DTO/state/progress/reward policy rõ theo SRS trước khi thêm implementation. `listActivityProgress` hiện có read API nhưng không chứng minh có writer cho các modes này.
- Rà ProfilePatch/identity/avatar configuration, app-level report và các free-offer semantics theo luật đã duyệt; thêm compatible contract/schema/fixtures nếu cần. Không tự sáng tạo endpoint trùng với SDK Appwrite hoặc 91 operations hiện có.
- Regenerate TS và Dart DTOs, endpoint matrix; có migration/rollback plan additive và dry-run. Không apply cloud.

### P3 — Runtime, event bus, cache, security, tải

- Rà wiring thật: AMQP/Redis adapters và test đã tồn tại nhưng chưa thấy chúng được nối vào composition nghiệp vụ. Hoàn thiện đường application receipt, per-target durable acknowledgement, producer ownership/hash check, worker lifecycle và rollback direct signed relay theo ADR.
- Broker confirm không đồng nghĩa reward applied. Chỉ ack delivery sau inbox/domain commit và source receipt; fan-out phải đủ acknowledgement từng đích. Test lost confirm/receipt, duplicates, changed payload, reorder, stale revisions, cancel, reconnect và dead-letter.
- Cache public immutable data theo environment/owner/schema/version/hash; private bypass mặc định, authorization trước lookup, account isolation, TTL, invalidate sau commit, bounded concurrency và cache-down fallback. Không cache ledger/quota/entitlement làm nguồn quyết định.
- API: bound body/headers/concurrency/timeouts/pagination, retry có giới hạn, safe logs/error envelopes, per-user auth/ownership, rate limits và graceful shutdown. Giữ cải thiện backpressure, cache fallback/isolation, AMQP correlation và local-load đã có.
- Đánh giá lazy loading và load balancing dựa trên stateless API, durable state và đo tải thực; không thêm infrastructure tùy tiện hoặc tuyên bố chịu 10K users từ memory test.
- CI phải kiểm tra source/content/contracts/schema/tooling; pinned actions, permissions tối thiểu, không expose secrets cho PR. CI hiện đã có load smoke loopback; bổ sung bằng chứng đúng phạm vi.

## Bộ kiểm thử và tiêu chí hoàn tất

Viết meaningful failing test → sửa → targeted test → broader gate phù hợp. Không xóa/skip test đỏ, nới assertion hoặc thay golden để báo xanh.

Postman và automated tests tối thiểu:
- A enroll → start → đủ answer → complete → nhận đúng một reward/frontier; replay cùng và khác key không nhân thưởng; changed payload conflict.
- Answer/review sai, assisted, retry passes, pool rỗng, pagination và content signature/hash sai.
- Pause/resume/abandon, reset/remove đối đầu answer/complete, offline replay/uncertain commit/process restart trong môi trường hỗ trợ.
- User B không đọc/sửa dữ liệu A; private/blocked/deleted user và late response/event không khôi phục quyền/dữ liệu.
- Streak/timezone/midnight/DST/late events, caps/boost expiry/quest claim/league watermark/settlement.
- 400/401/403/404/409/413/429/503/504 theo contract, invalid IDs/unknown fields/missing keys, timeout và retry.
- Provider-disabled phải trả unavailable/null đúng contract, test riêng với expected outcome; 503 do chưa cấu hình không được tính là endpoint business đã thành công.

Chạy các lệnh thực sự có trong `package.json`: `pnpm backend:verify`, `backend:smoke`, `dev:smoke`, `local:test`, `contracts:check`, `api:lint`, `schema:plan`, `schema:test`, `seed:check`, `blueprint:check`, `audit:check`; targeted Flutter tests và analyzer khi sửa integration. Dùng Node22/pnpm10.15 theo toolchain; nếu máy dùng Node khác, ghi rõ. Không nhầm compile với chạy test, memory test với durable/cloud, cấu hình Docker với container execution. Không cài Android toolchain trên máy này.

Đầu ra phải có: code thật; collection/environment/README; inventory cập nhật từng operation; script verify API reproducible; log redacted; command và pass/fail/skip counts; danh sách provider/config/permission còn chặn; next task cụ thể. Chỉ đánh dấu local backend complete khi các nghiệp vụ đã có test HTTP phù hợp và toàn bộ gates local đạt. Đánh dấu live integration/release riêng, không hứa thêm key là 100% chạy tốt khi chưa có bằng chứng.
