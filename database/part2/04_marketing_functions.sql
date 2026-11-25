-- P2.4 — Hai hàm tính toán, mỗi hàm có validate, truy vấn, cursor, IF và LOOP.
-- Chạy sau phần 1; chỉ đọc dữ liệu, không sửa bảng hoặc tự mở giao dịch.
USE marketing_btl;
SET NAMES utf8mb4;
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,ONLY_FULL_GROUP_BY,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

DROP FUNCTION IF EXISTS fn_P2_DemHoatDongVuotNganSach;
DROP FUNCTION IF EXISTS fn_P2_ChiPhiTrenChuyenDoi;

DELIMITER $$

-- Thực chi toàn lịch sử > ngân sách được cấp mới được tính là vượt.
-- Không dùng ngân sách chiến dịch làm mẫu so sánh, không cộng kết quả ngày
-- vào truy vấn chi phí. Tính từ KhoanChi để độc lập với cột tổng lưu ở P2.2.
CREATE FUNCTION fn_P2_DemHoatDongVuotNganSach(p_MaChienDich VARCHAR(100))
RETURNS BIGINT UNSIGNED
NOT DETERMINISTIC
READS SQL DATA
SQL SECURITY INVOKER
BEGIN
    DECLARE v_HetDong BOOLEAN DEFAULT FALSE;
    DECLARE v_NganSach DECIMAL(18,0);
    DECLARE v_ThucChi DECIMAL(38,0);
    DECLARE v_SoHoatDong BIGINT UNSIGNED DEFAULT 0;

    DECLARE cur_HoatDong CURSOR FOR
        SELECT h.NganSachDuocCap, COALESCE(SUM(k.SoTien),0)
        FROM HoatDongTrienKhai h
        LEFT JOIN KhoanChi k ON k.MaHoatDong=h.MaHoatDong
        WHERE h.MaChienDich=p_MaChienDich
        GROUP BY h.MaHoatDong,h.NganSachDuocCap
        ORDER BY h.MaHoatDong;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_HetDong=TRUE;

    IF p_MaChienDich IS NULL OR CHAR_LENGTH(TRIM(p_MaChienDich))=0
       OR CHAR_LENGTH(p_MaChienDich)>20
       OR CHAR_LENGTH(p_MaChienDich)<>CHAR_LENGTH(TRIM(p_MaChienDich)) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT='P2_FN_INPUT: MaChienDich bat buoc, toi da 20 ky tu, khong co dau cach dau/cuoi.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM ChienDich WHERE MaChienDich=p_MaChienDich) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_FN_NOTFOUND: Chien dich khong ton tai.';
    END IF;

    OPEN cur_HoatDong;
    doc_HoatDong: LOOP
        FETCH cur_HoatDong INTO v_NganSach,v_ThucChi;
        IF v_HetDong THEN LEAVE doc_HoatDong; END IF;
        IF v_ThucChi>v_NganSach THEN
            SET v_SoHoatDong=v_SoHoatDong+1;
        END IF;
    END LOOP;
    CLOSE cur_HoatDong;
    RETURN v_SoHoatDong;
END$$

-- CPA trong kỳ = tổng chi PHÁT SINH trong kỳ / tổng chuyển đổi trong kỳ.
-- Bao gồm hai đầu ngày; kỳ phải nằm trong thời gian hoạt động.
-- Thiếu ngày kết quả, có chuyển đổi NULL hoặc tổng chuyển đổi = 0: trả NULL.
-- Chi phí là số đã ghi nhận; không có khoản chi trong ngày được tính là 0.
CREATE FUNCTION fn_P2_ChiPhiTrenChuyenDoi(
    p_MaHoatDong VARCHAR(100), p_TuNgay DATE, p_DenNgay DATE
)
RETURNS DECIMAL(48,4)
NOT DETERMINISTIC
READS SQL DATA
SQL SECURITY INVOKER
BEGIN
    DECLARE v_HetDong BOOLEAN DEFAULT FALSE;
    DECLARE v_ThieuChuyenDoi BOOLEAN DEFAULT FALSE;
    DECLARE v_BatDau DATE;
    DECLARE v_KetThuc DATE;
    DECLARE v_ChuyenDoiNgay BIGINT;
    DECLARE v_ChiPhiNgay DECIMAL(38,0);
    DECLARE v_TongChuyenDoi DECIMAL(38,0) DEFAULT 0;
    DECLARE v_TongChiPhi DECIMAL(38,0) DEFAULT 0;
    DECLARE v_SoNgay INT UNSIGNED DEFAULT 0;
    DECLARE v_ChiPhiNhan10000 DECIMAL(42,0);
    DECLARE v_PhanDu DECIMAL(38,0);
    DECLARE v_DonViLamTron DECIMAL(42,0);

    -- Gộp khoản chi theo ngày TRƯỚC khi nối kết quả ngày, tránh nhân bản
    -- chi phí/chuyển đổi khi một ngày có nhiều khoản chi (HD01 ngày 05/11).
    DECLARE cur_KetQua CURSOR FOR
        SELECT q.SoChuyenDoi,COALESCE(k.ChiPhiNgay,0)
        FROM KetQuaNgay q
        LEFT JOIN (
            SELECT NgayPhatSinh,SUM(SoTien) AS ChiPhiNgay
            FROM KhoanChi
            WHERE MaHoatDong=p_MaHoatDong
              AND NgayPhatSinh BETWEEN p_TuNgay AND p_DenNgay
            GROUP BY NgayPhatSinh
        ) k ON k.NgayPhatSinh=q.NgayGhiNhan
        WHERE q.MaHoatDong=p_MaHoatDong
          AND q.NgayGhiNhan BETWEEN p_TuNgay AND p_DenNgay
        ORDER BY q.NgayGhiNhan;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_HetDong=TRUE;

    IF p_MaHoatDong IS NULL OR CHAR_LENGTH(TRIM(p_MaHoatDong))=0
       OR CHAR_LENGTH(p_MaHoatDong)>20
       OR CHAR_LENGTH(p_MaHoatDong)<>CHAR_LENGTH(TRIM(p_MaHoatDong)) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT='P2_FN_INPUT: MaHoatDong bat buoc, toi da 20 ky tu, khong co dau cach dau/cuoi.';
    END IF;
    IF p_TuNgay IS NULL OR p_DenNgay IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_FN_INPUT: TuNgay va DenNgay bat buoc.';
    END IF;
    IF p_TuNgay<'1000-01-01' OR p_DenNgay<'1000-01-01'
       OR MONTH(p_TuNgay)=0 OR DAY(p_TuNgay)=0
       OR MONTH(p_DenNgay)=0 OR DAY(p_DenNgay)=0
       OR DAY(p_TuNgay)>DAY(LAST_DAY(p_TuNgay))
       OR DAY(p_DenNgay)>DAY(LAST_DAY(p_DenNgay)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_FN_INPUT: Ngay phai la ngay lich hop le tu 1000-01-01.';
    END IF;
    IF p_TuNgay>p_DenNgay THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_FN_INPUT: TuNgay khong duoc sau DenNgay.';
    END IF;

    -- Aggregate luôn trả một dòng, không kích hoạt handler hết cursor.
    SELECT MIN(NgayBatDau),MAX(NgayKetThucDuKien) INTO v_BatDau,v_KetThuc
    FROM HoatDongTrienKhai WHERE MaHoatDong=p_MaHoatDong;
    IF v_BatDau IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_FN_NOTFOUND: Hoat dong khong ton tai.';
    END IF;
    IF p_TuNgay<v_BatDau OR p_DenNgay>v_KetThuc THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='P2_FN_INPUT: Khoang ngay phai nam trong thoi gian hoat dong.';
    END IF;

    OPEN cur_KetQua;
    doc_KetQua: LOOP
        FETCH cur_KetQua INTO v_ChuyenDoiNgay,v_ChiPhiNgay;
        IF v_HetDong THEN LEAVE doc_KetQua; END IF;
        SET v_SoNgay=v_SoNgay+1;
        SET v_TongChiPhi=v_TongChiPhi+v_ChiPhiNgay;
        IF v_ChuyenDoiNgay IS NULL THEN
            SET v_ThieuChuyenDoi=TRUE;
        ELSE
            SET v_TongChuyenDoi=v_TongChuyenDoi+v_ChuyenDoiNgay;
        END IF;
    END LOOP;
    CLOSE cur_KetQua;

    IF v_SoNgay<>DATEDIFF(p_DenNgay,p_TuNgay)+1
       OR v_ThieuChuyenDoi OR v_TongChuyenDoi=0 THEN
        RETURN NULL;
    END IF;
    -- Làm tròn chính xác theo đơn vị 0.0001 VND, không làm tròn hai lần.
    -- Phép chia dưới đây có kết quả nguyên chính xác vì đã trừ phần dư.
    -- Do đó không phụ thuộc div_precision_increment của phiên gọi.
    SET v_ChiPhiNhan10000=v_TongChiPhi*10000;
    SET v_PhanDu=MOD(v_ChiPhiNhan10000,v_TongChuyenDoi);
    SET v_DonViLamTron=(v_ChiPhiNhan10000-v_PhanDu)/v_TongChuyenDoi;
    IF v_PhanDu*2>=v_TongChuyenDoi THEN
        SET v_DonViLamTron=v_DonViLamTron+1;
    END IF;
    RETURN v_DonViLamTron*0.0001;
END$$

DELIMITER ;

-- Role này đã có SELECT ở phần 1; không cấp quyền ghi bảng.
GRANT EXECUTE ON FUNCTION marketing_btl.fn_P2_DemHoatDongVuotNganSach TO 'marketing_p1';
GRANT EXECUTE ON FUNCTION marketing_btl.fn_P2_ChiPhiTrenChuyenDoi TO 'marketing_p1';

-- Minh họa trên seed, chạy từng SELECT khi báo cáo:
-- SELECT fn_P2_DemHoatDongVuotNganSach('CD01'); -- 2 (HD01, HD02)
-- SELECT fn_P2_DemHoatDongVuotNganSach('CD02'); -- 0
-- SELECT fn_P2_ChiPhiTrenChuyenDoi('HD01','2026-11-05','2026-11-06'); -- 3000000/13 = 230769.2308
-- SELECT fn_P2_ChiPhiTrenChuyenDoi('HD01','2026-11-05','2026-11-05'); -- 2500000/6 = 416666.6667
-- SELECT fn_P2_ChiPhiTrenChuyenDoi('HD02','2026-11-06','2026-11-06'); -- NULL: chuyển đổi 0
-- SELECT fn_P2_ChiPhiTrenChuyenDoi('HD03','2026-11-05','2026-11-06'); -- NULL: chuyển đổi chưa biết
-- SELECT fn_P2_ChiPhiTrenChuyenDoi('HD01','2026-11-05','2026-11-07'); -- NULL: thiếu ngày 07
-- SELECT fn_P2_DemHoatDongVuotNganSach('KHONG_CO'); -- P2_FN_NOTFOUND
-- SELECT fn_P2_ChiPhiTrenChuyenDoi('HD01','2026-11-06','2026-11-05'); -- P2_FN_INPUT
