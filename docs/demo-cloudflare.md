# Demo Campaign Desk qua Cloudflare

Trình duyệt mở URL HTTPS của Cloudflare. `cloudflared` chuyển yêu cầu đến Node.js, rồi Node.js gọi MySQL. Node.js, MySQL và `cloudflared` chạy trên máy demo hoặc máy chủ của nhóm. Dùng [Quick Tunnel](#3-mở-url-https) cho buổi demo hoặc [tunnel có tên](#dùng-tên-miền-cố-định) nếu cần một URL cố định.

## 1. Chuẩn bị trên máy demo

- Cài Git, Node.js **22.9** trở lên, MySQL Server **8.4** và `mysql` client. Khởi động MySQL và chuẩn bị tài khoản quản trị có quyền tạo database, routine, trigger, user và role.
- Cài `cloudflared` rồi chạy `cloudflared --version`. Nếu tải file thực thi rời, đặt đường dẫn đầy đủ vào `CLOUDFLARED_BIN` trong `app/.env`. [Tải cloudflared](https://developers.cloudflare.com/tunnel/downloads/)
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

Giữ terminal chạy web. Trong terminal thứ hai, từ thư mục gốc repo, chạy

```sh
cd app
npm run tunnel
```

Lệnh đọc `PORT` từ `app/.env` và kiểm tra trang đăng nhập trên cổng đó trước khi chạy `cloudflared`. Dùng cùng cấu hình `PORT` cho cả hai terminal nếu bạn đặt biến môi trường ngoài file. Sao chép URL HTTPS `*.trycloudflare.com` hiện trong terminal. Mở URL đó bằng cửa sổ ẩn danh hoặc thiết bị khác rồi thử đăng nhập và mở **Khoản chi**, **Báo cáo**, **Đăng xuất**. Giữ MySQL, web và `cloudflared` chạy trong buổi demo. Dừng tunnel bằng `Ctrl+C` khi kết thúc. Mỗi lần mở Quick Tunnel sẽ sinh URL mới. [Tài liệu Quick Tunnels](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/)

Để diễn tập đủ thêm, sửa, xóa và tính CPA từ URL HTTPS, làm theo [kịch bản trình bày](part3-web.md#kịch-bản-trình-bày). Kịch bản dùng mã `KC_DEMO` và xóa khoản chi này ở bước cuối để lần chạy sau vẫn bắt đầu từ dữ liệu mẫu.

## Dùng tên miền cố định

Chuẩn bị một domain đã thêm vào tài khoản Cloudflare của nhóm và chạy web tại máy sẽ chạy `cloudflared`. Trong Cloudflare Dashboard, mở **Networking → Tunnels**, tạo tunnel rồi mở **Routes → Add route → Published application**. Chọn hostname của nhóm và đặt **Service URL** là `http://127.0.0.1:8080` hoặc cổng `PORT` thực tế. [Hướng dẫn tạo tunnel và route](https://developers.cloudflare.com/tunnel/get-started/)

Lấy token kết nối tunnel từ Dashboard và lưu vào file riêng ngoài repo. Chạy lệnh sau với đường dẫn tới file đó. Cloudflare yêu cầu `cloudflared` 2025.4.0 trở lên cho tùy chọn này. [Tùy chọn `--token-file`](https://developers.cloudflare.com/tunnel/reference/run-parameters/#token-file)

```sh
cloudflared tunnel run --token-file "/path/to/tunnel-token.txt"
```

Khi trạng thái tunnel là **Healthy**, mở `https://<hostname>` rồi chạy lại kịch bản. Khi đổi `PORT`, cập nhật cả `app/.env` và Service URL của route. Để URL truy cập được giữa các buổi demo, giữ Node.js, MySQL và `cloudflared` chạy trên máy chủ của nhóm.

## Chỗ cần sửa khi bàn giao

| Muốn đổi | Sửa ở đâu | Áp dụng |
|---|---|---|
| Cổng web, kết nối MySQL, mật khẩu demo | `app/.env`, xem mẫu trong `app/.env.example` | Khởi động lại web. Khi đổi cổng, chạy lại Quick Tunnel hoặc cập nhật Service URL của tunnel có tên. |
| Tên hiển thị, mô tả và nền ở màn đăng nhập | `app/public/login.html`, `app/public/login.css` | Tải lại trang đăng nhập. |
| Bố cục, màu, biểu đồ và nhịp sáng trong ứng dụng | `app/public/index.html`, `app/public/styles.css`, `app/public/app.js`, `app/public/palette.js`, `app/public/ambient.js`, `app/public/motion.js`, `app/public/fx.js` | Tải lại trang. Giữ đồng bộ các `id` mà JavaScript dùng. |
| API, truy vấn và xử lý lỗi | `app/server.mjs` | Dùng `npm run dev` trong `app` để Node tự khởi động lại khi sửa server. Dùng `npm start` khi demo. |

Để cập nhật bản đang chạy từ GitHub, dùng `git pull --ff-only` trên đúng nhánh. Nếu máy có chỉnh sửa cần giữ, lưu các chỉnh sửa đó trên nhánh riêng trước khi kéo. Chạy `npm ci` trong `app` nếu file khóa dependencies thay đổi. Khởi động lại web khi cập nhật mã server hoặc cấu hình. Lần cập nhật giao diện có thể kiểm tra ngay bằng cách tải lại trang.

## Xử lý lỗi thường gặp

| Triệu chứng | Kiểm tra |
|---|---|
| Terminal không tìm thấy `mysql` hoặc `cloudflared` | Thêm thư mục chứa chương trình vào `PATH` hoặc dùng đường dẫn đến file thực thi. |
| MySQL báo `Access denied` khi dựng database | Kiểm tra quyền đăng nhập TCP tại `127.0.0.1`, tài khoản và cổng truyền vào script. |
| `npm start` báo lỗi kết nối MySQL | Kiểm tra MySQL đã chạy và đối chiếu `DB_PORT`, `DB_USER`, `DB_PASSWORD` trong `app/.env`. Nếu cấp quyền thủ công, kiểm tra đã đặt default role `marketing_web`. |
| `npm run tunnel` báo chưa thấy Campaign Desk | Kiểm tra `npm start` chạy trong terminal khác và mở thử trang đăng nhập tại cổng đã báo. |
| URL Cloudflare báo `502 Bad Gateway` | Mở thử địa chỉ local. Với Quick Tunnel, kiểm tra hai terminal dùng cùng `PORT`. Với tunnel có tên, kiểm tra Service URL trên Dashboard. |
| URL hoặc mật khẩu cũ hết hiệu lực | Lấy URL từ tiến trình tunnel đang chạy và `DEMO_PASSWORD` từ `app/.env` hiện tại. Web khởi động lại sẽ yêu cầu đăng nhập lại. |
