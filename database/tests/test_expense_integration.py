"""P2.1/P2.3 integration checks against a disposable seeded database.

Load part2/01, 02 and 03 first. Successful CRUD fixtures delete their own rows;
all rejected calls must leave the seed and stored expense totals unchanged.
"""
import json
import subprocess
import unittest

import sys
from test_constraints import client_command, remaining, run as run_sql, sql_literal


def run(sql, force=False):
    if not force:
        return run_sql(sql)
    return subprocess.run(client_command() + ['--force', 'marketing_btl'], input=sql,
                          encoding='utf-8', capture_output=True, timeout=30)


def lit(value):
    return sql_literal(value)


def payload(**changes):
    d = dict(MaKhoanChi='RV_COST', MaHoatDong='HD01', NgayPhatSinh='2026-11-07',
             SoTien=9000000, NoiDungChi='Review integration')
    d.update(changes)
    return lit(json.dumps(d, ensure_ascii=False))

class Part2Review(unittest.TestCase):
    def ok(self, sql):
        r = run(sql)
        self.assertEqual(r.returncode, 0, r.stderr)
        return [s.split('\t') for s in r.stdout.strip().splitlines() if s]

    def error(self, sql, code):
        r = run(sql)
        self.assertNotEqual(r.returncode, 0, r.stdout)
        self.assertIn(code, r.stderr)

    def reconcile(self):
        self.assertEqual(self.ok('SELECT h.MaHoatDong FROM HoatDongTrienKhai h '
            'LEFT JOIN KhoanChi k USING(MaHoatDong) GROUP BY h.MaHoatDong,h.TongChiPhiThucTe '
            'HAVING h.TongChiPhiThucTe<>COALESCE(SUM(k.SoTien),0);'), [])

    def test_crud_lifecycle_move_and_noop(self):
        self.assertEqual(self.ok(f"CALL sp_P2_ThemKhoanChi('NV04',{payload(MaChungTu='RV')});"), [['RV_COST','THEM','1']])
        try:
            self.assertEqual(self.ok("SELECT TongChiPhiThucTe FROM HoatDongTrienKhai WHERE MaHoatDong='HD01';"), [['12000000']])
            d = dict(MaHoatDong='HD01', NgayPhatSinh='2026-11-08', SoTien=9500000, NoiDungChi='Edited')
            p = lit(json.dumps(d))
            self.assertEqual(self.ok(f"CALL sp_P2_SuaKhoanChi('NV04','RV_COST',{p});"), [['RV_COST','SUA','1']])
            self.assertEqual(self.ok(f"CALL sp_P2_SuaKhoanChi('NV04','RV_COST',{p});"), [['RV_COST','SUA','0']])
            self.assertEqual(self.ok("SELECT MaNguoiGhiNhan, MaChungTu FROM KhoanChi WHERE MaKhoanChi='RV_COST';"), [['NV04','NULL']])
            d.update(MaHoatDong='HD02', SoTien=800000)
            self.ok(f"CALL sp_P2_SuaKhoanChi('NV04','RV_COST',{lit(json.dumps(d))});")
            self.assertEqual(self.ok("SELECT TongChiPhiThucTe FROM HoatDongTrienKhai WHERE MaHoatDong IN ('HD01','HD02') ORDER BY MaHoatDong;"), [['3000000'],['4300000']])
            self.reconcile()
        finally:
            self.ok("CALL sp_P2_XoaKhoanChi('NV04','RV_COST');")
        self.reconcile()

    def test_crud_invalid_amounts(self):
        for amount in [0,-1,1.5,1000000.0,10**18,10**19,1e40,'100',None,True]:
            with self.subTest(amount=amount):
                self.error(f"CALL sp_P2_ThemKhoanChi('NV04',{payload(SoTien=amount)});", 'P2_INPUT')

    def test_crud_boundary_amount(self):
        self.ok(f"CALL sp_P2_ThemKhoanChi('NV04',{payload(SoTien=999999999999999999)});")
        try:
            self.reconcile()
        finally:
            self.ok("CALL sp_P2_XoaKhoanChi('NV04','RV_COST');")

    def test_crud_bad_dates(self):
        for day in ['2026-02-30','2025-02-29','2026-13-01','2026-00-01','0000-00-00','0999-12-31','2026-11-00','26-11-07']:
            with self.subTest(day=day):
                self.error(f"CALL sp_P2_ThemKhoanChi('NV04',{payload(NgayPhatSinh=day)});", 'P2_INPUT')

    def test_crud_bad_text(self):
        for changes in [dict(NoiDungChi=None),dict(NoiDungChi=' '),dict(NoiDungChi='x'*501),
                        dict(MaKhoanChi='x'*21),dict(MaHoatDong='HD01 '),
                        dict(MaChungTu=''),dict(MaChungTu='x'*101),dict(MaNguoiGhiNhan='NV05')]:
            with self.subTest(changes=changes):
                self.error(f"CALL sp_P2_ThemKhoanChi('NV04',{payload(**changes)});", 'P2_INPUT')

    def test_crud_null_actor_and_json(self):
        for actor, p in [('NULL',payload()),("''",payload()),(lit('NV04'),'NULL'),(lit('NV04'),"'[]'"),(lit('NV04'),"'{}'")]:
            with self.subTest(actor=actor,p=p):
                self.error(f'CALL sp_P2_ThemKhoanChi({actor},{p});', 'P2_INPUT')

    def test_crud_actor_authorization(self):
        for actor,changes,error in [('NV99',{},'P2_NOTFOUND'),('NV08',{},'P2_ACTOR'),('NV05',{},'RB15'),('NV04',dict(MaHoatDong='HD99'),'P2_NOTFOUND'),('NV04',dict(MaKhoanChi='KC01'),'P2_DUP')]:
            with self.subTest(actor=actor,changes=changes):
                self.error(f'CALL sp_P2_ThemKhoanChi({lit(actor)},{payload(**changes)});', error)
        self.error("CALL sp_P2_XoaKhoanChi('NV05','KC01');",'P2_PERM')
        self.error("CALL sp_P2_XoaKhoanChi('NV04','MISSING');",'P2_NOTFOUND')

    def test_crud_history_and_move_rejection(self):
        replacement = lit(json.dumps(dict(MaHoatDong='HD01',NgayPhatSinh='2026-11-05',SoTien=1200000,NoiDungChi='x')))
        self.error(f"CALL sp_P2_SuaKhoanChi('NV06','KC05',{replacement});",'RB16')
        self.error("CALL sp_P2_XoaKhoanChi('NV06','KC05');",'RB16')
        self.error(f"CALL sp_P2_ThemKhoanChi('NV06',{payload(MaHoatDong='HD05')});",'RB16')
        for target, error in [('HD05','RB16'),('HD03','RB15')]:
            d = dict(MaHoatDong=target,NgayPhatSinh='2026-11-05',SoTien=2500000,NoiDungChi='x')
            self.error(f"CALL sp_P2_SuaKhoanChi('NV04','KC01',{lit(json.dumps(d))});",error)
        self.assertEqual(self.ok("SELECT MaHoatDong,SoTien FROM KhoanChi WHERE MaKhoanChi='KC01';"),[['HD01','2500000']])
        self.reconcile()

    def test_crud_paused_and_prelaunch_cost(self):
        self.ok(f"CALL sp_P2_ThemKhoanChi('NV07',{payload(MaHoatDong='HD07',NgayPhatSinh='2026-10-01',SoTien=1000)});")
        self.ok("CALL sp_P2_XoaKhoanChi('NV07','RV_COST');")

    def test_nested_transaction_keeps_caller(self):
        r=run("SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED; START TRANSACTION; "
              "INSERT INTO KhoanChi(MaKhoanChi,MaHoatDong,MaNguoiGhiNhan,NgayPhatSinh,SoTien,NoiDungChi) "
              "VALUES ('RV_NEST','HD01','NV04','2026-11-07',1000,'caller');\n"
              f"CALL sp_P2_ThemKhoanChi('NV04',{payload()});\n"
              "SELECT COUNT(*),IS_USED_LOCK('marketing_btl.integrity')=CONNECTION_ID() FROM KhoanChi WHERE MaKhoanChi='RV_NEST';\n"
              "ROLLBACK; DO RELEASE_LOCK('marketing_btl.integrity');",force=True)
        self.assertIn('1568',r.stderr)
        self.assertIn('1\t1',r.stdout)
        self.assertEqual(self.ok("SELECT COUNT(*) FROM KhoanChi WHERE MaKhoanChi IN ('RV_NEST','RV_COST');"),[['0']])
        self.reconcile()

    def test_caller_lock_preserved(self):
        rows=self.ok("DO GET_LOCK('marketing_btl.integrity',10); "
             f"CALL sp_P2_ThemKhoanChi('NV04',{payload()}); "
             "SELECT IS_USED_LOCK('marketing_btl.integrity')=CONNECTION_ID(); "
             "CALL sp_P2_XoaKhoanChi('NV04','RV_COST'); DO RELEASE_LOCK('marketing_btl.integrity');")
        self.assertEqual(rows,[['RV_COST','THEM','1'],['1'],['RV_COST','XOA','1']])

    def listing(self,campaign='NULL',activity='NULL',start="'2026-11-05'",end="'2026-11-06'",keyword='NULL',sort='NULL'):
        return self.ok(f'CALL sp_P2_DanhSachKhoanChi({campaign},{activity},{start},{end},{keyword},{sort});')

    def grouped(self,threshold='0',campaign="'CD01'",start="'2026-11-05'",end="'2026-11-06'"):
        return self.ok(f'CALL sp_P2_TongChiTheoHoatDong({campaign},{start},{end},{threshold});')

    def test_query_filters_and_dates(self):
        self.assertEqual([r[0] for r in self.listing(campaign="'CD01'")],['KC11','KC01','KC02'])
        self.assertEqual([r[0] for r in self.listing(campaign="'CD01'",activity="'HD01'",sort="'TIEN_GIAM'")],['KC01','KC11'])
        self.assertEqual(len(self.listing()),11)
        self.assertEqual([r[0] for r in self.listing(start="'2026-11-06'")],['KC11'])
        self.assertEqual([r[0] for r in self.listing(keyword="'CT-01'")],['KC01'])
        self.assertEqual(len(self.listing(keyword=lit('Chi phí'))),11)

    def test_query_sort_modes(self):
        amounts=['KC11','KC07','KC03','KC09','KC08','KC05','KC10','KC04','KC06','KC01','KC02']
        for mode,expected in [('TIEN_TANG',amounts),('TIEN_GIAM',list(reversed(amounts))),
                              ('NGAY_TANG',[f'KC{i:02}' for i in range(1,12)]),
                              ('NGAY_GIAM',['KC11']+[f'KC{i:02}' for i in range(1,11)])]:
            with self.subTest(mode=mode):
                self.assertEqual([r[0] for r in self.listing(sort=lit(mode))],expected)
        self.assertEqual(self.listing(sort="'  tien_tang  '"),self.listing(sort="'TIEN_TANG'"))
        self.assertEqual(self.listing(sort="''"),self.listing())

    def test_query_invalid_filters(self):
        for kwargs in [dict(campaign="'MISSING'"),dict(campaign="'CD02'",activity="'HD01'"),dict(start='NULL'),
                       dict(end='NULL'),dict(start="'2026-11-07'"),dict(sort="'BAD'")]:
            with self.subTest(kwargs=kwargs): self.assertEqual(self.listing(**kwargs),[])
        for threshold in ['NULL','-1','3500001']:
            with self.subTest(threshold=threshold): self.assertEqual(self.grouped(threshold),[])

    def test_query_aggregate_and_having(self):
        rows=self.grouped()
        self.assertEqual([(r[2],r[4],r[5]) for r in rows],[('HD02','1','3500000'),('HD01','2','3000000')])
        self.assertEqual([r[2] for r in self.grouped('3200000')],['HD02'])
        self.assertEqual([r[2] for r in self.grouped('3500000')],['HD02'])
        self.assertEqual(self.grouped(start="'2026-11-06'")[0][5],'500000')

    def test_z_seed_preserved_and_totals_match(self):
        self.assertEqual(self.ok('SELECT COUNT(*),SUM(SoTien) FROM KhoanChi;'),[['11','16200000']])
        self.assertEqual(self.ok("SELECT IS_USED_LOCK('marketing_btl.integrity');"),[['NULL']])
        self.reconcile()

if __name__=='__main__':
    unittest.main(argv=[sys.argv[0]]+remaining, verbosity=2)
