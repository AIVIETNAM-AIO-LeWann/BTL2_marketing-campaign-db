USE marketing_btl;
-- Read models for RB01/RB08/RB12; no new physical business tables.
CREATE VIEW v_ThoiLuongChienDich AS
SELECT MaChienDich, DATEDIFF(NgayKetThucDuKien,NgayBatDau)+1 AS ThoiLuongDuKien
FROM ChienDich;

-- Aggregate expenses BEFORE joining daily results to avoid multiplying expenses.
-- No WHERE requirement is added to NgayPhatSinh: BTL1 does not forbid a cost
-- before launch (e.g. producing content) or after the planned activity period.
CREATE VIEW v_KetQuaNgay AS
SELECT q.*,
    COALESCE(k.ChiPhiNgay,0) AS ChiPhiNgay,
    CASE WHEN q.LuotNhap IS NOT NULL AND q.LuotHienThi>0
        THEN q.LuotNhap/q.LuotHienThi ELSE NULL END AS TyLeNhap,
    CASE WHEN q.SoChuyenDoi>0 THEN COALESCE(k.ChiPhiNgay,0)/q.SoChuyenDoi
        ELSE NULL END AS ChiPhiTrenChuyenDoi
FROM KetQuaNgay q
LEFT JOIN (SELECT MaHoatDong,NgayPhatSinh,SUM(SoTien) AS ChiPhiNgay
    FROM KhoanChi GROUP BY MaHoatDong,NgayPhatSinh) k
ON k.MaHoatDong=q.MaHoatDong AND k.NgayPhatSinh=q.NgayGhiNhan;

CREATE VIEW v_ChiPhiHoatDong AS
SELECT h.MaHoatDong,h.MaChienDich,h.TenHoatDong,h.NganSachDuocCap,
    COALESCE(k.TongChiPhi,0) AS TongChiPhiThucTe,
    COALESCE(k.TongChiPhi,0)-h.NganSachDuocCap AS ChenhLechNganSach
FROM HoatDongTrienKhai h
LEFT JOIN (SELECT MaHoatDong,SUM(SoTien) AS TongChiPhi FROM KhoanChi GROUP BY MaHoatDong) k
    ON k.MaHoatDong=h.MaHoatDong;

-- Ratios across the COMPLETE planned activity period. Missing days/NULL metrics
-- yield NULL, not a misleading partial ratio. Part 2 will add date parameters.
CREATE VIEW v_HieuQuaHoatDong AS
SELECT h.MaHoatDong,
    CASE WHEN q.SoNgay=DATEDIFF(h.NgayKetThucDuKien,h.NgayBatDau)+1
          AND q.SoNgayDuNhap=q.SoNgay AND q.SoNgayDuHienThi=q.SoNgay AND q.TongHienThi>0
        THEN q.TongNhap/q.TongHienThi ELSE NULL END AS TyLeNhap,
    CASE WHEN q.SoNgay=DATEDIFF(h.NgayKetThucDuKien,h.NgayBatDau)+1
          AND q.SoNgayDuChuyenDoi=q.SoNgay AND q.TongChuyenDoi>0
        THEN COALESCE(k.TongChiPhi,0)/q.TongChuyenDoi ELSE NULL END AS ChiPhiTrenChuyenDoi
FROM HoatDongTrienKhai h
LEFT JOIN (SELECT MaHoatDong,COUNT(*) AS SoNgay,COUNT(LuotNhap) AS SoNgayDuNhap,
    COUNT(LuotHienThi) AS SoNgayDuHienThi,COUNT(SoChuyenDoi) AS SoNgayDuChuyenDoi,
    SUM(LuotNhap) AS TongNhap,SUM(LuotHienThi) AS TongHienThi,SUM(SoChuyenDoi) AS TongChuyenDoi
    FROM KetQuaNgay GROUP BY MaHoatDong) q ON q.MaHoatDong=h.MaHoatDong
LEFT JOIN (SELECT k.MaHoatDong,SUM(k.SoTien) AS TongChiPhi FROM KhoanChi k
    JOIN HoatDongTrienKhai x ON x.MaHoatDong=k.MaHoatDong
    WHERE k.NgayPhatSinh BETWEEN x.NgayBatDau AND x.NgayKetThucDuKien
    GROUP BY k.MaHoatDong) k ON k.MaHoatDong=h.MaHoatDong;
