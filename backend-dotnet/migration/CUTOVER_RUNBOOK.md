# Diễn tập chuyển Node sang .NET và rollback

Trạng thái: thủ tục để review và diễn tập trên `coccoc-test`; chưa có bằng chứng diễn tập thành công. Tài liệu này thực hiện giai đoạn 6 của [kế hoạch migration](IMPLEMENTATION_PLAN.md), không cấp quyền deploy hoặc đổi cấu hình cloud. Tiêu chí nghiệm thu được theo dõi trong [runtime inventory](runtime.json).

## Điều kiện hiện tại

- [HealthController](../src/CocEnglish.Shared/Hosting/HealthController.cs) đóng `/ready` mặc định bằng `SERVICE_NOT_CONFIGURED`, reason `DOTNET_MIGRATION_IN_PROGRESS`. Chỉ trả 200 khi Appwrite/business admission hợp lệ và `COC_<SERVICE>_READINESS_GATES` liệt kê chính xác đủ năm gate trong `runtime.json`. `/health` chỉ chứng minh process đang sống.
- [RuntimeSettings](../src/CocEnglish.Shared/Hosting/RuntimeSettings.cs) kiểm tra danh sách gate thiếu, lặp hoặc không biết và fail-closed. Danh sách cấu hình là operator attestation, không tự xác minh bằng chứng; không đặt đủ năm ID trước khi người review xác nhận evidence từng gate. Hiện cả năm gate vẫn pending.
- Compose foundation không có credentials hoặc worker. Smoke foundation cũ không chứng nhận code hiện tại hay dữ liệu Appwrite bền vững.
- Người dùng đã chọn hướng VPS/server chạy Docker Compose. Bộ cấu hình và unit systemd đã chuẩn bị tại [VPS setup](../docker/staging/vps/README.md), chưa cài hoặc chạy. Chưa có host/domain/TLS và cơ chế dừng traffic/scheduler cụ thể; chưa được bắt đầu cutover khi các mục này hoặc các điều kiện dưới đây còn thiếu.

## Phiếu chuẩn bị cho mỗi lần diễn tập

Ghi phiếu riêng cho từng owner, không đưa secret hoặc dữ liệu người học vào phiếu.

| Mục               | Phải ghi trước khi chạy                                                                                  |
| ----------------- | -------------------------------------------------------------------------------------------------------- |
| Môi trường        | Project test đã xác minh, database/bucket và URL của ba service                                          |
| Người thực hiện   | Operator, người duyệt và người có quyền khôi phục hosting/Appwrite                                       |
| Candidate         | Commit, image digest và build ID của Node hiện tại và .NET candidate                                     |
| Topology          | Tất cả API replica, scheduler, worker và delivery transport của owner                                    |
| Cách ngừng ghi    | Lệnh/công cụ hosting đã review để chặn mutation, event delivery và job trigger                           |
| Cách dừng process | Cách ngừng từng replica và chứng minh không còn request/tick đang thực thi                               |
| Khôi phục         | Artifact Node tương thích, cấu hình tham chiếu secret và bằng chứng export/restore theo runbook vận hành |
| Quan sát          | Dashboard/log có request ID, outbox age/depth/DEAD, inbox, receipt và ledger; không chứa secret          |
| Quyết định        | Cửa sổ diễn tập, ngưỡng dừng và người quyết định rollback                                                |

Thông số và cách xử lý sự cố dùng [operations](../../docs/devops/OPERATIONS.md); schema/permission dùng [Appwrite setup](../../docs/devops/APPWRITE_SETUP.md). Không sao chép secret vào command history hoặc log.

## Điều kiện bắt đầu

1. Candidate có contract/fixture checks và test suite đạt trên đúng commit; container build, HTTP smoke và Linux tests đã chạy với đúng image digest.
2. Appwrite test đã qua kiểm tra identity, owner isolation, transaction/receipt/inbox/outbox concurrency, restart và lease recovery. Schema drift đã được review riêng; không gộp schema apply vào cutover.
3. Event tương thích ở cả hai chiều Node/.NET được chứng minh cho các boundary bên dưới; giữ nguyên HMAC, event ID và payload. Giữ transport đã được nhận duyệt, không đổi đồng thời direct relay sang broker.
4. Flutter native đã kiểm tra các luồng của owner đang chuyển, gồm mất mạng, retry, đổi tài khoản và hoàn tất trùng. Mọi test failure liên quan phải được xử lý hoặc review với lý do cụ thể.
5. Có cách chặn toàn bộ mutation và internal event/job traffic đến runtime cũ. Đổi URL client hoặc tắt worker đơn thuần không chứng minh API cũ đã ngừng ghi.
6. Readiness của candidate đã được review sau khi các gate nghiệm thu cần thiết đạt. Chỉ sau đó operator mới khai báo đủ năm ID trong cấu hình server. Với runtime inventory hiện tại còn gate pending, dừng ở bước này; không bỏ readiness check hoặc dùng `/health` để thay thế.

## Boundary cần diễn tập

| Owner được chuyển | Luồng phải xác minh khi các owner còn lại vẫn chạy Node                                                                                                                   |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Progress          | Nhận `lesson.completed.v1` từ Learning và `ai.practice.completed.v1` từ AI; nhận purge acknowledgements; gửi entitlement/deletion tới Learning và AI, energy tới Learning |
| Learning          | Gửi completion/purge acknowledgement tới Progress; nhận entitlement/deletion/energy; Progress đọc signed outbox watermark của Learning                                    |
| AI                | Gửi practice completion/purge acknowledgement tới Progress; nhận entitlement/deletion; giữ provider-off và null-score behavior                                            |

Mỗi boundary kiểm tra thành công, duplicate, payload conflict, mất ACK rồi retry, sender sai và transaction thất bại. Replay phải giữ event ID và không tạo effect thứ hai. Sau khi chuyển thêm owner, lặp lại các boundary bị thay đổi runtime; cuối cùng kiểm tra cả ba owner chạy .NET.

## Chuyển một owner

Lặp lại riêng cho Progress, Learning rồi AI; chỉ chuyển owner tiếp theo sau khi owner trước ổn định và đã diễn tập rollback. Thứ tự có thể đổi khi operator ghi rõ dependency và boundary tương ứng trong phiếu.

1. Khóa thay đổi của môi trường. Ghi Node build ID, replica/worker inventory, outbox pending/leased/dead và các tổng receipt/ledger liên quan tới dữ liệu test.
2. Chặn mutation từ client, internal event delivery và job trigger vào owner đang chuyển. Tạm dừng scheduler/worker của owner; producer khác phải giữ event trong outbox để retry. Reads và chế độ offline chỉ tiếp tục theo hành vi sản phẩm đã có.
3. Đợi request, transaction và tick đang chạy kết thúc trong deadline đã ghi. Nếu không chứng minh được đã dừng, hủy cutover. Không xóa lease hoặc sửa inbox/receipt bằng tay.
4. Dừng tất cả Node API/worker replica của owner. Xác nhận không còn active process/execution và không có write mới từ build Node. Không khởi động writer .NET trước khi có bằng chứng này.
5. Khởi động API .NET candidate với worker tắt. Xác minh build ID, signed readiness, identity và owner isolation. Không mở traffic nếu readiness chưa đạt.
6. Chuyển routing được kiểm soát sang .NET và chạy mutation smoke bằng tài khoản test: request mới, replay cùng key, retry sau mất response và conflict. Kiểm tra response lẫn row/receipt/outbox/ledger tương ứng.
7. Bật đúng một nguồn job trigger: một worker instance hoặc external scheduler. Không dùng đồng thời cả hai trong diễn tập. Các flag worker là `COC_PROGRESS_WORKER_ENABLED`, `COC_LEARNING_WORKER_ENABLED`, `COC_AI_WORKER_ENABLED`; giữ tắt trên replica khác.
8. Cho producer/consumer tiếp tục giao event. Để lease hết hạn và được worker hợp lệ thu hồi theo protocol; xác minh pending giảm, watermark và effect hội tụ, duplicate không phát thưởng lại.
9. Quan sát ít nhất cửa sổ đã ghi trong phiếu và một chu kỳ worker; các job theo giờ/tuần phải có kiểm chứng lịch riêng. Chỉ đánh dấu owner ổn định sau khi không còn lỗi chưa giải thích hoặc DEAD event mới.

## Dừng và rollback

Rollback khi có đọc/ghi chéo owner, mất completion, effect trùng, contract sai, readiness thất bại, worker trùng, hoặc outbox/ledger không hội tụ. Ngưỡng latency/error theo [operations](../../docs/devops/OPERATIONS.md) và phiếu diễn tập.

1. Chặn mutation, internal delivery và job trigger tới owner .NET. Tạm dừng worker/scheduler .NET.
2. Đợi và xác minh không còn request/tick đang thực thi; dừng tất cả API/worker .NET replica. Nếu có transaction với kết quả chưa biết, xác minh trạng thái bền vững qua receipt/ledger trước khi xử lý lại.
3. Giữ nguyên rows, event IDs, inbox, outbox và receipts. Không reset dữ liệu, hoàn XP thủ công hoặc chạy lại seed. Giữ schema additive tương thích với Node.
4. Khởi động đúng Node artifact/cấu hình đã ghi, ban đầu chưa bật worker. Xác minh build ID, signed readiness, quyền owner và smoke replay trên dữ liệu đã được .NET ghi.
5. Chuyển routing về Node; bật một nguồn job trigger, tiếp tục event delivery và kiểm tra lease recovery. Giữ nguyên idempotency key/event ID khi retry.
6. So sánh receipt/ledger/effect sau rollback với baseline và các operation hợp lệ trong cửa sổ .NET. Xác minh không mất completion, không cộng thưởng hai lần, pending hội tụ và user khác không bị tác động.
7. Ghi nguyên nhân, thời gian khôi phục và kết quả; khóa chuyển owner tiếp theo cho tới khi lỗi được xử lý và diễn tập lại.

## Bằng chứng kết thúc

Phiếu phải ghi timestamp, commit/image/build ID, operator, các bước thực sự đã chạy, expected/actual, request/event IDs đã khử dữ liệu nhạy cảm và nơi lưu logs an toàn. Ghi riêng:

- Bằng chứng Node dừng trước .NET và .NET dừng trước Node khi rollback, bao gồm tất cả replica và scheduler.
- Dữ liệu .NET ghi được Node đọc/replay an toàn sau rollback; receipts/ledgers không phát sinh effect trùng.
- Kết quả restart/crash tại các điểm trước/sau commit và ACK; lease cũ không settle sau khi mất quyền.
- Mobile native, event boundary và current-image Docker results; không thay chúng bằng liveness hoặc fixture memory.
- Các gate còn thiếu và quyết định của người chịu trách nhiệm.

Chỉ cập nhật `one-writer-cutover-and-rollback` trong runtime inventory sau khi có bằng chứng diễn tập. Readiness và triển khai production vẫn cần quyết định riêng theo kế hoạch; tài liệu này không đánh dấu bất kỳ gate nào đạt.
