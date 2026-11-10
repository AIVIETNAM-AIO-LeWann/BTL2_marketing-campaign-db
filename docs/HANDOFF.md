# Bàn giao ngữ cảnh — đọc trước khi tiếp tục trên Ubuntu

Cập nhật ngày 10/11/2026. File này giữ các quyết định đã thống nhất để thành viên hoặc phiên trợ lý mới tiếp tục mà không cần lịch sử chat. Hướng dẫn môi trường nằm ở [ubuntu-setup.md](ubuntu-setup.md).

## 1. Mục tiêu và phạm vi đang làm

Đề tài: **Cơ sở dữ liệu quản lý chiến dịch marketing đa kênh**, dùng cho nhiều ngành hàng, không giới hạn mỹ phẩm. Nhóm 4 người. BTL1 đã có đặc tả, EERD và ánh xạ 15 bảng. BTL2 yêu cầu MySQL hoặc SQL Server; nhóm đã chọn **MySQL**.

Chỉ triển khai và rà soát **phần 1 — Tạo bảng và dữ liệu mẫu (3 điểm)** trước. Phần 2 trở đi sẽ chia việc sau. Không tự mở rộng sang web hoặc viết toàn bộ các bài procedure/function nghiệp vụ khi chưa phân công.

Yêu cầu phần 1:

- Hiện thực tất cả bảng, khóa, miền giá trị và ràng buộc ngữ nghĩa BTL1.
- Điều kiện kiểm tra được trong CREATE TABLE phải dùng PK/FK/UNIQUE/NOT NULL/CHECK, không thay bằng trigger.
- Điều kiện liên bảng/liên dòng dùng trigger hoặc workflow giao dịch có kiểm tra trước COMMIT.
- Mỗi bảng ít nhất 5 dòng dữ liệu mẫu có ý nghĩa; có tình huống minh họa hợp lệ và vi phạm.

## 2. Những quyết định đã chốt — không tự đổi lại

| Quyết định | Nội dung |
|---|---|
| 15 bảng | Giữ số lượng theo ánh xạ BTL1, không thêm bảng cho đủ chỉ tiêu. |
| Phân công | Tên thống nhất của quan hệ Nhân viên–Chiến dịch; N:M có nhiệm vụ và khoảng tham gia; ánh xạ thành PhanCong. |
| Hoạt động | Chuyên biệt hóa **rời nhau và toàn phần**: mỗi hoạt động thuộc đúng 1 lớp Email hoặc Mạng xã hội. Không có hoạt động thuộc kênh khác trong phạm vi này. |
| Thương hiệu–tài nguyên | **Giữ** liên kết trực tiếp tới danh sách email và tài khoản MXH. Lý do: biết chủ sở hữu ngay khi tài nguyên được khai báo, trước khi có hoạt động sử dụng. Đường qua hoạt động/chiến dịch chỉ cho biết nơi sử dụng. |
| Cùng thương hiệu | Danh sách email/tài khoản MXH sử dụng trong hoạt động phải cùng thương hiệu với chiến dịch. Không cho dùng chung một tài nguyên cho nhiều thương hiệu. |
| Nhân viên–tài khoản | Mỗi nhân viên đúng 1 tài khoản; mỗi tài khoản đúng 1 nhân viên. |
| Ngân sách | Tổng ngân sách hoạt động không vượt ngân sách chiến dịch; **thực chi được phép vượt**, hiển thị chênh lệch. |
| Kết quả ngày | Thực thể yếu, PK (MaHoatDong, NgayGhiNhan); người cập nhật là FK, không nằm trong PK. |
| Dữ liệu thiếu | NULL khác 0; không tính CPA khi chuyển đổi bằng 0/chưa đủ dữ liệu; không lấy trung bình các tỷ lệ riêng lẻ. |
| Lịch sử | Hoàn thành/hủy không tự xóa dữ liệu; giữ phân công, khoản chi và kết quả. |

EERD cũ trong tài liệu BTL1 có thể còn chữ “Tham gia” và chuyên biệt hóa bán phần. Cần sửa hình theo quyết định trên khi hoàn thiện report; code hiện tại đã theo Phân công/toàn phần. Ma trận [constraints.md](constraints.md) diễn giải RB01–RB16 và các ràng buộc EERD.

## 3. Lược đồ hiện thực

- Nhân sự: NhanVien, TaiKhoan, SoDienThoaiNhanVien, PhanCong.
- Lõi chiến dịch: ThuongHieu, KenhMarketing, ChienDich, HoatDongTrienKhai.
- Email: HoatDongEmail, DanhSachNhanEmail, HoatDongEmail_DanhSach.
- Mạng xã hội và đo lường: TaiKhoanMangXaHoi, HoatDongMangXaHoi, KhoanChi, KetQuaNgay.

Tên cột, kiểu dữ liệu và khóa chính thức ở `database/01_schema.sql`. Không đổi tên FK/tên cột riêng lẻ khi chia việc; MaNhanVien ở ChienDich là người chính, ở HoatDongTrienKhai là người phụ trách. KhoanChi dùng MaNguoiGhiNhan; KetQuaNgay dùng MaNguoiCapNhat.

Mã trạng thái/nhóm/vai trò dùng chuỗi ASCII theo CHECK trong schema. Ngày JSON dùng dạng YYYY-MM-DD, tiền là số nguyên VND. JSON null ở trường được phép để trống chuyển thành SQL NULL; trường bắt buộc không nhận JSON null. Lời gọi mẫu đầy đủ ở `04_seed.sql`.

## 4. Kiến trúc ràng buộc cần hiểu

`sp_P1_KiemTraToanVen` kiểm tra các điều kiện liên bảng trên tập dữ liệu nhỏ. Trigger trên các bảng gọi lại validator để không bỏ sót thao tác từ phía cha (giảm ngân sách, đổi thời gian, đổi thương hiệu). Đây là lựa chọn cho phạm vi BTL, chưa tối ưu cho dữ liệu lớn.

Một số đối tượng phải tạo cùng nhau: nhân viên+tài khoản; chiến dịch+phân công người chính; hoạt động+lớp con+danh sách nếu là email. MySQL kiểm tra FK tức thời nên dùng ba procedure hạ tầng:

1. sp_P1_TaoNhanVien(p_nv JSON, p_tk JSON).
2. sp_P1_TaoChienDich(p_cd JSON).
3. sp_P1_TaoHoatDong(p_hd JSON, p_rieng JSON, p_danhsach JSON).

Các workflow tự quản lý giao dịch, kiểm tra trước commit, rollback toàn bộ khi lỗi và quản lý khóa tên `marketing_btl.integrity`. Gọi ở ngoài cùng, không lồng trong giao dịch có sẵn. Role marketing_p1 chỉ được đọc và gọi ba workflow, không được ghi bảng trực tiếp. `@p1_internal` chỉ là cờ hạ tầng; bảo vệ thực tế nằm ở quyền hạn và routine đã kiểm tra. Không cấp raw DML cho user web sau này.

Root/DB owner là tài khoản tin cậy, dùng cài đặt và kiểm thử. Khi ghi thủ công, dùng READ COMMITTED và giải phóng khóa sau COMMIT/ROLLBACK như README hướng dẫn. Không tắt FK hay trigger để làm seed chạy qua.

## 5. Trạng thái và cách kiểm chứng

- Nhánh triển khai: `feat/part1-database`; PR đích main. Xem trạng thái PR trên GitHub trước khi chọn nhánh làm tiếp; tài liệu này không mặc định PR đã merge.
- Đã dựng sạch và kiểm thử trực tiếp bằng MySQL 8.4.7 portable trên Windows; Windows của người dùng không cần cài MySQL.
- Có 15 bảng và 118 dòng mẫu. DS06 và MXH06 là tài nguyên chưa dùng nhưng có thương hiệu. HD01/HD02 có thực chi vượt ngân sách. CD03 hoàn thành; CD05 hủy vẫn giữ lịch sử. NV08 bị khóa nhưng dữ liệu cũ còn.
- Kết quả kiểm thử mới nhất và giới hạn ở [part1-test-results.md](part1-test-results.md). CI `Part 1 MySQL` dựng MySQL 8.4.7 và chạy test trên Ubuntu; kiểm tra trạng thái thực tế trong GitHub Actions, không suy đoán đã xanh từ tên workflow.
- Dữ liệu server, runtime tạm và mật khẩu không được chuyển bằng Git. Sang Ubuntu dựng lại từ SQL, không chép thư mục data MySQL Windows sang Linux.

## 6. Hướng phần 2–3 đã đồng ý, chưa hiện thực

| Sản phẩm | Hướng đã chọn |
|---|---|
| CRUD | KhoanChi; ba procedure thêm/sửa/xóa, validate cụ thể, giải thích điều kiện được xóa. |
| Procedure truy vấn 1 | Danh sách khoản chi theo chiến dịch/hoạt động/khoảng ngày, có sắp xếp, nối >=2 bảng. |
| Procedure truy vấn 2 | Tổng chi phí theo hoạt động, WHERE + GROUP BY + HAVING + ORDER BY, nối >=2 bảng. |
| Trigger nghiệp vụ | Dùng ràng buộc tổng ngân sách cấp không vượt ngân sách duyệt; đã có nền tảng kiểm tra ở phần 1. |
| Trigger dẫn xuất | Dự kiến thêm cột TongChiPhiThucTe và trigger cập nhật khi khoản chi thêm/sửa/xóa/chuyển hoạt động. Hiện tại chỉ tính qua view. |
| Function 1 | Đếm hoạt động có thực chi vượt ngân sách trong chiến dịch. |
| Function 2 | Tính chi phí trên một chuyển đổi của hoạt động trong khoảng ngày. |
| Kỹ thuật function | Phải có kiểm tra tham số, truy vấn, IF/vòng lặp và cursor theo đề. Hai function có ý nghĩa khác nhau. |
| Web | Quản lý khoản chi, tìm kiếm/lọc/sắp xếp và báo cáo; gọi procedure/function thật. Công nghệ web **chưa chốt**; người dùng muốn giao diện đẹp. |
| Phân công | Nhóm 4 người; **mỗi thành viên phải viết ít nhất một nội dung SQL phần 2**, không để ai chỉ làm giao diện/report. |

## 7. Việc đầu tiên trong phiên Ubuntu

1. Đọc file này, README, ubuntu-setup.md và constraints.md.
2. Kiểm tra nhánh/PR, phiên bản MySQL server và cách xác thực trên Ubuntu.
3. Dựng từ SQL trên database thử nghiệm trống; xác nhận 15 bảng/118 dòng.
4. Chạy bộ kiểm thử và đọc kết quả thực tế trước khi sửa tiếp.
5. Hoàn tất review/merge phần 1; sau đó bàn phân công phần 2. Không tự làm thêm web trong lúc này.

Prompt để bắt đầu lại với trợ lý:

> Tiếp tục BTL2 marketing trong repo này. Hãy đọc docs/HANDOFF.md, docs/ubuntu-setup.md, README.md và docs/constraints.md trước. Hiện chỉ hoàn thiện phần 1; MySQL đã chốt, thiết kế 15 bảng với chuyên biệt hóa toàn phần. Kiểm tra nhánh/PR và môi trường Ubuntu, dựng CSDL thử nghiệm và chạy test. Giữ các quyết định đã ghi; chưa triển khai phần 2–3 hoặc chọn công nghệ web.
