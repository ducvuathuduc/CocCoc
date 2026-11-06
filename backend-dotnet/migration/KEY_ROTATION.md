# Xoay API key và HMAC key cho backend .NET

Trạng thái: runbook để review; chưa chạy live, chưa thay secret hoặc recreate container. Không gửi key vào chat, commit, ticket hoặc log. Cấu hình file secret được đọc lúc host khởi động; muốn đổi giá trị phải recreate container liên quan.

## Phân biệt các loại Appwrite key

| Mục đích | Tên cấu hình | Nơi lưu | Phạm vi |
| --- | --- | --- | --- |
| Chạy live probe trên project test | `APPWRITE_API_KEY` | `.secrets/real.env` bị Git ignore trên máy chạy probe | Chỉ dành cho test runner; chỉ cấp scope mà probe được duyệt cần. Không đưa key này vào container .NET. |
| API Progress | `COC_PROGRESS_APPWRITE_KEY` | File secret riêng của Progress trên host | Key server riêng cho owner Progress; chỉ scope TablesDB rows cần thiết. |
| API Learning | `COC_LEARNING_APPWRITE_KEY` | File secret riêng của Learning trên host | Key server riêng cho owner Learning; scope rows và Storage files cần cho chức năng Learning. |
| API AI | `COC_AI_APPWRITE_KEY` | File secret riêng của AI trên host | Key server riêng cho owner AI; chỉ scope TablesDB rows cần thiết. |

Không dùng một operator key có quyền schema/deploy làm runtime key. Không dùng key live probe làm runtime VPS key. Ba key owner phải được tạo riêng trong Appwrite Console cho đúng project; xác nhận endpoint/project ID trước khi cấp. Adapter .NET còn giới hạn bảng theo owner, nhưng key scope vẫn phải theo quyền tối thiểu. Các tên scope cụ thể cần đối chiếu với phiên bản Appwrite và capability thực tế trong Console trước khi tạo key.

Key đã từng được dán vào chat phải coi là đã lộ: tạo key thay thế, cập nhật file private cần thiết, rồi revoke key cũ trong Console trước khi dùng lại; không chờ đến cửa sổ xoay định kỳ. Không đưa giá trị key cũ hoặc mới vào biên bản.

## Xoay Appwrite server key

### Key test dùng cho live probe

1. Xác nhận đúng `coccoc-test` và đúng owner đã duyệt probe. Tạo key test có thời hạn ngắn nhất khả dụng và chỉ scope các hàng/bucket mà probe sẽ chạm tới. Probe Storage cần `files.read` và `files.write`; các probe row cần TablesDB row access.
2. Ghi key trực tiếp vào `.secrets/real.env` trên máy chạy runner, dưới `APPWRITE_API_KEY`. Không đặt `APPWRITE_API_KEY` trong Docker Compose, GitHub Actions hoặc file staging của VPS.
3. Sau khi probe được chủ động cho phép và hoàn tất, revoke key trong Console, rồi xóa giá trị khỏi file local/secret manager. Nếu key đã bị lộ, revoke ngay và tạo key mới thay vì tiếp tục dùng nó.

### Key của service trên VPS

1. Tạo key mới riêng cho đúng service và project. Không thay đồng thời quyền hoặc database. Ghi value trực tiếp vào secret manager/host file tương ứng:
   - `progress/COC_PROGRESS_APPWRITE_KEY`
   - `learning/COC_LEARNING_APPWRITE_KEY`
   - `ai/COC_AI_APPWRITE_KEY`
2. File chỉ có raw value, quyền đọc tối thiểu, không `KEY=`, không shell quotes. Giữ key fields rỗng trong `common.env`/`<service>.env` khi dùng Compose secret overlay, để env fallback không che giấu file thiếu.
3. Recreate duy nhất container của owner đã đổi bằng release/Compose metadata đã review. Host startup provider `/run/secrets` có precedence trên environment; restart/recreate cần được theo dõi như một thao tác vận hành. Không mở readiness hoặc worker bằng thao tác xoay key.
4. Sau khi có quyền kiểm thử, xác nhận service dùng đúng project/owner, Appwrite calls cần thiết thành công, owner boundary còn giữ nguyên và log không chứa key. Với key cũ chưa lộ, revoke sau khi service mới đã được xác nhận. Với key đã lộ, revoke ngay; nếu cần thì tạm dừng service cho tới khi key thay thế được cấu hình.
5. Thu hồi key cũ và xóa bản sao cũ khỏi file/secret manager theo chính sách lưu trữ. Không in cấu hình Compose mở rộng vì có thể chứa giá trị secret.

## Xoay HMAC giữa service

Mỗi entry của `COC_SERVICE_KEYS` là `{ "keyId", "sender", "secretHex" }`; secret phải có ít nhất 32 byte và key ID phải duy nhất trong mỗi keyring. Receiver kiểm tra key ID và sender. Node giữ thứ tự mảng JSON và chọn entry đầu tiên có đúng sender; .NET tự dùng key duy nhất cho sender, hoặc cần `COC_<SERVICE>_SIGNING_KEY_ID` khi có nhiều key. ID .NET thiếu/sai hoặc thuộc sender khác làm relay không có signing key và fail-closed. Runbook phải giữ lựa chọn key cũ trong thời gian chuẩn bị và đổi active selector riêng cho từng runtime.

| Sender key | Receiver keyring cần nhận key đó |
| --- | --- |
| `progress` | Progress, Learning, AI |
| `learning` | Learning, Progress |
| `ai` | AI, Progress |

Các key `scheduler`/`maintainer` do operator quản lý riêng; thêm receiver nào thì phải liệt kê trong phiếu thay đổi trước khi xoay. Không sao chép toàn bộ keyring của một service sang service khác.

### Xoay có overlap

1. Tạo key ID mới và secret ngẫu nhiên riêng cho sender. Lập danh sách toàn bộ receiver từ bảng trên. Ghi nhận release, receiver, sender, operator và cửa sổ thay đổi, không ghi secret.
2. Xác định các Node/.NET sender đang hoạt động. Với .NET, đặt `COC_<SERVICE>_SIGNING_KEY_ID` ở sender bằng key ID cũ trước khi ring có key trùng sender. Với Node, bảo đảm entry cũ đứng trước entry mới trong mảng. Recreate sender và xác nhận vẫn ký bằng key cũ.
3. Thêm key mới vào keyring của tất cả receiver, đồng thời giữ key cũ. Ở sender Node cũng thêm key mới nhưng giữ entry cũ trước; ở sender .NET giữ active ID trỏ tới key cũ.
4. Recreate/restart receiver trước và xác nhận mỗi receiver đã nạp cả hai ID. Recreate sender với cả hai key trong ring nhưng selector vẫn là key cũ. Chưa đổi routing, worker hoặc quyền Appwrite.
5. Chuyển từng sender sang key mới: với .NET đặt `COC_<SERVICE>_SIGNING_KEY_ID` sang ID mới; với Node đưa entry mới lên trước entry cũ trong mảng. Recreate sender và làm tương tự cho scheduler/maintainer signer đang dùng key này. Nếu cùng service vừa là sender vừa là receiver, bước nhận cả hai key phải hoàn tất trước.
6. Giữ key cũ trên receiver trong suốt thời gian mọi Node/.NET sender và scheduler liên quan đã chuyển. HMAC timestamp chỉ hợp lệ trong 5 phút; đợi hết request đang chạy và hơn 5 phút sau lần cuối sender cũ được xác nhận dừng trước khi gỡ key cũ. Nếu không thể xác nhận sender cũ đã dừng, chưa gỡ key.
7. Gỡ key cũ khỏi tất cả receiver và sender, recreate những container/config liên quan, rồi kiểm tra lại event/job path sau khi được cho phép kiểm thử. Không đánh dấu gate cutover đạt chỉ nhờ hoàn tất rotation.

### Key HMAC bị lộ

Không dùng quy trình overlap thông thường để giữ key đã lộ. Phối hợp cửa sổ bảo trì: chuẩn bị key mới; cập nhật tất cả receiver và sender trong cùng cửa sổ; dừng hoặc chặn signed traffic trong lúc cấu hình chưa đồng bộ; xác nhận mọi sender dùng key mới; sau đó gỡ/revoke key cũ ngay. Nếu không thể đổi đồng bộ và xác nhận toàn bộ runtime, giữ internal traffic/worker dừng cho đến khi an toàn.

## Những secret không xoay theo runbook này

- `COC_PROGRESS_CODE_SECRET`: đổi key có thể làm mã giới thiệu/gia đình đã phát hành không còn xác minh được. Cần phân tích format/version và kế hoạch chuyển tiếp dữ liệu trước khi xoay.
- Khóa ký nội dung: đổi khóa riêng/public cần phát hành và xác minh manifest/bundle tương ứng; xử lý theo quy trình ký nội dung.
- Azure/AssemblyAI/Deepgram credentials: xoay theo console/provider và ngân sách/quota tương ứng; giữ provider tắt khi chưa nghiệm thu.

## Bằng chứng cần lưu

Lưu thời gian, project/owner, service/container, commit/image digest, key ID HMAC đã đổi, sender/receiver đã xác nhận, thời điểm revoke, người thao tác và kết quả đã khử secret. Không lưu giá trị key, chữ ký HMAC, JWT, request body hoặc expanded Compose config.

Tất cả bước trên cần được kiểm thử/diễn tập trên test environment trước khi nhận staging. Hiện runbook chỉ hoàn tất phần hướng dẫn; không có key nào được xoay bởi tài liệu này.
