# Demo Campaign Desk qua Cloudflare

Trình duyệt mở URL HTTPS của Cloudflare. `cloudflared` chuyển yêu cầu đến Node.js tại `127.0.0.1:8080`. Node.js gọi MySQL trên máy demo. Phương án này dùng Cloudflare Quick Tunnel và có thể chạy với dữ liệu mẫu mà không cần tên miền. [Tài liệu Quick Tunnels](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/)

## 1. Chuẩn bị trên máy demo

- Cài Git, Node.js 22 trở lên, MySQL Server **8.4** và `mysql` client. Khởi động MySQL và chuẩn bị tài khoản quản trị có quyền tạo database, routine, trigger, user và role.
- Cài `cloudflared` rồi chạy `cloudflared --version`. Trên Windows, nếu tải file `.exe` rời, dùng đường dẫn tới file đó thay cho lệnh `cloudflared`. [Tải cloudflared](https://developers.cloudflare.com/tunnel/downloads/)
- Dùng một MySQL dành cho dữ liệu mẫu. Trên instance này cần còn trống tên database `marketing_btl`. Nếu đã cài đủ các phần 1, 2 và cấu hình web, có thể dùng lại bản cài mẫu đó và chuyển đến bước 2. Cách cấu hình thủ công nằm trong [hướng dẫn phần 3](part3-web.md#chạy-web).

```sh
git clone https://github.com/AIVIETNAM-AIO-LeWann/BTL2_marketing-campaign-db.git
cd BTL2_marketing-campaign-db
```

Nếu đang dùng bản trong [PR #8](https://github.com/AIVIETNAM-AIO-LeWann/BTL2_marketing-campaign-db/pull/8), chạy `git switch --track origin/feat/part3-web` sau khi clone. Khi bản web đã có trong `main`, chạy tiếp từ bản clone mặc định.

```sh
node scripts/setup-demo.mjs
```

Nhập mật khẩu quản trị MySQL khi `mysql` hỏi. Lệnh nạp các file SQL phần 1 và 2, tạo role `marketing_web`, cấp role cho tài khoản MySQL riêng, rồi sinh `app/.env` với hai mật khẩu độc lập. Giá trị `DEMO_PASSWORD` trong đó dùng để đăng nhập web với tên `demo`. `DB_PASSWORD` chỉ dùng cho kết nối từ Node.js đến MySQL. Giữ `app/.env` trên máy demo và gửi riêng `DEMO_PASSWORD` cho người cần truy cập.

Mặc định MySQL dùng TCP `127.0.0.1:3306`, tài khoản quản trị `root` và web dùng cổng `8080`. Nếu máy dùng thông số khác, chạy `node scripts/setup-demo.mjs --help` để xem `--mysql`, `--user`, `--db-port` và `--web-port`. Khi database `marketing_btl` hoặc `app/.env` đã tồn tại, lệnh sẽ dừng. Nếu nạp SQL dừng giữa chừng, đọc lỗi và kiểm tra database đã tạo trước khi thử lại trên một instance demo trống.

## 2. Khởi động web và kiểm tra local

Trong terminal thứ nhất, từ thư mục gốc repo, chạy

```sh
cd app
npm ci
npm start
```

Mở `http://127.0.0.1:8080` và đăng nhập bằng `demo` cùng `DEMO_PASSWORD` trong `app/.env`. Trang **Khoản chi** trên dữ liệu mẫu mới hiển thị **11 khoản chi**. Mở thêm tab **Báo cáo** để xác nhận cả thủ tục truy vấn và hàm MySQL đều chạy.

## 3. Mở URL HTTPS

Giữ terminal chạy web. Mở terminal thứ hai trên cùng máy và chạy

```sh
cloudflared tunnel --url http://127.0.0.1:8080
```

Nếu đã đổi `PORT`, thay `8080` bằng đúng cổng của ứng dụng. Sao chép URL HTTPS `*.trycloudflare.com` hiện trong terminal. Mở URL đó bằng cửa sổ ẩn danh hoặc thiết bị khác rồi thử đăng nhập và mở **Khoản chi**, **Báo cáo**, **Đăng xuất**. Giữ MySQL, web và `cloudflared` chạy trong buổi demo. Dừng `cloudflared` bằng `Ctrl+C` khi kết thúc. Khi mở tunnel mới, lấy URL mới từ terminal. [Tài liệu Quick Tunnels](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/)

Để diễn tập đủ thêm, sửa, xóa và tính CPA từ URL HTTPS, làm theo [kịch bản trình bày](part3-web.md#kịch-bản-trình-bày). Kịch bản dùng mã `KC_DEMO` và xóa khoản chi này ở bước cuối để lần chạy sau vẫn bắt đầu từ dữ liệu mẫu.

## Xử lý lỗi thường gặp

| Triệu chứng | Kiểm tra |
|---|---|
| Terminal không tìm thấy `mysql` hoặc `cloudflared` | Thêm thư mục chứa chương trình vào `PATH` hoặc dùng đường dẫn đến file thực thi. |
| MySQL báo `Access denied` khi dựng database | Kiểm tra quyền đăng nhập TCP tại `127.0.0.1`, tài khoản và cổng truyền vào script. |
| `npm start` báo lỗi kết nối MySQL | Kiểm tra MySQL đã chạy và đối chiếu `DB_PORT`, `DB_USER`, `DB_PASSWORD` trong `app/.env`. Nếu cấp quyền thủ công, kiểm tra đã đặt default role `marketing_web`. |
| URL Cloudflare báo `502 Bad Gateway` | Mở lại địa chỉ local trên máy demo. Đối chiếu cổng Node.js với `--url` của `cloudflared`. |
| URL hoặc mật khẩu cũ hết hiệu lực | Lấy URL từ tiến trình tunnel đang chạy và `DEMO_PASSWORD` từ `app/.env` hiện tại. Web khởi động lại sẽ yêu cầu đăng nhập lại. |
