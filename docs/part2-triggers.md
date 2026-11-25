# Mục 2.2 — Trigger kiểm tra ngân sách và tính tổng thực chi

## 2.2.1. Kiểm tra ngân sách phân bổ (RB07)

Tổng `NganSachDuocCap` của các hoạt động trong một chiến dịch phải nhỏ hơn hoặc bằng `NganSachDuocDuyet` của chiến dịch đó. `CHECK` trong lúc tạo bảng chỉ kiểm tra được ngân sách từng dòng có âm hay không. RB07 cần tính tổng nhiều dòng hoạt động và so sánh với một dòng ở bảng chiến dịch.

Các trigger `AFTER` ở [02_constraints.sql](../database/02_constraints.sql) gọi `sp_P1_KiemTraToanVen()` để kiểm tra điều kiện này. Khi tạo hoạt động qua `sp_P1_TaoHoatDong`, phần kiểm tra liên bảng được hoãn trong lúc ghi lớp cha và lớp con. Procedure gọi cùng bộ kiểm tra trước `COMMIT`. Nếu vi phạm, MySQL báo `RB07` và hủy thay đổi.

| DML | Khi nào có thể vi phạm | Nơi kiểm tra |
|---|---|---|
| `INSERT HoatDongTrienKhai` | Thêm ngân sách cấp vào tổng của chiến dịch | `trg_HoatDongTrienKhai_ai` hoặc bước kiểm tra trước `COMMIT` của `sp_P1_TaoHoatDong` |
| `UPDATE HoatDongTrienKhai.NganSachDuocCap` | Tăng ngân sách khiến tổng vượt mức duyệt | `trg_HoatDongTrienKhai_au` |
| `UPDATE HoatDongTrienKhai.MaChienDich` | Khoản phân bổ được cộng vào chiến dịch đích | `trg_HoatDongTrienKhai_au` |
| `UPDATE ChienDich.NganSachDuocDuyet` | Giảm mức duyệt xuống dưới tổng đã cấp | `trg_ChienDich_au` |
| `DELETE HoatDongTrienKhai` | Chỉ giảm tổng đã cấp | `trg_HoatDongTrienKhai_ad` vẫn gọi bộ kiểm tra chung |

**Demo trên dữ liệu mẫu.** `CD01` được duyệt 20.000.000 VND. `HD01` được cấp 2.000.000 và `HD02` được cấp 3.000.000. Chạy từng lệnh trong cùng một phiên quản trị để vẫn thực hiện được `ROLLBACK` sau lỗi dự kiến.

```sql
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;

UPDATE HoatDongTrienKhai SET NganSachDuocCap=17000000 WHERE MaHoatDong='HD01';
-- Thành công: 17.000.000 + 3.000.000 = 20.000.000.

UPDATE HoatDongTrienKhai SET NganSachDuocCap=17000001 WHERE MaHoatDong='HD01';
-- RB07: tổng cấp dự kiến vượt 1 VND.

SELECT NganSachDuocCap FROM HoatDongTrienKhai WHERE MaHoatDong='HD01';
-- 17000000: lệnh bị từ chối không làm thay đổi giá trị.

UPDATE ChienDich SET NganSachDuocDuyet=19999999 WHERE MaChienDich='CD01';
-- RB07: mức duyệt dự kiến thấp hơn tổng đã cấp 1 VND.

ROLLBACK;
DO RELEASE_LOCK('marketing_btl.integrity');
```

Ca chuyển hoạt động được kiểm thử riêng bằng chiến dịch đích cùng thương hiệu, đủ thời gian và phân công. Chuyển `HD03` có ngân sách 2.000.000 VND sang đích có mức duyệt 1.999.999 bị chặn bởi RB07. Tăng mức duyệt đích lên đúng 2.000.000 thì chuyển thành công. Xem [test_expense_integration.py](../database/tests/test_expense_integration.py).

## 2.2.2. Tính thuộc tính dẫn xuất `TongChiPhiThucTe`

`HoatDongTrienKhai.TongChiPhiThucTe` lưu tổng `KhoanChi.SoTien` của từng hoạt động. Hoạt động chưa có khoản chi có tổng bằng 0. File [01_expense_triggers.sql](../database/part2/01_expense_triggers.sql) tính lại tổng cho dữ liệu đã tồn tại, sau đó các trigger duy trì giá trị khi khoản chi thay đổi.

| DML trên `KhoanChi` | Trigger | Thay đổi tổng |
|---|---|---|
| Thêm khoản chi | `trg_KhoanChi_ai_tong` | Cộng `NEW.SoTien` cho hoạt động nhận chi |
| Sửa tiền trong cùng hoạt động | `trg_KhoanChi_au_tong` | Cộng `NEW.SoTien - OLD.SoTien` |
| Chuyển khoản chi sang hoạt động khác | `trg_KhoanChi_au_tong` | Trừ `OLD.SoTien` ở hoạt động cũ, cộng `NEW.SoTien` ở hoạt động mới |
| Sửa nội dung hoặc chứng từ, giữ nguyên hoạt động và số tiền | `trg_KhoanChi_au_tong` | Tổng giữ nguyên |
| Xóa khoản chi | `trg_KhoanChi_ad_tong` | Trừ `OLD.SoTien` |

Trigger chạy trong cùng giao dịch với câu lệnh ghi khoản chi, nên `ROLLBACK` khôi phục cả khoản chi và tổng. Thực chi được phép vượt mức cấp theo RB08. RB07 chỉ so sánh các khoản **ngân sách cấp** với mức ngân sách duyệt.

**Demo trên dữ liệu mẫu.** `HD01` thực chi 3.000.000 VND và `HD02` thực chi 3.500.000 VND trước khi chạy.

```sql
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;

INSERT INTO KhoanChi
    (MaKhoanChi,MaHoatDong,MaNguoiGhiNhan,NgayPhatSinh,SoTien,NoiDungChi)
VALUES ('KC_DEMO_22','HD01','NV04','2026-11-07',9000000,'Demo trigger');
SELECT TongChiPhiThucTe FROM HoatDongTrienKhai WHERE MaHoatDong='HD01';
-- 12000000, dù ngân sách cấp cho HD01 là 2000000.

UPDATE KhoanChi SET SoTien=9500000 WHERE MaKhoanChi='KC_DEMO_22';
SELECT TongChiPhiThucTe FROM HoatDongTrienKhai WHERE MaHoatDong='HD01';
-- 12500000.

UPDATE KhoanChi SET MaHoatDong='HD02',SoTien=800000 WHERE MaKhoanChi='KC_DEMO_22';
SELECT MaHoatDong,TongChiPhiThucTe FROM HoatDongTrienKhai
WHERE MaHoatDong IN ('HD01','HD02') ORDER BY MaHoatDong;
-- HD01 = 3000000, HD02 = 4300000.

DELETE FROM KhoanChi WHERE MaKhoanChi='KC_DEMO_22';
SELECT TongChiPhiThucTe FROM HoatDongTrienKhai WHERE MaHoatDong='HD02';
-- 3500000.

ROLLBACK;
DO RELEASE_LOCK('marketing_btl.integrity');
```

Sau demo, đối soát cột lưu với view tính trực tiếp từ `KhoanChi`. Câu lệnh phải trả về 0 dòng.

```sql
SELECT h.MaHoatDong, h.TongChiPhiThucTe AS TongLuu, v.TongChiPhiThucTe AS TongTinhLai
FROM HoatDongTrienKhai h JOIN v_ChiPhiHoatDong v USING (MaHoatDong)
WHERE h.TongChiPhiThucTe <> v.TongChiPhiThucTe;
```
