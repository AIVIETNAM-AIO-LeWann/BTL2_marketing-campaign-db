# Ma trận ràng buộc — phần 1

Nguồn: đặc tả BTL1 marketing của nhóm, bổ sung quyết định chuyên biệt hóa toàn phần và tên liên kết Phân công. Đây là ma trận kỹ thuật để rà đủ yêu cầu 1.1; không thay nguyên văn phần mô tả văn xuôi BTL1.

| Mục | Cách hiện thực | Thao tác cần kiểm tra |
|---|---|---|
| Khóa, lực lượng 1:N | PK/FK, NOT NULL; FK mặc định RESTRICT, không tự xóa lịch sử | INSERT/UPDATE khóa và DELETE dòng được tham chiếu |
| Tài khoản 1:1, toàn phần hai phía | FK và UNIQUE MaNhanVien; workflow tạo nhân viên+tài khoản; validator không cho nhân viên thiếu tài khoản | Tạo nhân viên, xóa tài khoản, đổi liên kết |
| Họ tên tổ hợp | Ho, TenDem, Ten; TenDem được NULL | INSERT/UPDATE nhân viên |
| Điện thoại đa trị | Bảng SoDienThoaiNhanVien; PK ghép; CHECK định dạng; cho phép 0 số | INSERT/UPDATE điện thoại |
| Phân công N:M | PK (MaNhanVien, MaChienDich), hai FK, thuộc tính nhiệm vụ và thời gian | INSERT/UPDATE/DELETE phân công |
| Chuyên biệt hóa rời nhau, toàn phần | Validator kiểm tra mỗi mã lớp cha thuộc đúng 1 lớp con; workflow tạo đầy đủ cùng giao dịch | Tạo/xóa lớp con; đổi kênh; tạo lớp cha |
| Email tham gia toàn phần vào sử dụng danh sách | Workflow tạo email kèm danh sách; validator ngăn xóa liên kết cuối cùng | Tạo email, INSERT/DELETE bảng nối |
| Thực thể yếu kết quả ngày | PK (MaHoatDong, NgayGhiNhan); FK chủ sở hữu; FK người cập nhật riêng | INSERT trùng ngày, xóa chủ sở hữu |
| **RB01** thời gian chiến dịch | CHECK ngày kết thúc >= bắt đầu; view v_ThoiLuongChienDich tính +1 | INSERT/UPDATE chiến dịch |
| **RB02** thời gian hoạt động | CHECK thứ tự ngày; validator so với chiến dịch | Sửa hoạt động **và sửa thời gian chiến dịch** |
| **RB03** thời gian phân công | CHECK thứ tự ngày; validator so với chiến dịch | Sửa phân công **và sửa thời gian chiến dịch** |
| **RB04** người chịu trách nhiệm chính | Validator kiểm tra phân công bao phủ toàn chiến dịch và VaiTro của tài khoản là QUAN_LY_MARKETING | Đổi người chính, thời gian chiến dịch/phân công, xóa phân công, đổi vai trò |
| **RB05** người phụ trách hoạt động | Validator kiểm tra cùng chiến dịch và phân công bao phủ thời gian hoạt động | Đổi người phụ trách/chiến dịch/thời gian hoạt động, sửa/xóa phân công |
| **RB06** giám sát hợp lệ | CHECK chặn tự giám sát; validator dùng CTE đệ quy phát hiện chu trình nhiều cấp | INSERT/UPDATE nhân viên |
| **RB07** ngân sách | CHECK các ngân sách không âm; validator SUM ngân sách hoạt động <= ngân sách chiến dịch | INSERT/UPDATE hoạt động, đổi chiến dịch, **giảm ngân sách chiến dịch** |
| **RB08** khoản chi, tiền tệ | CHECK SoTien > 0; DECIMAL tiền VND; view tổng chi và chênh lệch; không chặn thực chi vượt ngân sách | INSERT/UPDATE khoản chi; truy vấn chênh lệch |
| **RB09** loại hoạt động/kênh | CHECK nhóm kênh và định dạng; validator khớp lớp con, nhóm kênh, kênh tài khoản MXH với hoạt động | Sửa lớp con, hoạt động, nhóm kênh, kênh tài khoản |
| **RB10** cùng thương hiệu | FK lưu chủ sở hữu tài nguyên; validator đối chiếu với chiến dịch | Thêm danh sách vào email, đổi tài khoản sử dụng, **đổi chủ sở hữu tài nguyên hoặc chiến dịch** |
| **RB11** ngày và chỉ số kết quả | CHECK chỉ số không âm khi khác NULL; kiểu số nguyên; validator kiểm tra khoảng ngày | INSERT/UPDATE kết quả và sửa thời gian hoạt động |
| **RB12** tính chỉ số | View chi phí tách khỏi kết quả để tránh nhân bản khi JOIN; chia có điều kiện; NULL khi mẫu số 0/thiếu dữ liệu; view tổng kỳ yêu cầu đủ ngày và đủ chỉ số | Thay đổi khoản chi/kết quả được phản ánh ngay qua view |
| **RB13** duyệt chiến dịch | CHECK nội dung/ngân sách khi trạng thái đã duyệt trở đi; validator yêu cầu >=1 hoạt động; trigger kiểm tra tài khoản người chính đang hoạt động khi duyệt | Chuyển trạng thái; làm rỗng nội dung; xóa hoạt động cuối; đổi tài khoản |
| **RB14** bắt đầu hoạt động | Trigger kiểm tra chiến dịch đang thực hiện, tài khoản phụ trách hoạt động; validator kiểm tra nội dung lớp con; ngăn xóa nội dung bắt buộc sau khi bắt đầu | Chuyển trạng thái hoạt động và sửa thông tin lớp con |
| **RB15** người ghi/cập nhật | Trigger kiểm tra tài khoản đang hoạt động tại thời điểm INSERT/UPDATE; validator giữ điều kiện thành viên phân công | INSERT/UPDATE khoản chi/kết quả, sửa/xóa phân công, chuyển hoạt động sang chiến dịch khác |
| **RB16** hoàn thành/lịch sử | Validator không cho hoàn thành chiến dịch nếu còn hoạt động chưa kết thúc; không dùng CASCADE; DELETE trigger bảo vệ phân công/chi phí/kết quả đã kết thúc | Hoàn thành chiến dịch; sửa trạng thái hoạt động; xóa dữ liệu lịch sử |

## Bất biến và điều kiện tại thời điểm thao tác

Tài khoản người ghi phải hoạt động **khi ghi/cập nhật**. Sau này khóa tài khoản không làm khoản chi cũ trở thành sai; vì vậy validator không yêu cầu mọi người ghi lịch sử luôn có tài khoản hoạt động. Tương tự, hoạt động đã hoàn thành không yêu cầu chiến dịch hiện tại vẫn đang thực hiện.

Nhóm bổ sung chính sách không mở lại chiến dịch/hoạt động đã hoàn thành hoặc hủy; xóa dữ liệu lịch sử bị chặn, không chỉ tránh tự động xóa. Đây là lựa chọn triển khai để giữ lịch sử, cần đưa vào bản mô tả cập nhật.

## Bảo đảm toàn phần trong MySQL

Ngày 0/tháng 0 và mã định danh rỗng bị chặn bằng CHECK. SQL mode được đặt nhất quán khi tạo routine/trigger, kể cả chạy sáu file trong cùng một phiên. Workflow kiểm tra kiểu/trường JSON để giá trị JSON null không biến thành chuỗi văn bản 'null' ở cột bắt buộc.

Trigger kiểm tra toàn bộ bất biến sau mỗi dòng khi ghi trực tiếp. Tạo các đối tượng bắt buộc đi cùng nhau phải dùng workflow file 03: tạm hoãn các kiểm tra liên bảng bên trong giao dịch, kiểm tra lại đầy đủ trước COMMIT. PK/FK/CHECK vẫn luôn hoạt động. Nếu có lỗi, toàn bộ workflow rollback.

Biến hoãn kiểm tra không có khả năng tự bảo vệ. Vì vậy role marketing_p1 không có raw INSERT/UPDATE/DELETE; chỉ được gọi ba workflow đã giới hạn đầu vào và luôn kiểm tra trước commit. Phải giữ nguyên ranh giới quyền này khi triển khai ứng dụng. Không tuyên bố chỉ bằng hai FK là đã bảo đảm toàn phần.

## Giới hạn phải hiểu khi bảo vệ

- RB12: CSDL chỉ biết các khoản chi đã được ghi nhận. Nó không tự biết một hóa đơn ngoài hệ thống còn bị bỏ sót hay số đo nền tảng có đúng thực tế hay không. Việc xác nhận đủ chi phí nguồn là quy trình nghiệp vụ. Các view không thay NULL chuyển đổi thành 0 và không gộp chuyển đổi khác định nghĩa giữa các chiến dịch.
- Không áp đặt lượt nhấp <= lượt hiển thị hay chuyển đổi <= lượt nhấp: đặc tả không có các quy tắc này.
- Không áp đặt ngày phát sinh khoản chi phải nằm trong kế hoạch hoạt động: đặc tả không cấm chi phí chuẩn bị/đối soát trước hoặc sau kế hoạch.
- Validator quét toàn bộ dữ liệu để bao phủ các cập nhật từ nhiều phía, phù hợp phạm vi BTL nhỏ. Chưa phải phương án tối ưu cho dữ liệu lớn. CTE giám sát chịu giới hạn recursion của MySQL; không thiết kế cho cây tổ chức sâu hàng nghìn cấp.
- Ghi cạnh tranh phải tuân thủ khóa/giao dịch đã mô tả. Workflow dùng READ COMMITTED, khóa ghi được giữ đến COMMIT; không hứa bảo đảm cho phiên quản trị tùy ý bỏ qua quy trình.

## Tài liệu kỹ thuật đối chiếu

- [MySQL 8.4 — CHECK constraints](https://dev.mysql.com/doc/refman/8.4/en/create-table-check-constraints.html): điều kiện có thể kiểm tra ngay trong định nghĩa bảng.
- [MySQL 8.4 — Foreign keys](https://dev.mysql.com/doc/refman/8.4/en/create-table-foreign-keys.html): InnoDB kiểm tra tức thời; hành động CASCADE không kích hoạt trigger.
- [MySQL 8.4 — Trigger syntax](https://dev.mysql.com/doc/refman/8.4/en/trigger-syntax.html): trigger theo từng dòng, lỗi trigger làm câu lệnh thất bại; trigger không tự COMMIT/ROLLBACK giao dịch.
