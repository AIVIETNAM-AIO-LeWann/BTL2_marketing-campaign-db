# Hướng dẫn cho Codex trong repo BTL2 marketing

## Đọc khi bắt đầu phiên mới

Đọc `docs/HANDOFF.md` trước khi sửa dự án. Đây là bản bàn giao ngữ cảnh: mục tiêu, yêu cầu, quyết định đã chốt, trạng thái hiện thực và việc tiếp theo. Không giả định có sẵn lịch sử trò chuyện từ máy hoặc phiên trước.

Sau đó đọc theo nhiệm vụ:

- `README.md`: cấu trúc repo, cách dựng và kiểm thử.
- `docs/constraints.md` và `docs/design-decisions.md`: khi sửa SQL, ràng buộc hoặc mô hình.
- `docs/part1-test-results.md`: bằng chứng kiểm thử và giới hạn kết luận; kiểm tra thêm CI của commit đang dùng.
- `docs/ubuntu-setup.md`: chỉ khi thiết lập/chạy môi trường Ubuntu của người dùng.

## Ngữ cảnh môi trường

Người dùng chính chuyển công việc cá nhân từ Windows sang Ubuntu và muốn Codex ở Ubuntu tiếp tục từ các tài liệu này. **Không có quyết định yêu cầu cả nhóm dùng Ubuntu.** Không ép thành viên khác chuyển hệ điều hành hoặc dùng Docker. Kiểm tra môi trường hiện tại trước khi cài đặt; MySQL trên Ubuntu có thể đã tồn tại.

## Phạm vi và quyết định nền tảng

- Hiện tại tập trung phần 1 BTL2: bảng, ràng buộc và dữ liệu mẫu. Chỉ chuyển sang phần 2–3 khi yêu cầu mới của người dùng mở rộng phạm vi; không tự chọn framework web hoặc triển khai trước phần chưa phân công.
- MySQL đã chốt; baseline kiểm thử 8.4.7, 15 bảng, dữ liệu mẫu ban đầu 118 dòng và tối thiểu 5 dòng mỗi bảng.
- Giữ chuyên biệt hóa hoạt động **rời nhau và toàn phần**, tên quan hệ **Phân công**, liên kết thương hiệu sở hữu danh sách email/tài khoản MXH ngay cả khi chưa dùng.
- Hướng phần 2–3 đã thống nhất và các chi tiết chưa chốt nằm trong HANDOFF; phân biệt kế hoạch với code đã hiện thực.

## Khi thay đổi

- Không tắt FK, CHECK hoặc trigger để làm dữ liệu chạy qua. Tôn trọng giao dịch, khóa ghi và quyền hạn được mô tả trong README.
- SQL thay đổi cần chạy bootstrap trên database thử nghiệm trống và bộ kiểm thử phù hợp; không DROP dữ liệu hiện có của người dùng để thử. Nếu chưa chạy được, nói rõ phần chưa xác minh.
- Sửa tài liệu đơn thuần thì kiểm tra tính nhất quán và liên kết; không cần chạy lại toàn bộ SQL.
- Kiểm tra nhánh và trạng thái PR thực tế; không suy ra PR đã merge từ tài liệu cũ. PR phần 1 ban đầu là #1, nhánh `feat/part1-database`.
- Khi có quyết định mới hoặc hoàn tất một mốc, cập nhật HANDOFF cùng code để phiên Codex sau hiểu trạng thái hiện tại.
- Trao đổi với người dùng bằng tiếng Việt; giải thích rõ nghiệp vụ và tránh thuật ngữ không cần thiết.
