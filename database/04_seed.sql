-- Fictional Vietnamese brands and people; all monetary values are VND.
USE marketing_btl;
SET NAMES utf8mb4;
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;


INSERT INTO ThuongHieu VALUES ('TH01','An Nhiên','Thực phẩm và đồ uống','https://th01.example','contact@th01.example');

INSERT INTO ThuongHieu VALUES ('TH02','Bước Việt','Giày thể thao','https://th02.example','contact@th02.example');

INSERT INTO ThuongHieu VALUES ('TH03','Mộc Gia','Đồ gia dụng','https://th03.example','contact@th03.example');

INSERT INTO ThuongHieu VALUES ('TH04','Sắc Mây','Thời trang','https://th04.example','contact@th04.example');

INSERT INTO ThuongHieu VALUES ('TH05','Học Mở','Giáo dục','https://th05.example','contact@th05.example');

INSERT INTO KenhMarketing VALUES ('K_EMAIL_A','Email qua Zoho','EMAIL',NULL);

INSERT INTO KenhMarketing VALUES ('K_EMAIL_B','Email qua Mailchimp','EMAIL',NULL);

INSERT INTO KenhMarketing VALUES ('K_FACEBOOK','Facebook','MANG_XA_HOI',NULL);

INSERT INTO KenhMarketing VALUES ('K_INSTAGRAM','Instagram','MANG_XA_HOI',NULL);

INSERT INTO KenhMarketing VALUES ('K_LINKEDIN','LinkedIn','MANG_XA_HOI',NULL);

CALL sp_P1_TaoNhanVien('{"MaNhanVien": "NV01", "Ho": "Nguyễn", "TenDem": "Văn", "Ten": "An", "Email": "nv01@marketing.example", "NgayVaoLam": "2025-08-01", "MaNguoiGiamSat": null}','{"MaTK": "TK01", "TenDangNhap": "nv01", "MatKhauBam": "!seed-no-login-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", "VaiTro": "QUAN_TRI"}');

INSERT INTO SoDienThoaiNhanVien VALUES ('NV01','0900000001');

CALL sp_P1_TaoNhanVien('{"MaNhanVien": "NV02", "Ho": "Trần", "TenDem": "Minh", "Ten": "Bình", "Email": "nv02@marketing.example", "NgayVaoLam": "2025-08-01", "MaNguoiGiamSat": "NV01"}','{"MaTK": "TK02", "TenDangNhap": "nv02", "MatKhauBam": "!seed-no-login-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", "VaiTro": "QUAN_LY_MARKETING"}');

INSERT INTO SoDienThoaiNhanVien VALUES ('NV02','0900000002');

CALL sp_P1_TaoNhanVien('{"MaNhanVien": "NV03", "Ho": "Lê", "TenDem": "Thu", "Ten": "Chi", "Email": "nv03@marketing.example", "NgayVaoLam": "2025-08-01", "MaNguoiGiamSat": "NV01"}','{"MaTK": "TK03", "TenDangNhap": "nv03", "MatKhauBam": "!seed-no-login-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", "VaiTro": "QUAN_LY_MARKETING"}');

INSERT INTO SoDienThoaiNhanVien VALUES ('NV03','0900000003');

CALL sp_P1_TaoNhanVien('{"MaNhanVien": "NV04", "Ho": "Phạm", "TenDem": "Quốc", "Ten": "Dũng", "Email": "nv04@marketing.example", "NgayVaoLam": "2025-08-01", "MaNguoiGiamSat": "NV02"}','{"MaTK": "TK04", "TenDangNhap": "nv04", "MatKhauBam": "!seed-no-login-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", "VaiTro": "NHAN_VIEN_MARKETING"}');

INSERT INTO SoDienThoaiNhanVien VALUES ('NV04','0900000004');

CALL sp_P1_TaoNhanVien('{"MaNhanVien": "NV05", "Ho": "Võ", "TenDem": "Ngọc", "Ten": "Hà", "Email": "nv05@marketing.example", "NgayVaoLam": "2025-08-01", "MaNguoiGiamSat": "NV03"}','{"MaTK": "TK05", "TenDangNhap": "nv05", "MatKhauBam": "!seed-no-login-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", "VaiTro": "NHAN_VIEN_MARKETING"}');

INSERT INTO SoDienThoaiNhanVien VALUES ('NV05','0900000005');

CALL sp_P1_TaoNhanVien('{"MaNhanVien": "NV06", "Ho": "Đặng", "TenDem": "Hoài", "Ten": "Linh", "Email": "nv06@marketing.example", "NgayVaoLam": "2025-08-01", "MaNguoiGiamSat": "NV02"}','{"MaTK": "TK06", "TenDangNhap": "nv06", "MatKhauBam": "!seed-no-login-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", "VaiTro": "NHAN_VIEN_MARKETING"}');

INSERT INTO SoDienThoaiNhanVien VALUES ('NV06','0900000006');

CALL sp_P1_TaoNhanVien('{"MaNhanVien": "NV07", "Ho": "Bùi", "TenDem": "Anh", "Ten": "Minh", "Email": "nv07@marketing.example", "NgayVaoLam": "2025-08-01", "MaNguoiGiamSat": "NV03"}','{"MaTK": "TK07", "TenDangNhap": "nv07", "MatKhauBam": "!seed-no-login-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", "VaiTro": "NHAN_VIEN_MARKETING"}');

INSERT INTO SoDienThoaiNhanVien VALUES ('NV07','0900000007');

CALL sp_P1_TaoNhanVien('{"MaNhanVien": "NV08", "Ho": "Đỗ", "TenDem": null, "Ten": "Phúc", "Email": "nv08@marketing.example", "NgayVaoLam": "2025-08-01", "MaNguoiGiamSat": "NV02"}','{"MaTK": "TK08", "TenDangNhap": "nv08", "MatKhauBam": "!seed-no-login-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", "VaiTro": "NHAN_VIEN_MARKETING"}');

INSERT INTO SoDienThoaiNhanVien VALUES ('NV08','0900000008');

INSERT INTO SoDienThoaiNhanVien VALUES ('NV04','0910000004');

CALL sp_P1_TaoChienDich('{"MaChienDich": "CD01", "TenChienDich": "Ra mắt trà thảo mộc", "MucTieu": "Tăng đơn hàng và nhận diện thương hiệu", "MoTaDoiTuongHuongToi": "Khách hàng 18–35 tuổi tại Việt Nam", "CachXacDinhChuyenDoi": "Đơn hàng thanh toán thành công", "NgayBatDau": "2026-11-01", "NgayKetThucDuKien": "2026-11-30", "NganSachDuocDuyet": 20000000, "MaThuongHieu": "TH01", "MaNhanVien": "NV02"}');

INSERT INTO PhanCong VALUES ('NV04','CD01','Triển khai nội dung, ghi nhận chi phí và kết quả','2026-11-01','2026-11-30');

INSERT INTO DanhSachNhanEmail VALUES ('DS01','TH01','Khách hàng quan tâm tháng 11',NULL,'Zoho Campaigns','external-list-01');

INSERT INTO TaiKhoanMangXaHoi VALUES ('MXH01','TH01','K_FACEBOOK','An Nhiên Official','platform-account-01','https://social.example/account-01');

CALL sp_P1_TaoChienDich('{"MaChienDich": "CD02", "TenChienDich": "Giày chạy mùa mới", "MucTieu": "Tăng đơn hàng và nhận diện thương hiệu", "MoTaDoiTuongHuongToi": "Khách hàng 18–35 tuổi tại Việt Nam", "CachXacDinhChuyenDoi": "Đơn hàng thanh toán thành công", "NgayBatDau": "2026-11-01", "NgayKetThucDuKien": "2026-11-30", "NganSachDuocDuyet": 12000000, "MaThuongHieu": "TH02", "MaNhanVien": "NV03"}');

INSERT INTO PhanCong VALUES ('NV05','CD02','Triển khai nội dung, ghi nhận chi phí và kết quả','2026-11-01','2026-11-30');

INSERT INTO DanhSachNhanEmail VALUES ('DS02','TH02','Khách hàng quan tâm tháng 11',NULL,'Zoho Campaigns','external-list-02');

INSERT INTO TaiKhoanMangXaHoi VALUES ('MXH02','TH02','K_INSTAGRAM','Bước Việt Official','platform-account-02','https://social.example/account-02');

CALL sp_P1_TaoChienDich('{"MaChienDich": "CD03", "TenChienDich": "Gian bếp tiện nghi", "MucTieu": "Tăng đơn hàng và nhận diện thương hiệu", "MoTaDoiTuongHuongToi": "Khách hàng 18–35 tuổi tại Việt Nam", "CachXacDinhChuyenDoi": "Đơn hàng thanh toán thành công", "NgayBatDau": "2026-11-01", "NgayKetThucDuKien": "2026-11-30", "NganSachDuocDuyet": 15000000, "MaThuongHieu": "TH03", "MaNhanVien": "NV02"}');

INSERT INTO PhanCong VALUES ('NV06','CD03','Triển khai nội dung, ghi nhận chi phí và kết quả','2026-11-01','2026-11-30');

INSERT INTO DanhSachNhanEmail VALUES ('DS03','TH03','Khách hàng quan tâm tháng 11',NULL,'Zoho Campaigns','external-list-03');

INSERT INTO TaiKhoanMangXaHoi VALUES ('MXH03','TH03','K_LINKEDIN','Mộc Gia Official','platform-account-03','https://social.example/account-03');

CALL sp_P1_TaoChienDich('{"MaChienDich": "CD04", "TenChienDich": "Bộ sưu tập cuối năm", "MucTieu": "Tăng đơn hàng và nhận diện thương hiệu", "MoTaDoiTuongHuongToi": "Khách hàng 18–35 tuổi tại Việt Nam", "CachXacDinhChuyenDoi": "Đơn hàng thanh toán thành công", "NgayBatDau": "2026-11-01", "NgayKetThucDuKien": "2026-11-30", "NganSachDuocDuyet": 8000000, "MaThuongHieu": "TH04", "MaNhanVien": "NV03"}');

INSERT INTO PhanCong VALUES ('NV07','CD04','Triển khai nội dung, ghi nhận chi phí và kết quả','2026-11-01','2026-11-30');

INSERT INTO DanhSachNhanEmail VALUES ('DS04','TH04','Khách hàng quan tâm tháng 11',NULL,'Zoho Campaigns','external-list-04');

INSERT INTO TaiKhoanMangXaHoi VALUES ('MXH04','TH04','K_FACEBOOK','Sắc Mây Official','platform-account-04','https://social.example/account-04');

CALL sp_P1_TaoChienDich('{"MaChienDich": "CD05", "TenChienDich": "Khóa học SQL nền tảng", "MucTieu": "Tăng đơn hàng và nhận diện thương hiệu", "MoTaDoiTuongHuongToi": "Khách hàng 18–35 tuổi tại Việt Nam", "CachXacDinhChuyenDoi": "Đơn hàng thanh toán thành công", "NgayBatDau": "2026-11-01", "NgayKetThucDuKien": "2026-11-30", "NganSachDuocDuyet": 10000000, "MaThuongHieu": "TH05", "MaNhanVien": "NV02"}');

INSERT INTO PhanCong VALUES ('NV08','CD05','Triển khai nội dung, ghi nhận chi phí và kết quả','2026-11-01','2026-11-30');

INSERT INTO DanhSachNhanEmail VALUES ('DS05','TH05','Khách hàng quan tâm tháng 11',NULL,'Zoho Campaigns','external-list-05');

INSERT INTO TaiKhoanMangXaHoi VALUES ('MXH05','TH05','K_INSTAGRAM','Học Mở Official','platform-account-05','https://social.example/account-05');

INSERT INTO DanhSachNhanEmail VALUES ('DS06','TH01','Khách hàng mới tháng 12','Chưa sử dụng trong hoạt động nào','Zoho Campaigns','external-list-06');

INSERT INTO TaiKhoanMangXaHoi VALUES ('MXH06','TH01','K_LINKEDIN','An Nhiên Careers','platform-account-06','https://social.example/account-06');

CALL sp_P1_TaoHoatDong('{"MaHoatDong": "HD01", "TenHoatDong": "Email giới thiệu sản phẩm — Ra mắt trà thảo mộc", "MoTa": "Nội dung phục vụ chiến dịch tháng 11", "NgayBatDau": "2026-11-05", "NgayKetThucDuKien": "2026-11-20", "NganSachDuocCap": 2000000, "MaKenh": "K_EMAIL_A", "MaChienDich": "CD01", "MaNhanVien": "NV04"}','{"TieuDeThu": "Ra mắt trà thảo mộc", "DiaChiGui": "news@th01.example", "TenNguoiGui": "An Nhiên", "DuongDanNoiDung": "https://assets.example/hd01.html"}','["DS01"]');

CALL sp_P1_TaoHoatDong('{"MaHoatDong": "HD02", "TenHoatDong": "Bài đăng mạng xã hội — Ra mắt trà thảo mộc", "MoTa": "Nội dung phục vụ chiến dịch tháng 11", "NgayBatDau": "2026-11-05", "NgayKetThucDuKien": "2026-11-20", "NganSachDuocCap": 3000000, "MaKenh": "K_FACEBOOK", "MaChienDich": "CD01", "MaNhanVien": "NV04"}','{"MaTKMangXaHoi": "MXH01", "NoiDungBaiDang": "Khám phá sản phẩm và ưu đãi tháng 11.", "DinhDang": "HINH_ANH", "DuongDanTaiNguyen": "https://assets.example/hd02.png", "DuongDanBaiDang": null}','[]');

CALL sp_P1_TaoHoatDong('{"MaHoatDong": "HD03", "TenHoatDong": "Email giới thiệu sản phẩm — Giày chạy mùa mới", "MoTa": "Nội dung phục vụ chiến dịch tháng 11", "NgayBatDau": "2026-11-05", "NgayKetThucDuKien": "2026-11-20", "NganSachDuocCap": 2000000, "MaKenh": "K_EMAIL_B", "MaChienDich": "CD02", "MaNhanVien": "NV05"}','{"TieuDeThu": "Giày chạy mùa mới", "DiaChiGui": "news@th02.example", "TenNguoiGui": "Bước Việt", "DuongDanNoiDung": "https://assets.example/hd03.html"}','["DS02"]');

CALL sp_P1_TaoHoatDong('{"MaHoatDong": "HD04", "TenHoatDong": "Bài đăng mạng xã hội — Giày chạy mùa mới", "MoTa": "Nội dung phục vụ chiến dịch tháng 11", "NgayBatDau": "2026-11-05", "NgayKetThucDuKien": "2026-11-20", "NganSachDuocCap": 3000000, "MaKenh": "K_INSTAGRAM", "MaChienDich": "CD02", "MaNhanVien": "NV05"}','{"MaTKMangXaHoi": "MXH02", "NoiDungBaiDang": "Khám phá sản phẩm và ưu đãi tháng 11.", "DinhDang": "HINH_ANH", "DuongDanTaiNguyen": "https://assets.example/hd04.png", "DuongDanBaiDang": null}','[]');

CALL sp_P1_TaoHoatDong('{"MaHoatDong": "HD05", "TenHoatDong": "Email giới thiệu sản phẩm — Gian bếp tiện nghi", "MoTa": "Nội dung phục vụ chiến dịch tháng 11", "NgayBatDau": "2026-11-05", "NgayKetThucDuKien": "2026-11-20", "NganSachDuocCap": 2000000, "MaKenh": "K_EMAIL_A", "MaChienDich": "CD03", "MaNhanVien": "NV06"}','{"TieuDeThu": "Gian bếp tiện nghi", "DiaChiGui": "news@th03.example", "TenNguoiGui": "Mộc Gia", "DuongDanNoiDung": "https://assets.example/hd05.html"}','["DS03"]');

CALL sp_P1_TaoHoatDong('{"MaHoatDong": "HD06", "TenHoatDong": "Bài đăng mạng xã hội — Gian bếp tiện nghi", "MoTa": "Nội dung phục vụ chiến dịch tháng 11", "NgayBatDau": "2026-11-05", "NgayKetThucDuKien": "2026-11-20", "NganSachDuocCap": 3000000, "MaKenh": "K_LINKEDIN", "MaChienDich": "CD03", "MaNhanVien": "NV06"}','{"MaTKMangXaHoi": "MXH03", "NoiDungBaiDang": "Khám phá sản phẩm và ưu đãi tháng 11.", "DinhDang": "HINH_ANH", "DuongDanTaiNguyen": "https://assets.example/hd06.png", "DuongDanBaiDang": null}','[]');

CALL sp_P1_TaoHoatDong('{"MaHoatDong": "HD07", "TenHoatDong": "Email giới thiệu sản phẩm — Bộ sưu tập cuối năm", "MoTa": "Nội dung phục vụ chiến dịch tháng 11", "NgayBatDau": "2026-11-05", "NgayKetThucDuKien": "2026-11-20", "NganSachDuocCap": 2000000, "MaKenh": "K_EMAIL_B", "MaChienDich": "CD04", "MaNhanVien": "NV07"}','{"TieuDeThu": "Bộ sưu tập cuối năm", "DiaChiGui": "news@th04.example", "TenNguoiGui": "Sắc Mây", "DuongDanNoiDung": "https://assets.example/hd07.html"}','["DS04"]');

CALL sp_P1_TaoHoatDong('{"MaHoatDong": "HD08", "TenHoatDong": "Bài đăng mạng xã hội — Bộ sưu tập cuối năm", "MoTa": "Nội dung phục vụ chiến dịch tháng 11", "NgayBatDau": "2026-11-05", "NgayKetThucDuKien": "2026-11-20", "NganSachDuocCap": 3000000, "MaKenh": "K_FACEBOOK", "MaChienDich": "CD04", "MaNhanVien": "NV07"}','{"MaTKMangXaHoi": "MXH04", "NoiDungBaiDang": "Khám phá sản phẩm và ưu đãi tháng 11.", "DinhDang": "HINH_ANH", "DuongDanTaiNguyen": "https://assets.example/hd08.png", "DuongDanBaiDang": null}','[]');

CALL sp_P1_TaoHoatDong('{"MaHoatDong": "HD09", "TenHoatDong": "Email giới thiệu sản phẩm — Khóa học SQL nền tảng", "MoTa": "Nội dung phục vụ chiến dịch tháng 11", "NgayBatDau": "2026-11-05", "NgayKetThucDuKien": "2026-11-20", "NganSachDuocCap": 2000000, "MaKenh": "K_EMAIL_A", "MaChienDich": "CD05", "MaNhanVien": "NV08"}','{"TieuDeThu": "Khóa học SQL nền tảng", "DiaChiGui": "news@th05.example", "TenNguoiGui": "Học Mở", "DuongDanNoiDung": "https://assets.example/hd09.html"}','["DS05"]');

CALL sp_P1_TaoHoatDong('{"MaHoatDong": "HD10", "TenHoatDong": "Bài đăng mạng xã hội — Khóa học SQL nền tảng", "MoTa": "Nội dung phục vụ chiến dịch tháng 11", "NgayBatDau": "2026-11-05", "NgayKetThucDuKien": "2026-11-20", "NganSachDuocCap": 3000000, "MaKenh": "K_INSTAGRAM", "MaChienDich": "CD05", "MaNhanVien": "NV08"}','{"MaTKMangXaHoi": "MXH05", "NoiDungBaiDang": "Khám phá sản phẩm và ưu đãi tháng 11.", "DinhDang": "HINH_ANH", "DuongDanTaiNguyen": "https://assets.example/hd10.png", "DuongDanBaiDang": null}','[]');

UPDATE ChienDich SET TrangThai='DA_DUYET';

UPDATE ChienDich SET TrangThai='DANG_THUC_HIEN';

UPDATE HoatDongTrienKhai SET TrangThai='DANG_THUC_HIEN';

INSERT INTO KhoanChi VALUES ('KC01','HD01','NV04','2026-11-05',2500000,'Chi phí triển khai ngày đầu','CT-01' ,'2026-11-05 18:00:00');

INSERT INTO KetQuaNgay VALUES ('HD01','2026-11-05','NV04',1100,105,21,6,1200000);

INSERT INTO KetQuaNgay VALUES ('HD01','2026-11-06','NV04',1100,105,21,7,1400000);

INSERT INTO KhoanChi VALUES ('KC02','HD02','NV04','2026-11-05',3500000,'Chi phí triển khai ngày đầu','CT-02' ,'2026-11-05 18:00:00');

INSERT INTO KetQuaNgay VALUES ('HD02','2026-11-05','NV04',1200,110,22,7,1400000);

INSERT INTO KetQuaNgay VALUES ('HD02','2026-11-06','NV04',1200,110,22,0,0);

INSERT INTO KhoanChi VALUES ('KC03','HD03','NV05','2026-11-05',700000,'Chi phí triển khai ngày đầu',NULL ,'2026-11-05 18:00:00');

INSERT INTO KetQuaNgay VALUES ('HD03','2026-11-05','NV05',1300,115,23,8,1600000);

INSERT INTO KetQuaNgay VALUES ('HD03','2026-11-06','NV05',1300,NULL,23,NULL,NULL);

INSERT INTO KhoanChi VALUES ('KC04','HD04','NV05','2026-11-05',1800000,'Chi phí triển khai ngày đầu','CT-04' ,'2026-11-05 18:00:00');

INSERT INTO KetQuaNgay VALUES ('HD04','2026-11-05','NV05',1400,120,24,9,1800000);

INSERT INTO KetQuaNgay VALUES ('HD04','2026-11-06','NV05',1400,120,24,10,2000000);

INSERT INTO KhoanChi VALUES ('KC05','HD05','NV06','2026-11-05',1200000,'Chi phí triển khai ngày đầu','CT-05' ,'2026-11-05 18:00:00');

INSERT INTO KetQuaNgay VALUES ('HD05','2026-11-05','NV06',1500,125,25,10,2000000);

INSERT INTO KetQuaNgay VALUES ('HD05','2026-11-06','NV06',1500,125,25,11,2200000);

INSERT INTO KhoanChi VALUES ('KC06','HD06','NV06','2026-11-05',2200000,'Chi phí triển khai ngày đầu',NULL ,'2026-11-05 18:00:00');

INSERT INTO KetQuaNgay VALUES ('HD06','2026-11-05','NV06',1600,130,26,11,2200000);

INSERT INTO KetQuaNgay VALUES ('HD06','2026-11-06','NV06',1600,130,26,12,2400000);

INSERT INTO KhoanChi VALUES ('KC07','HD07','NV07','2026-11-05',600000,'Chi phí triển khai ngày đầu','CT-07' ,'2026-11-05 18:00:00');

INSERT INTO KetQuaNgay VALUES ('HD07','2026-11-05','NV07',1700,135,27,12,2400000);

INSERT INTO KetQuaNgay VALUES ('HD07','2026-11-06','NV07',1700,135,27,13,2600000);

INSERT INTO KhoanChi VALUES ('KC08','HD08','NV07','2026-11-05',900000,'Chi phí triển khai ngày đầu','CT-08' ,'2026-11-05 18:00:00');

INSERT INTO KetQuaNgay VALUES ('HD08','2026-11-05','NV07',1800,140,28,13,2600000);

INSERT INTO KetQuaNgay VALUES ('HD08','2026-11-06','NV07',1800,140,28,14,2800000);

INSERT INTO KhoanChi VALUES ('KC09','HD09','NV08','2026-11-05',800000,'Chi phí triển khai ngày đầu',NULL ,'2026-11-05 18:00:00');

INSERT INTO KetQuaNgay VALUES ('HD09','2026-11-05','NV08',1900,145,29,14,2800000);

INSERT INTO KetQuaNgay VALUES ('HD09','2026-11-06','NV08',1900,145,29,15,3000000);

INSERT INTO KhoanChi VALUES ('KC10','HD10','NV08','2026-11-05',1500000,'Chi phí triển khai ngày đầu','CT-10' ,'2026-11-05 18:00:00');

INSERT INTO KetQuaNgay VALUES ('HD10','2026-11-05','NV08',2000,150,30,15,3000000);

INSERT INTO KetQuaNgay VALUES ('HD10','2026-11-06','NV08',2000,150,30,16,3200000);

INSERT INTO KhoanChi VALUES ('KC11','HD01','NV04','2026-11-06',500000,'Chi phí chỉnh sửa nội dung',NULL,'2026-11-06 18:00:00');

UPDATE HoatDongTrienKhai SET TrangThai='HOAN_THANH' WHERE MaChienDich='CD03';

UPDATE ChienDich SET TrangThai='HOAN_THANH' WHERE MaChienDich='CD03';

UPDATE HoatDongTrienKhai SET TrangThai='TAM_DUNG' WHERE MaChienDich='CD04';

UPDATE ChienDich SET TrangThai='TAM_DUNG' WHERE MaChienDich='CD04';

UPDATE HoatDongTrienKhai SET TrangThai='HUY' WHERE MaChienDich='CD05';

UPDATE ChienDich SET TrangThai='HUY' WHERE MaChienDich='CD05';

UPDATE TaiKhoan SET TrangThai='BI_KHOA' WHERE MaNhanVien='NV08'; -- historical data remain

CALL sp_P1_KiemTraToanVen();

DO RELEASE_LOCK('marketing_btl.integrity');
