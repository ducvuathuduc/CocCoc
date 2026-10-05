# Architecture Blueprint V1 — CocEnglish

Research snapshot2026-10-03; final review2026-10-04, Asia/Saigon. This is the Phase0 handoff package requested by the master directive. Normative product/platform choices are frozen; current account, runtime and device capabilities require the named implementation gates. All technical documents use one concise English source; this executive decision is Vietnamese.

## PART A — Executive Engineering Decision

**Chốt kiến trúc:** ứng dụng Flutter Android/iOS, ba microservice **Learning / Progress / AI** viết TypeScript chạy Node22. Learning giữ nội dung, đường học, phiên học, chấm đáp án và ôn tập; Progress giữ hồ sơ, XP, streak, gems, quest, bạn bè và league; AI giữ provider, quota, tutor, voice và assessment. Không tách thêm auth, gateway, notification hoặc broker thành service.

**Flutter:** feature-first MVVM, Riverpod thủ công, go_router, repository có nguồn remote/local, Drift cho cache và journal giao dịch. Domain reducer chỉ dùng ở lesson, sync và speech có logic phức tạp. Appwrite SDK quản lý Account; business REST dùng http. DTO dùng json_serializable; animation mặc định dùng Flutter. Phiên bản nền đã kiểm tra trên máy: Flutter3.47.0/Dart3.13.0; đây không phải tuyên bố patch mới nhất.

**Appwrite:** Auth, một TablesDB database, một bucket có file security, ba Function trong thời gian Education còn hiệu lực. Chỉ service chủ sở hữu được ghi bảng của mình. API key theo project không tạo cách ly cứng giữa bảng; allowlist và negative test bảo vệ ranh giới logic. Lesson hoàn tất trong transaction của Learning, rồi outbox/inbox chuyển reward sang Progress, có dedupe và trạng thái reward pending.

**AI:** Gemini2.5Flash-Lite cho tutor; Gemini native-audio preview12-2025 là ứng viên Live được bật sau kiểm tra account, token constraint và thiết bị. Backend cấp credential ngắn hạn, single-use, khóa model/config; Flutter truyền PCM16kHz và phát PCM24kHz qua bridge native. Quota được giữ ở server; timer phía app không được coi là kiểm soát bảo mật. Mất kết quả mint token không cấp lại dưới cùng reservation. Fallback là Groq Whisper → Gemini text → TTS trên thiết bị/audio có sẵn; tiếp theo Cloudflare Whisper → câu trả lời tác giả. Offline luôn có record/replay, shadowing, nghe audio có sẵn và nhập chữ. Azure pronunciation assessment chỉ bật khi entitlement và eval thật đạt; không dùng LLM bịa điểm phát âm.

**CI/CD:** Linux kiểm tra PR với provider giả; macOS GitHub Actions build/smoke iOS simulator, Codemagic personal M2 dự phòng. Android phát triển/build trên Windows. IPA ký và kiểm tra iPhone thật phụ thuộc Apple team hợp lệ; cloud CI không cung cấp miễn phí membership. Deploy/publish cần một task được người dùng yêu cầu riêng.

**0 VND:** mục tiêu là demo giới hạn với tài nguyên đã có và quota thật. Education hiện công bố6tháng, hai project; không dựa vào thông tin student lifetime cũ. Sau hết hạn, giữ Auth/DB/Storage trong Free và chạy cùng ba service bằng Node local cho demo; Free chỉ có hai Function. Không tự chuyển sang gói trả phí. Khi cloud AI hết quota, bài học thường và chức năng offline vẫn hoạt động. Xem [nguồn Appwrite](https://appwrite.io/education), [phân loại chi phí](devops/COST_MODEL.md).

**Đánh đổi đã chốt:** reward eventual-consistency; đồng bộ offline mới mở node kế tiếp; đáp án cache không có bảo đảm chống gian lận mạnh; Live preview và điểm phát âm là capability có điều kiện; simulator không thay thế kiểm tra mic/Bluetooth trên iPhone; mốc100/1,000/10,000 người dùng là mô hình load cần đo, không phải capacity đã chứng minh. P1-FOUND-001 có đủ input để bắt đầu mà không chọn lại kiến trúc.

## PART B — Existing Documentation Audit

[DOCUMENTATION_AUDIT](research/DOCUMENTATION_AUDIT.md) inventories the empty initial checkout and the sole2,491-line directive. Its keep/modify/remove/missing matrix covers sections0–50. There were no prior SRS/API/design/code files to diff. The directive's sample tree is consolidated into canonical owners rather than copied as dozens of overlapping documents.

## PART C — Research Evidence

[RESEARCH_EVIDENCE](research/RESEARCH_EVIDENCE.md) contains dated primary-source evidence, conflict resolution and weighted architecture comparisons. [STACK](architecture/STACK.md) records registry versions/adoption and unverified compatibility/issue health. [AI_EVIDENCE](research/AI_EVIDENCE.md) separates supported capabilities, permanent tiers, credits and paid models. [GUMMBLE_RESEARCH](design/GUMMBLE_RESEARCH.md) records actual flows/screens, six visual inspections, version limits, OAuth setup and paid/trial access. [FEATURE_MATRIX](product/FEATURE_MATRIX.md) distinguishes current official Duolingo evidence from older captured UI and CocEnglish choices.

Research workstreams: current product/reference UX; Flutter/packages/Windows; Appwrite ownership/transactions; AI speech/cost/security; CI/operations/agent mechanisms. Exa search/fetch, official docs/registries and Gummble MCP were actually used. Provider/account entitlements and device metrics are not inferred from marketing.

## PART D — Complete Product Specification

Canonical [SRS](product/SRS.md) defines stable requirements, priorities, triggers, preconditions, normal/alternate/error behavior, acceptance and dependencies, plus exact lesson/grading/review/reward/zone/quest rules. [USER_FLOWS](product/USER_FLOWS.md), [SCREEN_INVENTORY](product/SCREEN_INVENTORY.md), [COMPONENT_STATES](design/COMPONENT_STATES.md) and [EDGE_CASE_MATRIX](product/EDGE_CASE_MATRIX.md) define navigation, commands, loading/error/offline/empty states and recovery. [DESIGN](design/DESIGN.md) owns tokens, layout, accessibility, motion and audio interaction. [NFR](architecture/NFR.md) owns measurable targets and load assumptions. [TRACEABILITY](quality/TRACEABILITY.md) maps requirements to contract/screen/task acceptance locations.

V1 includes onboarding/guest/auth, path/placement,12typed exercise kinds, lesson retries/feedback, offline replay, deterministic review, XP/streak/freeze/achievements, listening, optional AI speaking/assessment, profiles/friends/quests/weekly league/settings/reminders. Payment/ads, unrestricted generative content, a web administration app, additional language curricula and large public production traffic are excluded from the bounded student demo.

## PART E — Complete Technical Architecture

[ARCHITECTURE](architecture/ARCHITECTURE.md) contains C4 context/container/component views and the completion sequence. [SERVICE_CATALOG](architecture/SERVICE_CATALOG.md) owns deployment units/endpoints/boundaries. [DATA_MODEL](data/DATA_MODEL.md) contains tables, indexes, reference graph, assets, integrity, transaction sizes and retention; [PERMISSIONS](data/PERMISSIONS.md) contains owner/read/write trust; [MIGRATIONS](data/MIGRATIONS.md) defines expand/rollback/seed/publish. [OpenAPI](api/openapi.yaml) owns typed wire DTOs, methods, authentication, operation owners and requirement/table refs. [AUTH](api/AUTH.md), [EVENTS_ERRORS](api/EVENTS_ERRORS.md) and [OFFLINE](architecture/OFFLINE.md) define verification, retries, durable delivery and reconciliation. [ADRs](architecture/adr/README.md) explain17major choices and revisit triggers.

OpenAPI is JSON syntax saved as .yaml, valid YAML1.2; JSON is deliberate for dependency-free structural validation. No second handwritten API specification or shared cross-language domain-model library exists.

## PART F — AI & Speech Architecture

[AI_ARCHITECTURE](ai/AI_ARCHITECTURE.md) compares end-to-end Live versus STT→LLM→TTS, fixes provider order/interfaces, bounded credential issuance, quotas, PCM/VAD/queues/barge-in/reconnect/lifecycle, listening cache and dedicated scorer rules. [AI_EVALS](ai/AI_EVALS.md) specifies correctness, malformed output, silence/noise, audio routes, security and actual latency enablement evidence. Source confidence and current prices/limits remain in [AI_EVIDENCE](research/AI_EVIDENCE.md). Optional native/scored capabilities report disabled reasons until their gates pass; ordinary learning does not wait for AI.

## PART G — DevOps / CI/CD / SRE

[CI_CD](devops/CI_CD.md) defines environments, PR/main/artifact pipelines, secret boundaries, rollback, Android signing and default/fallback macOS strategy. [OPERATIONS](devops/OPERATIONS.md) defines telemetry, quota breakers, load profiles, backups and failure runbooks. [COST_MODEL](devops/COST_MODEL.md) classifies each selected/compared hosted dependency and rehearsed expiry fallback. [TEST_STRATEGY](quality/TEST_STRATEGY.md) defines layered tests, device evidence and release gates. Infrastructure templates contain blank server secrets and disabled optional capabilities; no account/project was created or deployed during Phase0.

## PART H — Agent Engineering System

Root [AGENTS](../AGENTS.md), [CLAUDE](../CLAUDE.md) and five module AGENTS establish scope, canonical sources and ownership. [AGENT_SYSTEM](agent/AGENT_SYSTEM.md) defines four canonical skills with Claude entrypoints, two read-only reviewers, actual hook scripts and example MCP configurations. [TASK_PROTOCOL](agent/TASK_PROTOCOL.md) defines claims, contract/ADR changes, evidence and DoD. [DEPENDENCY_DAG](agent/DEPENDENCY_DAG.md) makes phase precedence and SAFE_PARALLEL/BLOCKS/EXCLUSIVE_CHANGE_AREA explicit. Hooks are repository configuration, not a claim that global agent settings were installed. Native forks share quota and are limited by the human policy.

## PART I — Final Repository Tree

[REPOSITORY_TREE](agent/REPOSITORY_TREE.md) is the deliberate approved tree with directory purposes. It distinguishes Phase0 files that exist from future implementation paths. Only mobile and the three service AGENTS currently exist in application directories; there is no application pretending to be implemented.

## PART J — Documentation Package

[00_READ_ME_FIRST](00_READ_ME_FIRST.md) is the canonical inventory and reading order. All linked specifications and ADRs contain actual content in this checkout. Consolidations: PRD→SRS; C4/data flows→ARCHITECTURE; ERD→DATA_MODEL; tokens/motion→DESIGN; events/errors→EVENTS_ERRORS; AI speech/listening/fallback→AI_ARCHITECTURE; environments/deployment→CI_CD; observability/load/runbook→OPERATIONS; device/test/release matrix→TEST_STRATEGY; DoD/change policy→TASK_PROTOCOL. [ASSUMPTIONS](ASSUMPTIONS.md) names unresolved external gates, owners and fallback behavior. No bilingual duplicate technical specifications.

## PART K — Implementation Roadmap

[IMPLEMENTATION_PLAN](agent/IMPLEMENTATION_PLAN.md) contains all12phase rows with dependencies, parallel modules, deliverables, verification and exit gates, followed by concrete task IDs/files/interfaces/acceptance cases. Phase2 completes fake-data UX before real auth/backend features. Reliability primitives start with their owning feature; Phase10 measures/hardens them. First task **P1-FOUND-001** pins/generates the shell/toolchain and proves routing fixtures; it has exact inputs and commands. Later phases cannot begin before predecessor acceptance.

## PART L — Final Architecture Freeze Check

[FREEZE_REVIEW](FREEZE_REVIEW.md) records the eight-role adversarial review, corrected ambiguities, consistency/simplicity/cost checks, fresh validation and practical scope of readiness. Automated checks validate internal references/contracts/coverage; they do not certify an unbuilt app, actual cloud quotas, native audio or10Kcapacity. Unknown external facts have concrete probes and deterministic disabled/local fallbacks.

ARCHITECTURE BLUEPRINT V1 — READY FOR IMPLEMENTATION
