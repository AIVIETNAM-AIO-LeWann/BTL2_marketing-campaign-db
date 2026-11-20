-- =====================================================================
-- P2.1 — Procedure thêm / sửa / xóa KhoanChi
-- =====================================================================

USE marketing_btl;
SET NAMES utf8mb4;
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,ONLY_FULL_GROUP_BY,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

DROP PROCEDURE IF EXISTS sp_P2_ThemKhoanChi;
DROP PROCEDURE IF EXISTS sp_P2_SuaKhoanChi;
DROP PROCEDURE IF EXISTS sp_P2_XoaKhoanChi;

DELIMITER $$

CREATE PROCEDURE sp_P2_ThemKhoanChi(IN p_MaNguoiThaoTac VARCHAR(100), IN p_Chi JSON)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_started BOOLEAN DEFAULT FALSE;
    DECLARE v_acquired BOOLEAN DEFAULT FALSE;
    DECLARE v_ma VARCHAR(100);
    DECLARE v_hd VARCHAR(100);
    DECLARE v_ngay_txt TEXT;
    DECLARE v_ngay DATE;
    DECLARE v_kieu VARCHAR(30);
    DECLARE v_sotien DECIMAL(18,0);
    DECLARE v_big DECIMAL(65,0);
    DECLARE v_nd TEXT;
    DECLARE v_ct TEXT;
    DECLARE v_actor VARCHAR(20);
    DECLARE v_hd_db VARCHAR(20);
    DECLARE v_cd VARCHAR(20);
    DECLARE v_rows INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        IF v_started THEN ROLLBACK; END IF;
        IF v_acquired THEN DO RELEASE_LOCK('marketing_btl.integrity'); END IF;
        RESIGNAL;
    END;

    -- 1 Kiem tra input
    IF p_MaNguoiThaoTac IS NULL OR CHAR_LENGTH(TRIM(p_MaNguoiThaoTac))=0
       OR CHAR_LENGTH(p_MaNguoiThaoTac)>20 OR CHAR_LENGTH(p_MaNguoiThaoTac)<>CHAR_LENGTH(TRIM(p_MaNguoiThaoTac)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: Ma nguoi thao tac bat buoc, khong rong, toi da 20 ky tu, khong co dau cach dau/cuoi.';
    END IF;
    IF p_Chi IS NULL OR JSON_TYPE(p_Chi)<>'OBJECT' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: Can mot JSON object khoan chi.';
    END IF;
    IF NOT JSON_SCHEMA_VALID('{
  "type": "object",
  "required": ["MaKhoanChi","MaHoatDong","NgayPhatSinh","SoTien","NoiDungChi"],
  "properties": {
    "MaKhoanChi":   {"type": "string"},
    "MaHoatDong":   {"type": "string"},
    "NgayPhatSinh": {"type": "string"},
    "SoTien":       {"type": "number"},
    "NoiDungChi":   {"type": "string"},
    "MaChungTu":    {"type": ["string","null"]}
  },
  "additionalProperties": false
}', p_Chi) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: JSON khoan chi thieu truong bat buoc, sai kieu, co gia tri null hoac truong la.';
    END IF;

    SET v_ma = JSON_UNQUOTE(JSON_EXTRACT(p_Chi,'$.MaKhoanChi'));
    SET v_hd = JSON_UNQUOTE(JSON_EXTRACT(p_Chi,'$.MaHoatDong'));
    SET v_ngay_txt = JSON_UNQUOTE(JSON_EXTRACT(p_Chi,'$.NgayPhatSinh'));
    SET v_nd = JSON_UNQUOTE(JSON_EXTRACT(p_Chi,'$.NoiDungChi'));
    SET v_ct = IF(JSON_TYPE(JSON_EXTRACT(p_Chi,'$.MaChungTu'))='STRING', JSON_UNQUOTE(JSON_EXTRACT(p_Chi,'$.MaChungTu')), NULL);

    IF CHAR_LENGTH(TRIM(v_ma))=0 OR CHAR_LENGTH(v_ma)>20 OR CHAR_LENGTH(v_ma)<>CHAR_LENGTH(TRIM(v_ma)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: MaKhoanChi khong rong, toi da 20 ky tu, khong co dau cach dau/cuoi.';
    END IF;
    IF CHAR_LENGTH(TRIM(v_hd))=0 OR CHAR_LENGTH(v_hd)>20 OR CHAR_LENGTH(v_hd)<>CHAR_LENGTH(TRIM(v_hd)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: MaHoatDong khong rong, toi da 20 ky tu, khong co dau cach dau/cuoi.';
    END IF;
    IF CHAR_LENGTH(TRIM(v_nd))=0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: NoiDungChi khong duoc rong.';
    END IF;
    IF CHAR_LENGTH(v_nd)>500 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: NoiDungChi toi da 500 ky tu.';
    END IF;
    IF v_ct IS NOT NULL AND CHAR_LENGTH(TRIM(v_ct))=0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: MaChungTu khong duoc rong; dung null neu khong co chung tu.';
    END IF;
    IF CHAR_LENGTH(v_ct)>100 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: MaChungTu toi da 100 ky tu.';
    END IF;

    -- Keim tra ngay, tranh loi STR_TO_DATE.
    IF v_ngay_txt NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: NgayPhatSinh phai co dang YYYY-MM-DD.';
    END IF;
    IF CAST(SUBSTRING(v_ngay_txt,1,4) AS UNSIGNED) < 1000
       OR CAST(SUBSTRING(v_ngay_txt,6,2) AS UNSIGNED) NOT BETWEEN 1 AND 12
       OR CAST(SUBSTRING(v_ngay_txt,9,2) AS UNSIGNED) < 1
       OR CAST(SUBSTRING(v_ngay_txt,9,2) AS UNSIGNED) >
          DAY(LAST_DAY(STR_TO_DATE(CONCAT(SUBSTRING(v_ngay_txt,1,7),'-01'),'%Y-%m-%d'))) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: NgayPhatSinh khong phai ngay lich hop le (tu 1000-01-01).';
    END IF;
    SET v_ngay = STR_TO_DATE(v_ngay_txt,'%Y-%m-%d');

    SET v_kieu = JSON_TYPE(JSON_EXTRACT(p_Chi,'$.SoTien'));
    IF v_kieu IN ('DECIMAL','DOUBLE') THEN
        IF ABS(CAST(JSON_EXTRACT(p_Chi,'$.SoTien') AS DOUBLE)) >= 1e18 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: SoTien vuot mien DECIMAL(18,0) (toi da 999999999999999999).';
        END IF;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: SoTien phai la so nguyen VND, khong co phan le hoac dang mu.';
    END IF;
    IF v_kieu NOT IN ('INTEGER','UNSIGNED INTEGER') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: SoTien phai la so nguyen VND, khong co phan le hoac dang mu.';
    END IF;
    IF v_kieu = 'UNSIGNED INTEGER' THEN
        SET v_big = CAST(JSON_EXTRACT(p_Chi,'$.SoTien') AS UNSIGNED);
    ELSE
        SET v_big = CAST(JSON_EXTRACT(p_Chi,'$.SoTien') AS SIGNED);
    END IF;
    IF v_big <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: SoTien phai lon hon 0.';
    END IF;
    IF v_big > 999999999999999999 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: SoTien vuot mien DECIMAL(18,0) (toi da 999999999999999999).';
    END IF;
    SET v_sotien = v_big;

    -- 2 SET TRANSACTION tu choi neu da co giao dich mo 
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    SET v_acquired = COALESCE(IS_USED_LOCK('marketing_btl.integrity'),0) <> CONNECTION_ID();
    CALL sp_P1_KhoaGhi();
    START TRANSACTION;
    SET v_started = TRUE;

    -- 3 Kiem tra quyen trang thai trong thao tac ghi
    SET v_actor = (SELECT MaNhanVien FROM NhanVien WHERE MaNhanVien = p_MaNguoiThaoTac);
    IF v_actor IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_NOTFOUND: Nguoi thao tac khong ton tai.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM TaiKhoan WHERE MaNhanVien = v_actor AND TrangThai = 'HOAT_DONG') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_ACTOR: Tai khoan nguoi thao tac khong hoat dong.';
    END IF;
    SELECT MaHoatDong, MaChienDich INTO v_hd_db, v_cd FROM HoatDongTrienKhai WHERE MaHoatDong = v_hd;
    IF v_cd IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_NOTFOUND: Hoat dong khong ton tai.';
    END IF;
    IF EXISTS (SELECT 1 FROM HoatDongTrienKhai h JOIN ChienDich c USING (MaChienDich)
               WHERE h.MaHoatDong = v_hd_db
                 AND (h.TrangThai IN ('HOAN_THANH','HUY') OR c.TrangThai IN ('HOAN_THANH','HUY'))) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB16: Khong them/chuyen khoan chi vao hoat dong/chien dich da ket thuc.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM PhanCong WHERE MaNhanVien = v_actor AND MaChienDich = v_cd) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB15: Nguoi thao tac chua duoc phan cong vao chien dich cua hoat dong.';
    END IF;
    IF EXISTS (SELECT 1 FROM KhoanChi WHERE MaKhoanChi = v_ma) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_DUP: Ma khoan chi da ton tai.';
    END IF;

    -- 4 Ghi MaNguoiGhiNhan tu nguoi input - ThoiDiemNhap auto-gen
    INSERT INTO KhoanChi (MaKhoanChi, MaHoatDong, MaNguoiGhiNhan, NgayPhatSinh, SoTien, NoiDungChi, MaChungTu)
    VALUES (v_ma, v_hd_db, v_actor, v_ngay, v_sotien, v_nd, v_ct);
    SET v_rows = ROW_COUNT();

    COMMIT;
    SET v_started = FALSE;
    IF v_acquired THEN DO RELEASE_LOCK('marketing_btl.integrity'); END IF;
    SELECT v_ma AS MaKhoanChi, 'THEM' AS ThaoTac, v_rows AS SoDongTacDong;
END$$

-- ---------------------------------------------------------------------
-- replace
-- ---------------------------------------------------------------------

CREATE PROCEDURE sp_P2_SuaKhoanChi(IN p_MaNguoiThaoTac VARCHAR(100), IN p_MaKhoanChi VARCHAR(100), IN p_Chi JSON)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_started BOOLEAN DEFAULT FALSE;
    DECLARE v_acquired BOOLEAN DEFAULT FALSE;
    DECLARE v_ma VARCHAR(20);
    DECLARE v_hd VARCHAR(100);
    DECLARE v_ngay_txt TEXT;
    DECLARE v_ngay DATE;
    DECLARE v_kieu VARCHAR(30);
    DECLARE v_sotien DECIMAL(18,0);
    DECLARE v_big DECIMAL(65,0);
    DECLARE v_nd TEXT;
    DECLARE v_ct TEXT;
    DECLARE v_actor VARCHAR(20);
    DECLARE v_chu VARCHAR(20);
    DECLARE v_hd_cu VARCHAR(20);
    DECLARE v_cd_cu VARCHAR(20);
    DECLARE v_hd_db VARCHAR(20);
    DECLARE v_cd VARCHAR(20);
    DECLARE v_rows INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        IF v_started THEN ROLLBACK; END IF;
        IF v_acquired THEN DO RELEASE_LOCK('marketing_btl.integrity'); END IF;
        RESIGNAL;
    END;

    -- 1 Kiem tra input
    IF p_MaNguoiThaoTac IS NULL OR CHAR_LENGTH(TRIM(p_MaNguoiThaoTac))=0
       OR CHAR_LENGTH(p_MaNguoiThaoTac)>20 OR CHAR_LENGTH(p_MaNguoiThaoTac)<>CHAR_LENGTH(TRIM(p_MaNguoiThaoTac)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: Ma nguoi thao tac bat buoc, khong rong, toi da 20 ky tu, khong co dau cach dau/cuoi.';
    END IF;
    IF p_MaKhoanChi IS NULL OR CHAR_LENGTH(TRIM(p_MaKhoanChi))=0
       OR CHAR_LENGTH(p_MaKhoanChi)>20 OR CHAR_LENGTH(p_MaKhoanChi)<>CHAR_LENGTH(TRIM(p_MaKhoanChi)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: Ma khoan chi bat buoc, khong rong, toi da 20 ky tu, khong co dau cach dau/cuoi.';
    END IF;
    IF p_Chi IS NULL OR JSON_TYPE(p_Chi)<>'OBJECT' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: Can mot JSON object khoan chi.';
    END IF;
    IF NOT JSON_SCHEMA_VALID('{
  "type": "object",
  "required": ["MaHoatDong","NgayPhatSinh","SoTien","NoiDungChi"],
  "properties": {
    "MaHoatDong":   {"type": "string"},
    "NgayPhatSinh": {"type": "string"},
    "SoTien":       {"type": "number"},
    "NoiDungChi":   {"type": "string"},
    "MaChungTu":    {"type": ["string","null"]}
  },
  "additionalProperties": false
}', p_Chi) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: JSON sua thieu truong bat buoc, sai kieu, co gia tri null hoac truong la.';
    END IF;

    SET v_hd = JSON_UNQUOTE(JSON_EXTRACT(p_Chi,'$.MaHoatDong'));
    SET v_ngay_txt = JSON_UNQUOTE(JSON_EXTRACT(p_Chi,'$.NgayPhatSinh'));
    SET v_nd = JSON_UNQUOTE(JSON_EXTRACT(p_Chi,'$.NoiDungChi'));
    SET v_ct = IF(JSON_TYPE(JSON_EXTRACT(p_Chi,'$.MaChungTu'))='STRING', JSON_UNQUOTE(JSON_EXTRACT(p_Chi,'$.MaChungTu')), NULL);

    IF CHAR_LENGTH(TRIM(v_hd))=0 OR CHAR_LENGTH(v_hd)>20 OR CHAR_LENGTH(v_hd)<>CHAR_LENGTH(TRIM(v_hd)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: MaHoatDong khong rong, toi da 20 ky tu, khong co dau cach dau/cuoi.';
    END IF;
    IF CHAR_LENGTH(TRIM(v_nd))=0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: NoiDungChi khong duoc rong.';
    END IF;
    IF CHAR_LENGTH(v_nd)>500 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: NoiDungChi toi da 500 ky tu.';
    END IF;
    IF v_ct IS NOT NULL AND CHAR_LENGTH(TRIM(v_ct))=0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: MaChungTu khong duoc rong; dung null neu khong co chung tu.';
    END IF;
    IF CHAR_LENGTH(v_ct)>100 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: MaChungTu toi da 100 ky tu.';
    END IF;


    IF v_ngay_txt NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: NgayPhatSinh phai co dang YYYY-MM-DD.';
    END IF;
    IF CAST(SUBSTRING(v_ngay_txt,1,4) AS UNSIGNED) < 1000
       OR CAST(SUBSTRING(v_ngay_txt,6,2) AS UNSIGNED) NOT BETWEEN 1 AND 12
       OR CAST(SUBSTRING(v_ngay_txt,9,2) AS UNSIGNED) < 1
       OR CAST(SUBSTRING(v_ngay_txt,9,2) AS UNSIGNED) >
          DAY(LAST_DAY(STR_TO_DATE(CONCAT(SUBSTRING(v_ngay_txt,1,7),'-01'),'%Y-%m-%d'))) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: NgayPhatSinh khong phai ngay lich hop le (tu 1000-01-01).';
    END IF;
    SET v_ngay = STR_TO_DATE(v_ngay_txt,'%Y-%m-%d');


    SET v_kieu = JSON_TYPE(JSON_EXTRACT(p_Chi,'$.SoTien'));
    IF v_kieu IN ('DECIMAL','DOUBLE') THEN
        IF ABS(CAST(JSON_EXTRACT(p_Chi,'$.SoTien') AS DOUBLE)) >= 1e18 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: SoTien vuot mien DECIMAL(18,0) (toi da 999999999999999999).';
        END IF;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: SoTien phai la so nguyen VND, khong co phan le hoac dang mu.';
    END IF;
    IF v_kieu NOT IN ('INTEGER','UNSIGNED INTEGER') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: SoTien phai la so nguyen VND, khong co phan le hoac dang mu.';
    END IF;
    IF v_kieu = 'UNSIGNED INTEGER' THEN
        SET v_big = CAST(JSON_EXTRACT(p_Chi,'$.SoTien') AS UNSIGNED);
    ELSE
        SET v_big = CAST(JSON_EXTRACT(p_Chi,'$.SoTien') AS SIGNED);
    END IF;
    IF v_big <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: SoTien phai lon hon 0.';
    END IF;
    IF v_big > 999999999999999999 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: SoTien vuot mien DECIMAL(18,0) (toi da 999999999999999999).';
    END IF;
    SET v_sotien = v_big;

    -- 2 Giao dich top layer
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    SET v_acquired = COALESCE(IS_USED_LOCK('marketing_btl.integrity'),0) <> CONNECTION_ID();
    CALL sp_P1_KhoaGhi();
    START TRANSACTION;
    SET v_started = TRUE;

    -- 3 existence - permission - state
    SET v_actor = (SELECT MaNhanVien FROM NhanVien WHERE MaNhanVien = p_MaNguoiThaoTac);
    IF v_actor IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_NOTFOUND: Nguoi thao tac khong ton tai.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM TaiKhoan WHERE MaNhanVien = v_actor AND TrangThai = 'HOAT_DONG') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_ACTOR: Tai khoan nguoi thao tac khong hoat dong.';
    END IF;


    SELECT MaKhoanChi, MaHoatDong, MaNguoiGhiNhan INTO v_ma, v_hd_cu, v_chu
    FROM KhoanChi WHERE MaKhoanChi = p_MaKhoanChi FOR UPDATE;
    IF v_ma IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_NOTFOUND: Khoan chi khong ton tai.';
    END IF;
    IF v_chu <> v_actor THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_PERM: Chi nguoi tao khoan chi moi duoc sua/xoa khoan chi cua minh.';
    END IF;


    SET v_cd_cu = (SELECT MaChienDich FROM HoatDongTrienKhai WHERE MaHoatDong = v_hd_cu);
    IF EXISTS (SELECT 1 FROM HoatDongTrienKhai h JOIN ChienDich c USING (MaChienDich)
               WHERE h.MaHoatDong = v_hd_cu
                 AND (h.TrangThai IN ('HOAN_THANH','HUY') OR c.TrangThai IN ('HOAN_THANH','HUY'))) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB16: Khong sua/chuyen khoan chi cua hoat dong/chien dich da ket thuc.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM PhanCong WHERE MaNhanVien = v_actor AND MaChienDich = v_cd_cu) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB15: Nguoi thao tac chua duoc phan cong vao chien dich cua khoan chi hien tai.';
    END IF;


    SELECT MaHoatDong, MaChienDich INTO v_hd_db, v_cd FROM HoatDongTrienKhai WHERE MaHoatDong = v_hd;
    IF v_cd IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_NOTFOUND: Hoat dong dich khong ton tai.';
    END IF;
    IF EXISTS (SELECT 1 FROM HoatDongTrienKhai h JOIN ChienDich c USING (MaChienDich)
               WHERE h.MaHoatDong = v_hd_db
                 AND (h.TrangThai IN ('HOAN_THANH','HUY') OR c.TrangThai IN ('HOAN_THANH','HUY'))) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB16: Khong them/chuyen khoan chi vao hoat dong/chien dich da ket thuc.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM PhanCong WHERE MaNhanVien = v_actor AND MaChienDich = v_cd) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB15: Nguoi thao tac chua duoc phan cong vao chien dich cua hoat dong dich.';
    END IF;

    -- 4 Write - unchanged: MaKhoanChi, MaNguoiGhiNhan, ThoiDiemNhap.
    UPDATE KhoanChi
    SET MaHoatDong = v_hd_db, NgayPhatSinh = v_ngay, SoTien = v_sotien, NoiDungChi = v_nd, MaChungTu = v_ct
    WHERE MaKhoanChi = v_ma;
    SET v_rows = ROW_COUNT();

    COMMIT;
    SET v_started = FALSE;
    IF v_acquired THEN DO RELEASE_LOCK('marketing_btl.integrity'); END IF;
    SELECT v_ma AS MaKhoanChi, 'SUA' AS ThaoTac, v_rows AS SoDongTacDong;
END$$

-- ---------------------------------------------------------------------
-- delete
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_P2_XoaKhoanChi(IN p_MaNguoiThaoTac VARCHAR(100), IN p_MaKhoanChi VARCHAR(100))
SQL SECURITY DEFINER
BEGIN
    DECLARE v_started BOOLEAN DEFAULT FALSE;
    DECLARE v_acquired BOOLEAN DEFAULT FALSE;
    DECLARE v_ma VARCHAR(20);
    DECLARE v_actor VARCHAR(20);
    DECLARE v_chu VARCHAR(20);
    DECLARE v_hd VARCHAR(20);
    DECLARE v_cd VARCHAR(20);
    DECLARE v_rows INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        IF v_started THEN ROLLBACK; END IF;
        IF v_acquired THEN DO RELEASE_LOCK('marketing_btl.integrity'); END IF;
        RESIGNAL;
    END;

    IF p_MaNguoiThaoTac IS NULL OR CHAR_LENGTH(TRIM(p_MaNguoiThaoTac))=0
       OR CHAR_LENGTH(p_MaNguoiThaoTac)>20 OR CHAR_LENGTH(p_MaNguoiThaoTac)<>CHAR_LENGTH(TRIM(p_MaNguoiThaoTac)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: Ma nguoi thao tac bat buoc, khong rong, toi da 20 ky tu, khong co dau cach dau/cuoi.';
    END IF;
    IF p_MaKhoanChi IS NULL OR CHAR_LENGTH(TRIM(p_MaKhoanChi))=0
       OR CHAR_LENGTH(p_MaKhoanChi)>20 OR CHAR_LENGTH(p_MaKhoanChi)<>CHAR_LENGTH(TRIM(p_MaKhoanChi)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INPUT: Ma khoan chi bat buoc, khong rong, toi da 20 ky tu, khong co dau cach dau/cuoi.';
    END IF;

    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    SET v_acquired = COALESCE(IS_USED_LOCK('marketing_btl.integrity'),0) <> CONNECTION_ID();
    CALL sp_P1_KhoaGhi();
    START TRANSACTION;
    SET v_started = TRUE;

    SET v_actor = (SELECT MaNhanVien FROM NhanVien WHERE MaNhanVien = p_MaNguoiThaoTac);
    IF v_actor IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_NOTFOUND: Nguoi thao tac khong ton tai.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM TaiKhoan WHERE MaNhanVien = v_actor AND TrangThai = 'HOAT_DONG') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_ACTOR: Tai khoan nguoi thao tac khong hoat dong.';
    END IF;

    SELECT MaKhoanChi, MaHoatDong, MaNguoiGhiNhan INTO v_ma, v_hd, v_chu
    FROM KhoanChi WHERE MaKhoanChi = p_MaKhoanChi FOR UPDATE;
    IF v_ma IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_NOTFOUND: Khoan chi khong ton tai.';
    END IF;
    IF v_chu <> v_actor THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_PERM: Chi nguoi tao khoan chi moi duoc sua/xoa khoan chi cua minh.';
    END IF;
    SET v_cd = (SELECT MaChienDich FROM HoatDongTrienKhai WHERE MaHoatDong = v_hd);
    IF EXISTS (SELECT 1 FROM HoatDongTrienKhai h JOIN ChienDich c USING (MaChienDich)
               WHERE h.MaHoatDong = v_hd
                 AND (h.TrangThai IN ('HOAN_THANH','HUY') OR c.TrangThai IN ('HOAN_THANH','HUY'))) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB16: Khong xoa khoan chi cua hoat dong/chien dich da ket thuc (du lieu lich su).';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM PhanCong WHERE MaNhanVien = v_actor AND MaChienDich = v_cd) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB15: Nguoi thao tac chua duoc phan cong vao chien dich cua khoan chi.';
    END IF;

    DELETE FROM KhoanChi WHERE MaKhoanChi = v_ma;
    SET v_rows = ROW_COUNT();
    IF v_rows <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_INTERNAL: Xoa khong tac dong dung mot dong; da rollback.';
    END IF;

    COMMIT;
    SET v_started = FALSE;
    IF v_acquired THEN DO RELEASE_LOCK('marketing_btl.integrity'); END IF;
    SELECT v_ma AS MaKhoanChi, 'XOA' AS ThaoTac, v_rows AS SoDongTacDong;
END$$

DELIMITER ;

-- =====================================================================
-- 7. MINH HỌA (chạy từng ca khi báo cáo; mọi ca chạy được trên seed sạch + gói B)
--    Dùng MySQL client. Mỗi lệnh gọi tự quản lý giao dịch nên KHÔNG đặt START TRANSACTION trước
--    (trừ ca 14a cố ý). Nhóm 1 chạy theo thứ tự 1 -> 5 (thêm rồi sửa rồi chuyển rồi xóa cùng KC_T1);
--    các ca còn lại độc lập. Ca lỗi không để lại dữ liệu; sau mọi ca chạy ca 15 để đối soát.
--    Seed: HD01 cấp 2.000.000/thực chi 3.000.000; HD02 cấp 3.000.000/thực chi 3.500.000;
--    KC05 thuộc HD05/CD03 (HOAN_THANH, người tạo NV06); NV08 bị khóa; NV04 chỉ được phân công CD01.
-- =====================================================================
--
-- 1. THÊM hợp lệ; thực chi vượt ngân sách vẫn thêm được (HD01 cấp 2.000.000)
--   CALL sp_P2_ThemKhoanChi('NV04','{"MaKhoanChi":"KC_T1","MaHoatDong":"HD01","NgayPhatSinh":"2026-11-07","SoTien":9000000,"NoiDungChi":"Quang cao bo sung","MaChungTu":"CT-T1"}');
--   SELECT MaHoatDong, NganSachDuocCap, TongChiPhiThucTe FROM HoatDongTrienKhai WHERE MaHoatDong IN ('HD01','HD02') ORDER BY 1;
--   => KC_T1 | THEM | 1
--   => HD01: NganSachDuocCap 2000000, TongChiPhiThucTe 12000000 (HD02 giữ 3500000)
--
-- 2. SỬA hợp lệ: đổi ngày/tiền/nội dung; vắng MaChungTu => NULL (thay thế đầy đủ)
--   CALL sp_P2_SuaKhoanChi('NV04','KC_T1','{"MaHoatDong":"HD01","NgayPhatSinh":"2026-11-08","SoTien":9500000,"NoiDungChi":"Quang cao bo sung (sua)"}');
--   SELECT MaKhoanChi, MaNguoiGhiNhan, NgayPhatSinh, SoTien, MaChungTu FROM KhoanChi WHERE MaKhoanChi='KC_T1';
--   SELECT MaHoatDong, NganSachDuocCap, TongChiPhiThucTe FROM HoatDongTrienKhai WHERE MaHoatDong IN ('HD01','HD02') ORDER BY 1;
--   => KC_T1 | SUA | 1
--   => KC_T1 | NV04 | 2026-11-08 | 9500000 | NULL   (người tạo không đổi)
--   => HD01 TongChiPhiThucTe = 12500000
--
-- 3. SỬA không đổi giá trị vẫn hợp lệ (mã tồn tại) => SoDongTacDong = 0
--   CALL sp_P2_SuaKhoanChi('NV04','KC_T1','{"MaHoatDong":"HD01","NgayPhatSinh":"2026-11-08","SoTien":9500000,"NoiDungChi":"Quang cao bo sung (sua)"}');
--   => KC_T1 | SUA | 0
--
-- 4. Chuyển khoản chi giữa hai hoạt động đang mở (HD01 -> HD02) đồng thời đổi tiền 9.500.000 -> 800.000
--   CALL sp_P2_SuaKhoanChi('NV04','KC_T1','{"MaHoatDong":"HD02","NgayPhatSinh":"2026-11-08","SoTien":800000,"NoiDungChi":"Chuyen sang HD02","MaChungTu":"CT-T1B"}');
--   SELECT MaHoatDong, NganSachDuocCap, TongChiPhiThucTe FROM HoatDongTrienKhai WHERE MaHoatDong IN ('HD01','HD02') ORDER BY 1;
--   => KC_T1 | SUA | 1
--   => HD01 TongChiPhiThucTe = 3000000 (về như seed); HD02 TongChiPhiThucTe = 4300000
--
-- 5. XÓA hợp lệ (khoản nhập nhầm còn mở); tổng HD02 trở về seed
--   CALL sp_P2_XoaKhoanChi('NV04','KC_T1');
--   SELECT COUNT(*) AS ConKC_T1 FROM KhoanChi WHERE MaKhoanChi='KC_T1';
--   SELECT MaHoatDong, NganSachDuocCap, TongChiPhiThucTe FROM HoatDongTrienKhai WHERE MaHoatDong IN ('HD01','HD02') ORDER BY 1;
--   => KC_T1 | XOA | 1
--   => ConKC_T1 = 0
--   => HD01 = 3000000, HD02 = 3500000
--
-- 6. Mã trùng
--   CALL sp_P2_ThemKhoanChi('NV04','{"MaKhoanChi":"KC01","MaHoatDong":"HD01","NgayPhatSinh":"2026-11-07","SoTien":1000,"NoiDungChi":"Trung ma"}');
--   => ERROR 1644: P2_DUP: Ma khoan chi da ton tai.
--
-- 7a. Sửa mã không tồn tại
--   CALL sp_P2_SuaKhoanChi('NV04','KC_KHONG_CO','{"MaHoatDong":"HD01","NgayPhatSinh":"2026-11-07","SoTien":1000,"NoiDungChi":"x"}');
--   => ERROR 1644: P2_NOTFOUND: Khoan chi khong ton tai.
--
-- 7b. Xóa mã không tồn tại
--   CALL sp_P2_XoaKhoanChi('NV04','KC_KHONG_CO');
--   => ERROR 1644: P2_NOTFOUND: Khoan chi khong ton tai.
--
-- 8a. Số tiền 0
--   CALL sp_P2_ThemKhoanChi('NV04','{"MaKhoanChi":"KC_X","MaHoatDong":"HD01","NgayPhatSinh":"2026-11-07","SoTien":0,"NoiDungChi":"x"}');
--   => ERROR 1644: P2_INPUT: SoTien phai lon hon 0.
--
-- 8b. Số tiền âm (-5)
--   CALL sp_P2_ThemKhoanChi('NV04','{"MaKhoanChi":"KC_X","MaHoatDong":"HD01","NgayPhatSinh":"2026-11-07","SoTien":-5,"NoiDungChi":"x"}');
--   => ERROR 1644: P2_INPUT: SoTien phai lon hon 0.
--
-- 8c. Số tiền có phần lẻ (1.5)
--   CALL sp_P2_ThemKhoanChi('NV04','{"MaKhoanChi":"KC_X","MaHoatDong":"HD01","NgayPhatSinh":"2026-11-07","SoTien":1.5,"NoiDungChi":"x"}');
--   => ERROR 1644: P2_INPUT: SoTien phai la so nguyen VND, khong co phan le hoac dang mu.
--
-- 8d. Số tiền 1000000.0 (không làm tròn rồi mới kiểm tra)
--   CALL sp_P2_ThemKhoanChi('NV04','{"MaKhoanChi":"KC_X","MaHoatDong":"HD01","NgayPhatSinh":"2026-11-07","SoTien":1000000.0,"NoiDungChi":"x"}');
--   => ERROR 1644: P2_INPUT: SoTien phai la so nguyen VND, khong co phan le hoac dang mu.
--
-- 8e. Số tiền dạng mũ (1e6)
--   CALL sp_P2_ThemKhoanChi('NV04','{"MaKhoanChi":"KC_X","MaHoatDong":"HD01","NgayPhatSinh":"2026-11-07","SoTien":1e6,"NoiDungChi":"x"}');
--   => ERROR 1644: P2_INPUT: SoTien phai la so nguyen VND, khong co phan le hoac dang mu.
--
-- 8f. Số tiền vượt miền DECIMAL(18,0): 10^18
--   CALL sp_P2_ThemKhoanChi('NV04','{"MaKhoanChi":"KC_X","MaHoatDong":"HD01","NgayPhatSinh":"2026-11-07","SoTien":1000000000000000000,"NoiDungChi":"x"}');
--   => ERROR 1644: P2_INPUT: SoTien vuot mien DECIMAL(18,0) (toi da 999999999999999999).
--
-- 8g. Số tiền vượt miền DECIMAL(18,0): 10^19
--   CALL sp_P2_ThemKhoanChi('NV04','{"MaKhoanChi":"KC_X","MaHoatDong":"HD01","NgayPhatSinh":"2026-11-07","SoTien":10000000000000000000,"NoiDungChi":"x"}');
--   => ERROR 1644: P2_INPUT: SoTien vuot mien DECIMAL(18,0) (toi da 999999999999999999).
--
-- 8h. Số tiền biên trên 999999999999999999 hợp lệ (thêm rồi xóa)
--   CALL sp_P2_ThemKhoanChi('NV04','{"MaKhoanChi":"KC_BIEN","MaHoatDong":"HD01","NgayPhatSinh":"2026-11-07","SoTien":999999999999999999,"NoiDungChi":"Bien tren"}');
--   CALL sp_P2_XoaKhoanChi('NV04','KC_BIEN');
--   => KC_BIEN | THEM | 1
--   => KC_BIEN | XOA | 1
--
-- 9a. Ngày phát sinh sai: 2026-02-30
--   CALL sp_P2_ThemKhoanChi('NV04','{"MaKhoanChi":"KC_X","MaHoatDong":"HD01","NgayPhatSinh":"2026-02-30","SoTien":1000,"NoiDungChi":"x"}');
--   => ERROR 1644: P2_INPUT: NgayPhatSinh khong phai ngay lich hop le (tu 1000-01-01).
--
-- 9b. Ngày phát sinh sai: 2025-02-29
--   CALL sp_P2_ThemKhoanChi('NV04','{"MaKhoanChi":"KC_X","MaHoatDong":"HD01","NgayPhatSinh":"2025-02-29","SoTien":1000,"NoiDungChi":"x"}');
--   => ERROR 1644: P2_INPUT: NgayPhatSinh khong phai ngay lich hop le (tu 1000-01-01).
--
-- 9c. Ngày phát sinh sai: 2026-13-01
--   CALL sp_P2_ThemKhoanChi('NV04','{"MaKhoanChi":"KC_X","MaHoatDong":"HD01","NgayPhatSinh":"2026-13-01","SoTien":1000,"NoiDungChi":"x"}');
--   => ERROR 1644: P2_INPUT: NgayPhatSinh khong phai ngay lich hop le (tu 1000-01-01).
--
-- 9d. Ngày phát sinh sai: 07/11/2026
--   CALL sp_P2_ThemKhoanChi('NV04','{"MaKhoanChi":"KC_X","MaHoatDong":"HD01","NgayPhatSinh":"07/11/2026","SoTien":1000,"NoiDungChi":"x"}');
--   => ERROR 1644: P2_INPUT: NgayPhatSinh phai co dang YYYY-MM-DD.
--
-- 10a. Nội dung rỗng (chỉ dấu cách)
--   CALL sp_P2_ThemKhoanChi('NV04','{"MaKhoanChi":"KC_X","MaHoatDong":"HD01","NgayPhatSinh":"2026-11-07","SoTien":1000,"NoiDungChi":"   "}');
--   => ERROR 1644: P2_INPUT: NoiDungChi khong duoc rong.
--
-- 10b. Nội dung quá dài (501 ký tự)
--   CALL sp_P2_ThemKhoanChi('NV04', CONCAT('{"MaKhoanChi":"KC_X","MaHoatDong":"HD01","NgayPhatSinh":"2026-11-07","SoTien":1000,"NoiDungChi":"', REPEAT('x',501), '"}'));
--   => ERROR 1644: P2_INPUT: NoiDungChi toi da 500 ky tu.
--
-- 10c. Chứng từ quá dài (101 ký tự)
--   CALL sp_P2_ThemKhoanChi('NV04', CONCAT('{"MaKhoanChi":"KC_X","MaHoatDong":"HD01","NgayPhatSinh":"2026-11-07","SoTien":1000,"NoiDungChi":"x","MaChungTu":"', REPEAT('c',101), '"}'));
--   => ERROR 1644: P2_INPUT: MaChungTu toi da 100 ky tu.
--
-- 10d. Mã khoản chi quá dài (21 ký tự)
--   CALL sp_P2_ThemKhoanChi('NV04', CONCAT('{"MaKhoanChi":"', REPEAT('K',21), '","MaHoatDong":"HD01","NgayPhatSinh":"2026-11-07","SoTien":1000,"NoiDungChi":"x"}'));
--   => ERROR 1644: P2_INPUT: MaKhoanChi khong rong, toi da 20 ky tu, khong co dau cach dau/cuoi.
--
-- 11a. JSON không phải object
--   CALL sp_P2_ThemKhoanChi('NV04','[1,2]');
--   => ERROR 1644: P2_INPUT: Can mot JSON object khoan chi.
--
-- 11b. Trường lạ (MaNguoiGhiNhan trong JSON thêm)
--   CALL sp_P2_ThemKhoanChi('NV04','{"MaKhoanChi":"KC_X","MaHoatDong":"HD01","NgayPhatSinh":"2026-11-07","SoTien":1000,"NoiDungChi":"x","MaNguoiGhiNhan":"NV05"}');
--   => ERROR 1644: P2_INPUT: JSON khoan chi thieu truong bat buoc, sai kieu, co gia tri null hoac truong la.
--
-- 11c. Trường bắt buộc là null (NoiDungChi)
--   CALL sp_P2_ThemKhoanChi('NV04','{"MaKhoanChi":"KC_X","MaHoatDong":"HD01","NgayPhatSinh":"2026-11-07","SoTien":1000,"NoiDungChi":null}');
--   => ERROR 1644: P2_INPUT: JSON khoan chi thieu truong bat buoc, sai kieu, co gia tri null hoac truong la.
--
-- 11d. JSON sửa có MaKhoanChi (không nhận khóa trong JSON sửa)
--   CALL sp_P2_SuaKhoanChi('NV04','KC01','{"MaHoatDong":"HD01","NgayPhatSinh":"2026-11-05","SoTien":2500000,"NoiDungChi":"x","MaKhoanChi":"KC01"}');
--   => ERROR 1644: P2_INPUT: JSON sua thieu truong bat buoc, sai kieu, co gia tri null hoac truong la.
--
-- 12a. Tài khoản người thao tác bị khóa (NV08)
--   CALL sp_P2_ThemKhoanChi('NV08','{"MaKhoanChi":"KC_X","MaHoatDong":"HD09","NgayPhatSinh":"2026-11-07","SoTien":1000,"NoiDungChi":"x"}');
--   => ERROR 1644: P2_ACTOR: Tai khoan nguoi thao tac khong hoat dong.
--
-- 12b. Người thao tác không tồn tại
--   CALL sp_P2_ThemKhoanChi('NV99','{"MaKhoanChi":"KC_X","MaHoatDong":"HD01","NgayPhatSinh":"2026-11-07","SoTien":1000,"NoiDungChi":"x"}');
--   => ERROR 1644: P2_NOTFOUND: Nguoi thao tac khong ton tai.
--
-- 12c. Không được phân công (NV05 thêm vào HD01 thuộc CD01)
--   CALL sp_P2_ThemKhoanChi('NV05','{"MaKhoanChi":"KC_X","MaHoatDong":"HD01","NgayPhatSinh":"2026-11-07","SoTien":1000,"NoiDungChi":"x"}');
--   => ERROR 1644: RB15: Nguoi thao tac chua duoc phan cong vao chien dich cua hoat dong.
--
-- 12d. Hoạt động không tồn tại
--   CALL sp_P2_ThemKhoanChi('NV04','{"MaKhoanChi":"KC_X","MaHoatDong":"HD99","NgayPhatSinh":"2026-11-07","SoTien":1000,"NoiDungChi":"x"}');
--   => ERROR 1644: P2_NOTFOUND: Hoat dong khong ton tai.
--
-- 12e. Không đủ quyền xóa: NV05 xóa KC01 của NV04
--   CALL sp_P2_XoaKhoanChi('NV05','KC01');
--   => ERROR 1644: P2_PERM: Chi nguoi tao khoan chi moi duoc sua/xoa khoan chi cua minh.
--
-- 12f. Không đủ quyền sửa: NV02 (quản lý) sửa KC01 của NV04
--   CALL sp_P2_SuaKhoanChi('NV02','KC01','{"MaHoatDong":"HD01","NgayPhatSinh":"2026-11-05","SoTien":2500000,"NoiDungChi":"x"}');
--   => ERROR 1644: P2_PERM: Chi nguoi tao khoan chi moi duoc sua/xoa khoan chi cua minh.
--
-- 13a. Sửa khoản chi của hoạt động đã hoàn thành (KC05, NV06)
--   CALL sp_P2_SuaKhoanChi('NV06','KC05','{"MaHoatDong":"HD05","NgayPhatSinh":"2026-11-05","SoTien":1300000,"NoiDungChi":"x"}');
--   => ERROR 1644: RB16: Khong sua/chuyen khoan chi cua hoat dong/chien dich da ket thuc.
--
-- 13b. Xóa khoản chi đã kết thúc (KC05, NV06)
--   CALL sp_P2_XoaKhoanChi('NV06','KC05');
--   => ERROR 1644: RB16: Khong xoa khoan chi cua hoat dong/chien dich da ket thuc (du lieu lich su).
--
-- 13c. Thêm vào hoạt động đã kết thúc (NV06 vào HD05/CD03)
--   CALL sp_P2_ThemKhoanChi('NV06','{"MaKhoanChi":"KC_X","MaHoatDong":"HD05","NgayPhatSinh":"2026-11-07","SoTien":1000,"NoiDungChi":"x"}');
--   => ERROR 1644: RB16: Khong them/chuyen khoan chi vao hoat dong/chien dich da ket thuc.
--
-- 13d. Chuyển KC05 từ HD05/CD03 (đã hoàn thành) sang HD01 bị chặn (NV06 là người tạo)
--   CALL sp_P2_SuaKhoanChi('NV06','KC05','{"MaHoatDong":"HD01","NgayPhatSinh":"2026-11-05","SoTien":1200000,"NoiDungChi":"x"}');
--   => ERROR 1644: RB16: Khong sua/chuyen khoan chi cua hoat dong/chien dich da ket thuc.
--
-- 13e. Chuyển KC05 sang HD01 bởi người không phải người tạo (NV04)
--   CALL sp_P2_SuaKhoanChi('NV04','KC05','{"MaHoatDong":"HD01","NgayPhatSinh":"2026-11-05","SoTien":1200000,"NoiDungChi":"x"}');
--   => ERROR 1644: P2_PERM: Chi nguoi tao khoan chi moi duoc sua/xoa khoan chi cua minh.
--
-- 13f. Chuyển khoản chi đang mở vào hoạt động đã kết thúc (KC01 -> HD05)
--   CALL sp_P2_SuaKhoanChi('NV04','KC01','{"MaHoatDong":"HD05","NgayPhatSinh":"2026-11-05","SoTien":2500000,"NoiDungChi":"x"}');
--   => ERROR 1644: RB16: Khong them/chuyen khoan chi vao hoat dong/chien dich da ket thuc.
--
-- 13g. Chuyển sang chiến dịch mà người thao tác không được phân công (KC01 -> HD03/CD02)
--   CALL sp_P2_SuaKhoanChi('NV04','KC01','{"MaHoatDong":"HD03","NgayPhatSinh":"2026-11-05","SoTien":2500000,"NoiDungChi":"x"}');
--   => ERROR 1644: RB15: Nguoi thao tac chua duoc phan cong vao chien dich cua hoat dong dich.
--
-- 13h. Chiến dịch TAM_DUNG chưa kết thúc: vẫn thêm/xóa được (NV07, HD07/CD04)
--   CALL sp_P2_ThemKhoanChi('NV07','{"MaKhoanChi":"KC_G9","MaHoatDong":"HD07","NgayPhatSinh":"2026-11-09","SoTien":1000,"NoiDungChi":"Tam dung van mo"}');
--   CALL sp_P2_XoaKhoanChi('NV07','KC_G9');
--   => KC_G9 | THEM | 1
--   => KC_G9 | XOA | 1
--
-- 14a. Gọi lồng trong giao dịch đang mở: bị từ chối, giao dịch và khóa của bên gọi không bị mất
--   SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
--   START TRANSACTION;
--   INSERT INTO KhoanChi(MaKhoanChi,MaHoatDong,MaNguoiGhiNhan,NgayPhatSinh,SoTien,NoiDungChi) VALUES('KC_N1','HD01','NV04','2026-11-09',1000,'Cua ben goi');
--   CALL sp_P2_ThemKhoanChi('NV04','{"MaKhoanChi":"KC_N2","MaHoatDong":"HD01","NgayPhatSinh":"2026-11-09","SoTien":2000,"NoiDungChi":"Long"}');
--   SELECT COUNT(*) AS KC_N1_con, IS_USED_LOCK('marketing_btl.integrity')=CONNECTION_ID() AS ben_goi_giu_khoa FROM KhoanChi WHERE MaKhoanChi='KC_N1';
--   ROLLBACK;
--   DO RELEASE_LOCK('marketing_btl.integrity');
--   SELECT COUNT(*) AS sau_rollback FROM KhoanChi WHERE MaKhoanChi IN ('KC_N1','KC_N2');
--   => ERROR 1568: Transaction characteristics can't be changed while a transaction is in progress
--   => KC_N1_con = 1, ben_goi_giu_khoa = 1 (INSERT của bên gọi vẫn nằm trong giao dịch của họ)
--   => sau_rollback = 0
--
-- 14b. Bên gọi chỉ giữ khóa (chưa có giao dịch): procedure không nhả khóa của bên gọi
--   SELECT GET_LOCK('marketing_btl.integrity',10) AS lay_khoa;
--   CALL sp_P2_ThemKhoanChi('NV04','{"MaKhoanChi":"KC_H2","MaHoatDong":"HD01","NgayPhatSinh":"2026-11-09","SoTien":2000,"NoiDungChi":"Giu khoa"}');
--   SELECT IS_USED_LOCK('marketing_btl.integrity')=CONNECTION_ID() AS ben_goi_van_giu_khoa;
--   DO RELEASE_LOCK('marketing_btl.integrity');
--   CALL sp_P2_XoaKhoanChi('NV04','KC_H2');
--   => KC_H2 | THEM | 1
--   => ben_goi_van_giu_khoa = 1
--   => KC_H2 | XOA | 1
--
-- 15. Sau mọi ca lỗi: khóa đã nhả, không còn khoản chi test, đối soát cột tổng với SUM dữ liệu gốc
--   SELECT IS_USED_LOCK('marketing_btl.integrity') AS khoa_dang_giu, (SELECT COUNT(*) FROM KhoanChi) AS so_khoan_chi, (SELECT SUM(SoTien) FROM KhoanChi) AS tong_tien;
--   SELECT h.MaHoatDong, h.TongChiPhiThucTe, COALESCE(SUM(k.SoTien),0) AS TongGoc FROM HoatDongTrienKhai h LEFT JOIN KhoanChi k USING(MaHoatDong) GROUP BY h.MaHoatDong, h.TongChiPhiThucTe HAVING h.TongChiPhiThucTe<>TongGoc;
--   => khoa_dang_giu = NULL, so_khoan_chi = 11, tong_tien = 16200000
--   => câu đối soát: 0 dòng (không lệch)
--
