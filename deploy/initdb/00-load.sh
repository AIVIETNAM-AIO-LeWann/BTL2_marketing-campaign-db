#!/bin/sh
# Chạy một lần khi thư mục dữ liệu MySQL còn trống: nạp phần 1, 2, role web rồi tạo tài khoản cho app.
set -eu
run() { mysql --default-character-set=utf8mb4 -uroot -p"$MYSQL_ROOT_PASSWORD" "$@"; }
for f in 01_schema 02_constraints 03_creation_workflows 04_seed 05_reports 06_verify \
         part2/01_expense_triggers part2/02_expense_crud part2/03_expense_queries part2/04_marketing_functions \
         part3/01_app_role; do
  echo "Nạp $f.sql"
  run < "/sql/$f.sql"
done
run <<SQL
CREATE USER '${APP_DB_USER}'@'%' IDENTIFIED BY '${APP_DB_PASSWORD}';
GRANT 'marketing_web' TO '${APP_DB_USER}'@'%';
SET DEFAULT ROLE 'marketing_web' TO '${APP_DB_USER}'@'%';
SQL
echo "Xong: database marketing_btl và tài khoản ${APP_DB_USER}."
