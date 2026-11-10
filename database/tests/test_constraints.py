"""Integration tests against a disposable, already seeded MySQL database.

Uses the official mysql client; no third-party Python packages.
Example: python database/tests/test_constraints.py --mysql /path/to/mysql --port 3306
Password: set MYSQL_PWD locally, or use your MySQL client option file.
Most cases roll back; the successful workflow/role test cleans its own test rows.
"""
import argparse
import json
import os
import secrets
import subprocess
import sys
import unittest

parser = argparse.ArgumentParser()
parser.add_argument('--mysql', default='mysql')
parser.add_argument('--host', default='127.0.0.1')
parser.add_argument('--port', default='3306')
parser.add_argument('--user', default='root')
parser.add_argument('--socket', help='Unix socket for native Ubuntu MySQL (overrides host/port)')
args, remaining = parser.parse_known_args()
TABLES = ['NhanVien','TaiKhoan','SoDienThoaiNhanVien','ThuongHieu','KenhMarketing',
          'ChienDich','PhanCong','HoatDongTrienKhai','HoatDongEmail','DanhSachNhanEmail',
          'HoatDongEmail_DanhSach','TaiKhoanMangXaHoi','HoatDongMangXaHoi','KhoanChi','KetQuaNgay']

def sql_literal(value):
    return "'" + value.replace('\\','\\\\').replace("'","''") + "'"

def client_command(user=None):
    cmd=[args.mysql]
    if args.socket:
        cmd += ['--protocol=SOCKET','--socket='+args.socket]
    else:
        cmd += ['--protocol=TCP','-h',args.host,'-P',args.port]
    return cmd+['-u',user or args.user,'--default-character-set=utf8mb4',
                '--batch','--raw','--skip-column-names']

def run(sql, user=None, password=None):
    env = os.environ.copy()
    if password is not None:
        env['MYSQL_PWD'] = password
    cmd = client_command(user)+['marketing_btl']
    return subprocess.run(cmd, input=sql, encoding='utf-8', errors='replace',
                          capture_output=True, env=env, timeout=30)

class Constraints(unittest.TestCase):
    def ok(self, sql):
        r = run(sql)
        self.assertEqual(r.returncode, 0, r.stderr)
        return r.stdout.strip()

    def reject(self, sql, message):
        r = run('SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED; START TRANSACTION;\n' + sql + '\nROLLBACK;')
        self.assertNotEqual(r.returncode, 0, r.stdout)
        self.assertIn(message, r.stderr)

    def test_01_exactly_fifteen_tables(self):
        self.assertEqual(self.ok("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_type='BASE TABLE';"), '15')

    def test_02_all_tables_have_five_rows(self):
        for t in TABLES:
            with self.subTest(table=t):
                self.assertGreaterEqual(int(self.ok(f'SELECT COUNT(*) FROM {t};')), 5)

    def test_03_integrity(self):
        self.ok('CALL sp_P1_KiemTraToanVen();')

    def test_04_innodb_and_utf8(self):
        self.assertEqual(self.ok("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_type='BASE TABLE' AND (engine<>'InnoDB' OR table_collation NOT LIKE 'utf8mb4%');"), '0')
        self.assertEqual(self.ok("SELECT TenThuongHieu FROM ThuongHieu WHERE MaThuongHieu='TH01';"), 'An Nhiên')

    def test_pk(self):
        self.reject("INSERT INTO ThuongHieu(MaThuongHieu,TenThuongHieu) VALUES ('TH01','Duplicate');", 'Duplicate entry')

    def test_fk(self):
        self.reject("INSERT INTO SoDienThoaiNhanVien VALUES ('NO_NV','0901234567');", 'foreign key constraint fails')

    def test_unique_login(self):
        self.reject("UPDATE TaiKhoan SET TenDangNhap='nv01' WHERE MaNhanVien='NV02';", 'Duplicate entry')

    def test_not_null(self):
        self.reject("UPDATE KhoanChi SET SoTien=NULL WHERE MaKhoanChi='KC01';", 'cannot be null')

    def test_phone_check(self):
        self.reject("INSERT INTO SoDienThoaiNhanVien VALUES ('NV04','not-a-phone');", 'ck_sdt_format')

    def test_email_check(self):
        self.reject("UPDATE NhanVien SET Email='wrong' WHERE MaNhanVien='NV04';", 'ck_nv_email')

    def test_status_check(self):
        self.reject("UPDATE TaiKhoan SET TrangThai='UNKNOWN' WHERE MaNhanVien='NV04';", 'ck_tk_trangthai')

    def test_rb01_dates(self):
        self.reject("UPDATE ChienDich SET NgayKetThucDuKien='2026-10-01' WHERE MaChienDich='CD01';", 'ck_cd_ngay')

    def test_rb01_duration(self):
        self.assertEqual(self.ok("SELECT ThoiLuongDuKien FROM v_ThoiLuongChienDich WHERE MaChienDich='CD01';"), '30')

    def test_rb02_activity_dates(self):
        self.reject("UPDATE HoatDongTrienKhai SET NgayBatDau='2026-10-31' WHERE MaHoatDong='HD01';", 'RB02')

    def test_rb02_reverse_campaign_dates(self):
        self.reject("UPDATE ChienDich SET NgayKetThucDuKien='2026-11-10' WHERE MaChienDich='CD01';", 'RB02')

    def test_rb03_assignment_dates(self):
        self.reject("UPDATE PhanCong SET NgayBatDauThamGia='2026-10-31' WHERE MaNhanVien='NV04' AND MaChienDich='CD01';", 'RB03')

    def test_rb03_local_date_order(self):
        self.reject("UPDATE PhanCong SET NgayKetThucThamGia='2026-10-01' WHERE MaNhanVien='NV04' AND MaChienDich='CD01';", 'ck_pc_ngay')

    def test_rb04_owner_role(self):
        self.reject("UPDATE TaiKhoan SET VaiTro='NHAN_VIEN_MARKETING' WHERE MaNhanVien='NV02';", 'RB04')

    def test_rb04_owner_assignment(self):
        self.reject("DELETE FROM PhanCong WHERE MaNhanVien='NV02' AND MaChienDich='CD01';", 'RB04')

    def test_rb04_owner_coverage(self):
        self.reject("UPDATE PhanCong SET NgayBatDauThamGia='2026-11-02' WHERE MaNhanVien='NV02' AND MaChienDich='CD01';", 'RB04')

    def test_rb05_activity_worker(self):
        self.reject("UPDATE HoatDongTrienKhai SET MaNhanVien='NV01' WHERE MaHoatDong='HD01';", 'RB05')

    def test_rb05_reverse_assignment(self):
        self.reject("UPDATE PhanCong SET NgayBatDauThamGia='2026-11-10' WHERE MaNhanVien='NV04' AND MaChienDich='CD01';", 'RB05')

    def test_rb06_self(self):
        self.reject("UPDATE NhanVien SET MaNguoiGiamSat='NV04' WHERE MaNhanVien='NV04';", 'ck_nv_khong_tu_giamsat')

    def test_rb06_indirect_cycle(self):
        self.reject("UPDATE NhanVien SET MaNguoiGiamSat='NV04' WHERE MaNhanVien='NV01';", 'RB06')

    def test_rb07_negative(self):
        self.reject("UPDATE ChienDich SET NganSachDuocDuyet=-1 WHERE MaChienDich='CD01';", 'ck_cd_')

    def test_rb07_allocation(self):
        self.reject("UPDATE HoatDongTrienKhai SET NganSachDuocCap=30000000 WHERE MaHoatDong='HD01';", 'RB07')

    def test_rb07_reverse_budget(self):
        self.reject("UPDATE ChienDich SET NganSachDuocDuyet=4000000 WHERE MaChienDich='CD01';", 'RB07')

    def test_rb08_zero_amount(self):
        self.reject("UPDATE KhoanChi SET SoTien=0 WHERE MaKhoanChi='KC01';", 'ck_chi_sotien')

    def test_rb08_actual_overspend_allowed(self):
        self.assertGreater(int(self.ok("SELECT ChenhLechNganSach FROM v_ChiPhiHoatDong WHERE MaHoatDong='HD01';")),0)
        self.ok("SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED; START TRANSACTION; UPDATE KhoanChi SET SoTien=90000000 WHERE MaKhoanChi='KC01'; ROLLBACK;")

    def test_rb09_channel(self):
        self.reject("UPDATE HoatDongTrienKhai SET MaKenh='K_FACEBOOK' WHERE MaHoatDong='HD01';", 'RB09')

    def test_rb09_account_group(self):
        self.reject("UPDATE TaiKhoanMangXaHoi SET MaKenh='K_EMAIL_A' WHERE MaTKMangXaHoi='MXH06';", 'RB09')

    def test_rb09_reverse_account_channel(self):
        self.reject("UPDATE TaiKhoanMangXaHoi SET MaKenh='K_INSTAGRAM' WHERE MaTKMangXaHoi='MXH01';", 'RB09')

    def test_rb10_list_owner(self):
        self.reject("UPDATE DanhSachNhanEmail SET MaThuongHieu='TH02' WHERE MaDanhSach='DS01';", 'RB10')

    def test_rb10_account_owner(self):
        self.reject("UPDATE TaiKhoanMangXaHoi SET MaThuongHieu='TH02' WHERE MaTKMangXaHoi='MXH01';", 'RB10')

    def test_rb10_reverse_campaign_owner(self):
        self.reject("UPDATE ChienDich SET MaThuongHieu='TH02' WHERE MaChienDich='CD01';", 'RB10')

    def test_rb10_wrong_list(self):
        self.reject("INSERT INTO HoatDongEmail_DanhSach VALUES ('HD01','DS02');", 'RB10')

    def test_rb11_day_range(self):
        self.reject("INSERT INTO KetQuaNgay(MaHoatDong,NgayGhiNhan,MaNguoiCapNhat) VALUES ('HD01','2026-12-01','NV04');", 'RB11')

    def test_rb11_nonnegative(self):
        for col in ['LuotHienThi','LuotNhap','SoKHTiemNang','SoChuyenDoi','DoanhThu']:
            with self.subTest(col=col):
                self.reject(f"UPDATE KetQuaNgay SET {col}=-1 WHERE MaHoatDong='HD01' AND NgayGhiNhan='2026-11-05';", 'ck_kq_')

    def test_rb11_weak_key(self):
        self.reject("INSERT INTO KetQuaNgay(MaHoatDong,NgayGhiNhan,MaNguoiCapNhat) VALUES ('HD01','2026-11-05','NV04');", 'Duplicate entry')

    def test_rb12_zero_and_unknown(self):
        self.assertEqual(self.ok("SELECT ChiPhiTrenChuyenDoi IS NULL FROM v_KetQuaNgay WHERE MaHoatDong='HD02' AND NgayGhiNhan='2026-11-06';"),'1')
        self.assertEqual(self.ok("SELECT SoChuyenDoi IS NULL FROM KetQuaNgay WHERE MaHoatDong='HD03' AND NgayGhiNhan='2026-11-06';"),'1')

    def test_rb12_formula(self):
        self.assertAlmostEqual(float(self.ok("SELECT ChiPhiTrenChuyenDoi FROM v_KetQuaNgay WHERE MaHoatDong='HD01' AND NgayGhiNhan='2026-11-05';")), 2500000/6, places=3)

    def test_rb12_incomplete_period(self):
        self.assertEqual(self.ok("SELECT ChiPhiTrenChuyenDoi IS NULL FROM v_HieuQuaHoatDong WHERE MaHoatDong='HD01';"),'1')

    def test_rb13_required_content(self):
        self.reject("UPDATE ChienDich SET MucTieu=NULL WHERE MaChienDich='CD01';", 'ck_cd_du_noidung')

    def test_rb14_parent_not_running(self):
        self.reject("UPDATE HoatDongTrienKhai SET TrangThai='DANG_THUC_HIEN' WHERE MaHoatDong='HD07';", 'RB14')

    def test_rb14_active_worker(self):
        self.reject("UPDATE TaiKhoan SET TrangThai='BI_KHOA' WHERE MaNhanVien='NV04'; UPDATE HoatDongTrienKhai SET TrangThai='TAM_DUNG' WHERE MaHoatDong='HD01'; UPDATE HoatDongTrienKhai SET TrangThai='DANG_THUC_HIEN' WHERE MaHoatDong='HD01';", 'RB14')

    def test_rb14_email_content(self):
        self.reject("UPDATE HoatDongEmail SET TieuDeThu=NULL WHERE MaHoatDong='HD01';", 'RB14')

    def test_rb14_social_content(self):
        self.reject("UPDATE HoatDongMangXaHoi SET NoiDungBaiDang=NULL WHERE MaHoatDong='HD02';", 'RB14')

    def test_rb15_not_assigned(self):
        self.reject("UPDATE KhoanChi SET MaNguoiGhiNhan='NV05' WHERE MaKhoanChi='KC01';", 'RB15')

    def test_rb15_inactive_actor(self):
        self.reject("INSERT INTO KhoanChi VALUES ('TEST_CHI','HD09','NV08','2026-11-10',1000,'Test',NULL,NOW());", 'RB15')

    def test_rb15_inactive_result_actor(self):
        self.reject("UPDATE KetQuaNgay SET LuotNhap=42 WHERE MaHoatDong='HD09' AND NgayGhiNhan='2026-11-05';", 'RB15')

    def test_rb16_finish_too_early(self):
        self.reject("UPDATE ChienDich SET TrangThai='HOAN_THANH' WHERE MaChienDich='CD01';", 'RB16')

    def test_rb16_delete_history_cost(self):
        self.reject("DELETE FROM KhoanChi WHERE MaKhoanChi='KC05';", 'RB16')

    def test_rb16_delete_history_result(self):
        self.reject("DELETE FROM KetQuaNgay WHERE MaHoatDong='HD05' AND NgayGhiNhan='2026-11-05';", 'RB16')

    def test_rb16_delete_history_assignment(self):
        self.reject("DELETE FROM PhanCong WHERE MaNhanVien='NV06' AND MaChienDich='CD03';", 'RB16')

    def test_rb16_reopen(self):
        self.reject("UPDATE ChienDich SET TrangThai='DANG_THUC_HIEN' WHERE MaChienDich='CD03';", 'RB16')

    def test_eer_account_total(self):
        self.reject("DELETE FROM TaiKhoan WHERE MaNhanVien='NV04';", 'EER_ACCOUNT')

    def test_eer_subtype_total(self):
        self.reject("DELETE FROM HoatDongMangXaHoi WHERE MaHoatDong='HD02';", 'EER_TOTAL')

    def test_eer_subtype_disjoint(self):
        self.reject("INSERT INTO HoatDongMangXaHoi(MaHoatDong,MaTKMangXaHoi) VALUES ('HD01','MXH01');", 'EER_TOTAL')

    def test_eer_email_total_list(self):
        self.reject("DELETE FROM HoatDongEmail_DanhSach WHERE MaHoatDong='HD01';", 'EER_EMAIL_LIST')

    def test_eer_owner_without_usage(self):
        self.assertEqual(self.ok("SELECT MaThuongHieu FROM DanhSachNhanEmail WHERE MaDanhSach='DS06';"), 'TH01')
        self.assertEqual(self.ok("SELECT COUNT(*) FROM HoatDongEmail_DanhSach WHERE MaDanhSach='DS06';"), '0')

    def test_workflow_rollback(self):
        nv={'MaNhanVien':'TEST_NV','Ho':'Test','Ten':'Rollback','Email':'test@example.com','NgayVaoLam':'2026-01-01'}
        tk={'MaTK':'TEST_TK','TenDangNhap':'nv01','MatKhauBam':'x'*60,'VaiTro':'NHAN_VIEN_MARKETING'}
        r=run('CALL sp_P1_TaoNhanVien('+sql_literal(json.dumps(nv))+','+sql_literal(json.dumps(tk))+');')
        self.assertNotEqual(r.returncode,0)
        self.assertIn('Duplicate entry',r.stderr)
        self.assertEqual(self.ok("SELECT COUNT(*) FROM NhanVien WHERE MaNhanVien='TEST_NV';"),'0')

    def test_direct_orphan_employee_rejected(self):
        self.reject("INSERT INTO NhanVien VALUES ('TEST_NV','Test',NULL,'Orphan','test@example.com','2026-01-01',NULL);", 'EER_ACCOUNT')

    def test_direct_orphan_activity_rejected(self):
        self.reject("INSERT INTO HoatDongTrienKhai VALUES ('TEST_HD','Orphan',NULL,'2026-11-05','2026-11-10',0,'CHUA_BAT_DAU','K_EMAIL_A','CD01','NV04');", 'EER_TOTAL')

    def activity_call(self, lists, budget=1000):
        h={'MaHoatDong':'TEST_HD','TenHoatDong':'Test atomic activity','NgayBatDau':'2026-11-05',
           'NgayKetThucDuKien':'2026-11-10','NganSachDuocCap':budget,
           'MaKenh':'K_EMAIL_A','MaChienDich':'CD01','MaNhanVien':'NV04'}
        return 'CALL sp_P1_TaoHoatDong('+','.join(sql_literal(json.dumps(x)) for x in [h,{},lists])+');'

    def assert_no_test_activity(self):
        for t in ['HoatDongTrienKhai','HoatDongEmail','HoatDongEmail_DanhSach']:
            self.assertEqual(self.ok(f"SELECT COUNT(*) FROM {t} WHERE MaHoatDong='TEST_HD';"),'0')

    def test_workflow_email_empty_list_rolls_back(self):
        r=run(self.activity_call([]))
        self.assertNotEqual(r.returncode,0)
        self.assertIn('EER_EMAIL_LIST',r.stderr)
        self.assert_no_test_activity()

    def test_workflow_wrong_brand_rolls_back(self):
        r=run(self.activity_call(['DS02']))
        self.assertNotEqual(r.returncode,0)
        self.assertIn('RB10',r.stderr)
        self.assert_no_test_activity()

    def test_workflow_overallocation_rolls_back(self):
        r=run(self.activity_call(['DS01'],30000000))
        self.assertNotEqual(r.returncode,0)
        self.assertIn('RB07',r.stderr)
        self.assert_no_test_activity()

    def test_rb13_approval_workflow(self):
        c={'MaChienDich':'TEST_CD','TenChienDich':'Approval test','MucTieu':'Test',
           'MoTaDoiTuongHuongToi':'Test','CachXacDinhChuyenDoi':'Paid order',
           'NgayBatDau':'2026-11-01','NgayKetThucDuKien':'2026-11-30',
           'NganSachDuocDuyet':100000,'MaThuongHieu':'TH01','MaNhanVien':'NV02'}
        self.ok('CALL sp_P1_TaoChienDich('+sql_literal(json.dumps(c))+');')
        try:
            self.reject("UPDATE ChienDich SET TrangThai='DA_DUYET' WHERE MaChienDich='TEST_CD';",'RB13')
            h={'MaHoatDong':'TEST_APPROVE','TenHoatDong':'Test','NgayBatDau':'2026-11-05',
               'NgayKetThucDuKien':'2026-11-10','NganSachDuocCap':1000,
               'MaKenh':'K_EMAIL_A','MaChienDich':'TEST_CD','MaNhanVien':'NV02'}
            self.ok('CALL sp_P1_TaoHoatDong('+','.join(sql_literal(json.dumps(x)) for x in [h,{},['DS01']])+');')
            self.reject("UPDATE TaiKhoan SET TrangThai='BI_KHOA' WHERE MaNhanVien='NV02'; UPDATE ChienDich SET TrangThai='DA_DUYET' WHERE MaChienDich='TEST_CD';",'RB13')
            self.ok("SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED; START TRANSACTION; UPDATE ChienDich SET TrangThai='DA_DUYET' WHERE MaChienDich='TEST_CD'; ROLLBACK;")
        finally:
            # Trusted test owner removes only its own fixture in a complete batch.
            self.ok("START TRANSACTION; SET @p1_internal=1; DELETE FROM HoatDongEmail_DanhSach WHERE MaHoatDong='TEST_APPROVE'; DELETE FROM HoatDongEmail WHERE MaHoatDong='TEST_APPROVE'; DELETE FROM HoatDongTrienKhai WHERE MaHoatDong='TEST_APPROVE'; DELETE FROM PhanCong WHERE MaChienDich='TEST_CD'; DELETE FROM ChienDich WHERE MaChienDich='TEST_CD'; CALL sp_P1_KiemTraToanVen(); SET @p1_internal=0; COMMIT;")

    def test_role_cannot_bypass_deferred_checks(self):
        name='p1_test_'+secrets.token_hex(4)
        password=secrets.token_urlsafe(24)
        # The TCP client can be on the Docker host, not localhost from MySQL's
        # perspective. This temporary account is restricted to marketing_p1,
        # has a random password, and is removed in finally. It also works via
        # Unix socket. Do not enable the obsolete mysql_native_password plugin.
        account=sql_literal(name)+"@'%'"
        self.ok(f"CREATE USER {account} IDENTIFIED WITH caching_sha2_password BY {sql_literal(password)}; GRANT 'marketing_p1' TO {account}; SET DEFAULT ROLE 'marketing_p1' TO {account};")
        try:
            r=run("SET @p1_internal=1; UPDATE ChienDich SET NganSachDuocDuyet=1 WHERE MaChienDich='CD01';",user=name,password=password)
            self.assertNotEqual(r.returncode,0)
            self.assertIn('denied',r.stderr)
            r=run("SELECT COUNT(*) FROM KhoanChi;",user=name,password=password)
            self.assertEqual(r.returncode,0,r.stderr)
        finally:
            self.ok(f'DROP USER {account};')

    def employee_payload(self):
        return ({'MaNhanVien':'TEST_JSON','Ho':'Test','Ten':'Validation',
                 'Email':'test@example.com','NgayVaoLam':'2026-01-01'},
                {'MaTK':'TEST_JSON_TK','TenDangNhap':'test_json','MatKhauBam':'x'*60,
                 'VaiTro':'NHAN_VIEN_MARKETING'})

    def employee_call(self,nv,tk):
        return 'CALL sp_P1_TaoNhanVien('+','.join(sql_literal(json.dumps(x)) for x in [nv,tk])+');'

    def test_required_json_null_rejected(self):
        for field in ['MaNhanVien','Ho','Ten','Email','NgayVaoLam']:
            with self.subTest(field=field):
                nv,tk=self.employee_payload()
                nv[field]=None
                r=run(self.employee_call(nv,tk))
                self.assertNotEqual(r.returncode,0,r.stdout)
                self.assertIn('P1_INPUT',r.stderr)

    def test_json_wrong_scalar_type_rejected(self):
        nv,tk=self.employee_payload()
        nv['Ho']=123
        r=run(self.employee_call(nv,tk))
        self.assertNotEqual(r.returncode,0)
        self.assertIn('P1_INPUT',r.stderr)

    def test_json_missing_field_rejected(self):
        nv,tk=self.employee_payload()
        del nv['Ho']
        r=run(self.employee_call(nv,tk))
        self.assertNotEqual(r.returncode,0)
        self.assertIn('P1_INPUT',r.stderr)

    def test_json_optional_null_preserved(self):
        self.assertEqual(self.ok("SELECT TenDem IS NULL FROM NhanVien WHERE MaNhanVien='NV08';"),'1')

    def test_json_string_array_item_required(self):
        r=run(self.activity_call([None]))
        self.assertNotEqual(r.returncode,0)
        self.assertIn('P1_INPUT',r.stderr)
        self.assert_no_test_activity()

    def test_json_noninteger_vnd_rejected(self):
        r=run(self.activity_call(['DS01'],1000.5))
        self.assertNotEqual(r.returncode,0)
        self.assertIn('P1_INPUT',r.stderr)
        self.assert_no_test_activity()

    def test_empty_primary_key_rejected(self):
        self.reject("INSERT INTO ThuongHieu(MaThuongHieu,TenThuongHieu) VALUES ('','Empty key');",'ck_th_ma')

    def test_zero_date_even_with_relaxed_caller_mode(self):
        self.reject("SET SESSION sql_mode='STRICT_TRANS_TABLES'; UPDATE NhanVien SET NgayVaoLam='0000-00-00' WHERE MaNhanVien='NV04';",'ck_nv_ngay')

    def test_partial_zero_date_even_with_relaxed_caller_mode(self):
        self.reject("SET SESSION sql_mode='STRICT_TRANS_TABLES'; UPDATE NhanVien SET NgayVaoLam='2026-00-01' WHERE MaNhanVien='NV04';",'ck_nv_ngay')

    def test_workflow_rejects_invalid_calendar_date(self):
        nv,tk=self.employee_payload()
        nv['NgayVaoLam']='2026-02-30'
        r=run(self.employee_call(nv,tk))
        self.assertNotEqual(r.returncode,0)
        self.assertIn('Incorrect date',r.stderr)
        self.assertEqual(self.ok("SELECT COUNT(*) FROM NhanVien WHERE MaNhanVien='TEST_JSON';"),'0')

    def test_nested_workflow_keeps_caller_transaction_and_lock(self):
        nv,tk=self.employee_payload()
        # --force is confined to this deliberate error test, so SELECT can inspect
        # the same session AFTER a rejected call. Never use it for installation.
        sql=("SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED; START TRANSACTION; "
             "UPDATE ThuongHieu SET MoTa='uncommitted-review' WHERE MaThuongHieu='TH01'; "
             "SET @p1_internal=7; "+self.employee_call(nv,tk)+
             " SELECT IS_USED_LOCK('marketing_btl.integrity')=CONNECTION_ID(), @p1_internal; ROLLBACK;")
        cmd=client_command()+['--force','marketing_btl']
        r=subprocess.run(cmd,input=sql,encoding='utf-8',errors='replace',capture_output=True,timeout=30)
        self.assertIn('Transaction characteristics',r.stderr)
        self.assertIn('1\t7',r.stdout)
        self.assertEqual(self.ok("SELECT MoTa='uncommitted-review' FROM ThuongHieu WHERE MaThuongHieu='TH01';"),'0')
        self.assertEqual(self.ok("SELECT COUNT(*) FROM NhanVien WHERE MaNhanVien='TEST_JSON';"),'0')

    def test_multirow_failure_rolls_back_entire_statement(self):
        self.reject("INSERT INTO HoatDongEmail_DanhSach VALUES ('HD01','DS06'),('HD01','DS02');",'RB10')
        self.assertEqual(self.ok("SELECT COUNT(*) FROM HoatDongEmail_DanhSach WHERE MaHoatDong='HD01' AND MaDanhSach='DS06';"),'0')

    def test_reports_do_not_multiply_expenses(self):
        self.assertEqual(self.ok("SELECT TongChiPhiThucTe FROM v_ChiPhiHoatDong WHERE MaHoatDong='HD01';"),'3000000')

if __name__=='__main__':
    unittest.main(argv=[sys.argv[0]]+remaining,verbosity=2)
