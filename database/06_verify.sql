USE marketing_btl;
CALL sp_P1_KiemTraToanVen();

SELECT 'NhanVien' AS TenBang,COUNT(*) AS SoDong FROM NhanVien
UNION ALL SELECT 'TaiKhoan',COUNT(*) FROM TaiKhoan
UNION ALL SELECT 'SoDienThoaiNhanVien',COUNT(*) FROM SoDienThoaiNhanVien
UNION ALL SELECT 'ThuongHieu',COUNT(*) FROM ThuongHieu
UNION ALL SELECT 'KenhMarketing',COUNT(*) FROM KenhMarketing
UNION ALL SELECT 'ChienDich',COUNT(*) FROM ChienDich
UNION ALL SELECT 'PhanCong',COUNT(*) FROM PhanCong
UNION ALL SELECT 'HoatDongTrienKhai',COUNT(*) FROM HoatDongTrienKhai
UNION ALL SELECT 'HoatDongEmail',COUNT(*) FROM HoatDongEmail
UNION ALL SELECT 'DanhSachNhanEmail',COUNT(*) FROM DanhSachNhanEmail
UNION ALL SELECT 'HoatDongEmail_DanhSach',COUNT(*) FROM HoatDongEmail_DanhSach
UNION ALL SELECT 'TaiKhoanMangXaHoi',COUNT(*) FROM TaiKhoanMangXaHoi
UNION ALL SELECT 'HoatDongMangXaHoi',COUNT(*) FROM HoatDongMangXaHoi
UNION ALL SELECT 'KhoanChi',COUNT(*) FROM KhoanChi
UNION ALL SELECT 'KetQuaNgay',COUNT(*) FROM KetQuaNgay;

SELECT * FROM v_ChiPhiHoatDong ORDER BY MaHoatDong;
SELECT MaHoatDong,NgayGhiNhan,SoChuyenDoi,ChiPhiTrenChuyenDoi
FROM v_KetQuaNgay WHERE (MaHoatDong='HD02' AND NgayGhiNhan='2026-11-06')
    OR (MaHoatDong='HD03' AND NgayGhiNhan='2026-11-06');

-- Ownership can be queried even before a resource is used.
SELECT d.MaDanhSach,t.TenThuongHieu FROM DanhSachNhanEmail d
JOIN ThuongHieu t USING(MaThuongHieu)
WHERE NOT EXISTS (SELECT 1 FROM HoatDongEmail_DanhSach x WHERE x.MaDanhSach=d.MaDanhSach);
SELECT m.MaTKMangXaHoi,t.TenThuongHieu FROM TaiKhoanMangXaHoi m
JOIN ThuongHieu t USING(MaThuongHieu)
WHERE NOT EXISTS (SELECT 1 FROM HoatDongMangXaHoi x WHERE x.MaTKMangXaHoi=m.MaTKMangXaHoi);
