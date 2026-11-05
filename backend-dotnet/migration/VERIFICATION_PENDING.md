# Kiểm thử và nghiệm thu để chạy sau

Theo yêu cầu hiện tại, tập trung triển khai và ghi lại các bước kiểm thử; không chạy kiểm thử cho thay đổi staging mới. Kết quả cũ được lưu riêng trong [runtime inventory](runtime.json), không chứng minh các thay đổi sau đó đã qua kiểm thử.

## Cấu hình staging mới — chưa kiểm thử

- [ ] Kiểm tra cú pháp Nginx template sau khi điền domain/cert/snippet paths; xử lý default host, IPv6, DNS, renewal và site có sẵn trên VPS.
- [ ] Xác minh raw path/query và body qua HTTPS proxy không thay đổi chữ ký HMAC; giữ nguyên Authorization/HMAC headers, không thêm URI suffix/rewrite vào proxy_pass.
- [ ] Kiểm tra allowlist `/internal/` và `/ready`: dịch vụ/địa chỉ operator thật được phép, public caller bị chặn, vẫn yêu cầu HMAC; xác định source sau Docker/NAT thực tế.
- [ ] Kiểm tra payload voice, provider fallback timeout, disconnect, proxy 413/502/504 và không tự retry mutation tại proxy.
- [ ] Kiểm tra log Nginx và log toàn host không lộ URI/query, token hoặc nội dung nhạy cảm ngoài policy; cấu hình rotation/collection trước khi mở traffic.

- [ ] VPS: kiểm tra unit `docker/staging/vps/cocenglish-dotnet.service`, đường dẫn Docker/Compose, EnvironmentFile, quyền host và khả năng đọc file secret.
- [ ] Xác nhận systemd và lệnh Compose thủ công dùng cùng project name, base + file-secret overlay và metadata; start chỉ dùng image digest đã pull, không tạo stack thứ hai, stop dùng đúng Compose/metadata của release đang chạy.
- [ ] Diễn tập systemd start/stop, reboot, Docker restart, container crash/unhealthy, timeout shutdown; xác nhận `ExecStartPre` preflight chặn Compose khi cấu hình sai mà không lộ secret; systemd active không thay thế readiness.
- [ ] Diễn tập update/rollback: stop release cũ trước khi đổi path file; giữ artifact/secret references cũ, không xóa dữ liệu hoặc chạy trùng Node/.NET writer.
- [ ] Cấu hình và kiểm tra domain/TLS/firewall/internal-route access, registry pull access, giám sát và dung lượng VPS sau khi có thông tin host.

- [ ] Kiểm tra commit trong `images.json`, OCI revision label, biến `BUILD_ID` trong image, `/health` và request log khớp nhau; env/secret staging không ghi đè build ID bằng giá trị cũ.
- [ ] Chạy `check-staging-config.sh` trên Linux với cấu hình đúng và các tình huống thiếu/duplicate/placeholder/credential-like variable/secret chỉ có whitespace/trùng Appwrite owner key/sai Compose overlay; xác nhận `docker compose config --quiet` không in resolved model, không có secret value trong stdout/stderr và script không đọc bằng shell `source`. Kiểm tra riêng quyền đọc secret bằng user thực của image; preflight không tự chứng minh container access.

- [ ] Build và kiểm tra middleware telemetry: mỗi request tạo một event 1001 với service/build/operation/route mẫu/status/duration/request ID/error code.
- [ ] Kiểm tra đủ success, lỗi auth/validation/business, lỗi chưa xử lý, OPTIONS/health/readiness và client disconnect; telemetry không thay response hoặc cancellation.
- [ ] Kiểm tra log mới không chứa raw URL/query, body, token, Appwrite key, HMAC headers/signature, dữ liệu user hoặc exception message; kiểm tra cả framework/HttpClient log sau bộ lọc.
- [ ] Kiểm tra meter `CocEnglish.Api`, counter `cocenglish.api.requests` và histogram `cocenglish.api.request.duration`; tags chỉ dùng service/operation/method/status/error, không gắn request ID/user ID.
- [ ] Chọn collector/hosting, retention và người phụ trách dashboard/cảnh báo; exporter OTLP/HTTP đã có nhưng mặc định tắt, không có collector/dashboard trong Compose và không bổ sung endpoint vào OpenAPI.
- [ ] Cấu hình exporter tùy chọn: endpoint trống phải tắt export; URL sai scheme/path/userinfo/query/fragment phải fail-closed; endpoint HTTPS `/v1/metrics` gửi đúng hai meter với HTTP/protobuf và resource service name.
- [ ] Chạy restore `--locked-mode` và build ba service với OpenTelemetry package locks; khi endpoint trống, host phải khởi động như trước và không tạo OTLP exporter.
- [ ] Nếu collector yêu cầu header, dùng overlay `compose.staging.otel-secrets.yaml` với mỗi file `COC_OTEL_METRICS_HEADERS` riêng cho service; kiểm tra không xuất hiện trong env, logs, URL hoặc image. Xác nhận collector unreachable/rejected không làm lộ secret hay ảnh hưởng kết quả request.
- [ ] Kiểm tra meter `CocEnglish.Workers`: một tick success/failure/cancelled và histogram duration cho từng service; xác nhận invoked signed job routes và scheduled workers đều đi qua cùng runner.
- [ ] Xác nhận đủ bốn job Progress (`outbox_relay`, `deletion_purge`, `streak_rollover`, `league_settlement`) đều phát đúng một mẫu tick cho signed route lẫn worker; cancellation do shutdown không bị ghi thành failure hoặc bị tính hai lần.
- [ ] Kiểm tra `cocenglish.outbox.events`: leased bằng tổng claim, ACK/retry/dead đúng dispatcher report, series zero được phát; tags chỉ là service/outcome. Xác nhận không có user/event/request/owner ID.
- [ ] Kiểm tra gauge `cocenglish.outbox.backlog` có pending/leased/dead và `cocenglish.outbox.oldest_event.age` tính đúng tuổi PENDING/LEASED theo từng owner; sampler chỉ chạy khi exporter có endpoint và `COC_<OWNER>_ADMITTED=reviewed-cloud-gate`, dùng query tối đa một row với projection dữ liệu `occurredAt`, không đọc payload và không log/export row ID; khi không có event thì bỏ mẫu tuổi, lỗi refresh xóa snapshot cũ và không ảnh hưởng API.
- [ ] Bổ sung/chạy test driver cho JSON `Query.select`, giữ system ID dùng nội bộ, không đưa projection vào `CountAsync`; test age với đồng hồ giả, queue rỗng, timestamp tương lai/hỏng và refresh lỗi xóa gauge cũ. Hiện các test này chưa được viết/chạy theo yêu cầu hoãn kiểm thử.
- [ ] Xác nhận index `(status,occurredAt)` đã được áp dụng cho p_outbox/a_outbox trước khi bật sampler production; chọn dashboard/alert cho backlog depth, tuổi event, DEAD và worker failures.

- [ ] Build host sau khi thêm `AddKeyPerFile`; kiểm tra key-per-file provider có trong shared framework/image được pin.
- [ ] Kiểm tra thứ tự cấu hình: file `/run/secrets` override env/JSON/command-line ở startup; không mount thì giữ cấu hình hiện có.
- [ ] Xác nhận `APPWRITE_API_KEY` dùng cho live runner không cấu hình được host Staging/Production; mỗi owner chỉ được bật persistence bằng key `COC_<OWNER>_APPWRITE_KEY` riêng, còn chế độ Development hoạt động như đã định.
- [ ] Kiểm tra file trống/sai nội dung, directory vắng mặt hoặc không đọc được: không được vô tình mở business/readiness hoặc nhận HMAC sai.
- [ ] Kiểm tra overlay `compose.staging.secrets.yaml`, quyền đọc của user non-root và mỗi container chỉ nhận secret thuộc service mình.
- [ ] Kiểm tra API key/HMAC key không xuất hiện trong container env, build context, image hoặc log khi dùng overlay.
- [ ] Kiểm tra secret rotation bằng recreate container; không reload keyring giữa request, không bật worker/đổi admission ngoài ý muốn.
- [ ] Xác nhận AI provider vẫn tắt với template mặc định; sau khi có gate speech mới kiểm tra overlay secret tùy chọn, quyền file của non-root, provider fallback/quota và không lộ key trong env/image/log.
- [ ] Diễn tập quy trình trong [KEY_ROTATION.md](KEY_ROTATION.md) trên test project: test probe key khác key runtime owner; thay Appwrite key không lộ; triển khai receiver-first, giữ signer trên key cũ rồi chuyển Node theo thứ tự mảng hoặc .NET qua `COC_<SERVICE>_SIGNING_KEY_ID`; chờ hết cửa sổ chữ ký 5 phút rồi gỡ key cũ; xác nhận outage/rollback khi cấu hình một phía thất bại.
- [ ] Xác nhận host tự chọn key khi chỉ có một key cho sender; khi có nhiều key, chỉ ID cấu hình đúng mới ký được, còn thiếu/sai ID và ID thuộc sender khác đều fail-closed.

- [ ] Kiểm tra cú pháp YAML workflow `dotnet-images.yml` và Bash `tools/build-images.sh`; chưa chạy syntax check/build/workflow cho các file mới này.
- [ ] Chạy thủ công chế độ build-only: đủ ba image, đúng commit/architecture/OCI labels và artifact metadata; không publish hoặc chạy test.
- [ ] Sau khi được cho phép publish: kiểm tra quyền GHCR, manifest digest của đủ ba image, `images.env` và quyền pull trên staging host.
- [ ] Kiểm tra trường hợp build/push thất bại giữa chừng: không tạo bộ metadata hoàn chỉnh, giữ `.pending`; output directory cũ và checkout có thay đổi phải bị từ chối.
- [ ] Kiểm tra workflow chỉ chạy khi dispatch, mặc định publish=false; chỉ job publish có packages:write, không tự deploy hoặc chạm Appwrite.

- [ ] Kiểm tra cú pháp và nội suy `docker/compose.staging.yaml` bằng metadata mẫu không chứa secret.
- [ ] Build/pull đúng ba image Linux amd64 theo digest, chạy với filesystem chỉ đọc và user mặc định của image.
- [ ] Kiểm tra health probe, giới hạn bộ nhớ/PID, log rotation và shutdown trong thời gian grace.
- [ ] Kiểm tra port chỉ bind loopback; TLS, DNS, certificate trust, routing và truy cập internal routes do hosting cung cấp.
- [ ] Xác nhận URL HTTPS của cả ba service truy cập được từ container và HMAC keyring khớp giữa các cặp sender/receiver.
- [ ] Thay các host `.invalid` trong `apps/mobile/config/dotnet-vps.public.example.json` bằng domain staging và callback recovery/verification đã duyệt, build API-mode native, xác nhận Appwrite JWT/Auth, CORS, idempotency và ba contract; giữ `real.public.json` chưa đổi cho tới cutover được duyệt.
- [ ] Kiểm tra real-profile admission từ chối mọi API endpoint có host kết thúc `.invalid`, đồng thời vẫn nhận domain HTTPS hợp lệ; mẫu chưa thay host không được mở API mode.
- [ ] Kiểm tra Appwrite recovery/verification callbacks từ chối `.invalid`, HTTP, userinfo, query và fragment; callback HTTPS đã đăng ký vẫn gửi đúng URL.
- [ ] Xác nhận thiếu key/admission vẫn đóng business routes và readiness; health xanh không mở admission.
- [ ] Xác nhận mỗi service chỉ nhận server key của owner mình, không có secret trong image/build context/log.
- [ ] Xác nhận worker mặc định tắt, một worker/owner khi bật, không trùng external scheduler hoặc Node writer.
- [ ] Diễn tập cập nhật image và rollback bằng đúng artifact; không đổi/xóa dữ liệu học viên.

## Các phần của migration vẫn cần nghiệm thu

- [ ] Friend-streak: kiểm tra giới hạn quan hệ PENDING/ACTIVE, quyền inviter/recipient, CHILD/block/preferences, response/replay và cập nhật khi cả hai cùng có activity theo ngày. Code đã có trong `ProgressFriendStreaks`, `ProgressCompletionEffects.ExtendFriendStreaksAsync` và được gọi từ cả `ProgressLesson`/`ProgressPractice`; các nhãn `response-capacity-and-authorization-expansion` và `completion-consumer-extension` trong ma trận vẫn được giữ cho đến khi có bằng chứng kiểm chứng tương ứng.

- [ ] Appwrite `coccoc-test`: identity thật, quyền user, cô lập tài khoản, transaction/concurrency, Storage, phục hồi lease và restart/crash. Chạy runner `tools/test-appwrite-live.ps1` sau khi cấu hình key ở máy; các probe chuẩn bị sẵn chưa phải bằng chứng cloud.
- [ ] Event Node/.NET hai chiều: thành công, duplicate, payload conflict, sender sai, mất ACK, retry và lỗi transaction.
- [ ] Toàn bộ backend mới trên Docker/Linux với cấu hình thật; Docker hiện chưa phản hồi ở lần kiểm tra gần nhất.
- [ ] Flutter Android/iOS xuyên suốt ba host .NET: học online/offline, review/từ vựng, progress/economy/social, đổi tài khoản và xóa tài khoản.
- [ ] Provider giọng nói: thiết bị, chất lượng đánh giá, quota, quyền riêng tư, chi phí; giữ provider tắt trước khi nghiệm thu.
- [ ] Chủ repo review schema drift, hosting, secrets và lịch chuyển đổi; diễn tập one-writer cutover/rollback theo runbook.

Không đổi các gate thành đạt chỉ vì đã viết code hoặc chuẩn bị cấu hình. Ghi command, commit/image, expected/actual và môi trường thực tế khi các bước trên được thực hiện.
