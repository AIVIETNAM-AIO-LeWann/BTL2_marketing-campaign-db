import { spawn } from 'node:child_process';
import { once } from 'node:events';

async function startTunnel() {
  const { PORT = '8080', CLOUDFLARED_BIN, ...env } = process.env;
  const port = Number(PORT);
  if (!/^\d+$/.test(PORT) || port < 1 || port > 65535) {
    throw new Error('PORT trong app/.env phải là số nguyên từ 1 đến 65535.');
  }

  const origin = `http://127.0.0.1:${port}`;
  const loginPage = await fetch(`${origin}/login`, {
    redirect: 'error',
    signal: AbortSignal.timeout(3500),
  }).then(response => response.ok ? response.text() : '').catch(() => '');
  if (!loginPage.includes('id="login-form"') || !loginPage.includes('src="/login.js"')) {
    throw new Error(`Chưa thấy Campaign Desk tại ${origin}. Chạy npm start trong thư mục app và đối chiếu PORT trước.`);
  }

  // The connector only needs the origin address. Keep web/MySQL credentials out of its environment.
  for (const key of Object.keys(env)) {
    if (/^(DB_PASSWORD|DEMO_PASSWORD|MYSQL_PWD)$/i.test(key)) delete env[key];
  }
  const connector = spawn(CLOUDFLARED_BIN || 'cloudflared', ['tunnel', '--url', origin], { env, stdio: 'inherit' });
  const stop = () => connector.kill();
  process.once('SIGINT', stop);
  process.once('SIGTERM', stop);
  try {
    const [code, signal] = await once(connector, 'exit');
    process.exitCode = code ?? (signal === 'SIGINT' ? 130 : 1);
  } catch (error) {
    if (error.code === 'ENOENT') {
      throw new Error('Không tìm thấy cloudflared. Cài cloudflared hoặc đặt CLOUDFLARED_BIN trong app/.env.');
    }
    throw error;
  } finally {
    process.off('SIGINT', stop);
    process.off('SIGTERM', stop);
  }
}

try {
  await startTunnel();
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
