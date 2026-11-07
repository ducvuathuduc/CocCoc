# CocEnglish CMS (`apps/cms`)

Trang quản trị chạy trên máy tính, viết bằng Next.js (App Router) để soạn nội dung cho app mobile.
CMS chỉ sở hữu các bảng `c_*`; bản nội dung đã publish (`l_*`) vẫn do service Learning quản. CMS **đọc**
các bảng của app (`p_*`, `l_*`) để cho thấy một người học đã làm gì, nhưng không ghi vào đó một dòng nào.

## Chạy local

```bash
cp .env.example .env.local   # chỉ cần điền CMS_ADMIN_USER_IDS; key Appwrite lấy từ .secrets/real.env
pnpm --filter @cocenglish/cms dev
```

Mở http://127.0.0.1:5174 (hoặc `localhost:5174` — `allowedDevOrigins` đã cho phép cả hai, nếu không
Next chặn tài nguyên dev của origin lạ và trang hiện ra nhưng không bấm được gì). Đăng nhập bằng tài
khoản quản trị Appwrite (email + mật khẩu), và `CMS_ADMIN_USER_IDS` phải chứa `userId` của tài khoản
đó. CMS không còn chế độ đăng nhập dev không cần mật khẩu.

Đặt `APPWRITE_ENDPOINT`, `APPWRITE_PROJECT_ID`,
`APPWRITE_API_KEY` vào `<repo>/.secrets/real.env` (thư mục đã gitignore và nằm ngoài `apps/cms` —
ứng dụng này không chứa key trong file của nó), rồi chạy `dev` như bình thường, không cần lệnh nào
khác. Biến có sẵn trong môi trường luôn thắng file, nên CI và máy publish giữ nguyên hành vi. Điền
thêm `CMS_ADMIN_USER_IDS` là danh sách `userId` được vào. Thiếu cả ba biến Appwrite mà
`NODE_ENV=production` thì app từ chối khởi động (`CONFIG_INCOMPLETE`) — không âm thầm ghi file.
Không có Appwrite thì cũng không đăng nhập được: file store chỉ còn là chỗ để harness chạy.

## Màn hình

| Trang | Nội dung |
| --- | --- |
| `/` | Bảng điều khiển: việc cần làm hôm nay (đếm từ bản nháp thật), hành trình Soạn → Kiểm tra → Xuất bản, bài học gần đây và tình trạng khóa |
| `/lessons` | Không gian bài học của khóa: tìm, lọc theo trạng thái, sửa và xem trước từng bài |
| `/courses` | Danh sách khóa học |
| `/courses/[courseId]` | Thông tin khóa, cấu trúc section, bài kiểm tra trình độ (10 câu bộ dựng lấy theo vị trí), danh sách unit, tạo/xóa unit, đổi thứ tự unit, nhập từ repo, lối vào media toàn khóa và lối vào tìm kiếm trong nội dung |
| `/courses/[courseId]/media` | Báo cáo nợ media của cả khóa: bảng từng unit, danh sách key cho `generate-audio.mjs --only`, bản JSON `/api/media/owed`, ô nạp audio/ảnh cấp khóa |
| `/courses/[courseId]/search` | Tìm trên bản nháp của cả khóa (không phân biệt hoa thường và dấu thanh), mỗi kết quả chỉ đúng tab · dòng · cột trong editor và bấm vào là mở ngay chỗ đó; kèm ba danh sách nội dung lặp lại và bảng "Thay thế trong toàn khóa" xem trước từng dòng sẽ đổi |
| `/courses/[courseId]/units/[unitId]` | Editor từ vựng / câu / hội thoại / truyện, lint trực tiếp, `Ctrl+S` lưu, panel media app sẽ dùng (nghe + xem ảnh), ô nạp audio/ảnh, cảnh báo manifest/catalog lệch bản nháp, badge `#N` trên những dòng bài kiểm tra trình độ đọc theo vị trí (chỉ unit đầu), lối vào *bài học bản dựng* |
| `/courses/[courseId]/units/[unitId]/lesson` | Những gì bản dựng gần nhất thực sự giao cho app: node/bài/câu theo `manifest.json`, đáp án đọc từ đúng trường bộ dựng dùng để chấm, mỗi câu trỏ lại dòng soạn (kể cả khi từ ấy thuộc unit khác), bài thay thế khi máy không có mic/loa, và danh sách id mà không bản nháp nào còn sở hữu |
| `/courses/[courseId]/readiness` | Checklist "còn việc gì trước khi app nhận bản này": mọi điều kiện của bản hiện hành trong một bảng, mỗi dòng lấy số từ đúng màn hình sở hữu nó và có lối `sửa →` |
| `/builds?course=` | Nút xuất file tác giả + chạy ba cổng kiểm tra nội dung, panel Publish (chạy thử / publish thật) và lịch sử mọi lần chạy kèm log |
| `/users?q=` | Mọi tài khoản người học trong Appwrite (mới nhất trước), tìm theo email hoặc mã tài khoản |
| `/users/[userId]` | Một người học: hồ sơ, gói đang dùng, khóa đang học, 14 ngày gần nhất, góp ý còn mở, và nút khóa/mở tài khoản |
| `/ops/inbox` | Thư của người học: góp ý còn mở, báo cáo về một người, báo lỗi câu hỏi |
| `/ops/reports` | Báo cáo lỗi & cảnh báo theo unit |
| `/ops/audit` | Nhật ký thao tác của admin |
| `/ops/access` | Danh sách userId được phép vào CMS |

## Pipeline nội dung

1. **Nhập**: `importCourseFromRepo` đọc `content/<courseId>/source/<version>` bằng đúng parser của repo
   (`tools/content/course-lib.mjs`) qua tiến trình con `scripts/read-authored.mjs`.
2. **Sửa**: editor làm việc trên `UnitDraft`, dùng `parse`/`render` trong `src/cms/`.
3. **Xuất**: `exportCourseToRepo` ghi ngược lại các file `.mjs` tác giả, giữ nguyên khối comment đầu file.
4. **Kiểm tra**: `runContentGates` chạy `build-course`, `lint-course`, `check-content` và ghi kết quả vào
   `c_build_runs`.
5. **Publish**: nút ở `/builds` gọi `tools/content/publish-appwrite.mjs` — chạy thử mặc định là
   `--dry-run` (không ghi gì), còn publish thật cần `CMS_ALLOW_PUBLISH=1` và có xác nhận. Bộ publish
   của repo upload manifest/bundle/media lên bucket `learning-assets` rồi chuyển con trỏ bản publish qua
   `POST /v1/admin/content-versions`; CMS không tự chữ ký, không tự verify, không ghi `l_*`.

Đầu vào đóng băng của app là các bảng `.mjs`, nên CMS không thể sinh ra định dạng mà máy dựng không đọc được.

Lỗi mà người soạn cần đọc thì **trả về** (`{ ok: false, message }`), không `throw`: server action ném lỗi là
Next trả lời 500 và thay thông báo bằng digest, nên câu hướng dẫn biến mất trước khi tới toast — chỉ còn
"có lỗi xảy ra". Traceback của tiến trình con vì thế ghi bằng `console.error` ở server (giữ nguyên log), còn
người soạn nhận đúng một câu tiếng Việt chỉ vào folder cần kiểm tra. Đã bấm thật trong trình duyệt trên
instance cách ly (`CMS_DATA_DIR` trỏ thư mục tạm): khóa lạ → toast đỏ "Không đọc được bảng tác giả của khóa
"zz_probe_missing"…", khóa `vi_en` → toast xanh "Đã nhập 16 unit từ repo vào bản nháp." kèm bảng khóa cập nhật.

## Cấu trúc khóa (section)

Bộ dựng của repo nối unit với phần **theo theme**, không theo unitId
(`tools/content/build-course.mjs:46` — `sections.find((s) => s.units.includes(u.theme)).sectionId`),
nên một unit chưa section nào liệt kê theme của nó làm lần build hỏng ngay. CMS giữ bất biến đó:

- Tạo unit tự gán theme vào section cuối (`sec1` nếu khóa chưa có section).
- Xóa unit gỡ theme khỏi section trong cùng một action — nếu không, `course.mjs` còn lại một theme
  không unit nào và cổng lint sẽ từ chối bản xuất.
- Panel *Cấu trúc khóa* ở `/courses/[courseId]` cho phép đổi mã/tên section, thêm section, chuyển unit
  sang section khác, và xóa section **rỗng** (nút Xóa bị chặn khi section còn unit).
- `structureIssues()` trong `src/cms/structure.ts` là một kiểm tra duy nhất, dùng chung cho panel,
  `exportCourseToRepo` và trạng thái sẵn sàng publish, nên không thể lưu màn hình sang trạng thái mà
  lần xuất kế tiếp sẽ bị từ chối. Cổng lint còn đòi ít nhất 2 section (`tools/content/lint-course.mjs:252`).

**Cảnh báo khi xóa unit**: `build-course.mjs:39` đánh số `unitId = u{index+1}` theo thứ tự, nên xóa một
unit giữa khóa đổi mã `uNN` của mọi unit đứng sau; tiến độ người học đã lưu theo mã cũ sẽ không còn khớp.
Hộp xác nhận nói rõ điều này. File tác giả trong repo chỉ đổi ở lần *Xuất* kế tiếp.

## Đổi thứ tự unit

Cột **Thứ tự** ở `/courses/[courseId]` có nút ↑/↓ cho từng hàng; mã `uNN` in ngay bên cạnh là mã app sẽ
dùng, không phải id `01-greetings` của CMS. Vì `build-course.mjs:39` đánh số theo *vị trí*, chuyển một unit
qua bao nhiêu hàng thì bấy nhiêu unit đổi mã — nên hộp xác nhận liệt kê range sẽ đổi trước khi ghi, ví dụ
`Chuyển “Đồ ăn và thức uống” từ u02 sang u03? … 1 unit đi ngang sẽ đổi mã: u03…u03 thành u02…u02`.

- `moveUnitDraft` (`src/server/actions/unit.ts`) không tin vị trí trình duyệt gửi: nó đọc lại
  `store.listUnits`, tự tìm vị trí hiện tại của unit, rồi chỉ ghi những hàng có `order` thay đổi
  (`orderChanges` trong `src/cms/order.ts`). Một bước kề nhau ghi 2 hàng; kéo unit cuối lên đầu ghi cả
  đuôi. Vị trí luôn kín `0..n-1`, nên `uNN` sinh ra không bao giờ có khoảng trống.
- Mỗi hàng ghi kèm `expectedRevision`. Có người sửa cùng lúc thì hành động dừng và trả
  "Chỉ chuyển được X/Y unit … Tải lại trang để xem thứ tự hiện tại rồi thử lại." thay vì âm thầm ghi đè.
  Nửa chừng thì hai hàng có thể trùng vị trí, và lần chuyển kế tiếp tự vá, vì nó tính từ bảng đang lưu chứ
  không từ bảng trình duyệt đang hiển thị.
- Mỗi lần đổi ghi một mục `unit.reorder` vào `/ops/audit`, kèm danh sách `unitId`/`order` trước và sau.
- Hàng bị khóa cho tới khi `router.refresh()` vẽ lại (`useTransition`). Diễn lại hai lần bấm liên tiếp trong
  trình duyệt mới lộ ra race này: cú bấm thứ hai tính vị trí từ props cũ và xếp sai thứ tự thật.
- Hệ quả với người học: tiến độ đã lưu theo mã cũ sẽ lệch với các unit bị đổi mã. Chỉ thành vấn đề ở lần
  *Xuất* + *Publish* kế tiếp, vì file tác giả trong repo chưa đổi cho tới lúc đó.
- **Xuất không xóa file.** Sau khi đổi thứ tự, tên `.mjs` cũ của các unit đổi chỗ vẫn nằm trong
  `content/<courseId>/source/<version>/units`. `course.mjs` mới không tham chiếu tới chúng, nhưng
  "Nhập bảng tác giả từ repo" đọc cả thư mục nên sẽ dựng lại những unit ấy dưới tên cũ.
  `exportCourseToRepo` trả danh sách (`stale`) và trang khóa hiển thị cảnh báo kèm từng tên file; việc xóa
  trong repo để người giữ nội dung quyết, vì một file tác giả chưa nhập lần nào cũng là nội dung đã soạn.

## Bài kiểm tra trình độ (placement)

App mở khóa bằng 10 câu mà **không bản nháp nào mô tả**: `build-course.mjs:1005-1028` tự tay lấy
`vocab[3]`, `sentences[4]`, `sentences[9]`, `sentences[13]`, `vocab.slice(8)`, `sentences[17]`,
`vocab[14]`, `sentences[21]`, `story.questions[2]` và từ có ảnh thứ hai của unit đầu — toàn bộ theo
*vị trí* — rồi ghi thành `dist/<version>/bundles/placement.json` với `unitId: "u1"`,
`lessonId: "placement"`. Panel "Bài kiểm tra trình độ" trên trang khóa là bản sao có kiểm chứng của mười
slot đó (`src/cms/placement.ts`), không phải màn hình trang trí:
`node apps/cms/scripts/placement-check.mjs` so từng câu với bundle thật và fail nếu bộ dựng đổi slot.

Panel phân biệt ba trạng thái, vì ba việc phải làm khác nhau:

- **hết dòng để đọc** — unit đầu bị cắt ngắn hơn vị trí bộ dựng chỉ. `build-course.mjs` không bỏ câu ấy
  mà *dừng với TypeError* (`choiceVocab` đọc `v.vocabularyId` của `undefined`, `matchPairs` đọc
  `picked[0].en` khi slice rỗng). Panel liệt kê đúng những câu sẽ làm build chết, nên người soạn biết
  phải thêm lại dòng nào thay vì đoán vì sao gate đỏ.
- **khác bản nháp** — app đang hỏi một nội dung mà nháp hiện tại không còn chỉ nữa (sửa chữ một dòng đã
  đọc, hoặc đổi chỗ). Việc là chạy lại `build-course.mjs`, không phải nạp file nào.
- **khớp bản nháp** — app đã hỏi đúng những gì nháp nói.

Câu 10 là ví dụ thứ hai của cổng 4 ảnh đã nói ở mục media: `:1024` cho `imageChoice` khi unit đầu có từ 4
từ đánh dấu `img`, chưa đủ thì nó thành bài chọn chữ của `vocab[6]`; panel ghi rõ đang ở dạng nào và vì
sao. Câu 5 cũng chỉ có một cặp để nối nếu unit đầu còn 9 dòng — panel gọi đó là bài nối vô nghĩa.

`placementState()` chỉ so bằng khóa khi *bộ dựng tự nêu được khóa*: câu 1/7 đọc đúng một dòng từ vựng nên
id suy ra chính xác, câu 5 dự được cả danh sách 5 cặp (dedupe theo cả hai chiều, y như `:347-357`), câu 10
là id của từ có ảnh thứ hai. Bốn câu đó so bằng `vocabularyIds`; sáu câu còn lại so bằng chữ bộ dựng in
vào đề bài (`sentence.vi`, `question.q`, `word.en`), vì `vocabularyIds` của chúng do `vocabMatcher` suy từ
token trong câu (`build-course.mjs:70`) — CMS không có matcher đó và sẽ không tự chế một bản thứ hai.

Panel chỉ nói được *sau khi* lưu. Ngay trong editor của unit đầu (`order === 0`), mỗi dòng bộ dựng đọc theo
vị trí mang badge `#N` — `placementMarks()` đi qua đúng bảng slot ấy nên hai chỗ không thể lệch nhau: `#1`
trên `vocab[3]`, `#8` trên `sentences[21]`, `#5·cặp 1..5` trên cả dải năm dòng bài nối quét chứ không riêng
dòng nó bắt đầu, và `#10·ảnh 2` trên **từ có ảnh thứ hai** chứ không phải dòng 2 của bảng. Badge gắn theo
*vị trí*, không gắn theo nội dung: đổi chỗ hai dòng thì badge ở lại và câu hỏi đổi theo — đó là hệ quả phải
thấy trước khi bấm Lưu. Xóa đến mức hết dòng thì badge biến mất và dòng chữ đỏ "Unit không còn dòng cho câu
…" thay vào, đúng như panel báo build chết. Unit khác không có badge nào vì bộ dựng chỉ đọc unit đầu.

## Tìm trong nội dung và từ dạy trùng

Khóa `vi_en` có 16 unit và 3771 chuỗi trong bản nháp — không ai trả lời "từ này đã dạy chưa" bằng cách cuộn.
`src/cms/search.ts` làm hai việc, cả hai đều không hiển nhiên:

- **Gấp chữ**: NFD rồi bỏ `\u0300-\u036f`, lowercase, nén khoảng trắng ở *hai phía* của phép so, và giữ lại
  index nguồn của từng ký tự nó sinh ra. Vì vậy `chao hoi` vẫn tìm thấy `Chào hỏi`, và phần tô sáng cắt từ
  bản gốc chứ không phải từ bản đã gấp — một bản nháp thừa khoảng trắng vẫn tìm ra bình thường.
- **Vị trí**: mỗi kết quả mang `tab` · `row` · `field` đúng như editor in ra (màn hình đếm dòng từ 1), nên
  bấm vào kết quả mở unit đó ở đúng tab qua `?tab=`; `unit-editor.tsx` đọc tham số này và bỏ qua giá trị lạ.

Ba danh sách trùng là phần tìm từng từ không bao giờ chỉ ra được:

| Danh sách | Đếm | Vì sao tách ra |
| --- | --- | --- |
| `repeatedWords` | headword xuất hiện ở **nhiều hơn một unit** | app sẽ giới thiệu lại; hai unit cùng dạy một nghĩa thì một trong hai là thừa |
| `repeatsInsideUnit` | hai dòng cùng từ **trong một unit** | `lintUnit` đã chặn lưu loại này (`vocab[i] … Trùng từ với dòng j`), nên danh sách chỉ còn soi bản nháp lưu trước khi có cổng; bộ dựng dedupe khi nối cặp nên người học nghe một từ hai lần |
| `repeatedSentences` | cùng một câu tiếng Anh ở nhiều nơi | thường là lúc sửa câu mà quên xóa bản cũ |

Tìm chỉ đọc **bản nháp**, không đọc bản dựng — con số "trong N chuỗi của M unit" là những gì đang lưu; muốn
biết app sẽ phát gì thì xem `/courses/<courseId>/media`. Quá 200 kết quả thì màn hình gắn nhãn "chỉ hiện 200
đầu — tìm cụ thể hơn" chứ không âm thầm cắt, và ô tìm trống vẫn hiện ba danh sách trùng vì đó là câu hỏi không
có từ khóa.

## Thay thế hàng loạt có xem trước

`src/cms/replace.ts` là câu hỏi tiếp theo của ô tìm: "vậy có được phép ghi lại ở mọi nơi không". Nó đi qua
đúng những cột mà `unitEntries` đi qua — `check:replace` so hai danh sách cột với nhau nên không cột nào trở
thành thứ tìm được mà không nói rõ có thay được hay không — và khớp bằng chính phép gấp mà ô tìm dùng, vì vậy
điều màn hình gạch chân chính là điều sẽ bị đổi.

Ba điều khiến nó không phải một ô input đơn giản:

- **Hai cột bị khóa**: `vocab.id` là key mà câu, lượt thoại, truyện và file media trỏ vào; `unit.chủ đề` là key
  mà panel Cấu trúc khóa trỏ vào. Kế hoạch vẫn báo số dòng khớp ở đó kèm lý do, chứ không âm thầm bỏ qua.
- **Xem trước rồi mới ghi**: `previewReplace` chỉ tính, không ghi. Nút "Sửa N dòng ở M unit" gọi
  `checkReplace`, dựng lại từng unit trong bộ nhớ, đối chiếu từng ô với bản đang lưu (drift) và chạy `lintUnit`
  — một ô bị người khác sửa giây trước, hay một phép thay khiến hai headword trùng nhau, đều chặn **cả lô**,
  vì một nửa phép thay trên 16 unit khó thấy hơn là không thay gì.
- **Ghi qua đúng cổng của editor**: mỗi unit đi qua `store.saveUnit` với revision đang sống, rồi mới có audit
  `unit.replace` ghi lại tìm/thay. Không có đường tắt nào cho thao tác hàng loạt.

Thay ra đúng chữ cũ thì không thành edit (`text === cell.text`), nên "Hello" → "Hello" không đụng tới bản nháp
nào; `find` nằm trong `to` ("friend" → "best friend") cũng không lặp vô hạn vì bộ thay luôn tiến qua đoạn vừa
thay.

## Media mà app sẽ phát

Soạn chữ xong mà không nghe được thì chưa gọi là quản lý nội dung cho app. Panel "Media app sẽ dùng ·
uNN" trong trang unit liệt kê đúng những tài nguyên bộ dựng khai báo, theo quy tắc key trong
`docs/content/EXERCISE_FORMATS.md` §5: `a.<uNN>.s<k>.n` / `.s` cho từng câu, `a.<uNN>.d<k>.n` / `.s` cho
từng lượt thoại, `i.<uNN>.<wordId>.webp` cho từ đánh dấu `img`. `src/cms/media.ts` suy danh sách đó từ
`UnitDraft` (không đọc repo), `src/server/media-service.ts` nối nó với
`content/<courseId>/media/{audio,images}`, `dist/<version>/audio-catalog.json` và
`dist/<version>/bundles/*.json` để biết file nào đã có, clip ấy đọc câu nào.

Riêng clip nghe-when-chạm của từ vựng (`a.w.<slug>.n`) thì bản nháp **không** tự nêu được id: app suy slug
từ đúng chữ in trên ô bài tập (`build-course.mjs:166`), nên nó khác `wordId` của dòng từ vựng mỗi khi tên
id viết theo kiểu khác (`oclock` vs `o_clock`) và xuất hiện cả cho những từ chỉ là một token trong câu.
Vì vậy `media-service.ts` đọc thêm `dist/<version>/bundles/` — mỗi bundle ghi `unitId` theo số uNN và liệt
kê toàn bộ asset bài học của unit đó phát cho app — rồi nối những key `a.w.*` mà nháp không sinh ra vào
danh sách, đánh dấu `fromBuild`. Khóa thật có **498** clip như vậy, tức là 498 trong số 1760 asset app phát
ra mà suy từ nháp thì CMS liệt kê được **0**; `node apps/cms/scripts/media-check.mjs` đo lại hai con số này
trên repo thật mỗi lần chạy. Hai điều rút ra từ chính phép đo: một clip từ vựng xuất hiện trong bundle của
nhiều unit (410/498, có clip hiện ở cả 16 unit), nên nó là hàng đợi của *từng* unit dùng nó và là **một**
việc trong danh sách `--only`; và bundle cũng chở ảnh/clip của unit khác (`i.u3.apple` nằm trong bài ôn của
u10) — media-service cố ý chỉ lấy `a.w.*`, vì file ấy là nợ của unit đã giới thiệu từ, không phải của u10.

Mã `uNN` lấy theo *vị trí* (`generatorUnitId(order)`), tức là `build-course.mjs:39`, không phải id
`01-greetings` của CMS — cùng bất biến đã nói ở mục cấu trúc khóa.

**Bundle cũng trả lời câu hỏi mà không trường nháp nào trả lời được: app thực sự nhận dạng bài nào.**
`build-course.mjs:918-925` đổi `imageChoice` sang bài chọn chữ khi chưa có 4 từ đánh dấu `img` được giới
thiệu tới lúc dựng, và `:928-944` đổi `dialogueTurn` sang bài lặp câu khi chưa có 3 câu trả lời khác nhau;
bản nháp vẫn giữ nguyên yêu cầu cũ nên panel chỉ đọc nháp sẽ báo "đủ". Vì vậy `media-service.ts` đếm luôn
`exercises[].type` của từng bundle (`exerciseTypes`, đã trừ bài kiểm tra xếp lớp ở `:1035` — bundle đó
mượn số `u1` nhưng không phải bài của unit 1) và ghi `drilledWithPicture` cho từng ảnh: id của ảnh
(`i.u1.student`) và `vocabularyIds` của câu hỏi (`u1.student`) trùng nhau theo đúng quy tắc đặt tên của bộ
dựng, nên so được từng cái. Khóa thật hôm nay: unit 1 có **4** từ đánh dấu `img` nhưng bản dựng chỉ sinh
**3** bài chọn ảnh, và **2** ảnh (`i.u1.student`, `i.u1.teacher`) vào bài mà không câu hỏi nào đố tới —
CMS nói rõ đó là việc của nội dung (thêm từ có ảnh rồi dựng lại), không phải việc của kho media.

Clip và ảnh phục vụ qua `GET /api/media?course=&file=`: trang này chỉ người đã đăng nhập vào được (proxy
chuyển hướng trước khi tới handler), `file` và `course` bị chặn bởi whitelist `[a-z0-9_.-]` rồi resolve
bằng `path.resolve` và kiểm tra vẫn nằm trong thư mục media của đúng khóa đó; file chưa có trả 404 chứ
không lộ đường dẫn. Panel ghi rõ khi thiếu file: publish chỉ upload file tồn tại, nên những mục thiếu sẽ
chạy phương án không audio/ảnh của app.

### Nạp audio/ảnh ngay trong CMS

Ô *Nạp vào kho media* cuối panel cho phép kéo-thả đúng những file bộ tạo sinh ra, chọn nhiều một lúc.
**Tên file quyết định nó rơi vào key nào** (`a.u3.s7.n.aac`, `i.u3.apple.webp`) — người nạp không phải
đi tìm ô trống nào tương ứng với dòng nào. Action `uploadMedia` chỉ nhận key mà chính nó suy ra cho khóa
đó (`courseAssets`), nên:

- không có cách nào gieo một tên file tùy ý vào cây media, kể cả tên có `../`;
- sau một lần đổi thứ tự, số cũ không còn trong index — clip mang số cũ bị từ chối, đúng lúc người soạn
  cần biết clip ấy đã đổi chỗ.

Bốn lớp chặn còn lại chạy trước khi ghi: đúng đuôi theo key, đúng định dạng thật của file (`isAdtsAac`
cho clip, `webpSize` cho ảnh — ảnh phải 512×512 vì `build-course.mjs:216` khai mọi ảnh là 512×512 bất
kể file), dung lượng (8 MB clip / 4 MB ảnh), và file đã tồn tại thì chỉ ghi khi tích *cho phép ghi đè*.
Mỗi file sai bị trả về kèm lý do hiển thị ngay dưới ô chọn. Cấu hình
`experimental.serverActions.bodySizeLimit: '10mb'` cho vừa một lô file nhỏ (trình duyệt chia lô ≤ 8 MB).
Mỗi đợt ghi một mục `media.upload` vào `/ops/audit` kèm `fileId`/`bytes`/`sha256`.

**File chưa đủ, với audio còn cần manifest.** `build-course.mjs:117` lấy sha256/độ dài/giọng đọc của clip
từ `content/<course>/media/audio-manifest.json` — và bỏ qua entry có lời thoại khác bản đang soạn. Vì vậy
panel phân biệt bốn trạng thái: *thiếu file*, *đã có file nhưng manifest chưa có hoặc còn ghi lời thoại cũ*
(build vẫn dùng hash placeholder), *catalog bản dựng đang ghi lời khác bản nháp*, và *đủ*. Ảnh thì tin thẳng
từ byte trên đĩa, không cần manifest. Manifest do `tools/content/generate-audio.mjs` (ffmpeg) sở hữu, CMS
không tự bịa `durationMs` — chạy `node tools/content/generate-audio.mjs --only a.` sau khi nạp clip để bản
dựng dùng số thật.

**Trạng thái thứ ba tồn tại vì catalog, không phải vì file.** `generate-audio.mjs` thu âm theo
`dist/<version>/audio-catalog.json` (`build-course.mjs:1119` chép `sentence.en` / `dialogue.line` vào đó
lúc dựng), nên clip trên đĩa luôn nói đúng *catalog*, chứ không nói đúng *bản nháp*. Sửa một câu hoặc đổi
thứ tự unit mà chưa dựng lại thì file vẫn có, manifest vẫn khớp catalog, và app sẽ phát câu cũ. Panel gọi
đúng tên việc phải làm: chạy `build-course.mjs` để cập nhật catalog, rồi thu âm lại các key bị đánh dấu.

### Báo cáo media toàn khóa

`/courses/<courseId>/media` trả lời câu hỏi mà 16 panel unit không trả lời cùng lúc được: cả khóa còn nợ
gì. `courseMediaReport` đọc catalog + thư mục media + manifest + bundle **một lần** cho cả khóa rồi áp quy
tắc suy key của từng unit (`deriveAssets` dùng chung với panel, nên không thể có chuyện trang khóa báo
khác trang unit), gộp các mục chưa đủ thành một danh sách việc:

- bảng từng unit: `tài nguyên (audio/ảnh) · chưa có file · manifest chưa khớp · catalog lệch nháp · ảnh
  không bài nào dùng · ảnh chưa bị đố · đủ`, mỗi ô nợ là một liên bộ lọc tới đúng đơn vị đó;
- lệnh ready-to-paste cho `generate-audio.mjs --only <key>`, đã bỏ qua những key mà tool chưa nhìn thấy;
- hai hộp cảnh báo tách bạch *key chưa vào catalog* (phải dựng trước) và *catalog lệch bản nháp* (cũng
  phải dựng trước, nhưng vì lý do khác);
- hộp thứ ba nếu có bundle đọc được mà thiếu `unitId`/`assets`: danh sách clip từ vựng suy từ bản dựng
  sẽ thiếu theo, nên trang báo thẳng tên file thay vì làm như khóa đã đủ;
- ô *Nạp vào kho media* của chính trang khóa, dùng chung whitelist `courseAssets` với panel unit — whitelist
  này cũng lấy từ bản dựng, nên một clip `a.w.*` mà chỉ bundle biết vẫn nạp được.

`GET /api/media/owed?course=<id>` là bản máy đọc của cùng báo cáo đó (`audio.keys`, `audio.needsBuild`,
`audio.driftKeys`, `audio.wordClipGaps`, `images.keys`, `images.unusedKeys`, `images.unquizzedKeys`,
`built.unreadableBundles`, `built.exerciseTypes`, `built.perUnit[].exerciseTypes/images/unusedPictures/unquizzedPictures`,
`totals` với `pictureNotUsed` và `pictureNeverQuizzed`, và chuỗi `command`), cho người chạy bộ sinh thay vì copy từ màn hình. Route đứng sau phiên admin giống `/api/media`: thiếu `course` → 400, khóa chưa có nháp → 404,
không đăng nhập → proxy chuyển hướng về `/login`. Danh sách trên màn hình giới hạn 200 dòng để trang không
phình; route JSON trả toàn bộ.

## Bài học mà app sẽ hỏi

Trang unit trả lời "tôi đã soạn gì". Câu hỏi mà người vận hành gặp thật lại là *"điện thoại sẽ hỏi gì"* — và
bản nháp không trả lời được. `/courses/[courseId]/units/[unitId]/lesson` (nút *bài học bản dựng* ở đầu panel
media của unit) đọc `content/<course>/dist/<version>/manifest.json` rồi từng
`dist/<version>/bundles/<lessonId>.json`, tức đúng những file app tải về. `version` lấy từ bản ghi khóa
(`course.draft.version`, fallback `v2`) và `uNN` lấy từ *vị trí* (`generatorUnitId(order)`) — màn hình không
đoán thư mục nào "có vẻ" là bản mới.

Lý do không dựng lại câu hỏi từ nháp: bộ dựng đổi dạng bài theo điều kiện thực tế
(`build-course.mjs:918-925` thay `imageChoice` bằng bài chọn chữ khi chưa đủ 4 từ có ảnh đã giới thiệu,
`:928-944` thay `dialogueTurn` bằng bài lặp câu khi chưa đủ 3 câu trả lời khác nhau) và phát sinh đề bài từ
những trường ghép chữ. Một bản suy thứ hai trong CMS sẽ là nguồn sự thật thứ hai, và màn hình này tồn tại để
báo *đầu ra của chính bộ dựng*.

- **Đếm theo file, không theo nháp**: số node / số bài / số câu và phân bố theo 12 dạng bài đều đọc từ
  bundle. Bản `vi_en/v2` dựng 8 node · 32 bài · 399 câu cho mỗi unit; `u1n1l1.json` là tên file thật (không
  pad số 0). Khóa chưa từng dựng thì `manifestFound: false`, và màn hình nói "chưa có bài học nào để hỏi"
  thay vì đưa một trang số 0 trông như đã kiểm tra.
- **Đáp án đọc từ trường mà app chấm**: `correctChoiceId` → chữ của lựa chọn đó; không có thì
  `content.referenceText`; rồi dòng đầu của `gradingRule.acceptedText` (các cách chấp nhận còn lại hiển thị
  ở dòng "Chấp nhận cả", không in hai lần); `matchPairs` ghép theo `correctPairIds`, `wordBank` và
  `sentenceOrder` xếp theo `correctTokenIds` — để thứ tự hiện ra là thứ tự app mong, không phải thứ tự đã xáo.
  Bài nối cặp không in dòng "Đáp án" nữa vì danh sách cặp bên dưới chính là đáp án.
- **Mỗi câu trỏ về đúng dòng soạn**: chip từ vựng mở `?tab=vocab` ở đúng dòng. Mã `uNN` trong id không phải
  unit đang xem — bài ôn của unit 16 hỏi từ mà 13 unit khác dạy. Vì vậy `lesson-service.ts` gộp
  `wordIndex(draft, uNN)` của *mọi* unit trong khóa thành một index và trả kèm `unitIds` (dịch `uNN` sang id
  trang soạn); chip của từ mượn mang nhãn unit chủ và nối sang editor của unit đó. Đo trên bản dựng hôm nay:
  **275/399** câu của unit 16 là bài ôn; màn hình unit 16 có **948** chip từ vựng thì **394** mang nhãn một
  unit khác (`u11` 66, `u10` 49, `u2` 46 …).
- **`stale` chỉ nói một điều**: id mà *không* bản nháp nào trong khóa còn sở hữu. Trước khi có index toàn
  khóa, phép so theo từng unit biến mọi từ mượn thành cảnh báo đỏ (17–53 id giả trên mỗi unit 2…16, hàng
  trăm chip vàng); sau khi sửa, cả 16 unit đều `stale: 0` và ô cảnh báo chỉ hiện khi bản dựng thật sự cũ hơn
  bản nháp — xóa dòng `hello` khỏi unit 1 thì 43 câu báo `u1.hello`.
- **Bài thay thế** (`nonAudioAlternative` / `nonSpeechAlternative`) hiện cùng dạng, đề và đáp án của nó, để
  thấy người học không mic/loa sẽ làm gì thay vào; id mà chỉ bài thay thế hỏi cũng được tính vào `stale`.
- **Bao nhiêu thiếu thì nói thiếu bấy nhiêu**: file manifest liệt kê mà không đọc được vào `missing`, file
  có nhưng không phải bundle bài học vào `unreadable`; màn hình báo ngay phía trên các con số.

## Checklist sẵn sàng xuất bản

Nút Publish chỉ nói *một* lý do: `publishReadiness().blocking` trả câu đầu tiên và dừng ở đó, nên người soạn
sửa xong lý do 1, bấm lại, rồi mới thấy lý do 2. `/courses/[courseId]/readiness` (lối vào từ trang khóa và
từ chính panel Publish) liệt kê cùng lúc mọi điều kiện của bản hiện hành.

Trang này **không tự tính gì cả** — mỗi dòng gọi lại đúng hàm của màn hình sở hữu con số đó:

| Dòng | Số lấy từ |
| --- | --- |
| Unit có bản nháp | `c_units` (dòng duy nhất đếm quy mô, không đếm nợ — nên nó là dòng `ok` duy nhất có số khác 0) |
| Cấu trúc khóa | `structureIssues(sections, themes)` — nguyên văn như panel *Cấu trúc khóa* |
| Unit có lỗi chặn lưu / Unit có cảnh báo | `lintUnit` của editor — đúng bộ kiểm tra mà action lưu dùng để từ chối, nên dòng lỗi đếm theo số unit chứ không theo số câu |
| Gate nội dung gần nhất | `c_build_runs`: lần `GATES · SUCCEEDED` gần nhất so với `updatedAt` từng unit |
| Bài kiểm tra trình độ còn đọc được / lệch bản dựng | `placementReport` — bảng placement của trang khóa |
| Bundle bản dựng đọc được / Id bản dựng hỏi mà không nháp nào còn | `courseLessonDrift`, dùng lại đúng vòng đọc bundle `readBundles` của màn *bài học bản dựng* |
| Clip/ảnh app cần / Ảnh chưa bài nào đố tới | `courseMediaReport` — báo media toàn khóa |
| Nội dung dạy trùng | `repeatedWords` / `repeatsInsideUnit` / `repeatedSentences` của màn tìm kiếm |

- **Chặn** gồm: khóa không unit, cấu trúc hỏng, unit có lỗi chặn lưu, chưa từng chạy gate hoặc unit sửa sau
  lần gate, vị trí placement không còn dòng, và khóa chưa có `manifest.json`. **Cảnh báo** là phần còn lại;
  nợ media cố ý chỉ ở mức cảnh báo vì publish chỉ upload file tồn tại, app tự rơi về phương án không audio.
- `publishable` và câu "Nút publish đang chặn: …" là nguyên văn `publishReadiness()`, nên hai màn không cãi
  nhau được. Bảng thì **khắt khe hơn theo chủ đích**: khóa chưa từng dựng vẫn bật nút *Chạy thử publish*
  (nút này chỉ nhìn số unit, cấu trúc và độ mới của gate — nên lint sạch là đủ để nó bật) nhưng dòng bundle
  của checklist chặn, vì không có manifest thì app còn đang tải bản cũ.
- Mọi dòng có lối `sửa →` trỏ tới màn hình thật của chính khóa này; harness duyệt hết danh sách href.
- Đo trên bản `vi_en` thật (Part B của harness): 512 bài · 6384 câu · 3891 tài nguyên, 0 id mà không bản nháp
  nào còn sở hữu — cùng những số mà từng màn unit hiển thị.

## Kiểm chứng

```bash
pnpm --filter @cocenglish/cms typecheck
pnpm --filter @cocenglish/cms lint
pnpm --filter @cocenglish/cms check:parse    # parse/render của CMS khớp parser của repo (16 unit)
pnpm --filter @cocenglish/cms check:export   # file export đọc ra đúng nội dung bộ dựng đang đọc (101 checks)
pnpm --filter @cocenglish/cms check:store    # mọi thao tác ghi/đọc AppwriteStore khớp khai báo c_* trong foundation.json (37 checks)
pnpm --filter @cocenglish/cms check:structure # mỗi unit thuộc đúng 1 section, course.mjs do CMS xuất build được
pnpm --filter @cocenglish/cms check:media     # tài nguyên CMS liệt kê = tài nguyên bộ dựng khai báo, dạng bài + ảnh đo được từ bundle (40 checks)
pnpm --filter @cocenglish/cms check:order     # đổi thứ tự: vị trí kín, chỉ ghi lại unit đi ngang, xuất ra đúng mã uNN (42 checks)
pnpm --filter @cocenglish/cms check:media-upload # upload media: chỉ nhận key thật của khóa, đúng định dạng, ghi đúng cây publish đọc (38 checks)
pnpm --filter @cocenglish/cms check:media-report # báo cáo toàn khóa = cộng đúng từng panel unit, tính cả clip từ vựng + dạng bài + ảnh chưa bị đố chỉ bản dựng biết; key đưa được vào --only; đổi thứ tự chỉ chuyển nợ (56 checks)
pnpm --filter @cocenglish/cms check:placement   # mười câu placement = mười vị trí bộ dựng đọc; unit bị cắt ngắn báo là build chết; so từng câu với bundles/placement.json thật; badge #N trong editor nằm đúng những dòng đó (47 checks)
pnpm --filter @cocenglish/cms check:search      # gấp dấu/hoa thường vẫn tô đúng ký tự gốc; mỗi kết quả đúng tab·dòng·cột; ba danh sách trùng nói đúng điều tên nó gọi, gồm cả chuyện cổng lưu đã chặn trùng trong một unit; đo trên 16 unit và 3771 chuỗi thật (28 checks)
pnpm --filter @cocenglish/cms check:replace     # cột tìm được = cột thay được (chỉ id và chủ đề bị khóa, kèm lý do); thay đúng chữ người soạn gõ, thay vô nghĩa không thành edit; ô bị sửa/xóa sau khi xem trước chặn cả lô; lô không lưu được thì không ghi một byte; đo trên 3435 chuỗi của 16 unit thật (26 checks)
pnpm --filter @cocenglish/cms check:lesson      # đọc bundle thật: 12 dạng bài đều có nhãn, đáp án lấy đúng trường bộ dựng chấm, 399 câu unit 1 khớp phép đếm trực tiếp trên file, 275 câu ôn của unit 16 trỏ đúng unit chủ, id lạ không bị quy cho unit đang xem; cộng file thiếu / file không phải bundle / version chưa dựng / unit bị xóa dòng (42 checks)
pnpm --filter @cocenglish/cms check:readiness   # mỗi dòng checklist = đúng con số của màn hình sở hữu nó; chặn/cảnh báo khớp bộ điều kiện của nút Publish; khóa chưa từng dựng thì bảng khắt khe hơn nút; mọi lối "sửa →" trỏ tới một màn hình thật; đo cả trên 512 bài · 6384 câu · 3891 tài nguyên của bản vi_en (42 checks)
pnpm --filter @cocenglish/cms check:publish     # gate + publish: đúng ba cổng của repo chạy ở thư mục repo, một dòng lịch sử được ghi đè bằng chính runId; nút mặc định là --dry-run, publish thật cần CMS_ALLOW_PUBLISH=1 và bị từ chối trước khi khởi động tiến trình; sửa nháp sau gate chặn publish kèm tên unit; gate đỏ giữa đường dừng cả vòng lặp lẫn nút; bộ publish chết giữa chừng thành PUBLISH/FAILED kèm stderr; bốn kịch bản chỉ ghi bảng c_* đã khai báo (26 checks)
pnpm --filter @cocenglish/cms check:lifecycle    # năm nút soạn nội dung chạy thật, trên store c_* giả + repo thật (chỉ đọc): nhập 16 unit sinh đúng mã NN-theme theo file tác giả, section nguyên văn, lint sạch, id đủ, nhập lại ghi đè không nhân đôi; lưu thông tin khóa không đụng cấu trúc; tạo unit đưa theme vào section trước khi ghi hàng; cấu trúc bị từ chối bằng đúng câu của panel; lưu unit tự sinh id và trả danh sách lỗi thay vì ghi nửa bản; xóa unit gỡ theme theo; folder tác giả không đổi một byte (46 checks)
pnpm --filter @cocenglish/cms check:users        # màn người học: đọc Appwrite Auth + đúng những cột có index của bảng app (mọi `equal` đối chiếu foundation.json); người chưa có hồ sơ thì là null chứ không phải số 0; hộp thư chỉ tin còn mở; thứ duy nhất ghi xuống là status của tài khoản, kèm audit user.lock/user.unlock; bị từ chối khi khóa chính tài khoản quản trị, userId sai, tài khoản đã mất, Appwrite không gọi được, khóa lần hai, người không ở trong CMS_ADMIN_USER_IDS, và máy chưa nối project (30 checks)
```

## Cổng kiểm tra và publish

Đây là hai chỗ duy nhất của CMS khởi động tiến trình, và là chỗ duy nhất chạm vào project Appwrite dùng
chung, nên cả hai đều từ chối làm việc một nửa:

- `runContentGates` gọi `node tools/content/build-course.mjs`, `lint-course.mjs`, `check-content.mjs` với
  `cwd = CMS_REPO_ROOT` (thư mục repo, không phải thư mục CMS), timeout 5 phút/cổng và giữ 40 dòng cuối của
  mỗi cổng vào `log`. Cổng nào đỏ thì vòng lặp **dừng ở đó** — chạy tiếp hai cổng sau chỉ cho log dài hơn,
  không cho kết quả đúng hơn.
- Một lần chạy là **một dòng** `c_build_runs`: ghi `RUNNING` trước, rồi ghi đè bằng `SUCCEEDED`/`FAILED` với
  đúng `runId` đó (`revision` tăng, `createdAt` giữ nguyên). Nhờ vậy trang `/builds` vẫn còn hàng đang chạy
  nếu trình duyệt bị đóng giữa chừng.
- `publishReadiness()` trả lời theo thứ tự, và **dừng ở lý do đầu tiên**: khóa chưa có nháp → cấu trúc hỏng
  → chưa từng chạy gate thành công → có unit sửa *sau* lần gate xanh gần nhất (`updatedAt` của unit so với
  `createdAt` của run). Lý do cuối là điểm chính: bộ publish đóng gói `dist/`, nên một lần sửa sau gate có
  nghĩa là app sẽ nhận bản chưa từng được kiểm.
- Nút **Chạy thử publish** là mặc định và thêm `--dry-run` vào `tools/content/publish-appwrite.mjs`. Nút
  **Publish thật** bị disable khi `CMS_ALLOW_PUBLISH` chưa bật, và khi bật rồi vẫn cần một hộp xác nhận; cả
  hai nút disable khi `gatesOk` false hoặc khi CMS đang chạy chế độ file.
- Bộ publish nhận `APPWRITE_ENDPOINT`/`APPWRITE_PROJECT_ID`/`APPWRITE_API_KEY`/`COC_DATABASE_ID` do CMS
  truyền tường minh; ba cổng gate thì không — chúng là tool của repo, chạy bằng những gì repo có.
- CMS không tự ký, không tự upload, không tự chuyển con trỏ và **không ghi bảng `l_*`**: việc đó của service
  Learning qua `POST /v1/admin/content-versions`. Audit phân biệt `content.publish_dry_run` với
  `content.publish` để một lần chạy thử không trông như một lần lên sóng.

`node apps/cms/scripts/publish-check.mjs` chứng minh toàn bộ thứ tự trên mà không chạm tới project nào: nó
thay `node:child_process` bằng bản ghi lại mọi lời gọi (kể cả `env` và `cwd`) và thay TablesDB bằng bản kiểm
theo `foundation.json`. Stub phải mô phỏng cả chi tiết `execFile` tự định nghĩa `promisify.custom` — nếu
không, hành động gọi `await run(...)` nhận về một chuỗi thay vì `{ stdout, stderr }` và hỏng theo cách mà
tiến trình thật không bao giờ hỏng.

## Quản lý người học

Soạn bài rồi mà không biết người học đang ở đâu thì chưa gọi là vận hành. `/users`,
`/users/[userId]` và `/ops/inbox` đọc đúng những bảng app đã ghi — `p_profiles`, `p_entitlements`,
`l_enrollments`, `p_day_activity`, `p_feedback`, `p_user_reports`, `l_reports` — qua cùng một server key
mà store `c_*` dùng, và **không ghi một dòng nào** vào đó (`src/server/ops/appwrite.ts`).

- **Chỉ lọc trên cột có index.** Appwrite từ chối filter trên cột chưa được index bằng một 400 mà chỉ
  project thật mới báo, nên `users-check.mjs` đối chiếu từng `equal` mà code gửi với index khai báo trong
  `appwrite/schema/foundation.json` và fail nếu lệch. Mỗi hàng là một câu hỏi đã định sẵn
  (`firstRow` / `userRows` / `openRows`), không có đường nào để ai đó tự ghép filter tùy ý.
- **Không có số 0 nào được bịa.** Người học chưa đi qua onboarding thì hồ sơ/gói/tiến độ là `null`, và
  màn hình nói "App chưa lưu hồ sơ nào cho tài khoản này" thay vì đưa ra `0 XP · 0 bài` — con số 0 trông
  như một kết luận, còn null là sự thật.
- **Từ khóa rỗng không được biến thành tham số.** `Users.list` trả 400 cho `search=""` ("Value must be a
  valid string and at least 1 chars"), nên `listAccounts` bỏ hẳn tham số khi ô tìm trống hoặc toàn khoảng
  trắng. Đây là lỗi đầu tiên mà màn `/users` gặp khi chạy thật — danh sách mặc định chết ngay, chỉ vì
  một chuỗi rỗng được gửi đi như một từ khóa; `users-check.mjs` giờ dựng lại đúng 400 đó trong stub.
- **Khóa tài khoản = đổi status trên Appwrite Auth.** Đó là bản ghi duy nhất CMS chạm tới ngoài `c_*`,
  và là thứ app kiểm khi đăng nhập; tiến độ, điểm và file media của người kia vẫn nguyên, mở khóa thì mọi
  thứ trở lại. Vì vậy không có "reset tiến độ", "xóa tài khoản" hay "đổi gói" trong các trang này: những
  việc đó thuộc service Learning, không thuộc CMS.
- **Nút trả lời trước khi gọi đi** trong năm trường hợp: userId sai định dạng, tài khoản nằm trong
  `CMS_ADMIN_USER_IDS` (khóa nó là mất quyền vào CMS — và đó là cách duy nhất một admin tự nhốt mình),
  tài khoản đã bị xóa, Appwrite không gọi được, và máy chưa nối project nào. Khóa lại một tài khoản đang
  khóa trả `{ ok: true, unchanged: true }`: không ghi Appwrite, không ghi nhật ký, và toast nói thẳng là
  đã khóa sẵn.
- Mỗi lần khóa/mở ghi một mục `user.lock` / `user.unlock` vào `/ops/audit` với `targetId` là userId và
  `beforeJson` là trạng thái trước đó, nên lịch sử trả lời được "ai khóa ai, lúc nào, trước đó ra sao".
  Hai động từ đó phải có mặt trong `OPERATION_LABELS`: thiếu một dòng, `/ops/audit` in ra nhãn dự phòng
  và một lần khóa bị đọc thành "Cập nhật nội dung" — cột đối tượng vì thế giờ là "Đối tượng" (bài, file
  media hoặc tài khoản) và ô userId bấm được sang `/users/<id>`. `users-check.mjs` chốt cả hai.
- `'use server'` chỉ cho phép export hàm async. Đặt một hằng chuỗi trong file action làm `next build`
  bỏ cả module và mọi client import chết bằng câu "The module has no exports at all" — trông như sai
  đường dẫn, nhưng là một quy tắc khác. `LEARNER_GONE` vì thế nằm ở `src/server/ops/learners.ts`.

Cả ba màn đã chạy thật trong trình duyệt với project test, trên một tài khoản giả có đủ hồ sơ/gói/tiến độ
(rồi xóa sạch sau khi chụp): bấm "Khóa tài khoản" → badge đổi sang "Đang khóa", và lời gọi đăng nhập thật
sau đó bị Appwrite trả `403 user_blocked` — đúng câu màn hình hứa; bấm mở lại thì đăng nhập được ngay.
Một tab cũ bấm khóa lần hai chỉ nhận toast "Tài khoản đã bị khóa trước đó." và `c_admin_audit` vẫn chỉ có
bốn mục cho hai lần khóa hai lần mở, không có dòng thứ năm. Màn `/users/<id>` của một userId không còn
trong project (các dòng `p_day_activity` do probe cũ để lại) hiện đúng trang "Không có tài khoản này" thay
vì một bộ số toàn 0.

## Khi Appwrite chập chờn

Endpoint region thỉnh thoảng đứt một nhịp (connect timeout), nên `AppwriteStore` tự thử lại 3 lần
(nghỉ 400 ms rồi 800 ms) cho mỗi lời gọi. Hết retries mà vẫn không gọi được thì người soạn nhận một câu
tiếng Việt ("nội dung vẫn chưa lưu — bấm lưu lại") thay vì một 500 làm nút kẹt mãi ở chữ "Đang lưu…";
mọi nút đều `try/finally` nên nó luôn bấm lại được. Một 4xx (Appwrite từ chối request) và exception của
chính app thì không bị che. Nhật ký thao tác là bước *sau* khi nội dung đã ghi: nếu chỉ riêng nó hỏng,
hành động trả `ok: true` kèm `warning` và màn hình báo "đã lưu nội dung, nhưng nhật ký không ghi được" —
nói "chưa lưu" sẽ khiến người soạn bấm lại một lần lưu đã thành công. Mọi hành động ghi đều mang `warning`
đó: lưu khóa, lưu unit, tạo/xóa unit, đổi thứ tự unit, đổi cấu trúc section, nhập từ repo, xuất ra file tác
giả, nạp audio/ảnh, chạy gate và publish.
Đã diễn lại cả hai nhánh trong trình duyệt bằng một server giả lập Appwrite (chỉ bảng `c_admin_audit` trả
500): nút "Nhập bảng tác giả từ repo" và "Chạy gate kiểm tra nội dung" vẫn báo thành công kèm dòng cảnh báo
màu vàng về nhật ký — không có trang 500, không có nút kẹt ở "Đang…".
Phần đọc người học (`src/server/ops/appwrite.ts`) đi qua đúng `withTransientRetry` đó, nên một nhịp đứt ở
Appwrite cũng chỉ nhận về một câu (`LEARNERS_UNAVAILABLE`) thay vì một trang trắng hoặc một danh sách rỗng
trông như "chưa có ai".

## Bảng Appwrite của CMS

Bốn bảng `c_*` đã là một phần sơ đồ chính thức của repo: khai báo ở `docs/data/DATA_MODEL.md`
(owner `CMS`) + `docs/data/PERMISSIONS.md`, rồi `pnpm schema:declare` sinh ra
`appwrite/schema/foundation.json` (66 bảng). Tất cả `rowSecurity: true`, không cấp quyền cho client —
chỉ server key của CMS đọc/ghi, và CMS không bao giờ ghi `l_*`/`p_*`/`a_*`. Phần quản lý người học đọc
các bảng `p_*`/`l_*` bằng chính key đó (chỉ lọc trên cột có index) và không ghi lại gì; thay đổi duy nhất
nó tạo ra nằm ở Appwrite Auth, không phải trong bảng nào.

| Bảng | Row id | Cột | Index |
| --- | --- | --- | --- |
| `c_courses` | UUID (tìm theo cột `courseId`) | `courseId` string36, `title` string120, `updatedBy` string36, `draftJson` mediumtext65536 + `revision`/`createdAt`/`updatedAt` | `u_courseId` unique |
| `c_units` | UUID (tìm theo cột `unitKey`) | `courseId` string36, `unitId` string36, `unitKey` string80 (`courseId__unitId`), `order` integer, `theme` string40, `title` string120, `cefr` enum A1/A2/B1/B2, `vocabCount`/`sentenceCount` integer, `draftJson` mediumtext65536 + `revision`/`createdAt`/`updatedAt` | `u_unitKey` unique, `k_courseId_order` (courseId, order) |
| `c_build_runs` | `runId` | `runId`/`courseId`/`versionId`/`actorId` string36, `kind` enum GATES/PUBLISH, `status` enum RUNNING/SUCCEEDED/FAILED, `message` string500, `logJson` mediumtext65536, `createdAt` datetime + `revision`/`updatedAt` | `k_courseId_createdAt` (courseId, createdAt) |
| `c_admin_audit` | `entryId` | `entryId`/`actorId`/`requestId` string36, `operation` string64, `targetId` string120, `beforeJson`/`afterJson` mediumtext20000 (writer cắt ở 20000 ký tự), `createdAt` datetime | `k_createdAt` (createdAt) |

Ba bảng đầu mutable nên bộ sinh tự thêm `revision`, `createdAt`, `updatedAt`; `c_admin_audit`
append-only nên giữ nguyên. Row id của course/unit là UUID do Appwrite sinh, vì vậy bản ghi tìm theo
cột có index (`courseId`, `unitKey`) chứ không phải `$id`.

`pnpm schema:apply` với bốn bảng `c_*` **đã chạy một lần trên test project** (có yêu cầu rõ ràng,
`APPWRITE_PROJECT_ENV=test` + `ALLOW_SCHEMA_APPLY=reviewed-test-project`, cộng dồn 4 bảng / 40 cột / 5
index, `missing: 0`). Project khác vẫn cần yêu cầu riêng. Key chỉ nằm trong môi trường của tiến trình
(khuyên export từ một file ngoài repo), không bao giờ trong file của app.
