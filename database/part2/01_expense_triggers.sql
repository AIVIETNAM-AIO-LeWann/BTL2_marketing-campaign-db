-- =====================================================================
-- P2.2 — Trigger nghiệp vụ và thuộc tính dẫn xuất TongChiPhiThucTe
-- Chạy SAU khi đã dựng phần 1 (01..06), trong một phiên quản trị,
-- trên database chưa chạy file này (ALTER sẽ báo lỗi nếu cột đã có).
-- =====================================================================
--
-- 1. RÀNG BUỘC NGHIỆP VỤ RB07
--    Với mỗi chiến dịch: SUM(HoatDongTrienKhai.NganSachDuocCap) <= ChienDich.NganSachDuocDuyet.
--    Miền giá trị không âm giữ ở CHECK ck_hd_ngansach / ck_cd_ngansach trong CREATE TABLE.
--
--    Rà soát phần 1: RB07 đã nằm trong sp_P1_KiemTraToanVen (02_constraints.sql), được gọi
--    sau MỖI dòng thay đổi bởi trg_HoatDongTrienKhai_ai/_au/_ad và trg_ChienDich_ai/_au/_ad,
--    và trước COMMIT trong các workflow sp_P1_Tao*. Kiểm tra là toàn phần (mọi chiến dịch),
--    nên phủ cả phía cha (giảm trần) lẫn phía con (tăng cấp, chuyển chiến dịch).
--    => Không tạo trigger RB07 trùng chức năng; file này không đổi logic RB07.
--
--    Ma trận DML:
--    | Thao tác                                   | Ảnh hưởng RB07                     | Nơi chặn                           |
--    |--------------------------------------------|------------------------------------|------------------------------------|
--    | INSERT HoatDongTrienKhai                   | Tăng tổng cấp của chiến dịch       | trg_HoatDongTrienKhai_ai / workflow|
--    | UPDATE HoatDongTrienKhai.NganSachDuocCap   | Tăng có thể vượt trần              | trg_HoatDongTrienKhai_au           |
--    | UPDATE HoatDongTrienKhai.MaChienDich       | Chiến dịch đích có thể vượt trần   | trg_HoatDongTrienKhai_au           |
--    | UPDATE ChienDich.NganSachDuocDuyet (giảm)  | Trần thấp hơn tổng đã cấp          | trg_ChienDich_au                   |
--    | DELETE HoatDongTrienKhai                   | Chỉ giảm tổng, không tự gây vượt   | (vẫn kiểm tra toàn phần ở _ad)     |
--    | INSERT/UPDATE/DELETE KhoanChi              | Đổi THỰC CHI, không đổi ngân sách  | Không thuộc RB07                   |
--
--    Thực chi vượt ngân sách cấp là HỢP LỆ (chỉ hiển thị chênh lệch qua v_ChiPhiHoatDong).
--
-- 2. BẢO VỆ LỊCH SỬ KHOẢN CHI (chính sách khóa sổ, thống nhất với gói A — P2.1)
--    "Đã kết thúc" = hoạt động HOẶC chiến dịch ở trạng thái HOAN_THANH/HUY.
--    - INSERT KhoanChi: hoạt động đích phải chưa kết thúc.
--    - UPDATE KhoanChi: hoạt động NGUỒN (OLD) phải chưa kết thúc — khóa sửa mọi trường của
--      khoản chi đã khóa sổ, kể cả khi đồng thời đổi MaNguoiGhiNhan để lách RB15;
--      hoạt động ĐÍCH (NEW) cũng phải chưa kết thúc.
--      => Không thể chuyển khoản chi lịch sử ra hoạt động đang mở rồi xóa.
--    - DELETE KhoanChi: giữ kiểm tra RB16 của phần 1 (trg_KhoanChi_bd, không đổi).
--    - Giữ nguyên RB15 (người ghi phải được phân công, tài khoản hoạt động) và khóa P1_KEY;
--      kiểm tra phần 1 chạy trước, kiểm tra P2 chạy sau nên mã lỗi cũ không đổi.
--    Kiểm tra đặt ở trigger nên áp dụng cho cả DML trực tiếp, không chỉ qua procedure.
--
-- 3. THUỘC TÍNH DẪN XUẤT
--    HoatDongTrienKhai.TongChiPhiThucTe DECIMAL(38,0) NOT NULL DEFAULT 0, CHECK >= 0
--    TongChiPhiThucTe = SUM(KhoanChi.SoTien) của hoạt động (0 nếu không có khoản chi).
--    - Khởi tạo lại từ SoTien gốc ở cuối file (không tin DEFAULT 0), kể cả hoạt động đã kết thúc:
--      trigger của HoatDongTrienKhai chỉ chặn đổi TrangThai, không chặn ghi cột tổng.
--    - Duy trì bằng 3 AFTER trigger trên KhoanChi (cùng câu lệnh => cùng giao dịch):
--        INSERT: hoạt động NEW  += NEW.SoTien
--        DELETE: hoạt động OLD  -= OLD.SoTien
--        UPDATE: cùng hoạt động  += NEW.SoTien - OLD.SoTien (bỏ qua nếu tiền không đổi)
--                đổi hoạt động   nguồn -= OLD.SoTien, đích += NEW.SoTien
--    - Thứ tự: mỗi trigger tổng PRECEDES trigger kiểm tra toàn vẹn AFTER cũ, để kiểm tra
--      toàn phần chạy trên trạng thái đã cập nhật tổng.
--    - Khóa: BEFORE trigger của KhoanChi đã lấy khóa marketing_btl.integrity (sp_P1_KhoaGhi);
--      UPDATE cột tổng đi qua trg_HoatDongTrienKhai_bu, gọi lại sp_P1_KhoaGhi (không lấy lại
--      khóa đã giữ). Không có vòng trigger: trigger HoatDongTrienKhai không ghi KhoanChi.
--    - Chốt chặn: trg_HoatDongTrienKhai_bi/_bu từ chối mọi giá trị cột tổng khác SUM thực tế,
--      nên cột không bị sửa tay lệch dữ liệu gốc.
--    - v_ChiPhiHoatDong (05_reports.sql) vẫn tính từ SUM(KhoanChi), là nguồn đối soát độc lập.
-- =====================================================================

USE marketing_btl;
SET NAMES utf8mb4;
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,ONLY_FULL_GROUP_BY,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

-- ---------------------------------------------------------------------
-- A. Cột dẫn xuất
-- ---------------------------------------------------------------------
ALTER TABLE HoatDongTrienKhai
    ADD COLUMN TongChiPhiThucTe DECIMAL(38,0) NOT NULL DEFAULT 0
        COMMENT 'Dan xuat: SUM(KhoanChi.SoTien), duy tri boi trigger KhoanChi',
    ADD CONSTRAINT ck_hd_tongchi CHECK (TongChiPhiThucTe >= 0);

DELIMITER $$

-- ---------------------------------------------------------------------
-- B. Kiểm tra trạng thái khóa sổ (dùng chung cho INSERT/UPDATE KhoanChi)
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_P2_KiemTraHoatDongMo(IN p_hd VARCHAR(20), IN p_msg VARCHAR(128))
SQL SECURITY DEFINER
BEGIN
    IF EXISTS (SELECT 1 FROM HoatDongTrienKhai h JOIN ChienDich c USING(MaChienDich)
        WHERE h.MaHoatDong=p_hd AND (h.TrangThai IN ('HOAN_THANH','HUY') OR c.TrangThai IN ('HOAN_THANH','HUY'))) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT=p_msg;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- C. Thay trigger phần 1 (giữ nguyên tên và toàn bộ logic cũ, thêm phần đánh dấu P2)
-- ---------------------------------------------------------------------
DROP TRIGGER trg_HoatDongTrienKhai_bi$$
CREATE TRIGGER trg_HoatDongTrienKhai_bi BEFORE INSERT ON HoatDongTrienKhai
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
    IF NEW.TrangThai<>'CHUA_BAT_DAU' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB14: Hoat dong moi phai o trang thai CHUA_BAT_DAU.'; END IF;
    -- P2: hoạt động mới chưa có khoản chi nào.
    IF NEW.TongChiPhiThucTe<>0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_TONGCHI: TongChiPhiThucTe phai bang tong SoTien cua khoan chi; khong ghi tay.';
    END IF;
END$$

DROP TRIGGER trg_HoatDongTrienKhai_bu$$
CREATE TRIGGER trg_HoatDongTrienKhai_bu BEFORE UPDATE ON HoatDongTrienKhai
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
    IF NOT (NEW.MaHoatDong <=> OLD.MaHoatDong) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1_KEY: Khong doi khoa dinh danh; tao ban ghi moi neu can.'; END IF;
    IF NEW.TrangThai<>OLD.TrangThai THEN
        IF OLD.TrangThai IN ('HOAN_THANH','HUY') THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB16: Khong mo lai hoat dong da ket thuc.';
        END IF;
        IF NEW.TrangThai='CHUA_BAT_DAU' OR (OLD.TrangThai='CHUA_BAT_DAU' AND NEW.TrangThai NOT IN ('DANG_THUC_HIEN','HUY')) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB14: Thu tu chuyen trang thai hoat dong khong hop le.';
        END IF;
        IF NEW.TrangThai='DANG_THUC_HIEN' AND (NOT EXISTS (
            SELECT 1 FROM ChienDich WHERE MaChienDich=NEW.MaChienDich AND TrangThai='DANG_THUC_HIEN') OR NOT EXISTS (
            SELECT 1 FROM TaiKhoan WHERE MaNhanVien=NEW.MaNhanVien AND TrangThai='HOAT_DONG')) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB14: Chien dich phai dang thuc hien va tai khoan phu trach phai hoat dong.';
        END IF;
    END IF;
    -- P2: chỉ nhận giá trị tổng khớp dữ liệu gốc. Khi được gọi từ AFTER trigger KhoanChi,
    -- dòng KhoanChi đã thay đổi nên SUM ở đây là tổng mới đúng của hoạt động này.
    IF NEW.TongChiPhiThucTe<>OLD.TongChiPhiThucTe AND NEW.TongChiPhiThucTe<>
        (SELECT COALESCE(SUM(k.SoTien),0) FROM KhoanChi k WHERE k.MaHoatDong=NEW.MaHoatDong) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_TONGCHI: TongChiPhiThucTe phai bang tong SoTien cua khoan chi; khong ghi tay.';
    END IF;
END$$

DROP TRIGGER trg_KhoanChi_bi$$
CREATE TRIGGER trg_KhoanChi_bi BEFORE INSERT ON KhoanChi
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
    CALL sp_P1_KiemTraNguoiGhi(NEW.MaNguoiGhiNhan, NEW.MaHoatDong);
    -- P2: không thêm khoản chi vào hoạt động/chiến dịch đã kết thúc.
    CALL sp_P2_KiemTraHoatDongMo(NEW.MaHoatDong,
        'RB16: Khong them/chuyen khoan chi vao hoat dong/chien dich da ket thuc.');
END$$

DROP TRIGGER trg_KhoanChi_bu$$
CREATE TRIGGER trg_KhoanChi_bu BEFORE UPDATE ON KhoanChi
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
    IF NOT (NEW.MaKhoanChi <=> OLD.MaKhoanChi) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1_KEY: Khong doi khoa dinh danh; tao ban ghi moi neu can.'; END IF;
    CALL sp_P1_KiemTraNguoiGhi(NEW.MaNguoiGhiNhan, NEW.MaHoatDong);
    -- P2: RB15 chỉ xét NEW, nên đổi đồng thời MaNguoiGhiNhan sẽ qua được RB15. Nguồn (OLD)
    -- được kiểm tra riêng để khoản chi lịch sử không bị sửa hoặc chuyển ra ngoài rồi xóa.
    CALL sp_P2_KiemTraHoatDongMo(OLD.MaHoatDong,
        'RB16: Khong sua/chuyen khoan chi cua hoat dong/chien dich da ket thuc.');
    CALL sp_P2_KiemTraHoatDongMo(NEW.MaHoatDong,
        'RB16: Khong them/chuyen khoan chi vao hoat dong/chien dich da ket thuc.');
END$$

-- ---------------------------------------------------------------------
-- D. Trigger duy trì tổng thực chi
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_KhoanChi_ai_tong AFTER INSERT ON KhoanChi
FOR EACH ROW PRECEDES trg_KhoanChi_ai
BEGIN
    UPDATE HoatDongTrienKhai SET TongChiPhiThucTe=TongChiPhiThucTe+NEW.SoTien
    WHERE MaHoatDong=NEW.MaHoatDong;
END$$

CREATE TRIGGER trg_KhoanChi_au_tong AFTER UPDATE ON KhoanChi
FOR EACH ROW PRECEDES trg_KhoanChi_au
BEGIN
    IF NEW.MaHoatDong=OLD.MaHoatDong THEN
        IF NEW.SoTien<>OLD.SoTien THEN
            UPDATE HoatDongTrienKhai SET TongChiPhiThucTe=TongChiPhiThucTe+(NEW.SoTien-OLD.SoTien)
            WHERE MaHoatDong=NEW.MaHoatDong;
        END IF;
    ELSE
        UPDATE HoatDongTrienKhai SET TongChiPhiThucTe=TongChiPhiThucTe-OLD.SoTien
        WHERE MaHoatDong=OLD.MaHoatDong;
        UPDATE HoatDongTrienKhai SET TongChiPhiThucTe=TongChiPhiThucTe+NEW.SoTien
        WHERE MaHoatDong=NEW.MaHoatDong;
    END IF;
END$$

CREATE TRIGGER trg_KhoanChi_ad_tong AFTER DELETE ON KhoanChi
FOR EACH ROW PRECEDES trg_KhoanChi_ad
BEGIN
    UPDATE HoatDongTrienKhai SET TongChiPhiThucTe=TongChiPhiThucTe-OLD.SoTien
    WHERE MaHoatDong=OLD.MaHoatDong;
END$$

DELIMITER ;

-- ---------------------------------------------------------------------
-- E. Khởi tạo tổng từ dữ liệu gốc (sau khi trigger đã có, để không sót ghi đồng thời)
-- ---------------------------------------------------------------------
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;
UPDATE HoatDongTrienKhai h
LEFT JOIN (SELECT MaHoatDong, SUM(SoTien) AS Tong FROM KhoanChi GROUP BY MaHoatDong) k
    ON k.MaHoatDong=h.MaHoatDong
SET h.TongChiPhiThucTe=COALESCE(k.Tong,0);
COMMIT;
DO RELEASE_LOCK('marketing_btl.integrity');

-- Đối soát ngay sau khởi tạo: mong đợi 0 dòng.
SELECT h.MaHoatDong, h.TongChiPhiThucTe AS CotLuu, v.TongChiPhiThucTe AS TuKhoanChi
FROM HoatDongTrienKhai h JOIN v_ChiPhiHoatDong v USING(MaHoatDong)
WHERE h.TongChiPhiThucTe<>v.TongChiPhiThucTe;

-- =====================================================================
-- F. MINH HỌA (chạy từng ca trong phiên quản trị khi báo cáo)
--    Mỗi ca: đặt isolation trước giao dịch, kết thúc bằng ROLLBACK, rồi giải phóng khóa:
--      SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED; START TRANSACTION;
--      ... ;
--      ROLLBACK; DO RELEASE_LOCK('marketing_btl.integrity');
--    Seed: CD01 trần 20.000.000; HD01 cấp 2.000.000, HD02 cấp 3.000.000 (tổng 5.000.000).
-- =====================================================================
--
-- F1. Khởi tạo seed
--   SELECT MaHoatDong, NganSachDuocCap, TongChiPhiThucTe FROM HoatDongTrienKhai ORDER BY MaHoatDong;
--   -- HD01 = 3000000 (KC01 2.500.000 + KC11 500.000); HD02 = 3500000;
--   -- HD03 700000, HD04 1800000, HD05 1200000, HD06 2200000, HD07 600000,
--   -- HD08 900000, HD09 800000, HD10 1500000. Hoạt động không có khoản chi => 0.
--
-- F2. RB07 dưới trần / bằng trần: OK
--   UPDATE HoatDongTrienKhai SET NganSachDuocCap=10000000 WHERE MaHoatDong='HD01'; -- tổng 13.000.000
--   UPDATE HoatDongTrienKhai SET NganSachDuocCap=17000000 WHERE MaHoatDong='HD01'; -- tổng 20.000.000 = trần
--
-- F3. RB07 vượt trần do sửa ngân sách hoạt động: lỗi RB07
--   UPDATE HoatDongTrienKhai SET NganSachDuocCap=17000001 WHERE MaHoatDong='HD01';
--
-- F4. RB07 vượt trần do thêm hoạt động (qua workflow): lỗi RB07, không còn dòng TEST_HD
--   (gọi ngoài giao dịch, workflow tự rollback)
--   CALL sp_P1_TaoHoatDong('{"MaHoatDong":"TEST_HD","TenHoatDong":"Vuot tran","MoTa":null,
--     "NgayBatDau":"2026-11-05","NgayKetThucDuKien":"2026-11-20","NganSachDuocCap":15000001,
--     "MaKenh":"K_FACEBOOK","MaChienDich":"CD01","MaNhanVien":"NV04"}',
--     '{"MaTKMangXaHoi":"MXH01","NoiDungBaiDang":"Test","DinhDang":"HINH_ANH",
--       "DuongDanTaiNguyen":null,"DuongDanBaiDang":null}','[]');
--   SELECT COUNT(*) FROM HoatDongTrienKhai WHERE MaHoatDong='TEST_HD'; -- 0
--
-- F5. RB07 vượt trần do chuyển hoạt động sang chiến dịch khác: lỗi RB07
--   INSERT INTO PhanCong VALUES ('NV05','CD01','Ho tro','2026-11-01','2026-11-30'); -- để RB05 không chặn trước
--   UPDATE HoatDongTrienKhai SET NganSachDuocCap=15000001 WHERE MaHoatDong='HD01';  -- CD01: 18.000.001 (OK)
--   UPDATE HoatDongTrienKhai SET MaChienDich='CD01' WHERE MaHoatDong='HD03';        -- +2.000.000 => RB07
--
-- F6. Giảm trần chiến dịch: bằng tổng OK, dưới tổng lỗi RB07
--   UPDATE ChienDich SET NganSachDuocDuyet=5000000 WHERE MaChienDich='CD01'; -- OK
--   UPDATE ChienDich SET NganSachDuocDuyet=4999999 WHERE MaChienDich='CD01'; -- RB07
--
-- F7. Thực chi vượt ngân sách vẫn chấp nhận; tổng cộng đúng
--   INSERT INTO KhoanChi(MaKhoanChi,MaHoatDong,MaNguoiGhiNhan,NgayPhatSinh,SoTien,NoiDungChi)
--     VALUES ('KC_T1','HD01','NV04','2026-11-07',9000000,'Quang cao bo sung');
--   SELECT TongChiPhiThucTe, NganSachDuocCap FROM HoatDongTrienKhai WHERE MaHoatDong='HD01'; -- 12000000 | 2000000
--
-- F8. Sửa tiền cùng hoạt động: HD01 3.000.000 -> 3.100.000
--   UPDATE KhoanChi SET SoTien=2600000 WHERE MaKhoanChi='KC01';
--   SELECT TongChiPhiThucTe FROM HoatDongTrienKhai WHERE MaHoatDong='HD01'; -- 3100000
--
-- F9. Chỉ đổi nội dung/chứng từ: tổng giữ nguyên
--   UPDATE KhoanChi SET NoiDungChi='Sua mo ta', MaChungTu='CT-01B' WHERE MaKhoanChi='KC01';
--   SELECT TongChiPhiThucTe FROM HoatDongTrienKhai WHERE MaHoatDong='HD01'; -- 3000000
--
-- F10. Chuyển hoạt động đồng thời đổi tiền: KC11 (500.000) HD01 -> HD02 với 800.000
--   UPDATE KhoanChi SET MaHoatDong='HD02', SoTien=800000 WHERE MaKhoanChi='KC11';
--   SELECT MaHoatDong, TongChiPhiThucTe FROM HoatDongTrienKhai WHERE MaHoatDong IN ('HD01','HD02');
--   -- HD01 2500000 | HD02 4300000
--
-- F11. Xóa khoản chi của hoạt động đang mở: HD01 3.000.000 -> 2.500.000
--   DELETE FROM KhoanChi WHERE MaKhoanChi='KC11';
--   SELECT TongChiPhiThucTe FROM HoatDongTrienKhai WHERE MaHoatDong='HD01'; -- 2500000
--
-- F12. Rollback trả cả khoản chi và cột tổng
--   (sau F7 trong cùng giao dịch) ROLLBACK;
--   SELECT COUNT(*) FROM KhoanChi WHERE MaKhoanChi='KC_T1';                      -- 0
--   SELECT TongChiPhiThucTe FROM HoatDongTrienKhai WHERE MaHoatDong='HD01';      -- 3000000
--
-- F13. Câu lệnh nhiều dòng có lỗi: dòng KC11 vi phạm ck_chi_sotien, cả câu bị hủy, tổng không lệch
--   UPDATE KhoanChi SET SoTien=CASE MaKhoanChi WHEN 'KC01' THEN 2600000 ELSE 0 END
--   WHERE MaKhoanChi IN ('KC01','KC11');                                          -- lỗi ck_chi_sotien
--   SELECT SoTien FROM KhoanChi WHERE MaKhoanChi='KC01';                           -- 2500000
--   SELECT TongChiPhiThucTe FROM HoatDongTrienKhai WHERE MaHoatDong='HD01';       -- 3000000
--
-- F14. KC05 (HD05/CD03 đã hoàn thành) chuyển sang HD01, kể cả đổi người ghi để lách RB15: lỗi RB16
--   UPDATE KhoanChi SET MaHoatDong='HD01', MaNguoiGhiNhan='NV04' WHERE MaKhoanChi='KC05';
--   -- 'RB16: Khong sua/chuyen khoan chi cua hoat dong/chien dich da ket thuc.'
--   UPDATE KhoanChi SET SoTien=1300000 WHERE MaKhoanChi='KC05';                   -- RB16 (khóa sửa)
--   DELETE FROM KhoanChi WHERE MaKhoanChi='KC05';                                 -- RB16 (phần 1)
--
-- F15. Thêm/chuyển vào hoạt động đã kết thúc: lỗi RB16
--   INSERT INTO KhoanChi(MaKhoanChi,MaHoatDong,MaNguoiGhiNhan,NgayPhatSinh,SoTien,NoiDungChi)
--     VALUES ('KC_T2','HD05','NV06','2026-11-07',100000,'Sau khoa so');
--   UPDATE KhoanChi SET MaHoatDong='HD05', MaNguoiGhiNhan='NV06' WHERE MaKhoanChi='KC01';
--   -- 'RB16: Khong them/chuyen khoan chi vao hoat dong/chien dich da ket thuc.'
--
-- F16. Ghi tay cột tổng sai: lỗi P2_TONGCHI
--   UPDATE HoatDongTrienKhai SET TongChiPhiThucTe=0 WHERE MaHoatDong='HD01';
--
-- F17. Đối soát cột tổng với SUM dữ liệu gốc (chạy sau bất kỳ ca nào): 0 dòng
--   SELECT h.MaHoatDong, h.TongChiPhiThucTe, COALESCE(SUM(k.SoTien),0) AS TongGoc
--   FROM HoatDongTrienKhai h LEFT JOIN KhoanChi k USING(MaHoatDong)
--   GROUP BY h.MaHoatDong, h.TongChiPhiThucTe
--   HAVING h.TongChiPhiThucTe<>TongGoc;
