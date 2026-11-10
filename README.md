# BTL2 — Cơ sở dữ liệu quản lý chiến dịch marketing đa kênh

Phần 1: hiện thực 15 bảng MySQL, ràng buộc dữ liệu/ngữ nghĩa và dữ liệu mẫu. Procedure CRUD `KhoanChi`, hai procedure truy vấn, hai function nghiệp vụ, trigger lưu tổng chi phí và ứng dụng web thuộc phần 2–3, chưa triển khai trong nhánh này.

**Cho Codex tiếp tục ở phiên/máy khác:** [AGENTS.md](AGENTS.md) chỉ dẫn đọc [bản bàn giao ngữ cảnh](docs/HANDOFF.md), gồm mục tiêu, quyết định đã chốt, trạng thái và việc còn lại. [Hướng dẫn Ubuntu](docs/ubuntu-setup.md) phục vụ môi trường cá nhân của người dùng chính; cả nhóm không bắt buộc dùng Ubuntu hoặc Docker.

## Yêu cầu môi trường

- MySQL **8.4**, InnoDB, bộ ký tự `utf8mb4`; không thay bằng MariaDB hoặc MySQL 5.7.
- MySQL client hoặc Workbench. Khi dùng Workbench, chạy toàn bộ file và dừng nếu có lỗi.
- Tài khoản thiết lập có quyền tạo database, bảng, view, routine, trigger và role. Kiểm thử quyền cần thêm quyền tạo/xóa user tạm.
- Python 3 nếu chạy bộ kiểm thử tự động; không cần cài thêm thư viện Python.

## Cấu trúc

```text
database/
  01_schema.sql              # 15 bảng, PK/FK/UNIQUE/NOT NULL/CHECK
  02_constraints.sql         # kiểm tra liên bảng, trigger bảo vệ dữ liệu
  03_creation_workflows.sql  # tạo đủ các bản ghi phụ thuộc trong một giao dịch
  04_seed.sql                # dữ liệu mẫu hợp lệ, không tắt FK/trigger
  05_reports.sql             # view tính thời lượng, chi phí và tỷ lệ
  06_verify.sql              # đếm dòng và truy vấn minh chứng
  tests/test_constraints.py  # kiểm thử tích hợp, có ca cố ý vi phạm
scripts/
  bootstrap.sh              # dựng CSDL bằng một phiên client trên Ubuntu/CI
  mysql-docker.sh           # dùng client trong container nếu không có client native
docs/
  HANDOFF.md                # toàn bộ ngữ cảnh/điểm đã chốt để tiếp tục
  ubuntu-setup.md           # hướng dẫn chuyển sang Ubuntu
  constraints.md            # đối chiếu từng yêu cầu BTL1 với cách hiện thực
  design-decisions.md       # giải thích các thay đổi và giới hạn
```

## Chạy từ database trống

Không chạy trên database đang có dữ liệu quan trọng. Script không tự xóa database và cố ý không dùng `CREATE TABLE IF NOT EXISTS` để tránh che giấu một lược đồ cũ.

Mở client (thay user/host/port theo máy):

```console
mysql --default-character-set=utf8mb4 -h 127.0.0.1 -P 3306 -u root -p
```

Trong client, tại thư mục gốc repo, chạy lần lượt:

```sql
SOURCE database/01_schema.sql;
SOURCE database/02_constraints.sql;
SOURCE database/03_creation_workflows.sql;
SOURCE database/04_seed.sql;
SOURCE database/05_reports.sql;
SOURCE database/06_verify.sql;
```

Mỗi bước phải thành công trước khi chạy bước kế tiếp. `SOURCE` là lệnh của mysql client; trong Workbench mở và chạy từng file theo cùng thứ tự. Trên Ubuntu có thể dùng `bash scripts/bootstrap.sh -u root -p` để chạy toàn bộ trong một phiên. Không dùng tùy chọn `--force` khi cài đặt vì nó có thể bỏ qua lỗi và tiếp tục nạp dữ liệu thiếu.

## Dữ liệu mẫu

| Bảng | Số dòng ban đầu |
|---|---:|
| NhanVien | 8 |
| TaiKhoan | 8 |
| SoDienThoaiNhanVien | 9 |
| ThuongHieu | 5 |
| KenhMarketing | 5 |
| ChienDich | 5 |
| PhanCong | 10 |
| HoatDongTrienKhai | 10 |
| HoatDongEmail | 5 |
| DanhSachNhanEmail | 6 |
| HoatDongEmail_DanhSach | 5 |
| TaiKhoanMangXaHoi | 6 |
| HoatDongMangXaHoi | 5 |
| KhoanChi | 11 |
| KetQuaNgay | 20 |

Tên người, thương hiệu, địa chỉ `.example` và tài khoản nền tảng là dữ liệu minh họa. Các chuỗi `MatKhauBam` là giá trị mẫu **không dùng để đăng nhập**; chưa có chức năng xác thực. Tiền tệ thống nhất VND, dùng `DECIMAL(18,0)`.

Dữ liệu có hoạt động vượt ngân sách thực chi (được phép), chiến dịch hoàn thành/hủy giữ lịch sử, tài khoản nhân viên đã khóa, số chuyển đổi bằng 0, số chuyển đổi chưa biết (`NULL`), danh sách và tài khoản MXH chưa được sử dụng nhưng đã xác định thương hiệu sở hữu.

## Tạo dữ liệu có quan hệ bắt buộc

MySQL/InnoDB không có deferred constraint để chờ đến `COMMIT` mới kiểm tra FK. Nhân viên–tài khoản, chiến dịch–phân công người chính, hoạt động–lớp con–danh sách phải tạo theo các workflow tại file 03:

- `sp_P1_TaoNhanVien(JSON nhan_vien, JSON tai_khoan)`.
- `sp_P1_TaoChienDich(JSON chien_dich)`: tự thêm phân công người chính bao phủ toàn chiến dịch.
- `sp_P1_TaoHoatDong(JSON hoat_dong, JSON chi_tiet, JSON mang_ma_danh_sach)`: nhóm kênh quyết định lớp con; email cần ít nhất một danh sách.

Xem lời gọi hoàn chỉnh trong file 04. Mỗi workflow giữ khóa ghi, tạo các dòng trong một giao dịch, kiểm tra toàn bộ bất biến trước khi commit và rollback nếu có lỗi. Gọi workflow ở cấp ngoài cùng, không bọc trong giao dịch khác.

Đầu vào JSON kiểm tra trường bắt buộc và kiểu dữ liệu trước khi chuyển sang cột SQL. JSON null ở trường bắt buộc bị từ chối; trường tùy chọn giữ SQL NULL. Ngày phải hợp lệ, ngân sách JSON là số nguyên VND. Workflow bị gọi lồng sẽ không commit/rollback giao dịch ngoài, không đổi cờ hoặc giải phóng khóa của bên gọi.

Biến phiên `@p1_internal` chỉ giúp trì hoãn kiểm tra toàn phần bên trong workflow; **không phải cơ chế phân quyền**. Role `marketing_p1` chỉ có SELECT và EXECUTE ba workflow hoàn chỉnh, không có quyền ghi bảng hay gọi helper nội bộ. Không cấp quyền ghi thẳng cho user ứng dụng. Các procedure phần 2 cần dùng cùng nguyên tắc giao dịch/khóa và kiểm tra trước commit.

Tài khoản quản trị có quyền thay đổi schema, trigger hoặc biến phiên luôn là tài khoản tin cậy. Không dùng root làm tài khoản ứng dụng.

## Sửa dữ liệu thủ công để khảo sát

Dùng phiên quản trị riêng, đặt isolation `READ COMMITTED` **trước giao dịch**, không đặt `@p1_internal=1`. Trigger kiểm tra dữ liệu sau mỗi dòng thay đổi; một số thao tác nhiều bước phải dùng workflow để không đi qua trạng thái thiếu bản ghi bắt buộc.

```sql
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;
UPDATE KhoanChi SET SoTien=2600000 WHERE MaKhoanChi='KC01';
CALL sp_P1_KiemTraToanVen();
ROLLBACK; -- minh họa, không giữ thay đổi
DO RELEASE_LOCK('marketing_btl.integrity');
```

Khóa tên `marketing_btl.integrity` được giữ đến hết workflow; phiên quản trị ghi trực tiếp giữ khóa đến khi tự giải phóng hoặc ngắt kết nối. Nếu câu lệnh báo lỗi, rollback rồi giải phóng khóa. Không chạy nhiều phiên ghi quản trị tùy tiện hoặc tắt FK/trigger.

## Kiểm thử

Chạy trên database thử nghiệm đã nạp seed. Tài khoản kiểm thử là quản trị vì có ca kiểm tra quyền bằng cách tạo/xóa một user tạm có tên ngẫu nhiên. Không ghi mật khẩu vào mã nguồn; dùng cấu hình client hoặc biến môi trường `MYSQL_PWD` trong phiên cục bộ.

```console
python database/tests/test_constraints.py --mysql mysql --host 127.0.0.1 --port 3306 --user root
```

Các thao tác thay đổi thử nghiệm được rollback; user tạm được xóa ở cuối ca kiểm thử. Sau đó có thể chạy lại `06_verify.sql`. Không công bố phần 1 hoàn tất chỉ vì tạo đủ bảng: cần đọc ma trận ràng buộc, chạy các ca hợp lệ/vi phạm và kiểm tra kết quả thực tế.

GitHub Actions `Part 1 MySQL` chạy cùng bootstrap/test trên Ubuntu 24.04, MySQL 8.4.7. Xem kết quả cụ thể của commit/PR. Xác thực bằng Unix socket trên Ubuntu được hỗ trợ qua `--socket`; hướng dẫn chi tiết ở ubuntu-setup.md.

## Phạm vi phần tiếp theo

Đã thống nhất hướng `KhoanChi` làm CRUD chính; hai truy vấn là danh sách khoản chi và tổng hợp chi phí; hai function là đếm hoạt động vượt ngân sách và tính chi phí/chuyển đổi theo khoảng ngày. Thuộc tính lưu `TongChiPhiThucTe` và trigger duy trì nó chưa thêm ở phần 1: hiện giá trị được tính qua view, tránh có cột lưu nhưng chưa đồng bộ.
