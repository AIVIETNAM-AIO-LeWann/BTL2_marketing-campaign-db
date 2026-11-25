"""P2.4 integration tests on a disposable seeded MySQL database.

Load database/part2/04_marketing_functions.sql first. Client options are the
same as test_constraints.py. All data changes roll back; role test drops its user.
"""
from decimal import Decimal
import json
import secrets
import sys
import unittest

from test_constraints import remaining, run, sql_literal


class MarketingFunctions(unittest.TestCase):
    def ok(self, sql):
        r = run(sql)
        self.assertEqual(r.returncode, 0, r.stderr)
        return r.stdout.strip()

    def reject(self, sql, message):
        r = run(sql)
        self.assertNotEqual(r.returncode, 0, r.stdout)
        self.assertIn(message, r.stderr)

    def scalar(self, sql):
        return self.ok('SELECT ' + sql + ';')

    def transactional(self, update, expression):
        return self.ok('SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED; '
                       'START TRANSACTION; ' + update + '\nSELECT ' + expression + '; ROLLBACK;')

    def test_count_seed(self):
        self.assertEqual(self.scalar("fn_P2_DemHoatDongVuotNganSach('CD01')"), '2')
        for campaign in ['CD02', 'CD03', 'CD04', 'CD05']:
            with self.subTest(campaign=campaign):
                self.assertEqual(self.scalar(f"fn_P2_DemHoatDongVuotNganSach('{campaign}')"), '0')

    def test_count_invalid_campaign(self):
        for code in [None, '', ' ', 'CD01 ', ' CD01', 'x'*21]:
            with self.subTest(code=code):
                value = 'NULL' if code is None else sql_literal(code)
                self.reject(f'SELECT fn_P2_DemHoatDongVuotNganSach({value});', 'P2_FN_INPUT')
        self.reject("SELECT fn_P2_DemHoatDongVuotNganSach('MISSING');", 'P2_FN_NOTFOUND')

    def test_count_exact_budget_is_not_overspend(self):
        result = self.transactional("UPDATE HoatDongTrienKhai SET NganSachDuocCap=3000000 WHERE MaHoatDong='HD01';",
                                    "fn_P2_DemHoatDongVuotNganSach('CD01')")
        self.assertEqual(result, '1')

    def test_count_uses_sum_of_multiple_costs(self):
        result = self.transactional("UPDATE KhoanChi SET SoTien=1 WHERE MaKhoanChi='KC01';",
                                    "fn_P2_DemHoatDongVuotNganSach('CD01')")
        self.assertEqual(result, '1')

    def test_count_follows_changed_cost_and_rollback(self):
        result = self.transactional("UPDATE KhoanChi SET SoTien=3000000 WHERE MaKhoanChi='KC03';",
                                    "fn_P2_DemHoatDongVuotNganSach('CD02')")
        self.assertEqual(result, '1')
        self.assertEqual(self.scalar("fn_P2_DemHoatDongVuotNganSach('CD02')"), '0')

    def test_count_no_activities(self):
        # Workflow commits, so fixture cleanup is explicit and limited to its codes.
        data = dict(MaChienDich='FN_EMPTY', TenChienDich='Empty function fixture', MucTieu=None,
                    MoTaDoiTuongHuongToi=None, CachXacDinhChuyenDoi=None,
                    NgayBatDau='2026-11-01', NgayKetThucDuKien='2026-11-30',
                    NganSachDuocDuyet=0, MaThuongHieu='TH01', MaNhanVien='NV02')
        self.ok('CALL sp_P1_TaoChienDich(' + sql_literal(json.dumps(data)) + ');')
        try:
            self.assertEqual(self.scalar("fn_P2_DemHoatDongVuotNganSach('FN_EMPTY')"), '0')
        finally:
            self.ok("SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED; START TRANSACTION; "
                    "SET @p1_internal=1; DELETE FROM PhanCong WHERE MaChienDich='FN_EMPTY'; "
                    "DELETE FROM ChienDich WHERE MaChienDich='FN_EMPTY'; SET @p1_internal=0; "
                    "CALL sp_P1_KiemTraToanVen(); COMMIT; DO RELEASE_LOCK('marketing_btl.integrity');")

    def test_cpa_known_period(self):
        self.assertEqual(self.scalar("fn_P2_ChiPhiTrenChuyenDoi('HD01','2026-11-05','2026-11-06')"), '230769.2308')

    def test_cpa_same_day_inclusive(self):
        for day, expected in [('2026-11-05', '416666.6667'), ('2026-11-06', '71428.5714')]:
            with self.subTest(day=day):
                self.assertEqual(self.scalar(f"fn_P2_ChiPhiTrenChuyenDoi('HD01','{day}','{day}')"), expected)

    def test_cpa_zero_conversion(self):
        self.assertEqual(self.scalar("fn_P2_ChiPhiTrenChuyenDoi('HD02','2026-11-06','2026-11-06')"), 'NULL')

    def test_cpa_null_conversion(self):
        self.assertEqual(self.scalar("fn_P2_ChiPhiTrenChuyenDoi('HD03','2026-11-05','2026-11-06')"), 'NULL')

    def test_cpa_missing_result_day(self):
        for start,end in [('2026-11-05','2026-11-07'), ('2026-11-07','2026-11-07'),
                          ('2026-11-05','2026-11-20')]:
            with self.subTest(start=start,end=end):
                self.assertEqual(self.scalar(f"fn_P2_ChiPhiTrenChuyenDoi('HD01','{start}','{end}')"), 'NULL')

    def test_cpa_zero_conversion_day_plus_positive_day(self):
        # One zero day does not invalidate a period whose total is positive.
        self.assertEqual(self.scalar("fn_P2_ChiPhiTrenChuyenDoi('HD02','2026-11-05','2026-11-06')"), '500000.0000')

    def test_cpa_zero_cost_with_known_conversions(self):
        self.assertEqual(self.scalar("fn_P2_ChiPhiTrenChuyenDoi('HD04','2026-11-06','2026-11-06')"), '0.0000')

    def test_cpa_invalid_code(self):
        for code in [None, '', ' ', 'HD01 ', 'x'*21]:
            with self.subTest(code=code):
                value='NULL' if code is None else sql_literal(code)
                self.reject(f"SELECT fn_P2_ChiPhiTrenChuyenDoi({value},'2026-11-05','2026-11-06');", 'P2_FN_INPUT')
        self.reject("SELECT fn_P2_ChiPhiTrenChuyenDoi('MISSING','2026-11-05','2026-11-06');", 'P2_FN_NOTFOUND')

    def test_cpa_invalid_date_range(self):
        for start,end in [('NULL',"'2026-11-06'"), ("'2026-11-05'",'NULL'),
                          ("'2026-11-06'","'2026-11-05'"), ("'2026-11-04'","'2026-11-06'"),
                          ("'2026-11-05'","'2026-11-21'")]:
            with self.subTest(start=start,end=end):
                self.reject(f"SELECT fn_P2_ChiPhiTrenChuyenDoi('HD01',{start},{end});", 'P2_FN_INPUT')

    def test_cpa_invalid_calendar_input(self):
        # DATE parameter conversion can reject malformed dates before the body runs.
        for day in ['0000-00-00', '2026-00-05', '2026-02-30']:
            with self.subTest(day=day):
                result=run(f"SELECT fn_P2_ChiPhiTrenChuyenDoi('HD01','{day}','2026-11-06');")
                self.assertNotEqual(result.returncode,0,result.stdout)

    def test_cpa_no_cost_duplication(self):
        result=self.transactional("INSERT INTO KhoanChi(MaKhoanChi,MaHoatDong,MaNguoiGhiNhan,NgayPhatSinh,SoTien,NoiDungChi) "
            "VALUES ('FN_COST','HD01','NV04','2026-11-05',600000,'Function test');",
            "fn_P2_ChiPhiTrenChuyenDoi('HD01','2026-11-05','2026-11-05')")
        self.assertEqual(result,'516666.6667')  # (2500000+600000)/6, not 6*2 conversions

    def test_cpa_no_cost_outside_period(self):
        result=self.transactional("INSERT INTO KhoanChi(MaKhoanChi,MaHoatDong,MaNguoiGhiNhan,NgayPhatSinh,SoTien,NoiDungChi) "
            "VALUES ('FN_COST','HD01','NV04','2026-11-04',999999,'Before launch');",
            "fn_P2_ChiPhiTrenChuyenDoi('HD01','2026-11-05','2026-11-06')")
        self.assertEqual(result,'230769.2308')

    def test_cpa_reports_completed_and_canceled(self):
        for activity in ['HD05','HD09']:
            with self.subTest(activity=activity):
                self.assertNotEqual(self.scalar(f"fn_P2_ChiPhiTrenChuyenDoi('{activity}','2026-11-05','2026-11-06')"),'NULL')

    def test_cpa_recomputes_when_source_changes(self):
        result=self.transactional("UPDATE KetQuaNgay SET SoChuyenDoi=0 WHERE MaHoatDong='HD01' AND NgayGhiNhan='2026-11-05';",
                                  "fn_P2_ChiPhiTrenChuyenDoi('HD01','2026-11-05','2026-11-06')")
        self.assertEqual(result,'428571.4286')
        result=self.transactional("UPDATE KetQuaNgay SET SoChuyenDoi=NULL WHERE MaHoatDong='HD01' AND NgayGhiNhan='2026-11-05';",
                                  "fn_P2_ChiPhiTrenChuyenDoi('HD01','2026-11-05','2026-11-06')")
        self.assertEqual(result,'NULL')

    def test_cpa_ignores_other_activity_costs(self):
        result=self.transactional("UPDATE KhoanChi SET SoTien=999999999999999999 WHERE MaKhoanChi='KC02';",
                                  "fn_P2_ChiPhiTrenChuyenDoi('HD01','2026-11-05','2026-11-06')")
        self.assertEqual(result,'230769.2308')

    def test_cpa_large_amount_stays_exact(self):
        result=self.transactional("UPDATE KhoanChi SET SoTien=999999999999999999 WHERE MaKhoanChi='KC01';",
                                  "fn_P2_ChiPhiTrenChuyenDoi('HD01','2026-11-05','2026-11-05')")
        self.assertEqual(Decimal(result),Decimal('166666666666666666.5000'))

    def test_cpa_precision_independent_of_caller(self):
        self.assertEqual(self.ok("SET SESSION div_precision_increment=0; SELECT fn_P2_ChiPhiTrenChuyenDoi('HD01','2026-11-05','2026-11-06');"),'230769.2308')

    def test_cpa_rounding_on_both_sides_of_half_unit(self):
        for conversions,expected in [(20001,'0.0000'),(20000,'0.0001'),(19999,'0.0001')]:
            with self.subTest(conversions=conversions):
                sql=("SET SESSION div_precision_increment=0; "
                     "SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED; START TRANSACTION; "
                     "UPDATE KhoanChi SET SoTien=1 WHERE MaKhoanChi='KC01'; "
                     f"UPDATE KetQuaNgay SET SoChuyenDoi={conversions} WHERE MaHoatDong='HD01' AND NgayGhiNhan='2026-11-05'; "
                     "SELECT fn_P2_ChiPhiTrenChuyenDoi('HD01','2026-11-05','2026-11-05'); ROLLBACK;")
                self.assertEqual(self.ok(sql),expected)

    def test_functions_in_select_across_rows(self):
        result=self.ok('SELECT MaChienDich,fn_P2_DemHoatDongVuotNganSach(MaChienDich) FROM ChienDich ORDER BY MaChienDich;')
        self.assertEqual(result,'CD01\t2\nCD02\t0\nCD03\t0\nCD04\t0\nCD05\t0')

    def test_routine_characteristics_and_no_side_effects(self):
        self.assertEqual(self.ok("SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema=DATABASE() "
            "AND routine_name IN ('fn_P2_DemHoatDongVuotNganSach','fn_P2_ChiPhiTrenChuyenDoi') "
            "AND routine_type='FUNCTION' AND is_deterministic='NO' AND sql_data_access='READS SQL DATA' AND security_type='INVOKER';"),'2')
        self.assertEqual(self.ok('SELECT COUNT(*),SUM(SoTien) FROM KhoanChi;'),'11\t16200000')
        self.assertEqual(self.ok('SELECT COUNT(*) FROM KetQuaNgay;'),'20')

    def test_role_can_call_functions(self):
        username='fn_review_'+secrets.token_hex(6)
        password=secrets.token_hex(24)
        account=sql_literal(username)+"@'%'"
        self.ok(f"CREATE USER {account} IDENTIFIED WITH caching_sha2_password BY {sql_literal(password)};")
        try:
            self.ok(f"GRANT 'marketing_p1' TO {account}; SET DEFAULT ROLE 'marketing_p1' TO {account};")
            r=run("SELECT fn_P2_DemHoatDongVuotNganSach('CD01'),fn_P2_ChiPhiTrenChuyenDoi('HD01','2026-11-05','2026-11-06');",
                  user=username,password=password)
            self.assertEqual(r.returncode,0,r.stderr)
            self.assertEqual(r.stdout.strip(),'2\t230769.2308')
        finally:
            self.ok(f'DROP USER {account};')


if __name__=='__main__':
    unittest.main(argv=[sys.argv[0]]+remaining,verbosity=2)
