-- P2.3 — TRUY VẤN KHOẢN CHI
-- File: database/part2/03_expense_queries.sql
--
-- Quy ước tham số:
--   p_MaChienDich / p_MaHoatDong : có giá trị NULL hoặc '' thì sẽ không lọc theo mã
--   p_TuNgay / p_DenNgay         : BẮT BUỘC; NULL hoặc ngày bị đảo thì kết quả sẽ rỗng
--   p_TuKhoa                     : NULL/rỗng thì không lọc; tìm trong
--                                  NoiDungChi và MaChungTu
--   p_SapXep                     : NGAY_TANG | NGAY_GIAM | TIEN_TANG | TIEN_GIAM
--                                  NULL/rỗng → NGAY_GIAM; giá trị khác → rỗng
--   p_TongChiToiThieu            : BẮT BUỘC; NULL/âm → rỗng
--
-- LƯU Ý: Procedure 2 tính tổng chi trong kỳ (theo p_TuNgay–p_DenNgay),
--        không phải tổng toàn lịch sử của hoạt động.
USE marketing_btl;

DROP PROCEDURE IF EXISTS sp_P2_DanhSachKhoanChi;
DELIMITER $$
CREATE PROCEDURE sp_P2_DanhSachKhoanChi(
	IN p_MaChienDich VARCHAR(20),
    IN p_MaHoatDong VARCHAR(20),
    IN p_TuNgay DATE,
    IN p_DenNgay DATE,
    IN p_TuKhoa VARCHAR(255),
    IN p_SapXep VARCHAR(20)
)
BEGIN
	DECLARE v_SapXep VARCHAR(20);
    SET v_SapXep = UPPER(TRIM(COALESCE(p_SapXep, 'NGAY_GIAM')));
    IF v_SapXep = '' THEN SET v_SapXep = 'NGAY_GIAM'; END IF;
    
    SELECT
        kc.MaKhoanChi,
        kc.MaHoatDong,
        hd.TenHoatDong,
        cd.MaChienDich,
        cd.TenChienDich,
        kc.NgayPhatSinh,
        kc.SoTien,
        kc.NoiDungChi,
        kc.MaChungTu,
        kc.MaNguoiGhiNhan,
        kc.ThoiDiemNhap
    FROM KhoanChi kc
    JOIN HoatDongTrienKhai hd ON hd.MaHoatDong = kc.MaHoatDong
    JOIN ChienDich cd        ON cd.MaChienDich = hd.MaChienDich
    WHERE
        -- Khoảng ngày bắt buộc, bao gồm 2 đầu
        p_TuNgay IS NOT NULL
        AND p_DenNgay IS NOT NULL
        AND p_TuNgay <= p_DenNgay
        AND kc.NgayPhatSinh BETWEEN p_TuNgay AND p_DenNgay
        -- Lọc mã (NULL = không lọc)
        AND (p_MaChienDich IS NULL OR p_MaChienDich = '' OR cd.MaChienDich = p_MaChienDich)
        AND (p_MaHoatDong  IS NULL OR p_MaHoatDong  = '' OR hd.MaHoatDong  = p_MaHoatDong)
        -- Từ khóa (NULL/rỗng = không lọc)
        AND (p_TuKhoa IS NULL OR p_TuKhoa = ''
             OR kc.NoiDungChi LIKE CONCAT('%', p_TuKhoa, '%')
             OR kc.MaChungTu LIKE CONCAT('%', p_TuKhoa, '%'))
        -- Sort hợp lệ (nếu sai -> WHERE false -> rỗng)
        AND v_SapXep IN ('NGAY_TANG','NGAY_GIAM','TIEN_TANG','TIEN_GIAM')
    ORDER BY
        CASE WHEN v_SapXep = 'NGAY_TANG' THEN kc.NgayPhatSinh END ASC,
        CASE WHEN v_SapXep = 'NGAY_GIAM' THEN kc.NgayPhatSinh END DESC,
        CASE WHEN v_SapXep = 'TIEN_TANG' THEN kc.SoTien END ASC,
        CASE WHEN v_SapXep = 'TIEN_GIAM' THEN kc.SoTien END DESC,
        kc.MaKhoanChi ASC;  -- tiêu chí cuối ổn định
END$$
DELIMITER ;


DROP PROCEDURE IF EXISTS sp_P2_TongChiTheoHoatDong;
DELIMITER $$
CREATE PROCEDURE sp_P2_TongChiTheoHoatDong(
    IN p_MaChienDich      VARCHAR(20),
    IN p_TuNgay           DATE,
    IN p_DenNgay          DATE,
    IN p_TongChiToiThieu  DECIMAL(38,0)
)
BEGIN
    SELECT
        cd.MaChienDich,
        cd.TenChienDich,
        hd.MaHoatDong,
        hd.TenHoatDong,
        COUNT(kc.MaKhoanChi)        AS SoKhoanChiTrongKy,
        SUM(kc.SoTien)              AS TongChiTrongKy
    FROM KhoanChi kc
    JOIN HoatDongTrienKhai hd ON hd.MaHoatDong = kc.MaHoatDong
    JOIN ChienDich cd        ON cd.MaChienDich = hd.MaChienDich
    WHERE
        -- Khoảng ngày bắt buộc
        p_TuNgay IS NOT NULL
        AND p_DenNgay IS NOT NULL
        AND p_TuNgay <= p_DenNgay
        AND kc.NgayPhatSinh BETWEEN p_TuNgay AND p_DenNgay
        -- Lọc chiến dịch (NULL = không lọc)
        AND (p_MaChienDich IS NULL OR p_MaChienDich = '' OR cd.MaChienDich = p_MaChienDich)
        -- Ngưỡng hợp lệ (NULL/âm -> rỗng)
        AND p_TongChiToiThieu IS NOT NULL
        AND p_TongChiToiThieu >= 0
    GROUP BY
        cd.MaChienDich, cd.TenChienDich,
        hd.MaHoatDong,  hd.TenHoatDong
    HAVING SUM(kc.SoTien) >= p_TongChiToiThieu
    ORDER BY
        TongChiTrongKy DESC,
        hd.MaHoatDong ASC;
END$$
DELIMITER ;

-- Minh họa 
-- Ca 1: Danh sách CD01, kỳ 05–06/11/2026
-- Kỳ vọng: KC01, KC02, KC11
-- CALL sp_P2_DanhSachKhoanChi('CD01', NULL, '2026-11-05', '2026-11-06', NULL, NULL);

-- Ca 2: Tổng chi theo hoạt động, ngưỡng 0
-- Kỳ vọng: HD01 = 2 khoản / 3.000.000; HD02 = 1 khoản / 3.500.000
-- CALL sp_P2_TongChiTheoHoatDong('CD01', '2026-11-05', '2026-11-06', 0);

-- Ca 3: Ngưỡng 3.200.000 -> chỉ HD02
-- CALL sp_P2_TongChiTheoHoatDong('CD01', '2026-11-05', '2026-11-06', 3200000);

-- Ca 4: Ngưỡng 3.500.000 -> vẫn có HD02 (biên HAVING >=)
-- CALL sp_P2_TongChiTheoHoatDong('CD01', '2026-11-05', '2026-11-06', 3500000);

-- Ca 5: Ngày đúng hai đầu kỳ (05 và 06)
-- CALL sp_P2_DanhSachKhoanChi(NULL, NULL, '2026-11-05', '2026-11-06', NULL, 'NGAY_TANG');
-- Kỳ vọng: 11 dòng — KC01, KC02, KC03, KC04, KC05, KC06, KC07, KC08, KC09, KC10 (05/11) rồi KC11 (06/11).
-- Sắp ngày tăng, cùng ngày theo MaKhoanChi tăng. Chứng minh BETWEEN bao gồm cả 2 đầu kỳ.

-- Ca 6: Lọc phối hợp chiến dịch + hoạt động
-- CALL sp_P2_DanhSachKhoanChi('CD01', 'HD01', '2026-11-05', '2026-11-06', NULL, 'TIEN_GIAM');
-- Kỳ vọng: 2 dòng — KC01 (2.500.000) rồi KC11 (500.000). Sắp tiền giảm.
-- Chứng minh lọc phối hợp: KC02 (HD02, cùng CD01) bị loại vì không thuộc HD01.

-- Ca 7: Từ khóa nội dung/chứng từ
-- CALL sp_P2_DanhSachKhoanChi(NULL, NULL, '2026-11-05', '2026-11-06', 'Chi phí', 'TIEN_TANG');
-- Kỳ vọng: 11 dòng — KC11 (500k), KC07 (600k), KC03 (700k), KC09 (800k), KC08 (900k),
-- KC05 (1.2tr), KC10 (1.5tr), KC04 (1.8tr), KC06 (2.2tr), KC01 (2.5tr), KC02 (3.5tr). Sắp tiền tăng.

-- Ca 8: Các kiểu sắp xếp
-- CALL sp_P2_DanhSachKhoanChi(NULL, NULL, '2026-11-05', '2026-11-06', NULL, 'NGAY_GIAM');
-- Kỳ vọng: 11 dòng — KC11 (06/11) đầu tiên, rồi KC01→KC10 (05/11) theo MaKhoanChi tăng.
-- CALL sp_P2_DanhSachKhoanChi(NULL, NULL, '2026-11-05', '2026-11-06', NULL, 'TIEN_TANG');
-- Kỳ vọng: 11 dòng — giống hệt Ca 7 về thứ tự: KC11, KC07, KC03, KC09, KC08, KC05, KC10, KC04, KC06, KC01, KC02.

-- Ca 9: Mã không tồn tại -> rỗng
-- CALL sp_P2_DanhSachKhoanChi('CD99', NULL, '2026-11-05', '2026-11-06', NULL, NULL);
-- CALL sp_P2_TongChiTheoHoatDong('CD99', '2026-11-05', '2026-11-06', 0);

-- Ca 10: Bộ lọc sai -> rỗng
-- CALL sp_P2_DanhSachKhoanChi(NULL, NULL, NULL, '2026-11-06', NULL, NULL);      -- ngày NULL
-- CALL sp_P2_DanhSachKhoanChi(NULL, NULL, '2026-11-06', '2026-11-05', NULL, NULL); -- ngày đảo
-- CALL sp_P2_DanhSachKhoanChi(NULL, NULL, '2026-11-05', '2026-11-06', NULL, 'SAI'); -- sort sai
-- CALL sp_P2_TongChiTheoHoatDong('CD01', '2026-11-05', '2026-11-06', NULL);     -- ngưỡng NULL
-- CALL sp_P2_TongChiTheoHoatDong('CD01', '2026-11-05', '2026-11-06', -1);       -- ngưỡng âm

-- Ca 11: Hai mã lọc không khớp (CD02 + HD01) -> rỗng
-- CALL sp_P2_DanhSachKhoanChi('CD02', 'HD01', '2026-11-05', '2026-11-06', NULL, NULL);

-- Ca 12: Gọi procedure không làm thay đổi dữ liệu (kiểm tra trước/sau)
-- SELECT COUNT(*) FROM KhoanChi;
-- CALL sp_P2_DanhSachKhoanChi(NULL, NULL, '2026-11-05', '2026-11-06', NULL, NULL);
-- SELECT COUNT(*) FROM KhoanChi;  -- phải giống nhau
