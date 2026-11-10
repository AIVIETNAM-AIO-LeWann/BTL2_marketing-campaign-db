# Quyết định triển khai BTL1 → BTL2

1. **Giữ 15 bảng** đúng các nhóm ánh xạ BTL1. Không thêm bảng chỉ để đủ số lượng.
2. **Phân công** là tên thống nhất cho liên kết N:M giữa nhân viên và chiến dịch, sau ánh xạ thành PhanCong. Mỗi cặp chỉ có một khoảng tham gia liên tục; PK ghép không lưu nhiều đợt tách rời.
3. **Chuyên biệt hóa toàn phần và rời nhau**: mọi hoạt động thuộc đúng một lớp Email hoặc Mạng xã hội. Phạm vi không có lớp hoạt động khác. NhomKenh chỉ gồm EMAIL/MANG_XA_HOI; có thể có nhiều nền tảng/kênh trong mỗi nhóm. Cần cập nhật hình EERD gốc: đường đôi từ lớp cha tới vòng tròn d. Nhánh này chưa sửa hình vẽ BTL1.
4. **Thương hiệu sở hữu tài nguyên**: giữ DanhSachNhanEmail.MaThuongHieu và TaiKhoanMangXaHoi.MaThuongHieu. Danh sách/tài khoản có thể được tạo trước khi sử dụng; đi qua hoạt động chỉ tìm được nơi sử dụng. DS06 và MXH06 minh họa chủ sở hữu khi chưa có hoạt động nào tham chiếu. Mọi nơi sử dụng phải cùng thương hiệu đã gán.
5. **Tài khoản 1:1**: không sinh tài khoản tự động với mật khẩu mặc định; tạo nhân viên và tài khoản trong một workflow giao dịch. Seed chỉ dùng chuỗi không đăng nhập được.
6. **Ngân sách và thực chi tách biệt**: chặn phân bổ ngân sách vượt hạn mức, nhưng cho phép thực chi vượt ngân sách và hiển thị chênh lệch. Tiền ghi bằng VND.
7. **Dữ liệu đo lường NULL khác 0**: thiếu dữ liệu không được biến thành kết quả bằng 0. Chỉ số tỷ lệ dùng tổng tử số/tổng mẫu số trong cùng phạm vi và trả NULL nếu không đủ điều kiện. Không lấy trung bình các tỷ lệ ngày.
8. **Chính sách xóa**: các FK không CASCADE. Bản ghi đang dùng bị FK chặn; dữ liệu phân công/chi phí/kết quả thuộc đối tượng đã kết thúc được giữ lại. Procedure xóa KhoanChi chi tiết sẽ làm ở phần 2; chưa có màn hình hay procedure CRUD trong phần 1.
9. **Thuộc tính dẫn xuất**: thời lượng tính qua view; tổng thực chi hiện cũng tính qua view. Việc thêm cột TongChiPhiThucTe lưu vật lý và trigger đồng bộ dành cho phần 2. Không lưu một cột cache chưa có cơ chế cập nhật.
10. **Phân quyền**: role marketing_p1 chỉ có đọc và gọi các workflow tạo dữ liệu đầy đủ. Không dùng root hoặc cấp raw DML cho ứng dụng; biến phiên trong workflow không thay thế quyền truy cập.

## Đầu việc tiếp theo (chưa hiện thực)

- Ba procedure CRUD KhoanChi, hai procedure truy vấn có tham số.
- Hai function có cursor: đếm hoạt động vượt ngân sách và tính CPA trong khoảng ngày.
- Trigger duy trì tổng chi phí vật lý; tái sử dụng kiểm tra RB07 làm minh chứng trigger nghiệp vụ khi báo cáo.
- Ứng dụng web, kết nối MySQL bằng user giới hạn quyền, xử lý lỗi và giao diện.
- Phân công sao cho cả bốn thành viên có đóng góp SQL phần 2 và hiểu các workflow/ràng buộc nền tảng.
