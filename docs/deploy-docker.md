# Chạy Campaign Desk bằng Docker (24/7)

Một máy luôn bật chạy ba container: MySQL 8.4, ứng dụng Node.js và một cửa vào HTTPS. Có hai cách làm cửa vào, chọn một:

- **Caddy + IP tĩnh + tên `sslip.io`** ([mục 2](#2-chưa-có-tên-miền-caddy-và-địa-chỉ-sslipio)): địa chỉ cố định, miễn phí, không cần tên miền. Máy chủ mở cổng 80 và 443.
- **Cloudflare Tunnel** ([mục 3](#3-cloudflare-tunnel)): không mở cổng nào, nhưng địa chỉ cố định cần tên miền.

```
Caddy:      Trình duyệt ──HTTPS──> Caddy ──app:8080──> app ──> db (MySQL)
Cloudflare: Trình duyệt ──HTTPS──> Cloudflare ──tunnel──> cloudflared ──127.0.0.1:8080──> app ──> db
```

Cấu hình nằm trong [deploy/](../deploy/), Dockerfile của app trong [app/Dockerfile](../app/Dockerfile).

## 1. Chuẩn bị máy chủ

Một máy Linux nhỏ (1 vCPU, 2 GB RAM là đủ cho demo) có Docker Engine và plugin Compose. Ví dụ AWS Lightsail hoặc EC2 loại nhỏ, hoặc một VPS khác. Dùng Caddy thì cần mở cổng 80 và 443 (mục 2).

```sh
git clone https://github.com/AIVIETNAM-AIO-LeWann/BTL2_marketing-campaign-db.git
cd BTL2_marketing-campaign-db/deploy
cp .env.example .env
```

Điền `.env` (mật khẩu ngẫu nhiên, ví dụ `openssl rand -hex 16`):

| Biến | Ý nghĩa |
| --- | --- |
| `MYSQL_ROOT_PASSWORD` | mật khẩu root MySQL, chỉ dùng khi khởi tạo và quản trị |
| `DB_PASSWORD` | mật khẩu tài khoản `marketing_web_app` mà app dùng (role quyền tối thiểu) |
| `DEMO_PASSWORD` | mật khẩu đăng nhập web với tên `demo`, ít nhất 12 ký tự |
| `DEMO_ACTOR` | mã nhân viên ghi nhận khoản chi, mặc định `NV04` |
| `SITE_ADDRESS` | tên máy chủ công khai cho Caddy, ví dụ `3-1-2-4.sslip.io` (mục 2) |
| `TUNNEL_TOKEN` | chỉ cần khi dùng Cloudflare Tunnel có tên miền (mục 3) |

## 2. Chưa có tên miền: Caddy và địa chỉ sslip.io

[sslip.io](https://sslip.io) là dịch vụ DNS công cộng trả về chính IP có trong tên: `3-1-2-4.sslip.io` trỏ tới `3.1.2.4`. Gắn tên này với IP tĩnh của máy chủ thì Caddy xin được chứng chỉ Let's Encrypt, nên có HTTPS với địa chỉ cố định mà không phải mua tên miền. Đổi lại, bạn phụ thuộc vào dịch vụ sslip.io (miễn phí, của bên thứ ba) và máy chủ phải mở cổng 80 và 443.

**Với AWS Lightsail:**

1. Tạo instance Linux (Ubuntu), gói 1–2 GB RAM. Trong tab **Networking** của instance: tạo và gắn **IP tĩnh** (nếu không, IP đổi khi khởi động lại và địa chỉ sslip.io hỏng). Firewall cho phép **22** (SSH, nên giới hạn theo IP của bạn), **80** và **443**.
2. SSH vào máy, cài Docker Engine và plugin Compose, rồi clone repo như mục 1.
3. Điền `deploy/.env`, thêm `SITE_ADDRESS` là IP tĩnh viết bằng dấu gạch ngang, ví dụ IP `3.1.2.4`:

   ```
   SITE_ADDRESS=3-1-2-4.sslip.io
   ```

4. Chạy:

   ```sh
   docker compose -f docker-compose.yml -f docker-compose.caddy.yml up -d --build
   ```

   Lần đầu, MySQL tự nạp phần 1, phần 2 và role `marketing_web` từ [database/](../database/) rồi tạo tài khoản cho app ([deploy/initdb/00-load.sh](../deploy/initdb/00-load.sh)). Caddy cần vài chục giây để xin chứng chỉ.
5. Mở `https://3-1-2-4.sslip.io`, đăng nhập bằng `demo` và `DEMO_PASSWORD`. Trang Khoản chi trên dữ liệu mẫu có **11 khoản chi**.

Trong chế độ này app nghe `0.0.0.0` trong mạng Docker và nhận IP người dùng từ header `X-Real-IP` do Caddy đặt (`BIND_HOST`, `CLIENT_IP_HEADER` trong [docker-compose.caddy.yml](../deploy/docker-compose.caddy.yml)). Cổng của app **không được publish ra ngoài**, vì vậy chỉ Caddy gửi được yêu cầu tới app. Đừng thêm `ports` cho `app`, nếu không người ngoài giả được header IP và qua mặt bộ giới hạn đăng nhập.

## 3. Cloudflare Tunnel

Không mở cổng nào trên máy chủ. Chạy trực tiếp `docker compose …` không kèm `docker-compose.caddy.yml`.

**Địa chỉ tạm** (không cần tên miền, nhưng đổi mỗi lần container `tunnel-quick` khởi động lại):

```sh
docker compose --profile quick up -d --build
docker compose logs tunnel-quick | grep trycloudflare
```

**Địa chỉ cố định** (cần tên miền thêm vào tài khoản Cloudflare):

1. Trong Cloudflare Dashboard mở **Networking → Tunnels**, tạo tunnel, chọn **Published application**, đặt hostname và **Service URL** là `http://127.0.0.1:8080`.
2. Sao chép token của tunnel vào `TUNNEL_TOKEN` trong `.env`.
3. Chạy `docker compose --profile named up -d --build`.

## Vận hành

- Xem trạng thái: `docker compose ps`. Log: `docker compose logs -f app`.
- Các container có `restart: unless-stopped`, nên tự chạy lại sau khi máy khởi động lại (Docker cần tự bật cùng hệ điều hành).
- Cập nhật code: `git pull`, rồi `docker compose -f docker-compose.yml -f docker-compose.caddy.yml up -d --build` (hoặc lệnh của chế độ Cloudflare). Dữ liệu MySQL nằm trong volume `dbdata` và được giữ nguyên.
- Sao lưu dữ liệu:

  ```sh
  docker compose exec db sh -c 'mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --routines --triggers --single-transaction marketing_btl' > backup.sql
  ```

- Làm lại từ đầu, **xóa toàn bộ dữ liệu**: `docker compose down -v` (thêm `-f docker-compose.caddy.yml` nếu dùng Caddy). Script nạp chỉ chạy khi volume còn trống.

## Lưu ý an toàn

- Không commit `deploy/.env`. File này đã nằm trong `.gitignore`.
- Ai có địa chỉ và `DEMO_PASSWORD` đều thêm, sửa, xóa được dữ liệu. Không chia sẻ rộng.
- Phiên đăng nhập và bộ giới hạn đăng nhập nằm trong bộ nhớ của app, nên chỉ chạy **một** container `app`, khởi động lại thì mọi người phải đăng nhập lại.
- Bộ giới hạn đăng nhập dựa vào header IP do proxy đặt (`cf-connecting-ip` với Cloudflare, `x-real-ip` với Caddy). Vì app không publish cổng ra ngoài, chỉ proxy gửi được yêu cầu vào nên header này đáng tin. Đừng publish cổng 8080.
