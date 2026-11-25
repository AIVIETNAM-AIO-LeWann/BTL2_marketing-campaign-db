import { spawnSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { parseArgs } from 'node:util';

const root = new URL('../', import.meta.url);
const envFile = new URL('app/.env', root);
const sqlFiles = [
  '01_schema.sql', '02_constraints.sql', '03_creation_workflows.sql',
  '04_seed.sql', '05_reports.sql', '06_verify.sql',
  'part2/01_expense_triggers.sql', 'part2/02_expense_crud.sql',
  'part2/03_expense_queries.sql', 'part2/04_marketing_functions.sql', 'part3/01_app_role.sql',
];

function portOption(value) {
  if (!/^\d{1,5}$/.test(value) || Number(value) < 1 || Number(value) > 65535) {
    throw new Error(`Cổng không hợp lệ: ${value}`);
  }
  return String(Number(value));
}

function setup() {
  const { values } = parseArgs({ options: {
    mysql: { type: 'string', default: 'mysql' },
    user: { type: 'string', default: 'root' },
    'db-port': { type: 'string', default: '3306' },
    'web-port': { type: 'string', default: '8080' },
    help: { type: 'boolean' },
  } });
  if (values.help) {
    console.log('node scripts/setup-demo.mjs [--mysql <path>] [--user <admin>] [--db-port <3306>] [--web-port <8080>]');
    return;
  }
  if (existsSync(envFile)) throw new Error('Đã có app/.env. Dùng cấu hình hiện tại hoặc dựng demo trong một bản clone riêng.');
  const dbPort = portOption(values['db-port']);
  const webPort = portOption(values['web-port']);
  const dbUser = `marketing_web_demo_${randomBytes(4).toString('hex')}`;
  const dbPassword = randomBytes(24).toString('hex');
  const demoPassword = randomBytes(12).toString('base64url');
  const account = `'${dbUser}'@'127.0.0.1'`;

  const sql = sqlFiles.map(file => readFileSync(new URL(`database/${file}`, root), 'utf8'));
  // Let MySQL stop the batch on an existing schema before loading any tables or seed rows.
  const createDatabase = 'CREATE DATABASE IF NOT EXISTS marketing_btl';
  if (!sql[0].includes(createDatabase)) throw new Error('Kiểm tra lại câu lệnh tạo database trong 01_schema.sql.');
  sql[0] = sql[0].replace(createDatabase, 'CREATE DATABASE marketing_btl');
  sql.push(`CREATE USER ${account} IDENTIFIED BY '${dbPassword}';
GRANT 'marketing_web' TO ${account};
SET DEFAULT ROLE 'marketing_web' TO ${account};`);

  const client = spawnSync(values.mysql, [
    '--no-defaults', '--no-login-paths', '--batch', '--binary-mode', '--default-character-set=utf8mb4', '--connect-timeout=5',
    '--protocol=TCP', '--host=127.0.0.1', `--port=${dbPort}`, `--user=${values.user}`,
    ...(process.env.MYSQL_PWD === undefined ? ['--password'] : []),
  ], {
    input: sql.join('\n'), stdio: ['pipe', 'inherit', 'inherit'],
  });
  if (client.error) throw new Error(`Không chạy được mysql client. Kiểm tra PATH hoặc dùng --mysql <đường dẫn>. ${client.error.message}`);
  if (client.status !== 0) throw new Error('MySQL dừng khi nạp dữ liệu. Xem lỗi phía trên và trạng thái database trước khi chạy lại.');

  writeFileSync(envFile, [
    'DB_HOST=127.0.0.1', `DB_PORT=${dbPort}`, `DB_USER=${dbUser}`, `DB_PASSWORD=${dbPassword}`,
    'DEMO_ACTOR=NV04', `DEMO_PASSWORD=${demoPassword}`, `PORT=${webPort}`, '',
  ].join('\n'), { flag: 'wx', mode: 0o600 });
  console.log(`Đã tạo database demo và app/.env. Chạy npm ci rồi npm start trong app, sau đó mở http://127.0.0.1:${webPort}.`);
  console.log('Đăng nhập bằng demo và giá trị DEMO_PASSWORD trong app/.env.');
}

try {
  setup();
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
