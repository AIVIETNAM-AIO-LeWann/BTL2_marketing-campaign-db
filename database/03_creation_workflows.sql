USE marketing_btl;
SET NAMES utf8mb4;
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,ONLY_FULL_GROUP_BY,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
DELIMITER $$

-- These are infrastructure for total participation, NOT the Part 2 KhoanChi CRUD.
-- Call at top level, not inside another transaction. No foreign-key checks disabled.
-- SET TRANSACTION refuses an already active transaction before START TRANSACTION.
CREATE PROCEDURE sp_P1_TaoNhanVien(IN p_nv JSON, IN p_tk JSON)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_started BOOLEAN DEFAULT FALSE;
    DECLARE v_acquired BOOLEAN DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        IF v_started THEN
            SET @p1_internal=0;
            ROLLBACK;
        END IF;
        IF v_acquired THEN DO RELEASE_LOCK('marketing_btl.integrity'); END IF;
        RESIGNAL;
    END;
    IF JSON_TYPE(p_nv)<>'OBJECT' OR JSON_TYPE(p_tk)<>'OBJECT' OR p_nv IS NULL OR p_tk IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1_INPUT: Can hai JSON object nhan vien va tai khoan.';
    END IF;
    IF NOT JSON_SCHEMA_VALID('{
  "type": "object",
  "required": [
    "MaNhanVien",
    "Ho",
    "Ten",
    "Email",
    "NgayVaoLam"
  ],
  "properties": {
    "MaNhanVien": {
      "type": "string"
    },
    "Ho": {
      "type": "string"
    },
    "Ten": {
      "type": "string"
    },
    "Email": {
      "type": "string"
    },
    "NgayVaoLam": {
      "type": "string"
    },
    "TenDem": {
      "type": [
        "string",
        "null"
      ]
    },
    "MaNguoiGiamSat": {
      "type": [
        "string",
        "null"
      ]
    }
  },
  "additionalProperties": false
}',p_nv) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1_INPUT: Nhan vien thieu truong bat buoc hoac sai kieu JSON.';
    END IF;
    IF NOT JSON_SCHEMA_VALID('{
  "type": "object",
  "required": [
    "MaTK",
    "TenDangNhap",
    "MatKhauBam",
    "VaiTro"
  ],
  "properties": {
    "MaTK": {
      "type": "string"
    },
    "TenDangNhap": {
      "type": "string"
    },
    "MatKhauBam": {
      "type": "string"
    },
    "VaiTro": {
      "type": "string"
    }
  },
  "additionalProperties": false
}',p_tk) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1_INPUT: Tai khoan thieu truong bat buoc hoac sai kieu JSON.';
    END IF;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    SET v_acquired=COALESCE(IS_USED_LOCK('marketing_btl.integrity'),0)<>CONNECTION_ID();
    CALL sp_P1_KhoaGhi();
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
    SET v_started=FALSE;
    IF v_acquired THEN DO RELEASE_LOCK('marketing_btl.integrity'); END IF;
END$$

CREATE PROCEDURE sp_P1_TaoChienDich(IN p_cd JSON)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_started BOOLEAN DEFAULT FALSE;
    DECLARE v_acquired BOOLEAN DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        IF v_started THEN
            SET @p1_internal=0;
            ROLLBACK;
        END IF;
        IF v_acquired THEN DO RELEASE_LOCK('marketing_btl.integrity'); END IF;
        RESIGNAL;
    END;
    IF p_cd IS NULL OR JSON_TYPE(p_cd)<>'OBJECT' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1_INPUT: Can JSON object chien dich.';
    END IF;
    IF NOT JSON_SCHEMA_VALID('{
  "type": "object",
  "required": [
    "MaChienDich",
    "TenChienDich",
    "NgayBatDau",
    "NgayKetThucDuKien",
    "NganSachDuocDuyet",
    "MaThuongHieu",
    "MaNhanVien"
  ],
  "properties": {
    "MaChienDich": {
      "type": "string"
    },
    "TenChienDich": {
      "type": "string"
    },
    "NgayBatDau": {
      "type": "string"
    },
    "NgayKetThucDuKien": {
      "type": "string"
    },
    "NganSachDuocDuyet": {
      "type": "integer"
    },
    "MaThuongHieu": {
      "type": "string"
    },
    "MaNhanVien": {
      "type": "string"
    },
    "MucTieu": {
      "type": [
        "string",
        "null"
      ]
    },
    "MoTaDoiTuongHuongToi": {
      "type": [
        "string",
        "null"
      ]
    },
    "CachXacDinhChuyenDoi": {
      "type": [
        "string",
        "null"
      ]
    }
  },
  "additionalProperties": false
}',p_cd) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1_INPUT: Chien dich thieu truong bat buoc hoac sai kieu JSON.';
    END IF;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    SET v_acquired=COALESCE(IS_USED_LOCK('marketing_btl.integrity'),0)<>CONNECTION_ID();
    CALL sp_P1_KhoaGhi();
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
    SET v_started=FALSE;
    IF v_acquired THEN DO RELEASE_LOCK('marketing_btl.integrity'); END IF;
END$$

CREATE PROCEDURE sp_P1_TaoHoatDong(IN p_hd JSON, IN p_rieng JSON, IN p_danhsach JSON)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_nhom VARCHAR(20);
    DECLARE v_started BOOLEAN DEFAULT FALSE;
    DECLARE v_acquired BOOLEAN DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        IF v_started THEN
            SET @p1_internal=0;
            ROLLBACK;
        END IF;
        IF v_acquired THEN DO RELEASE_LOCK('marketing_btl.integrity'); END IF;
        RESIGNAL;
    END;
    IF p_hd IS NULL OR p_rieng IS NULL OR JSON_TYPE(p_hd)<>'OBJECT' OR JSON_TYPE(p_rieng)<>'OBJECT' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1_INPUT: Can JSON object hoat dong va chi tiet.';
    END IF;
    IF NOT JSON_SCHEMA_VALID('{
  "type": "object",
  "required": [
    "MaHoatDong",
    "TenHoatDong",
    "NgayBatDau",
    "NgayKetThucDuKien",
    "NganSachDuocCap",
    "MaKenh",
    "MaChienDich",
    "MaNhanVien"
  ],
  "properties": {
    "MaHoatDong": {
      "type": "string"
    },
    "TenHoatDong": {
      "type": "string"
    },
    "NgayBatDau": {
      "type": "string"
    },
    "NgayKetThucDuKien": {
      "type": "string"
    },
    "NganSachDuocCap": {
      "type": "integer"
    },
    "MaKenh": {
      "type": "string"
    },
    "MaChienDich": {
      "type": "string"
    },
    "MaNhanVien": {
      "type": "string"
    },
    "MoTa": {
      "type": [
        "string",
        "null"
      ]
    }
  },
  "additionalProperties": false
}',p_hd) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1_INPUT: Hoat dong thieu truong bat buoc hoac sai kieu JSON.';
    END IF;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    SET v_acquired=COALESCE(IS_USED_LOCK('marketing_btl.integrity'),0)<>CONNECTION_ID();
    CALL sp_P1_KhoaGhi();
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
    IF NOT JSON_SCHEMA_VALID('{
  "type": "object",
  "required": [],
  "properties": {
    "TieuDeThu": {
      "type": [
        "string",
        "null"
      ]
    },
    "DiaChiGui": {
      "type": [
        "string",
        "null"
      ]
    },
    "TenNguoiGui": {
      "type": [
        "string",
        "null"
      ]
    },
    "DuongDanNoiDung": {
      "type": [
        "string",
        "null"
      ]
    }
  },
  "additionalProperties": false
}',p_rieng) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1_INPUT: Chi tiet email sai kieu JSON.';
    END IF;
    IF NOT JSON_SCHEMA_VALID('{
  "type": "array",
  "items": {
    "type": "string"
  }
}',p_danhsach) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1_INPUT: Danh sach email phai la mang ma chuoi khong rong.';
    END IF;
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
    IF NOT JSON_SCHEMA_VALID('{
  "type": "object",
  "required": [
    "MaTKMangXaHoi"
  ],
  "properties": {
    "MaTKMangXaHoi": {
      "type": "string"
    },
    "NoiDungBaiDang": {
      "type": [
        "string",
        "null"
      ]
    },
    "DinhDang": {
      "type": [
        "string",
        "null"
      ]
    },
    "DuongDanTaiNguyen": {
      "type": [
        "string",
        "null"
      ]
    },
    "DuongDanBaiDang": {
      "type": [
        "string",
        "null"
      ]
    }
  },
  "additionalProperties": false
}',p_rieng) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P1_INPUT: Chi tiet mang xa hoi thieu tai khoan hoac sai kieu JSON.';
    END IF;
        INSERT INTO HoatDongMangXaHoi(MaHoatDong,MaTKMangXaHoi,NoiDungBaiDang,DinhDang,DuongDanTaiNguyen,DuongDanBaiDang)
        VALUES(p_hd->>'$.MaHoatDong',p_rieng->>'$.MaTKMangXaHoi',NULLIF(p_rieng->>'$.NoiDungBaiDang','null'),
            NULLIF(p_rieng->>'$.DinhDang','null'),NULLIF(p_rieng->>'$.DuongDanTaiNguyen','null'),NULLIF(p_rieng->>'$.DuongDanBaiDang','null'));
    END IF;
    CALL sp_P1_KiemTraToanVen();
    SET @p1_internal=0;
    COMMIT;
    SET v_started=FALSE;
    IF v_acquired THEN DO RELEASE_LOCK('marketing_btl.integrity'); END IF;
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
