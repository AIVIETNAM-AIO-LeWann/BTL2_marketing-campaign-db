USE marketing_btl;

CREATE ROLE IF NOT EXISTS 'marketing_web';
GRANT SELECT ON marketing_btl.ChienDich TO 'marketing_web';
GRANT SELECT ON marketing_btl.HoatDongTrienKhai TO 'marketing_web';
GRANT SELECT ON marketing_btl.KhoanChi TO 'marketing_web';
GRANT SELECT ON marketing_btl.KetQuaNgay TO 'marketing_web';
GRANT SELECT (MaNhanVien, MaChienDich) ON marketing_btl.PhanCong TO 'marketing_web';
GRANT EXECUTE ON PROCEDURE marketing_btl.sp_P2_ThemKhoanChi TO 'marketing_web';
GRANT EXECUTE ON PROCEDURE marketing_btl.sp_P2_SuaKhoanChi TO 'marketing_web';
GRANT EXECUTE ON PROCEDURE marketing_btl.sp_P2_XoaKhoanChi TO 'marketing_web';
GRANT EXECUTE ON PROCEDURE marketing_btl.sp_P2_DanhSachKhoanChi TO 'marketing_web';
GRANT EXECUTE ON PROCEDURE marketing_btl.sp_P2_TongChiTheoHoatDong TO 'marketing_web';
GRANT EXECUTE ON FUNCTION marketing_btl.fn_P2_DemHoatDongVuotNganSach TO 'marketing_web';
GRANT EXECUTE ON FUNCTION marketing_btl.fn_P2_ChiPhiTrenChuyenDoi TO 'marketing_web';
