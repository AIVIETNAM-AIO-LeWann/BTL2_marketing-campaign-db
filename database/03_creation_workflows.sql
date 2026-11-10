USE marketing_btl;
SET NAMES utf8mb4;
DELIMITER $$

-- These are infrastructure for total participation, NOT the Part 2 KhoanChi CRUD.
-- Call at top level, not inside another transaction. No foreign-key checks disabled.
-- SET TRANSACTION refuses an already active transaction before START TRANSACTION.
CREATE PROCEDURE sp_P1_TaoNhanVien(IN p_nv JSON, IN p_tk JSON)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_started BOOLEAN DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @p1_internal=0;
        IF v_started THEN ROLLBACK; END IF;
        DO RELEASE_LOCK('marketing_btl.integrity');
        RESIGNAL;
    END;
    IF JSON_TYPE(p_nv)<>'OBJECT' OR JSON_TYPE(p_tk)<>'OBJECT' OR p_nv IS NULL OR p_tk IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1_INPUT: Can hai JSON object nhan vien va tai khoan.';
    END IF;
    CALL sp_P1_KhoaGhi();
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    START TRANSACTION;
    SET v_started=TRUE;
    SET @p1_internal=1;
    INSERT INTO NhanVien(MaNhanVien,Ho,TenDem,Ten,Email,NgayVaoLam,MaNguoiGiamSat)
    VALUES(p_nv->>'$.MaNhanVien',p_nv->>'$.Ho',NULLIF(p_nv->>'$.TenDem','null'),p_nv->>'$.Ten',
        p_nv->>'$.Email',p_nv->>'$.NgayVaoLam',NULLIF(p_nv->>'$.MaNguoiGiamSat','null'));
    INSERT INTO TaiKhoan(MaTK,MaNhanVien,TenDangNhap,MatKhauBam,VaiTro)
    VALUES(p_tk->>'$.MaTK',p_nv->>'$.MaNhanVien',p_tk->>'$.TenDangNhap',p_tk->>'$.MatKhauBam',p_tk->>'$.VaiTro');
    CALL sp_P1_KiemTraToanVen();
    SET @p1_internal=0;
    COMMIT;
    DO RELEASE_LOCK('marketing_btl.integrity');
END$$

CREATE PROCEDURE sp_P1_TaoChienDich(IN p_cd JSON)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_started BOOLEAN DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @p1_internal=0;
        IF v_started THEN ROLLBACK; END IF;
        DO RELEASE_LOCK('marketing_btl.integrity');
        RESIGNAL;
    END;
    IF p_cd IS NULL OR JSON_TYPE(p_cd)<>'OBJECT' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1_INPUT: Can JSON object chien dich.';
    END IF;
    CALL sp_P1_KhoaGhi();
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    START TRANSACTION;
    SET v_started=TRUE;
    SET @p1_internal=1;
    INSERT INTO ChienDich(MaChienDich,TenChienDich,MucTieu,MoTaDoiTuongHuongToi,CachXacDinhChuyenDoi,
        NgayBatDau,NgayKetThucDuKien,NganSachDuocDuyet,MaThuongHieu,MaNhanVien)
    VALUES(p_cd->>'$.MaChienDich',p_cd->>'$.TenChienDich',NULLIF(p_cd->>'$.MucTieu','null'),
        NULLIF(p_cd->>'$.MoTaDoiTuongHuongToi','null'),NULLIF(p_cd->>'$.CachXacDinhChuyenDoi','null'),
        p_cd->>'$.NgayBatDau',p_cd->>'$.NgayKetThucDuKien',p_cd->>'$.NganSachDuocDuyet',
        p_cd->>'$.MaThuongHieu',p_cd->>'$.MaNhanVien');
    INSERT INTO PhanCong(MaNhanVien,MaChienDich,NhiemVu,NgayBatDauThamGia,NgayKetThucThamGia)
    VALUES(p_cd->>'$.MaNhanVien',p_cd->>'$.MaChienDich','Chiu trach nhiem chinh',p_cd->>'$.NgayBatDau',p_cd->>'$.NgayKetThucDuKien');
    CALL sp_P1_KiemTraToanVen();
    SET @p1_internal=0;
    COMMIT;
    DO RELEASE_LOCK('marketing_btl.integrity');
END$$

CREATE PROCEDURE sp_P1_TaoHoatDong(IN p_hd JSON, IN p_rieng JSON, IN p_danhsach JSON)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_nhom VARCHAR(20);
    DECLARE v_started BOOLEAN DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @p1_internal=0;
        IF v_started THEN ROLLBACK; END IF;
        DO RELEASE_LOCK('marketing_btl.integrity');
        RESIGNAL;
    END;
    IF p_hd IS NULL OR p_rieng IS NULL OR JSON_TYPE(p_hd)<>'OBJECT' OR JSON_TYPE(p_rieng)<>'OBJECT' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1_INPUT: Can JSON object hoat dong va chi tiet.';
    END IF;
    CALL sp_P1_KhoaGhi();
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    START TRANSACTION;
    SET v_started=TRUE;
    SET @p1_internal=1;
    SELECT NhomKenh INTO v_nhom FROM KenhMarketing WHERE MaKenh=p_hd->>'$.MaKenh';
    IF v_nhom IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RB09: Kenh khong ton tai.';
    END IF;
    INSERT INTO HoatDongTrienKhai(MaHoatDong,TenHoatDong,MoTa,NgayBatDau,NgayKetThucDuKien,NganSachDuocCap,MaKenh,MaChienDich,MaNhanVien)
    VALUES(p_hd->>'$.MaHoatDong',p_hd->>'$.TenHoatDong',NULLIF(p_hd->>'$.MoTa','null'),
        p_hd->>'$.NgayBatDau',p_hd->>'$.NgayKetThucDuKien',p_hd->>'$.NganSachDuocCap',
        p_hd->>'$.MaKenh',p_hd->>'$.MaChienDich',p_hd->>'$.MaNhanVien');
    IF v_nhom='EMAIL' THEN
        IF p_danhsach IS NULL OR JSON_TYPE(p_danhsach)<>'ARRAY' OR JSON_LENGTH(p_danhsach)=0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='EER_EMAIL_LIST: Can mang it nhat mot ma danh sach email.';
        END IF;
        INSERT INTO HoatDongEmail(MaHoatDong,TieuDeThu,DiaChiGui,TenNguoiGui,DuongDanNoiDung)
        VALUES(p_hd->>'$.MaHoatDong',NULLIF(p_rieng->>'$.TieuDeThu','null'),NULLIF(p_rieng->>'$.DiaChiGui','null'),
            NULLIF(p_rieng->>'$.TenNguoiGui','null'),NULLIF(p_rieng->>'$.DuongDanNoiDung','null'));
        INSERT INTO HoatDongEmail_DanhSach(MaHoatDong,MaDanhSach)
        SELECT p_hd->>'$.MaHoatDong',j.MaDanhSach
        FROM JSON_TABLE(p_danhsach,'$[*]' COLUMNS(MaDanhSach VARCHAR(20) PATH '$' ERROR ON ERROR)) j;
    ELSE
        INSERT INTO HoatDongMangXaHoi(MaHoatDong,MaTKMangXaHoi,NoiDungBaiDang,DinhDang,DuongDanTaiNguyen,DuongDanBaiDang)
        VALUES(p_hd->>'$.MaHoatDong',p_rieng->>'$.MaTKMangXaHoi',NULLIF(p_rieng->>'$.NoiDungBaiDang','null'),
            NULLIF(p_rieng->>'$.DinhDang','null'),NULLIF(p_rieng->>'$.DuongDanTaiNguyen','null'),NULLIF(p_rieng->>'$.DuongDanBaiDang','null'));
    END IF;
    CALL sp_P1_KiemTraToanVen();
    SET @p1_internal=0;
    COMMIT;
    DO RELEASE_LOCK('marketing_btl.integrity');
END$$
DELIMITER ;

-- In Part 1, this role can inspect data and use only complete creation workflows.
-- Do not grant application users raw base-table DML: it could bypass the
-- transaction protocol via a user-set session variable. Owners remain trusted.
CREATE ROLE IF NOT EXISTS 'marketing_p1';
GRANT SELECT ON marketing_btl.* TO 'marketing_p1';
GRANT EXECUTE ON PROCEDURE marketing_btl.sp_P1_TaoNhanVien TO 'marketing_p1';
GRANT EXECUTE ON PROCEDURE marketing_btl.sp_P1_TaoChienDich TO 'marketing_p1';
GRANT EXECUTE ON PROCEDURE marketing_btl.sp_P1_TaoHoatDong TO 'marketing_p1';
