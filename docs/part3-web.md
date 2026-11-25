# Phần 3 — Web quản lý khoản chi

Ứng dụng kết nối MySQL 8.4 từ máy chủ Node.js qua `mysql2`. Trình duyệt gọi API cùng địa chỉ với trang web. Tài khoản MySQL của web có quyền đọc các bảng cần thiết và gọi đúng các routine bên dưới.

| Yêu cầu | Thao tác trên web | Routine MySQL |
|---|---|---|
| Thêm, sửa, xóa khoản chi | Nút **Thêm khoản chi** và các nút **Sửa**, **Xóa** trên hàng khoản chi. Xóa cần xác nhận. | `sp_P2_ThemKhoanChi`, `sp_P2_SuaKhoanChi`, `sp_P2_XoaKhoanChi` |
| Danh sách và lọc | Từ khóa tìm trong nội dung/chứng từ, chiến dịch, hoạt động, khoảng ngày và thứ tự sắp xếp | `sp_P2_DanhSachKhoanChi` |
| Báo cáo | Tab **Báo cáo** nhận chiến dịch, khoảng ngày, ngưỡng tổng chi và hoạt động muốn tính CPA | `sp_P2_TongChiTheoHoatDong`, `fn_P2_DemHoatDongVuotNganSach`, `fn_P2_ChiPhiTrenChuyenDoi` |

Form kiểm tra dữ liệu bắt buộc, định dạng, ngày và số tiền. API kiểm tra lại trước khi gọi SQL. Các lỗi trùng mã, thiếu phân công và khóa sổ có thông báo riêng. Trang chỉ hiện nút sửa/xóa cho khoản chi thuộc nhân viên demo và chưa khóa sổ. Procedure vẫn kiểm tra mọi lần ghi.

Thẻ tổng chi và biểu đồ ngày đều dùng kết quả của bộ lọc hiện tại. Khi có hơn sáu ngày phát sinh, biểu đồ hiển thị sáu ngày có chi gần nhất, còn tổng tiền vẫn tính trên toàn bộ kết quả lọc.

Giao diện HTML/CSS sử dụng hệ biến màu và mẫu bảng, hộp thoại của [shadcn/ui](https://ui.shadcn.com/docs/theming), cùng họa tiết [Dot Pattern của Magic UI](https://magicui.design/docs/components/dot-pattern) được chuyển sang CSS. Bố cục và trạng thái được rà theo [taste-skill](https://github.com/leonxlnx/taste-skill). Bộ icon [Lucide](https://lucide.dev/) được chọn từ [Design Resources for Developers](https://github.com/bradtraversy/design-resources-for-developers) và được lưu cục bộ cùng font Geist. Giấy phép ở `app/LICENSE-Lucide.txt` và `app/LICENSE-Geist.txt`.

Bề mặt kính mờ và thanh điều hướng thu gọn lấy cảm hứng từ [Sylva](https://codeandchill.store/templates/sylva). Nút cạnh đường dẫn trang thu gọn thanh điều hướng trên máy tính. Nút ở cuối thanh điều hướng đổi giao diện sáng/tối. Trình duyệt lưu hai lựa chọn này cho lần mở sau.

## Chạy web

1. Dùng Node.js 22 trở lên và MySQL 8.4. Nạp phần 1 và phần 2 theo thứ tự trong [README](../README.md). Dùng database riêng có dữ liệu mẫu khi demo.
2. Trong MySQL client quản trị, nạp `SOURCE database/part3/01_app_role.sql;`. Tạo tài khoản database riêng cho web bằng các lệnh sau. Thay giá trị mẫu bằng mật khẩu riêng và dùng host phù hợp với máy Node kết nối tới MySQL.

   ```sql
   CREATE USER 'marketing_web_app'@'127.0.0.1' IDENTIFIED BY 'thay-bang-mat-khau-manh';
   GRANT 'marketing_web' TO 'marketing_web_app'@'127.0.0.1';
   SET DEFAULT ROLE 'marketing_web' TO 'marketing_web_app'@'127.0.0.1';
   ```

3. Sao chép `app/.env.example` thành `app/.env`. Điền `DB_PASSWORD` của tài khoản vừa tạo và đặt `DEMO_PASSWORD` riêng từ 12 ký tự trở lên. `DEMO_ACTOR=NV04` dùng với seed hiện có. Tất cả khách đăng nhập web sử dụng danh tính nghiệp vụ do server cấu hình. Tài khoản `demo` của web là một lớp truy cập dùng chung cho buổi demo; tài khoản nhân viên trong CSDL vẫn được procedure dùng để kiểm tra quyền ghi.
4. Tại thư mục `app`, chạy `npm ci` rồi `npm start`. Mở `http://127.0.0.1:8080` và đăng nhập với tên `demo` cùng `DEMO_PASSWORD`.

Giữ `.env` cục bộ. Tài khoản web MySQL chỉ cần role `marketing_web`; phần ghi dữ liệu đi qua procedure.

## Kịch bản trình bày

1. Mở **Khoản chi** và lọc chiến dịch `CD01` từ `05/11/2026` đến `06/11/2026`. Seed có ba khoản, tổng 6.500.000 VND. Thử sắp theo chi phí cao nhất và tìm `CT-01`.
2. Xóa bộ lọc từ khóa. Thêm `KC_DEMO` cho `HD01`, ngày `06/11/2026`, số tiền `600000`, nội dung `Dựng nội dung demo`. Thử thêm lại cùng mã để thấy lỗi trùng. Từ danh sách, sửa để chuyển khoản sang `HD02` với số tiền `800000`.
3. Vào **Báo cáo**, chọn `CD01`, `HD02`, đúng khoảng ngày ở bước 1 và ngưỡng tổng chi `4000000`. Bảng còn `HD02` với 4.300.000 VND. Có 2 hoạt động vượt ngân sách và CPA của `HD02` là 614.285,7143 VND/chuyển đổi.
4. Xóa `KC_DEMO` và xác nhận. Tổng chi `CD01` trở về 6.500.000 VND. Báo cáo ở ngưỡng 4.000.000 VND trở về trạng thái không có kết quả.

## Chia sẻ demo qua Cloudflare Tunnel

Sau khi web chạy cục bộ, người phụ trách demo có thể chạy `cloudflared tunnel --url http://127.0.0.1:8080` trên cùng máy. Cloudflare cấp một URL HTTPS tạm thời. Giữ Node.js, MySQL và `cloudflared` đang chạy trong buổi demo. Chia sẻ mật khẩu demo riêng với người xem. Phương án này đưa web ra Internet qua tunnel và MySQL vẫn chạy tại máy demo. Xem [hướng dẫn Quick Tunnels của Cloudflare](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/).
