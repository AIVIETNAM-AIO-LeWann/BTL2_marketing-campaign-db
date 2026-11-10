# Kết quả kiểm thử phần 1

Ngày chạy: 10/11/2026. Runtime kiểm thử: MySQL Community Server **8.4.7**, InnoDB, localhost trên cổng thử nghiệm 33077. Runtime và dữ liệu server nằm ngoài repo, không cài dịch vụ hệ thống.

## Dựng dữ liệu

Đã chạy lần lượt các file `01_schema.sql` đến `06_verify.sql` trên database trống. Tất cả kết thúc không có lỗi. Kết quả: **15 bảng vật lý, 118 dòng dữ liệu**, mọi bảng có ít nhất 5 dòng. Chi tiết số dòng ở README.

## Kiểm thử tích hợp

```console
python database/tests/test_constraints.py --mysql <mysql-client> --port 33077
```

Kết quả sau rà soát sâu: **81 tests, OK**. Đã dựng lại từ database trống bằng toàn bộ SQL trong **cùng một phiên client**, theo quy trình bootstrap của dự án. Bao gồm:

- PK, FK, UNIQUE, NOT NULL, CHECK định dạng và miền giá trị.
- Kiểm tra đúng 15 bảng, tối thiểu 5 dòng mỗi bảng, InnoDB và tiếng Việt UTF-8.
- Các RB01–RB16 có ca minh họa tương ứng, gồm cập nhật từ phía cha/tài nguyên để thử đường kiểm tra ngược.
- Tài khoản toàn phần; lớp con toàn phần/rời nhau; email có ít nhất một danh sách.
- Chặn chu trình giám sát nhiều cấp, sai thương hiệu/kênh, phân công thiếu thời gian và vượt ngân sách phân bổ.
- Cho phép thực chi vượt ngân sách; giữ nguyên sự khác biệt giữa NULL và 0.
- Chặn hoàn thành sớm, xóa lịch sử, ghi dữ liệu bằng tài khoản đã khóa.
- Workflow thất bại phải rollback cả cha/con: trùng tài khoản, email thiếu danh sách, sai thương hiệu, vượt ngân sách.
- Role giới hạn không thể tự đặt biến phiên rồi ghi trực tiếp để bỏ qua kiểm tra; tài khoản thử nghiệm được tạo/xóa trong ca này.
- JSON null/sai kiểu/thiếu trường ở đầu vào bắt buộc bị chặn; null ở trường tùy chọn được giữ đúng. Ngân sách không nhận phần lẻ VND trong JSON.
- Ngày 0000-00-00 hoặc có tháng 0 bị chặn cả khi caller giảm SQL mode; ngày lịch không hợp lệ bị từ chối.
- Mã định danh rỗng và tự giám sát được kiểm tra trong CREATE TABLE.
- Lời gọi workflow lồng không làm mất khóa/cờ/giao dịch của caller; câu lệnh nhiều dòng thất bại rollback toàn bộ câu lệnh.

Đợt review đã tái hiện và sửa ba nhóm lỗi của bản 68-test: JSON null thành chuỗi 'null', chấp nhận ngày zero khi SQL mode thiếu tùy chọn, và handler giải phóng nhầm khóa/cờ của giao dịch ngoài. Các ca hồi quy đã được đưa vào bộ test.

Kết quả minh họa: HD01 được cấp 2.000.000 VND và thực chi 3.000.000 VND; chênh lệch +1.000.000 được chấp nhận. DS06/MXH06 chưa được sử dụng nhưng xác định được thương hiệu sở hữu TH01. CPA bằng NULL khi chuyển đổi bằng 0 hoặc chưa biết.

## Phạm vi kết luận

Kết quả xác nhận các script và tình huống trong bộ thử chạy được trên runtime nêu trên. Không chứng minh đầy đủ mọi lịch ghi cạnh tranh, hiệu năng dữ liệu lớn hay tính đầy đủ của số liệu ngoài hệ thống. Các điều kiện quyền và quy trình giao dịch trong README là một phần của thiết kế cần giữ khi làm phần 2–3.
