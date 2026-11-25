# Quyết định triển khai BTL1 → BTL2

1. **Giữ 15 bảng** đúng các nhóm ánh xạ BTL1. Không thêm bảng chỉ để đủ số lượng.
2. **Phân công** là tên thống nhất cho liên kết N:M giữa nhân viên và chiến dịch, sau ánh xạ thành PhanCong. Mỗi cặp chỉ có một khoảng tham gia liên tục; PK ghép không lưu nhiều đợt tách rời.
3. **Chuyên biệt hóa toàn phần và rời nhau**: mọi hoạt động thuộc đúng một lớp Email hoặc Mạng xã hội. Phạm vi không có lớp hoạt động khác. NhomKenh chỉ gồm EMAIL/MANG_XA_HOI; có thể có nhiều nền tảng/kênh trong mỗi nhóm. Cần cập nhật hình EERD gốc: đường đôi từ lớp cha tới vòng tròn d. Nhánh này chưa sửa hình vẽ BTL1.
4. **Thương hiệu sở hữu tài nguyên**: giữ DanhSachNhanEmail.MaThuongHieu và TaiKhoanMangXaHoi.MaThuongHieu. Danh sách/tài khoản có thể được tạo trước khi sử dụng; đi qua hoạt động chỉ tìm được nơi sử dụng. DS06 và MXH06 minh họa chủ sở hữu khi chưa có hoạt động nào tham chiếu. Mọi nơi sử dụng phải cùng thương hiệu đã gán.
5. **Tài khoản 1:1**: không sinh tài khoản tự động với mật khẩu mặc định; tạo nhân viên và tài khoản trong một workflow giao dịch. Seed chỉ dùng chuỗi không đăng nhập được.
6. **Ngân sách và thực chi tách biệt**: chặn phân bổ ngân sách vượt hạn mức, nhưng cho phép thực chi vượt ngân sách và hiển thị chênh lệch. Tiền ghi bằng VND.
7. **Dữ liệu đo lường NULL khác 0**: thiếu dữ liệu không được biến thành kết quả bằng 0. Chỉ số tỷ lệ dùng tổng tử số/tổng mẫu số trong cùng phạm vi và trả NULL nếu không đủ điều kiện. Không lấy trung bình các tỷ lệ ngày.
8. **Chính sách xóa**: các FK không CASCADE. Bản ghi đang dùng bị FK chặn; dữ liệu phân công/chi phí/kết quả thuộc đối tượng đã kết thúc được giữ lại. Ba procedure 2.1 chỉ cho người tạo sửa/xóa khoản chi còn mở; xóa nhằm xử lý nhập nhầm/trùng, không xóa chi phí đã khóa sổ.
9. **Thuộc tính dẫn xuất**: thời lượng tính qua view. Phần 2.2 thêm cột TongChiPhiThucTe và trigger đồng bộ khi thêm/sửa/xóa/chuyển khoản chi; view tổng chi vẫn được giữ để đối soát độc lập.
10. **Phân quyền**: role `marketing_p1` có quyền đọc, gọi các workflow tạo dữ liệu và hai function 2.4. Web dùng role `marketing_web` với quyền đọc dữ liệu cần thiết và gọi routine phần 2. Biến phiên trong workflow chỉ phục vụ kiểm tra toàn vẹn, còn quyền ghi của web được kiểm soát qua procedure.

