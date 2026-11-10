# Tiếp tục dự án trên Ubuntu

Đọc [HANDOFF.md](HANDOFF.md) trước để giữ ngữ cảnh nghiệp vụ và phạm vi đã chốt. Windows không cần cài MySQL để chuyển dự án: Git giữ mã SQL, dữ liệu mẫu, kiểm thử và tài liệu; Ubuntu dựng lại server từ các file đó.

## 1. Lấy đúng mã nguồn

```bash
git clone https://github.com/AIVIETNAM-AIO-LeWann/BTL2_marketing-campaign-db.git
cd BTL2_marketing-campaign-db
git fetch origin
git status
```

Nếu PR phần 1 chưa merge, chuyển sang nhánh triển khai:

```bash
git switch feat/part1-database
git pull --ff-only
```

Nếu PR đã merge, dùng main và `git pull --ff-only`. README trên nhánh đang dùng phải có thư mục database/docs/scripts; main chỉ có README ban đầu nghĩa là chưa lấy phần 1.

## 2. Chọn một cách chạy MySQL

### A. Dùng MySQL đã cài trên Ubuntu

Kiểm tra cả client lẫn **server**; hai phiên bản có thể khác nhau:

```bash
mysql --version
python3 --version
mysql -u root -p -e 'SELECT VERSION(), @@version_comment, @@socket;'
```

Nếu root xác thực qua Unix socket thay vì mật khẩu:

```bash
sudo mysql -e 'SELECT VERSION(), @@version_comment, @@socket;'
```

Mục tiêu kiểm thử là **MySQL 8.4**, baseline 8.4.7. Nếu server đang là MariaDB hoặc dòng MySQL khác, không mặc định đã tương đương. Có thể chọn cách B để có server riêng cùng baseline, không cần thay server hiện tại. Nếu muốn cài MySQL 8.4 trực tiếp, dùng [hướng dẫn APT chính thức](https://dev.mysql.com/doc/mysql-apt-repo-quick-guide/en/), chọn dòng 8.4 và đọc hướng dẫn tương ứng nếu máy đã có server. Không chạy lệnh nâng cấp/thay thế hệ quản trị chỉ để thử bài.

Kiểm tra database đã tồn tại chưa:

```bash
mysql -u root -p -e "SHOW DATABASES LIKE 'marketing_btl';"
```

Với socket, thay `mysql -u root -p` bằng `sudo mysql`. Nếu database đã có dữ liệu cần giữ, không chạy bootstrap chồng và không xóa để làm theo hướng dẫn; dùng môi trường thử riêng hoặc sao lưu trước.

### B. Dùng MySQL 8.4.7 riêng qua Docker

Chỉ cần phần này nếu đã chọn Docker. Kiểm tra `docker --version` và `docker info`; nếu chưa cài, xem [hướng dẫn Docker Engine cho Ubuntu](https://docs.docker.com/engine/install/ubuntu/). Không cần Docker Desktop, Compose, Node hoặc framework web cho phần 1.

Tạo mật khẩu riêng cho môi trường cục bộ; không ghi vào Git:

```bash
read -rsp 'MySQL root password cho môi trường thử: ' MYSQL_ROOT_PASSWORD
echo
export MYSQL_ROOT_PASSWORD

docker run --name marketing-btl2-mysql \
  --env MYSQL_ROOT_PASSWORD \
  --publish 127.0.0.1:33077:3306 \
  --volume marketing-btl2-data:/var/lib/mysql \
  --detach mysql:8.4.7

export MYSQL_PWD="$MYSQL_ROOT_PASSWORD"
docker logs --tail 30 marketing-btl2-mysql
```

Đợi server sẵn sàng rồi chạy lệnh kiểm tra sau. Nếu chưa sẵn sàng, xem log và thử lại; chưa chạy bootstrap:

```bash
docker exec -e MYSQL_PWD marketing-btl2-mysql \
  mysql --protocol=TCP -h 127.0.0.1 -u root -e 'SELECT VERSION();'
```

Container phải có tên riêng như trên; nếu tên đã tồn tại từ lần trước, kiểm tra `docker ps -a` và dùng `docker start marketing-btl2-mysql`. Volume giữ dữ liệu qua các lần stop/start. Thay biến mật khẩu khi start lại **không đổi mật khẩu đã lưu** trong database.

## 3. Dựng toàn bộ phần 1

Chạy tại thư mục gốc repo. Bootstrap đọc đủ sáu file SQL trong một phiên mysql, theo thứ tự và dừng khi có lỗi; không DROP database hay tắt FK/trigger.

**Native, tài khoản dùng mật khẩu:**

```bash
bash scripts/bootstrap.sh --protocol=TCP -h 127.0.0.1 -P 3306 -u root -p
```

**Native, root dùng Unix socket:**

```bash
sudo bash scripts/bootstrap.sh --protocol=SOCKET -u root
```

**Docker, dùng client ngay trong container:**

```bash
chmod +x scripts/mysql-docker.sh
export MYSQL_CLIENT="$PWD/scripts/mysql-docker.sh"
bash scripts/bootstrap.sh --protocol=TCP -h 127.0.0.1 -P 3306 -u root
```

Ở cách Docker, MYSQL_PWD phải là mật khẩu đã đặt ở bước 2B. Client chạy **bên trong container**, vì vậy dùng cổng 3306; cổng công bố ra máy Ubuntu là 33077. Khi quay lại dùng MySQL native, chạy `unset MYSQL_CLIENT`.

Kết quả mong đợi: 15 bảng, 118 dòng; từng bảng ít nhất 5 dòng. File 06 in bảng đếm, chi phí, trường hợp CPA NULL và tài nguyên chưa dùng. Chi tiết số dòng từng bảng trong README. Chỉ chạy bootstrap một lần trên database trống; không chạy lại seed vào dữ liệu đang có.

## 4. Chạy bộ kiểm thử

Kiểm thử cần tài khoản quản trị trên **database thử nghiệm**: có ca tạo/xóa user tạm để kiểm tra role. Không dùng user web giới hạn quyền cho lệnh này.

**Native, đăng nhập TCP bằng mật khẩu:**

```bash
read -rsp 'MySQL password cho kiểm thử: ' MYSQL_PWD
echo
export MYSQL_PWD
python3 database/tests/test_constraints.py \
  --mysql mysql --host 127.0.0.1 --port 3306 --user root
unset MYSQL_PWD
```

**Native, root xác thực Unix socket:**

```bash
sudo python3 database/tests/test_constraints.py \
  --mysql mysql --socket /var/run/mysqld/mysqld.sock --user root
```

Nếu @@socket ở bước 2A khác đường dẫn trên, dùng giá trị thực tế. `--socket` bỏ qua host/port. Không cần đổi cách xác thực root của hệ thống chỉ để chạy test.

**Docker:**

```bash
python3 database/tests/test_constraints.py \
  --mysql "$PWD/scripts/mysql-docker.sh" --host 127.0.0.1 --port 3306 --user root
```

Kết quả mong đợi: toàn bộ tests kết thúc `OK`; số test mới nhất ở part1-test-results.md. Kiểm thử rollback các thay đổi, dọn fixture riêng và xóa user tạm. Khi báo cáo lỗi, giữ tên ca, lỗi SQL, VERSION() và commit hiện tại; không gửi mật khẩu.

## 5. Dừng và làm tiếp lần sau

Với Docker:

```bash
docker stop marketing-btl2-mysql
unset MYSQL_PWD MYSQL_ROOT_PASSWORD MYSQL_CLIENT
```

Lần sau dùng `docker start`, nhập lại mật khẩu cho client và chạy kiểm tra; **không bootstrap lại** nếu dữ liệu vẫn còn. Không chép thư mục data MySQL từ Windows sang Ubuntu. Nếu cần chuyển dữ liệu phát sinh sau seed, xuất logical dump bằng mysqldump trên đúng server nguồn và phục hồi có kiểm soát.

## 6. Lỗi thường gặp khi chuyển máy

| Hiện tượng | Kiểm tra/xử lý |
|---|---|
| Repo chỉ có README ngắn | Chưa checkout nhánh phần 1 hoặc PR chưa merge. |
| Access denied cho root | Xem server dùng mật khẩu hay Unix socket; không đoán mật khẩu hoặc tự đổi plugin. |
| Table already exists / duplicate entry | Database đã được dựng/nạp trước đó; dừng, kiểm tra dữ liệu, không dùng --force. |
| CHECK/JSON_SCHEMA_VALID không có hoặc bị bỏ qua | Kiểm tra VERSION() trên server, không chỉ mysql --version. |
| Ubuntu báo không có bảng dù Windows chạy | Linux có thể phân biệt hoa/thường tên bảng. Giữ đúng tên CamelCase trong SQL; CI Ubuntu kiểm tra việc này. |
| Lock timeout P1_LOCK | Phiên ghi khác còn giữ khóa; COMMIT/ROLLBACK và RELEASE_LOCK trong đúng phiên đó hoặc ngắt phiên; không tắt trigger. |
| P1_INPUT | JSON thiếu trường, trường bắt buộc là null, sai kiểu hoặc sai tên thuộc tính; xem ví dụ 04_seed.sql. |
| Transaction characteristics... | Đã gọi workflow trong giao dịch có sẵn; hoàn tất giao dịch ngoài trước. |
| Permission denied khi chạy wrapper | `chmod +x scripts/mysql-docker.sh`; file .sh được giữ LF bằng .gitattributes. |
| Không có mysql/Node trên Windows | Không ảnh hưởng chuyển mã; dựng phần 1 ở Ubuntu theo hướng dẫn. Web chưa cần cài. |

CI trên GitHub chạy Ubuntu 24.04 với server MySQL 8.4.7. Kết quả chạy trên máy Ubuntu riêng vẫn cần được xác nhận; CI xanh không tự chứng minh cấu hình máy cục bộ đã đúng.
