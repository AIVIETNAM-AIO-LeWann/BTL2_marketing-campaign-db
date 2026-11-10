-- MySQL 8.4 / InnoDB. Run against a NEW database; no DROP or FK disabling.
CREATE DATABASE IF NOT EXISTS marketing_btl
    CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE marketing_btl;
SET NAMES utf8mb4;
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

CREATE TABLE NhanVien (
    MaNhanVien VARCHAR(20) PRIMARY KEY,
    Ho VARCHAR(50) NOT NULL,
    TenDem VARCHAR(100) NULL,
    Ten VARCHAR(50) NOT NULL,
    Email VARCHAR(254) NOT NULL,
    NgayVaoLam DATE NOT NULL,
    MaNguoiGiamSat VARCHAR(20) NULL,
    CONSTRAINT fk_nv_giamsat FOREIGN KEY (MaNguoiGiamSat) REFERENCES NhanVien(MaNhanVien),
    CONSTRAINT ck_nv_hoten CHECK (CHAR_LENGTH(TRIM(Ho)) > 0 AND CHAR_LENGTH(TRIM(Ten)) > 0),
    CONSTRAINT ck_nv_email CHECK (Email LIKE '%_@_%._%' AND Email NOT LIKE '% %')
) ENGINE=InnoDB;

CREATE TABLE TaiKhoan (
    MaTK VARCHAR(20) PRIMARY KEY,
    MaNhanVien VARCHAR(20) NOT NULL,
    TenDangNhap VARCHAR(100) NOT NULL,
    MatKhauBam VARCHAR(255) NOT NULL,
    NgayTao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    TrangThai VARCHAR(20) NOT NULL DEFAULT 'HOAT_DONG',
    VaiTro VARCHAR(25) NOT NULL,
    CONSTRAINT uq_tk_nv UNIQUE (MaNhanVien),
    CONSTRAINT uq_tk_dangnhap UNIQUE (TenDangNhap),
    CONSTRAINT fk_tk_nv FOREIGN KEY (MaNhanVien) REFERENCES NhanVien(MaNhanVien),
    CONSTRAINT ck_tk_trangthai CHECK (TrangThai IN ('HOAT_DONG', 'BI_KHOA')),
    CONSTRAINT ck_tk_vaitro CHECK (VaiTro IN ('QUAN_TRI', 'QUAN_LY_MARKETING', 'NHAN_VIEN_MARKETING')),
    CONSTRAINT ck_tk_noidung CHECK (CHAR_LENGTH(TRIM(TenDangNhap)) > 0 AND CHAR_LENGTH(MatKhauBam) >= 60)
) ENGINE=InnoDB;

CREATE TABLE SoDienThoaiNhanVien (
    MaNhanVien VARCHAR(20) NOT NULL,
    SoDienThoai VARCHAR(16) NOT NULL,
    PRIMARY KEY (MaNhanVien, SoDienThoai),
    CONSTRAINT fk_sdt_nv FOREIGN KEY (MaNhanVien) REFERENCES NhanVien(MaNhanVien),
    CONSTRAINT ck_sdt_format CHECK (REGEXP_LIKE(SoDienThoai, '^[+]?[0-9]{9,15}$'))
) ENGINE=InnoDB;

CREATE TABLE ThuongHieu (
    MaThuongHieu VARCHAR(20) PRIMARY KEY,
    TenThuongHieu VARCHAR(150) NOT NULL,
    MoTa TEXT NULL,
    Website VARCHAR(500) NULL,
    EmailLienHe VARCHAR(254) NULL,
    CONSTRAINT ck_th_ten CHECK (CHAR_LENGTH(TRIM(TenThuongHieu)) > 0),
    CONSTRAINT ck_th_email CHECK (EmailLienHe IS NULL OR (EmailLienHe LIKE '%_@_%._%' AND EmailLienHe NOT LIKE '% %'))
) ENGINE=InnoDB;

CREATE TABLE KenhMarketing (
    MaKenh VARCHAR(20) PRIMARY KEY,
    TenKenh VARCHAR(100) NOT NULL,
    NhomKenh VARCHAR(20) NOT NULL,
    MoTa TEXT NULL,
    CONSTRAINT ck_kenh_nhom CHECK (NhomKenh IN ('EMAIL', 'MANG_XA_HOI')),
    CONSTRAINT ck_kenh_ten CHECK (CHAR_LENGTH(TRIM(TenKenh)) > 0)
) ENGINE=InnoDB;

CREATE TABLE ChienDich (
    MaChienDich VARCHAR(20) PRIMARY KEY,
    TenChienDich VARCHAR(200) NOT NULL,
    MucTieu TEXT NULL,
    MoTaDoiTuongHuongToi TEXT NULL,
    CachXacDinhChuyenDoi VARCHAR(500) NULL,
    NgayBatDau DATE NOT NULL,
    NgayKetThucDuKien DATE NOT NULL,
    NganSachDuocDuyet DECIMAL(18,0) NOT NULL DEFAULT 0,
    TrangThai VARCHAR(25) NOT NULL DEFAULT 'NHAP',
    MaThuongHieu VARCHAR(20) NOT NULL,
    MaNhanVien VARCHAR(20) NOT NULL COMMENT 'Nhan vien chiu trach nhiem chinh',
    CONSTRAINT fk_cd_th FOREIGN KEY (MaThuongHieu) REFERENCES ThuongHieu(MaThuongHieu),
    CONSTRAINT fk_cd_nv FOREIGN KEY (MaNhanVien) REFERENCES NhanVien(MaNhanVien),
    CONSTRAINT ck_cd_ngay CHECK (NgayKetThucDuKien >= NgayBatDau),
    CONSTRAINT ck_cd_ngansach CHECK (NganSachDuocDuyet >= 0),
    CONSTRAINT ck_cd_ten CHECK (CHAR_LENGTH(TRIM(TenChienDich)) > 0),
    CONSTRAINT ck_cd_trangthai CHECK (TrangThai IN ('NHAP','DA_DUYET','DANG_THUC_HIEN','TAM_DUNG','HOAN_THANH','HUY')),
    CONSTRAINT ck_cd_du_noidung CHECK (TrangThai IN ('NHAP','HUY') OR (
        COALESCE(CHAR_LENGTH(TRIM(MucTieu)),0) > 0
        AND COALESCE(CHAR_LENGTH(TRIM(MoTaDoiTuongHuongToi)),0) > 0
        AND COALESCE(CHAR_LENGTH(TRIM(CachXacDinhChuyenDoi)),0) > 0
        AND NganSachDuocDuyet > 0))
) ENGINE=InnoDB;

CREATE TABLE PhanCong (
    MaNhanVien VARCHAR(20) NOT NULL,
    MaChienDich VARCHAR(20) NOT NULL,
    NhiemVu VARCHAR(500) NOT NULL,
    NgayBatDauThamGia DATE NOT NULL,
    NgayKetThucThamGia DATE NOT NULL,
    PRIMARY KEY (MaNhanVien, MaChienDich),
    CONSTRAINT fk_pc_nv FOREIGN KEY (MaNhanVien) REFERENCES NhanVien(MaNhanVien),
    CONSTRAINT fk_pc_cd FOREIGN KEY (MaChienDich) REFERENCES ChienDich(MaChienDich),
    CONSTRAINT ck_pc_ngay CHECK (NgayKetThucThamGia >= NgayBatDauThamGia),
    CONSTRAINT ck_pc_nhiemvu CHECK (CHAR_LENGTH(TRIM(NhiemVu)) > 0)
) ENGINE=InnoDB;

CREATE TABLE HoatDongTrienKhai (
    MaHoatDong VARCHAR(20) PRIMARY KEY,
    TenHoatDong VARCHAR(200) NOT NULL,
    MoTa TEXT NULL,
    NgayBatDau DATE NOT NULL,
    NgayKetThucDuKien DATE NOT NULL,
    NganSachDuocCap DECIMAL(18,0) NOT NULL DEFAULT 0,
    TrangThai VARCHAR(25) NOT NULL DEFAULT 'CHUA_BAT_DAU',
    MaKenh VARCHAR(20) NOT NULL,
    MaChienDich VARCHAR(20) NOT NULL,
    MaNhanVien VARCHAR(20) NOT NULL COMMENT 'Nhan vien phu trach hoat dong',
    CONSTRAINT fk_hd_kenh FOREIGN KEY (MaKenh) REFERENCES KenhMarketing(MaKenh),
    CONSTRAINT fk_hd_cd FOREIGN KEY (MaChienDich) REFERENCES ChienDich(MaChienDich),
    CONSTRAINT fk_hd_nv FOREIGN KEY (MaNhanVien) REFERENCES NhanVien(MaNhanVien),
    CONSTRAINT ck_hd_ngay CHECK (NgayKetThucDuKien >= NgayBatDau),
    CONSTRAINT ck_hd_ngansach CHECK (NganSachDuocCap >= 0),
    CONSTRAINT ck_hd_ten CHECK (CHAR_LENGTH(TRIM(TenHoatDong)) > 0),
    CONSTRAINT ck_hd_trangthai CHECK (TrangThai IN ('CHUA_BAT_DAU','DANG_THUC_HIEN','TAM_DUNG','HOAN_THANH','HUY'))
) ENGINE=InnoDB;

CREATE TABLE HoatDongEmail (
    MaHoatDong VARCHAR(20) PRIMARY KEY,
    TieuDeThu VARCHAR(300) NULL,
    DiaChiGui VARCHAR(254) NULL,
    TenNguoiGui VARCHAR(150) NULL,
    DuongDanNoiDung VARCHAR(1000) NULL,
    CONSTRAINT fk_email_hd FOREIGN KEY (MaHoatDong) REFERENCES HoatDongTrienKhai(MaHoatDong),
    CONSTRAINT ck_email_gui CHECK (DiaChiGui IS NULL OR (DiaChiGui LIKE '%_@_%._%' AND DiaChiGui NOT LIKE '% %'))
) ENGINE=InnoDB;

CREATE TABLE DanhSachNhanEmail (
    MaDanhSach VARCHAR(20) PRIMARY KEY,
    MaThuongHieu VARCHAR(20) NOT NULL,
    TenDanhSach VARCHAR(150) NOT NULL,
    MoTa TEXT NULL,
    NenTangQuanLy VARCHAR(100) NOT NULL,
    MaThamChieu VARCHAR(150) NOT NULL,
    CONSTRAINT fk_ds_th FOREIGN KEY (MaThuongHieu) REFERENCES ThuongHieu(MaThuongHieu),
    CONSTRAINT ck_ds_noidung CHECK (CHAR_LENGTH(TRIM(TenDanhSach)) > 0 AND CHAR_LENGTH(TRIM(NenTangQuanLy)) > 0 AND CHAR_LENGTH(TRIM(MaThamChieu)) > 0)
) ENGINE=InnoDB;

CREATE TABLE HoatDongEmail_DanhSach (
    MaHoatDong VARCHAR(20) NOT NULL,
    MaDanhSach VARCHAR(20) NOT NULL,
    PRIMARY KEY (MaHoatDong, MaDanhSach),
    CONSTRAINT fk_eds_email FOREIGN KEY (MaHoatDong) REFERENCES HoatDongEmail(MaHoatDong),
    CONSTRAINT fk_eds_ds FOREIGN KEY (MaDanhSach) REFERENCES DanhSachNhanEmail(MaDanhSach)
) ENGINE=InnoDB;

CREATE TABLE TaiKhoanMangXaHoi (
    MaTKMangXaHoi VARCHAR(20) PRIMARY KEY,
    MaThuongHieu VARCHAR(20) NOT NULL,
    MaKenh VARCHAR(20) NOT NULL,
    TenHienThi VARCHAR(150) NOT NULL,
    MaTKNenTang VARCHAR(150) NOT NULL,
    DuongDanTrang VARCHAR(1000) NOT NULL,
    CONSTRAINT fk_mxh_th FOREIGN KEY (MaThuongHieu) REFERENCES ThuongHieu(MaThuongHieu),
    CONSTRAINT fk_mxh_kenh FOREIGN KEY (MaKenh) REFERENCES KenhMarketing(MaKenh),
    CONSTRAINT ck_mxh_noidung CHECK (CHAR_LENGTH(TRIM(TenHienThi)) > 0 AND CHAR_LENGTH(TRIM(MaTKNenTang)) > 0 AND CHAR_LENGTH(TRIM(DuongDanTrang)) > 0)
) ENGINE=InnoDB;

CREATE TABLE HoatDongMangXaHoi (
    MaHoatDong VARCHAR(20) PRIMARY KEY,
    MaTKMangXaHoi VARCHAR(20) NOT NULL,
    NoiDungBaiDang TEXT NULL,
    DinhDang VARCHAR(20) NULL,
    DuongDanTaiNguyen VARCHAR(1000) NULL,
    DuongDanBaiDang VARCHAR(1000) NULL,
    CONSTRAINT fk_hdmxh_hd FOREIGN KEY (MaHoatDong) REFERENCES HoatDongTrienKhai(MaHoatDong),
    CONSTRAINT fk_hdmxh_tk FOREIGN KEY (MaTKMangXaHoi) REFERENCES TaiKhoanMangXaHoi(MaTKMangXaHoi),
    CONSTRAINT ck_hdmxh_dinhdang CHECK (DinhDang IS NULL OR DinhDang IN ('VAN_BAN','HINH_ANH','VIDEO'))
) ENGINE=InnoDB;

CREATE TABLE KhoanChi (
    MaKhoanChi VARCHAR(20) PRIMARY KEY,
    MaHoatDong VARCHAR(20) NOT NULL,
    MaNguoiGhiNhan VARCHAR(20) NOT NULL,
    NgayPhatSinh DATE NOT NULL,
    SoTien DECIMAL(18,0) NOT NULL,
    NoiDungChi VARCHAR(500) NOT NULL,
    MaChungTu VARCHAR(100) NULL,
    ThoiDiemNhap DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_chi_hd FOREIGN KEY (MaHoatDong) REFERENCES HoatDongTrienKhai(MaHoatDong),
    CONSTRAINT fk_chi_nv FOREIGN KEY (MaNguoiGhiNhan) REFERENCES NhanVien(MaNhanVien),
    CONSTRAINT ck_chi_sotien CHECK (SoTien > 0),
    CONSTRAINT ck_chi_noidung CHECK (CHAR_LENGTH(TRIM(NoiDungChi)) > 0),
    INDEX ix_chi_hd_ngay (MaHoatDong, NgayPhatSinh)
) ENGINE=InnoDB;

CREATE TABLE KetQuaNgay (
    MaHoatDong VARCHAR(20) NOT NULL,
    NgayGhiNhan DATE NOT NULL,
    MaNguoiCapNhat VARCHAR(20) NOT NULL,
    LuotHienThi BIGINT NULL,
    LuotNhap BIGINT NULL,
    SoKHTiemNang BIGINT NULL,
    SoChuyenDoi BIGINT NULL,
    DoanhThu DECIMAL(18,0) NULL,
    PRIMARY KEY (MaHoatDong, NgayGhiNhan),
    CONSTRAINT fk_kq_hd FOREIGN KEY (MaHoatDong) REFERENCES HoatDongTrienKhai(MaHoatDong),
    CONSTRAINT fk_kq_nv FOREIGN KEY (MaNguoiCapNhat) REFERENCES NhanVien(MaNhanVien),
    CONSTRAINT ck_kq_hienthi CHECK (LuotHienThi IS NULL OR LuotHienThi >= 0),
    CONSTRAINT ck_kq_nhap CHECK (LuotNhap IS NULL OR LuotNhap >= 0),
    CONSTRAINT ck_kq_tiemnang CHECK (SoKHTiemNang IS NULL OR SoKHTiemNang >= 0),
    CONSTRAINT ck_kq_chuyendoi CHECK (SoChuyenDoi IS NULL OR SoChuyenDoi >= 0),
    CONSTRAINT ck_kq_doanhthu CHECK (DoanhThu IS NULL OR DoanhThu >= 0)
) ENGINE=InnoDB;
