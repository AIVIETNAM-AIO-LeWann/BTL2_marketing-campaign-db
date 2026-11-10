USE marketing_btl;
SET NAMES utf8mb4;
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,ONLY_FULL_GROUP_BY,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
DELIMITER $$

-- A connection-level lock serializes write workflows for this small assignment.
-- Top-level P1 creation procedures release it after COMMIT/ROLLBACK.
-- A maintenance connection doing direct DML must release it or disconnect.
CREATE PROCEDURE sp_P1_KhoaGhi()
SQL SECURITY DEFINER
BEGIN
    DECLARE v_ok INT;
    IF COALESCE(IS_USED_LOCK('marketing_btl.integrity'),0) <> CONNECTION_ID() THEN
        SELECT GET_LOCK('marketing_btl.integrity',10) INTO v_ok;
        IF COALESCE(v_ok,0) <> 1 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'P1_LOCK: Khong lay duoc khoa ghi; thu lai giao dich.';
        END IF;
    END IF;
END$$

-- Only cross-row/table invariants here; local domains stay in CREATE TABLE.
-- Rechecking the whole small dataset also covers changes on the reverse side
-- (e.g. shortening campaign dates or changing an account's brand).
CREATE PROCEDURE sp_P1_KiemTraToanVen()
SQL SECURITY DEFINER
BEGIN
    DECLARE v_cycle INT DEFAULT 0;
    IF EXISTS (SELECT 1 FROM NhanVien n LEFT JOIN TaiKhoan t ON t.MaNhanVien=n.MaNhanVien WHERE t.MaTK IS NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='EER_ACCOUNT: Moi nhan vien phai co dung mot tai khoan.';
    END IF;

    WITH RECURSIVE Chuoi AS (
        SELECT MaNhanVien AS Goc, MaNguoiGiamSat AS Tiep, 1 AS DoSau FROM NhanVien
        UNION ALL
        SELECT c.Goc, n.MaNguoiGiamSat, c.DoSau+1
        FROM Chuoi c JOIN NhanVien n ON n.MaNhanVien=c.Tiep
        WHERE c.Tiep<>c.Goc AND c.DoSau <= (SELECT COUNT(*) FROM NhanVien)
    ) SELECT COUNT(*) INTO v_cycle FROM Chuoi WHERE Goc=Tiep;
    IF v_cycle>0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB06: Quan he giam sat khong duoc tu giam sat hoac tao chu trinh.';
    END IF;

    IF EXISTS (SELECT 1 FROM HoatDongTrienKhai h JOIN ChienDich c USING(MaChienDich)
        WHERE h.NgayBatDau<c.NgayBatDau OR h.NgayKetThucDuKien>c.NgayKetThucDuKien) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB02: Thoi gian hoat dong phai nam trong thoi gian chien dich.';
    END IF;
    IF EXISTS (SELECT 1 FROM PhanCong p JOIN ChienDich c USING(MaChienDich)
        WHERE p.NgayBatDauThamGia<c.NgayBatDau OR p.NgayKetThucThamGia>c.NgayKetThucDuKien) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB03: Thoi gian phan cong phai nam trong thoi gian chien dich.';
    END IF;
    IF EXISTS (SELECT 1 FROM ChienDich c
        LEFT JOIN PhanCong p ON p.MaChienDich=c.MaChienDich AND p.MaNhanVien=c.MaNhanVien
        JOIN TaiKhoan t ON t.MaNhanVien=c.MaNhanVien
        WHERE p.MaNhanVien IS NULL OR t.VaiTro<>'QUAN_LY_MARKETING'
            OR p.NgayBatDauThamGia>c.NgayBatDau OR p.NgayKetThucThamGia<c.NgayKetThucDuKien) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB04: Nguoi chinh phai la quan ly va duoc phan cong suot chien dich.';
    END IF;
    IF EXISTS (SELECT 1 FROM HoatDongTrienKhai h
        LEFT JOIN PhanCong p ON p.MaChienDich=h.MaChienDich AND p.MaNhanVien=h.MaNhanVien
        WHERE p.MaNhanVien IS NULL OR p.NgayBatDauThamGia>h.NgayBatDau OR p.NgayKetThucThamGia<h.NgayKetThucDuKien) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB05: Nguoi phu trach phai duoc phan cong bao phu thoi gian hoat dong.';
    END IF;
    IF EXISTS (SELECT 1 FROM ChienDich c WHERE
        (SELECT COALESCE(SUM(h.NganSachDuocCap),0) FROM HoatDongTrienKhai h WHERE h.MaChienDich=c.MaChienDich)>c.NganSachDuocDuyet) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB07: Tong ngan sach cap vuot ngan sach duyet cua chien dich.';
    END IF;

    IF EXISTS (SELECT 1 FROM HoatDongTrienKhai h JOIN KenhMarketing k USING(MaKenh)
        LEFT JOIN HoatDongEmail e USING(MaHoatDong) LEFT JOIN HoatDongMangXaHoi m USING(MaHoatDong)
        WHERE ((e.MaHoatDong IS NOT NULL)+(m.MaHoatDong IS NOT NULL))<>1
          OR (e.MaHoatDong IS NOT NULL AND k.NhomKenh<>'EMAIL')
          OR (m.MaHoatDong IS NOT NULL AND k.NhomKenh<>'MANG_XA_HOI')) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='EER_TOTAL_RB09: Hoat dong phai thuoc dung mot lop con va dung nhom kenh.';
    END IF;
    IF EXISTS (SELECT 1 FROM HoatDongEmail e WHERE NOT EXISTS
        (SELECT 1 FROM HoatDongEmail_DanhSach d WHERE d.MaHoatDong=e.MaHoatDong)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='EER_EMAIL_LIST: Moi hoat dong email phai co it nhat mot danh sach.';
    END IF;
    IF EXISTS (SELECT 1 FROM TaiKhoanMangXaHoi t JOIN KenhMarketing k USING(MaKenh) WHERE k.NhomKenh<>'MANG_XA_HOI')
       OR EXISTS (SELECT 1 FROM HoatDongMangXaHoi m JOIN HoatDongTrienKhai h USING(MaHoatDong)
           JOIN TaiKhoanMangXaHoi t USING(MaTKMangXaHoi) WHERE h.MaKenh<>t.MaKenh) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB09: Tai khoan mang xa hoi phai thuoc kenh MXH va trung kenh hoat dong.';
    END IF;
    IF EXISTS (SELECT 1 FROM HoatDongEmail_DanhSach x JOIN DanhSachNhanEmail d USING(MaDanhSach)
        JOIN HoatDongTrienKhai h USING(MaHoatDong) JOIN ChienDich c USING(MaChienDich) WHERE d.MaThuongHieu<>c.MaThuongHieu)
       OR EXISTS (SELECT 1 FROM HoatDongMangXaHoi m JOIN TaiKhoanMangXaHoi t USING(MaTKMangXaHoi)
        JOIN HoatDongTrienKhai h USING(MaHoatDong) JOIN ChienDich c USING(MaChienDich) WHERE t.MaThuongHieu<>c.MaThuongHieu) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB10: Danh sach/tai khoan phai cung thuong hieu voi chien dich su dung.';
    END IF;
    IF EXISTS (SELECT 1 FROM KetQuaNgay q JOIN HoatDongTrienKhai h USING(MaHoatDong)
        WHERE q.NgayGhiNhan<h.NgayBatDau OR q.NgayGhiNhan>h.NgayKetThucDuKien) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB11: Ngay ket qua phai nam trong khoang thoi gian hoat dong.';
    END IF;
    IF EXISTS (SELECT 1 FROM ChienDich c WHERE c.TrangThai NOT IN ('NHAP','HUY')
        AND NOT EXISTS (SELECT 1 FROM HoatDongTrienKhai h WHERE h.MaChienDich=c.MaChienDich)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB13: Chien dich da duyet phai co it nhat mot hoat dong.';
    END IF;
    IF EXISTS (SELECT 1 FROM HoatDongTrienKhai h JOIN HoatDongEmail e USING(MaHoatDong)
        WHERE h.TrangThai NOT IN ('CHUA_BAT_DAU','HUY') AND (
            COALESCE(CHAR_LENGTH(TRIM(e.TieuDeThu)),0)=0 OR COALESCE(CHAR_LENGTH(TRIM(e.DiaChiGui)),0)=0
            OR COALESCE(CHAR_LENGTH(TRIM(e.TenNguoiGui)),0)=0 OR COALESCE(CHAR_LENGTH(TRIM(e.DuongDanNoiDung)),0)=0))
       OR EXISTS (SELECT 1 FROM HoatDongTrienKhai h JOIN HoatDongMangXaHoi m USING(MaHoatDong)
        WHERE h.TrangThai NOT IN ('CHUA_BAT_DAU','HUY') AND (
            COALESCE(CHAR_LENGTH(TRIM(m.NoiDungBaiDang)),0)=0 OR m.DinhDang IS NULL)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB14: Phai hoan thien noi dung truoc khi bat dau hoat dong.';
    END IF;
    IF EXISTS (SELECT 1 FROM KhoanChi k JOIN HoatDongTrienKhai h USING(MaHoatDong)
        WHERE NOT EXISTS (SELECT 1 FROM PhanCong p WHERE p.MaChienDich=h.MaChienDich AND p.MaNhanVien=k.MaNguoiGhiNhan))
       OR EXISTS (SELECT 1 FROM KetQuaNgay q JOIN HoatDongTrienKhai h USING(MaHoatDong)
        WHERE NOT EXISTS (SELECT 1 FROM PhanCong p WHERE p.MaChienDich=h.MaChienDich AND p.MaNhanVien=q.MaNguoiCapNhat)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB15: Nguoi ghi chi/ket qua phai duoc phan cong vao chien dich.';
    END IF;
    IF EXISTS (SELECT 1 FROM ChienDich c JOIN HoatDongTrienKhai h USING(MaChienDich)
        WHERE c.TrangThai='HOAN_THANH' AND h.TrangThai NOT IN ('HOAN_THANH','HUY')) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB16: Chi hoan thanh chien dich khi cac hoat dong da hoan thanh/huy.';
    END IF;
END$$

-- Row-local checks for cross-table permissions at the time of the action.
CREATE PROCEDURE sp_P1_KiemTraNguoiGhi(IN p_nv VARCHAR(20), IN p_hd VARCHAR(20))
SQL SECURITY DEFINER
BEGIN
    IF NOT EXISTS (SELECT 1 FROM TaiKhoan t JOIN PhanCong p USING(MaNhanVien)
        JOIN HoatDongTrienKhai h ON h.MaChienDich=p.MaChienDich
        WHERE t.MaNhanVien=p_nv AND h.MaHoatDong=p_hd AND t.TrangThai='HOAT_DONG') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB15: Nguoi thao tac phai duoc phan cong va co tai khoan dang hoat dong.';
    END IF;
END$$

DELIMITER ;
-- Row triggers follow below. Generated once during development, committed as SQL.

DELIMITER $$
CREATE TRIGGER trg_NhanVien_bi BEFORE INSERT ON NhanVien
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
END$$
CREATE TRIGGER trg_NhanVien_ai AFTER INSERT ON NhanVien
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_NhanVien_bu BEFORE UPDATE ON NhanVien
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
    IF NOT (NEW.MaNhanVien <=> OLD.MaNhanVien) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1_KEY: Khong doi khoa dinh danh; tao ban ghi moi neu can.'; END IF;
END$$
CREATE TRIGGER trg_NhanVien_au AFTER UPDATE ON NhanVien
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_NhanVien_bd BEFORE DELETE ON NhanVien
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
END$$
CREATE TRIGGER trg_NhanVien_ad AFTER DELETE ON NhanVien
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_TaiKhoan_bi BEFORE INSERT ON TaiKhoan
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
END$$
CREATE TRIGGER trg_TaiKhoan_ai AFTER INSERT ON TaiKhoan
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_TaiKhoan_bu BEFORE UPDATE ON TaiKhoan
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
    IF NOT (NEW.MaTK <=> OLD.MaTK) OR NOT (NEW.MaNhanVien <=> OLD.MaNhanVien) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1_KEY: Khong doi khoa dinh danh; tao ban ghi moi neu can.'; END IF;
END$$
CREATE TRIGGER trg_TaiKhoan_au AFTER UPDATE ON TaiKhoan
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_TaiKhoan_bd BEFORE DELETE ON TaiKhoan
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
END$$
CREATE TRIGGER trg_TaiKhoan_ad AFTER DELETE ON TaiKhoan
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_SoDienThoaiNhanVien_bi BEFORE INSERT ON SoDienThoaiNhanVien
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
END$$
CREATE TRIGGER trg_SoDienThoaiNhanVien_ai AFTER INSERT ON SoDienThoaiNhanVien
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_SoDienThoaiNhanVien_bu BEFORE UPDATE ON SoDienThoaiNhanVien
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
    IF NOT (NEW.MaNhanVien <=> OLD.MaNhanVien) OR NOT (NEW.SoDienThoai <=> OLD.SoDienThoai) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1_KEY: Khong doi khoa dinh danh; tao ban ghi moi neu can.'; END IF;
END$$
CREATE TRIGGER trg_SoDienThoaiNhanVien_au AFTER UPDATE ON SoDienThoaiNhanVien
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_SoDienThoaiNhanVien_bd BEFORE DELETE ON SoDienThoaiNhanVien
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
END$$
CREATE TRIGGER trg_SoDienThoaiNhanVien_ad AFTER DELETE ON SoDienThoaiNhanVien
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_ThuongHieu_bi BEFORE INSERT ON ThuongHieu
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
END$$
CREATE TRIGGER trg_ThuongHieu_ai AFTER INSERT ON ThuongHieu
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_ThuongHieu_bu BEFORE UPDATE ON ThuongHieu
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
    IF NOT (NEW.MaThuongHieu <=> OLD.MaThuongHieu) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1_KEY: Khong doi khoa dinh danh; tao ban ghi moi neu can.'; END IF;
END$$
CREATE TRIGGER trg_ThuongHieu_au AFTER UPDATE ON ThuongHieu
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_ThuongHieu_bd BEFORE DELETE ON ThuongHieu
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
END$$
CREATE TRIGGER trg_ThuongHieu_ad AFTER DELETE ON ThuongHieu
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_KenhMarketing_bi BEFORE INSERT ON KenhMarketing
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
END$$
CREATE TRIGGER trg_KenhMarketing_ai AFTER INSERT ON KenhMarketing
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_KenhMarketing_bu BEFORE UPDATE ON KenhMarketing
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
    IF NOT (NEW.MaKenh <=> OLD.MaKenh) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1_KEY: Khong doi khoa dinh danh; tao ban ghi moi neu can.'; END IF;
END$$
CREATE TRIGGER trg_KenhMarketing_au AFTER UPDATE ON KenhMarketing
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_KenhMarketing_bd BEFORE DELETE ON KenhMarketing
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
END$$
CREATE TRIGGER trg_KenhMarketing_ad AFTER DELETE ON KenhMarketing
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_ChienDich_bi BEFORE INSERT ON ChienDich
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
    IF NEW.TrangThai<>'NHAP' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB13: Chien dich moi phai o trang thai NHAP.'; END IF;
END$$
CREATE TRIGGER trg_ChienDich_ai AFTER INSERT ON ChienDich
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_ChienDich_bu BEFORE UPDATE ON ChienDich
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
    IF NOT (NEW.MaChienDich <=> OLD.MaChienDich) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1_KEY: Khong doi khoa dinh danh; tao ban ghi moi neu can.'; END IF;
    IF NEW.TrangThai<>OLD.TrangThai THEN
        IF OLD.TrangThai IN ('HOAN_THANH','HUY') THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB16: Khong mo lai chien dich da ket thuc.';
        END IF;
        IF (OLD.TrangThai='NHAP' AND NEW.TrangThai NOT IN ('DA_DUYET','HUY'))
            OR (OLD.TrangThai<>'NHAP' AND NEW.TrangThai='NHAP') THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB13: Chien dich phai qua buoc duyet truoc khi trien khai.';
        END IF;
        IF NEW.TrangThai='DA_DUYET' AND NOT EXISTS (
            SELECT 1 FROM TaiKhoan WHERE MaNhanVien=NEW.MaNhanVien AND TrangThai='HOAT_DONG') THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB13: Tai khoan nguoi chinh phai hoat dong khi duyet.';
        END IF;
    END IF;
END$$
CREATE TRIGGER trg_ChienDich_au AFTER UPDATE ON ChienDich
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_ChienDich_bd BEFORE DELETE ON ChienDich
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
    IF OLD.TrangThai IN ('HOAN_THANH','HUY') THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB16: Khong xoa du lieu lich su cua chien dich/hoat dong da ket thuc.'; END IF;
END$$
CREATE TRIGGER trg_ChienDich_ad AFTER DELETE ON ChienDich
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_PhanCong_bi BEFORE INSERT ON PhanCong
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
END$$
CREATE TRIGGER trg_PhanCong_ai AFTER INSERT ON PhanCong
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_PhanCong_bu BEFORE UPDATE ON PhanCong
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
    IF NOT (NEW.MaNhanVien <=> OLD.MaNhanVien) OR NOT (NEW.MaChienDich <=> OLD.MaChienDich) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1_KEY: Khong doi khoa dinh danh; tao ban ghi moi neu can.'; END IF;
END$$
CREATE TRIGGER trg_PhanCong_au AFTER UPDATE ON PhanCong
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_PhanCong_bd BEFORE DELETE ON PhanCong
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
    IF EXISTS (SELECT 1 FROM ChienDich c WHERE c.MaChienDich=OLD.MaChienDich AND c.TrangThai IN ('HOAN_THANH','HUY')) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB16: Khong xoa du lieu lich su cua chien dich/hoat dong da ket thuc.'; END IF;
END$$
CREATE TRIGGER trg_PhanCong_ad AFTER DELETE ON PhanCong
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_HoatDongTrienKhai_bi BEFORE INSERT ON HoatDongTrienKhai
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
    IF NEW.TrangThai<>'CHUA_BAT_DAU' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB14: Hoat dong moi phai o trang thai CHUA_BAT_DAU.'; END IF;
END$$
CREATE TRIGGER trg_HoatDongTrienKhai_ai AFTER INSERT ON HoatDongTrienKhai
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
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
END$$
CREATE TRIGGER trg_HoatDongTrienKhai_au AFTER UPDATE ON HoatDongTrienKhai
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_HoatDongTrienKhai_bd BEFORE DELETE ON HoatDongTrienKhai
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
    IF EXISTS (SELECT 1 FROM HoatDongTrienKhai h JOIN ChienDich c USING(MaChienDich) WHERE h.MaHoatDong=OLD.MaHoatDong AND (h.TrangThai IN ('HOAN_THANH','HUY') OR c.TrangThai IN ('HOAN_THANH','HUY'))) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB16: Khong xoa du lieu lich su cua chien dich/hoat dong da ket thuc.'; END IF;
END$$
CREATE TRIGGER trg_HoatDongTrienKhai_ad AFTER DELETE ON HoatDongTrienKhai
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_HoatDongEmail_bi BEFORE INSERT ON HoatDongEmail
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
END$$
CREATE TRIGGER trg_HoatDongEmail_ai AFTER INSERT ON HoatDongEmail
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_HoatDongEmail_bu BEFORE UPDATE ON HoatDongEmail
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
    IF NOT (NEW.MaHoatDong <=> OLD.MaHoatDong) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1_KEY: Khong doi khoa dinh danh; tao ban ghi moi neu can.'; END IF;
    IF EXISTS (SELECT 1 FROM HoatDongTrienKhai h WHERE h.MaHoatDong=OLD.MaHoatDong AND h.TrangThai<>'CHUA_BAT_DAU') AND ((OLD.TieuDeThu IS NOT NULL AND COALESCE(CHAR_LENGTH(TRIM(NEW.TieuDeThu)),0)=0) OR (OLD.DiaChiGui IS NOT NULL AND COALESCE(CHAR_LENGTH(TRIM(NEW.DiaChiGui)),0)=0) OR (OLD.TenNguoiGui IS NOT NULL AND COALESCE(CHAR_LENGTH(TRIM(NEW.TenNguoiGui)),0)=0) OR (OLD.DuongDanNoiDung IS NOT NULL AND COALESCE(CHAR_LENGTH(TRIM(NEW.DuongDanNoiDung)),0)=0)) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB14: Khong xoa noi dung bat buoc sau khi hoat dong bat dau/ket thuc.'; END IF;
END$$
CREATE TRIGGER trg_HoatDongEmail_au AFTER UPDATE ON HoatDongEmail
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_HoatDongEmail_bd BEFORE DELETE ON HoatDongEmail
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
END$$
CREATE TRIGGER trg_HoatDongEmail_ad AFTER DELETE ON HoatDongEmail
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_DanhSachNhanEmail_bi BEFORE INSERT ON DanhSachNhanEmail
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
END$$
CREATE TRIGGER trg_DanhSachNhanEmail_ai AFTER INSERT ON DanhSachNhanEmail
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_DanhSachNhanEmail_bu BEFORE UPDATE ON DanhSachNhanEmail
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
    IF NOT (NEW.MaDanhSach <=> OLD.MaDanhSach) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1_KEY: Khong doi khoa dinh danh; tao ban ghi moi neu can.'; END IF;
END$$
CREATE TRIGGER trg_DanhSachNhanEmail_au AFTER UPDATE ON DanhSachNhanEmail
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_DanhSachNhanEmail_bd BEFORE DELETE ON DanhSachNhanEmail
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
END$$
CREATE TRIGGER trg_DanhSachNhanEmail_ad AFTER DELETE ON DanhSachNhanEmail
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_HoatDongEmail_DanhSach_bi BEFORE INSERT ON HoatDongEmail_DanhSach
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
END$$
CREATE TRIGGER trg_HoatDongEmail_DanhSach_ai AFTER INSERT ON HoatDongEmail_DanhSach
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_HoatDongEmail_DanhSach_bu BEFORE UPDATE ON HoatDongEmail_DanhSach
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
    IF NOT (NEW.MaHoatDong <=> OLD.MaHoatDong) OR NOT (NEW.MaDanhSach <=> OLD.MaDanhSach) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1_KEY: Khong doi khoa dinh danh; tao ban ghi moi neu can.'; END IF;
END$$
CREATE TRIGGER trg_HoatDongEmail_DanhSach_au AFTER UPDATE ON HoatDongEmail_DanhSach
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_HoatDongEmail_DanhSach_bd BEFORE DELETE ON HoatDongEmail_DanhSach
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
END$$
CREATE TRIGGER trg_HoatDongEmail_DanhSach_ad AFTER DELETE ON HoatDongEmail_DanhSach
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_TaiKhoanMangXaHoi_bi BEFORE INSERT ON TaiKhoanMangXaHoi
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
END$$
CREATE TRIGGER trg_TaiKhoanMangXaHoi_ai AFTER INSERT ON TaiKhoanMangXaHoi
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_TaiKhoanMangXaHoi_bu BEFORE UPDATE ON TaiKhoanMangXaHoi
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
    IF NOT (NEW.MaTKMangXaHoi <=> OLD.MaTKMangXaHoi) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1_KEY: Khong doi khoa dinh danh; tao ban ghi moi neu can.'; END IF;
END$$
CREATE TRIGGER trg_TaiKhoanMangXaHoi_au AFTER UPDATE ON TaiKhoanMangXaHoi
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_TaiKhoanMangXaHoi_bd BEFORE DELETE ON TaiKhoanMangXaHoi
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
END$$
CREATE TRIGGER trg_TaiKhoanMangXaHoi_ad AFTER DELETE ON TaiKhoanMangXaHoi
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_HoatDongMangXaHoi_bi BEFORE INSERT ON HoatDongMangXaHoi
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
END$$
CREATE TRIGGER trg_HoatDongMangXaHoi_ai AFTER INSERT ON HoatDongMangXaHoi
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_HoatDongMangXaHoi_bu BEFORE UPDATE ON HoatDongMangXaHoi
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
    IF NOT (NEW.MaHoatDong <=> OLD.MaHoatDong) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1_KEY: Khong doi khoa dinh danh; tao ban ghi moi neu can.'; END IF;
    IF EXISTS (SELECT 1 FROM HoatDongTrienKhai h WHERE h.MaHoatDong=OLD.MaHoatDong AND h.TrangThai<>'CHUA_BAT_DAU') AND ((OLD.NoiDungBaiDang IS NOT NULL AND COALESCE(CHAR_LENGTH(TRIM(NEW.NoiDungBaiDang)),0)=0) OR (OLD.DinhDang IS NOT NULL AND COALESCE(CHAR_LENGTH(TRIM(NEW.DinhDang)),0)=0)) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB14: Khong xoa noi dung bat buoc sau khi hoat dong bat dau/ket thuc.'; END IF;
END$$
CREATE TRIGGER trg_HoatDongMangXaHoi_au AFTER UPDATE ON HoatDongMangXaHoi
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_HoatDongMangXaHoi_bd BEFORE DELETE ON HoatDongMangXaHoi
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
END$$
CREATE TRIGGER trg_HoatDongMangXaHoi_ad AFTER DELETE ON HoatDongMangXaHoi
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_KhoanChi_bi BEFORE INSERT ON KhoanChi
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
    CALL sp_P1_KiemTraNguoiGhi(NEW.MaNguoiGhiNhan, NEW.MaHoatDong);
END$$
CREATE TRIGGER trg_KhoanChi_ai AFTER INSERT ON KhoanChi
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_KhoanChi_bu BEFORE UPDATE ON KhoanChi
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
    IF NOT (NEW.MaKhoanChi <=> OLD.MaKhoanChi) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1_KEY: Khong doi khoa dinh danh; tao ban ghi moi neu can.'; END IF;
    CALL sp_P1_KiemTraNguoiGhi(NEW.MaNguoiGhiNhan, NEW.MaHoatDong);
END$$
CREATE TRIGGER trg_KhoanChi_au AFTER UPDATE ON KhoanChi
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_KhoanChi_bd BEFORE DELETE ON KhoanChi
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
    IF EXISTS (SELECT 1 FROM HoatDongTrienKhai h JOIN ChienDich c USING(MaChienDich) WHERE h.MaHoatDong=OLD.MaHoatDong AND (h.TrangThai IN ('HOAN_THANH','HUY') OR c.TrangThai IN ('HOAN_THANH','HUY'))) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB16: Khong xoa du lieu lich su cua chien dich/hoat dong da ket thuc.'; END IF;
END$$
CREATE TRIGGER trg_KhoanChi_ad AFTER DELETE ON KhoanChi
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_KetQuaNgay_bi BEFORE INSERT ON KetQuaNgay
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
    CALL sp_P1_KiemTraNguoiGhi(NEW.MaNguoiCapNhat, NEW.MaHoatDong);
END$$
CREATE TRIGGER trg_KetQuaNgay_ai AFTER INSERT ON KetQuaNgay
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_KetQuaNgay_bu BEFORE UPDATE ON KetQuaNgay
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
    IF NOT (NEW.MaHoatDong <=> OLD.MaHoatDong) OR NOT (NEW.NgayGhiNhan <=> OLD.NgayGhiNhan) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1_KEY: Khong doi khoa dinh danh; tao ban ghi moi neu can.'; END IF;
    CALL sp_P1_KiemTraNguoiGhi(NEW.MaNguoiCapNhat, NEW.MaHoatDong);
END$$
CREATE TRIGGER trg_KetQuaNgay_au AFTER UPDATE ON KetQuaNgay
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
CREATE TRIGGER trg_KetQuaNgay_bd BEFORE DELETE ON KetQuaNgay
FOR EACH ROW
BEGIN
    CALL sp_P1_KhoaGhi();
    IF EXISTS (SELECT 1 FROM HoatDongTrienKhai h JOIN ChienDich c USING(MaChienDich) WHERE h.MaHoatDong=OLD.MaHoatDong AND (h.TrangThai IN ('HOAN_THANH','HUY') OR c.TrangThai IN ('HOAN_THANH','HUY'))) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB16: Khong xoa du lieu lich su cua chien dich/hoat dong da ket thuc.'; END IF;
END$$
CREATE TRIGGER trg_KetQuaNgay_ad AFTER DELETE ON KetQuaNgay
FOR EACH ROW
BEGIN
    IF COALESCE(@p1_internal,0)=0 THEN
        CALL sp_P1_KiemTraToanVen();
    END IF;
END$$
DELIMITER ;
