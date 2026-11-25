# Mục 2.4 — Hai hàm tính toán marketing

Mã nguồn: [04_marketing_functions.sql](../database/part2/04_marketing_functions.sql). Nạp sau phần 1, theo thứ tự trong README. Hai hàm chỉ đọc dữ liệu và trả về một giá trị; không thay đổi ngân sách, khoản chi, kết quả hay trạng thái.

## 1. Đếm hoạt động thực chi vượt ngân sách

`fn_P2_DemHoatDongVuotNganSach(p_MaChienDich)` nhận mã chiến dịch và trả về số hoạt động có tổng khoản chi thực tế **lớn hơn** ngân sách được cấp của chính hoạt động đó. Thực chi bằng ngân sách không được tính là vượt. Chiến dịch hợp lệ chưa có hoạt động trả về 0; mã không tồn tại báo `P2_FN_NOTFOUND`, không giả thành kết quả 0.

Cursor truy vấn từng hoạt động cùng ngân sách và tổng `KhoanChi.SoTien`. LEFT JOIN giữ cả hoạt động chưa có khoản chi, với thực chi bằng 0. Vòng LOOP FETCH từng dòng; IF so sánh thực chi với ngân sách và tăng biến đếm. Kết thúc cursor thì trả biến đếm. Dữ liệu lấy từ khoản chi gốc, không phụ thuộc cột tổng lưu của trigger 2.2.

Hàm xét toàn bộ thực chi đã ghi nhận, kể cả khoản phát sinh ngoài thời gian dự kiến, theo chính sách RB08. Phạm vi gồm mọi trạng thái hoạt động của chiến dịch, kể cả đã hoàn thành hoặc hủy; đây là báo cáo thực chi, không phải danh sách công việc đang mở.

```sql
SELECT fn_P2_DemHoatDongVuotNganSach('CD01'); -- 2
SELECT fn_P2_DemHoatDongVuotNganSach('CD02'); -- 0
SELECT fn_P2_DemHoatDongVuotNganSach('KHONG_CO'); -- P2_FN_NOTFOUND
SELECT fn_P2_DemHoatDongVuotNganSach(NULL); -- P2_FN_INPUT
```

Trên seed, HD01 thực chi 3.000.000 so với ngân sách 2.000.000; HD02 thực chi 3.500.000 so với ngân sách 3.000.000. Cả hai thuộc CD01 nên kết quả bằng 2.

## 2. Tính chi phí trên một chuyển đổi trong kỳ

`fn_P2_ChiPhiTrenChuyenDoi(p_MaHoatDong, p_TuNgay, p_DenNgay)` nhận mã hoạt động và hai ngày, trả `DECIMAL(48,4)` với đơn vị VND/chuyển đổi. Khoảng ngày bao gồm cả hai đầu và phải nằm trong thời gian dự kiến của hoạt động.

CPA = tổng `KhoanChi.SoTien` có ngày phát sinh trong kỳ / tổng `KetQuaNgay.SoChuyenDoi` có ngày ghi nhận trong kỳ. Không dùng tổng chi toàn lịch sử cho một kỳ ngắn, không lấy trung bình các CPA ngày.

Cursor truy vấn kết quả từng ngày, nối với khoản chi đã GROUP BY ngày. Mỗi ngày chỉ FETCH một lần dù có nhiều khoản chi. LOOP cộng chi phí và chuyển đổi, đếm số ngày kết quả và đánh dấu khi gặp chuyển đổi NULL. IF sau vòng lặp kiểm tra đủ số ngày, không có dữ liệu chuyển đổi NULL và tổng chuyển đổi lớn hơn 0, rồi mới chia. Kết quả làm tròn đến bốn chữ số thập phân.

| Trường hợp | Kết quả |
|---|---|
| Mã NULL/rỗng/quá 20 ký tự/có khoảng trắng đầu cuối | Lỗi `P2_FN_INPUT` |
| Mã hoạt động không tồn tại | Lỗi `P2_FN_NOTFOUND` |
| Ngày NULL, đảo thứ tự, nằm ngoài thời gian hoạt động | Lỗi `P2_FN_INPUT` |
| Chuỗi ngày không hợp lệ truyền vào tham số DATE | MySQL có thể từ chối ngay khi chuyển kiểu, trước khi vào thân hàm |
| Thiếu bất kỳ ngày kết quả nào trong kỳ | NULL: chưa đủ dữ liệu |
| Có ngày với `SoChuyenDoi IS NULL` | NULL: chưa biết số chuyển đổi |
| Tổng chuyển đổi bằng 0 | NULL: không thể chia |
| Một ngày có 0 chuyển đổi, ngày khác có chuyển đổi, đủ dữ liệu | Tính trên tổng chuyển đổi của cả kỳ |
| Có chuyển đổi, không có khoản chi trong kỳ | 0.0000 theo chi phí đã ghi nhận |

```sql
SELECT fn_P2_ChiPhiTrenChuyenDoi('HD01','2026-11-05','2026-11-06');
-- 3.000.000 / (6 + 7) = 230769.2308

SELECT fn_P2_ChiPhiTrenChuyenDoi('HD01','2026-11-05','2026-11-05');
-- 2.500.000 / 6 = 416666.6667

SELECT fn_P2_ChiPhiTrenChuyenDoi('HD02','2026-11-06','2026-11-06');
-- NULL: số chuyển đổi bằng 0

SELECT fn_P2_ChiPhiTrenChuyenDoi('HD03','2026-11-05','2026-11-06');
-- NULL: số chuyển đổi ngày 06 chưa biết

SELECT fn_P2_ChiPhiTrenChuyenDoi('HD01','2026-11-05','2026-11-07');
-- NULL: chưa có bản ghi kết quả ngày 07

SELECT fn_P2_ChiPhiTrenChuyenDoi('HD01','2026-11-06','2026-11-05');
-- P2_FN_INPUT: ngày bắt đầu sau ngày kết thúc
```

Không có khoản chi trong CSDL được hiểu là không có **chi phí đã ghi nhận**. Mô hình hiện tại không có cờ xác nhận đã nhập đủ mọi chi phí thực tế bên ngoài. Vì vậy CPA phản ánh dữ liệu đã nhập, không chứng minh toàn bộ chi phí thực tế đã được kế toán xác nhận.

## 3. Đối chiếu yêu cầu của đề

| Yêu cầu mục 2.4 | Hàm đếm vượt ngân sách | Hàm CPA |
|---|---|---|
| Có tham số và kiểm tra đầu vào | Mã bắt buộc, độ dài, khoảng trắng, tồn tại | Mã và ngày bắt buộc, tồn tại, thứ tự, phạm vi ngày |
| Truy vấn dữ liệu để tính toán | Hoạt động LEFT JOIN khoản chi, SUM theo hoạt động | Kết quả ngày LEFT JOIN tổng chi theo ngày |
| Có con trỏ | `cur_HoatDong`, OPEN/FETCH/CLOSE | `cur_KetQua`, OPEN/FETCH/CLOSE |
| Có IF/LOOP | So sánh và đếm từng hoạt động | Cộng dồn, kiểm tra NULL, số ngày và mẫu số |
| Hai nghiệp vụ có ý nghĩa khác nhau | Cảnh báo số hoạt động vượt ngân sách | Đánh giá chi phí cho một chuyển đổi trong kỳ |
| Có lệnh và dữ liệu minh họa | Seed CD01 có hai hoạt động vượt | Seed có đủ ngày, 0, NULL và thiếu ngày |

Cursor được sử dụng để đáp ứng bài tập. Hai phép tính này có thể viết gọn bằng truy vấn aggregate trong ứng dụng thực tế; không khẳng định cursor nhanh hơn.

## 4. Kiểm thử và quyền thực thi

Chạy [test_marketing_functions.py](../database/tests/test_marketing_functions.py) trên database thử đã nạp seed và hai hàm. Bộ thử có 27 test, gồm nhiều trường hợp con: mã/ngày sai, bằng ngưỡng ngân sách, nhiều khoản chi/ngày, thiếu ngày, NULL/0, số tiền lớn, biên làm tròn, đổi dữ liệu gốc, rollback và quyền role. Chạy thêm 81 test phần 1 và 16 test ghép CRUD/truy vấn/trigger để kiểm tra tương thích.

Ngày 25/11/2026 đã dựng sạch bằng 10 file SQL (phần 1 rồi phần 2) trên MySQL 8.4.7 và chạy đạt cả **124 test**. CI cũng thực hiện thứ tự này; xem kết quả tương ứng với commit/PR đang dùng.

Hai hàm khai báo `NOT DETERMINISTIC`, `READS SQL DATA`, `SQL SECURITY INVOKER`: cùng tham số có thể cho kết quả khác sau khi dữ liệu thay đổi; người gọi cần quyền đọc bảng và EXECUTE hàm. File SQL cấp EXECUTE cho role `marketing_p1` vốn đã có quyền SELECT. Không cấp quyền ghi bảng cho role này.

Các kiểm thử xác nhận tình huống đã chuẩn bị, không chứng minh hiệu năng dữ liệu lớn hoặc mọi lịch cập nhật đồng thời. Báo cáo nhiều bước cần dùng cùng giao dịch đọc phù hợp nếu muốn một ảnh chụp dữ liệu thống nhất.

Tài liệu cú pháp: [MySQL — CREATE FUNCTION](https://dev.mysql.com/doc/refman/8.4/en/create-procedure.html), [MySQL — Cursors](https://dev.mysql.com/doc/refman/8.4/en/cursors.html).
