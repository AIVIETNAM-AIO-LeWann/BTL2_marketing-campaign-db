import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import { isIP } from 'node:net';
import { readFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import mysql from 'mysql2/promise';

const config = process.env;
const actor = config.DEMO_ACTOR ?? 'NV04';
if (!config.DB_USER || !config.DB_PASSWORD || (config.DEMO_PASSWORD?.length ?? 0) < 12) {
  throw new Error('Đặt DB_USER, DB_PASSWORD và DEMO_PASSWORD (ít nhất 12 ký tự) trong app/.env.');
}
if (!/^[A-Za-z0-9_-]{1,20}$/.test(actor)) throw new Error('DEMO_ACTOR không hợp lệ.');

const db = mysql.createPool({
  host: config.DB_HOST ?? '127.0.0.1', port: Number(config.DB_PORT ?? 3306),
  user: config.DB_USER, password: config.DB_PASSWORD, database: 'marketing_btl',
  charset: 'utf8mb4', dateStrings: true, supportBigNumbers: true, bigNumberStrings: true,
  connectionLimit: 5, queueLimit: 20, connectTimeout: 5000,
});

const staticFiles = new Map([
  ['/styles.css', ['styles.css', 'text/css; charset=utf-8']],
  ['/app.js', ['app.js', 'text/javascript; charset=utf-8']],
  ['/ambient.js', ['ambient.js', 'text/javascript; charset=utf-8']],
  ['/validity-vi.js', ['validity-vi.js', 'text/javascript; charset=utf-8']],
  ['/login.css', ['login.css', 'text/css; charset=utf-8']],
  ['/login.js', ['login.js', 'text/javascript; charset=utf-8']],
  ['/icons.svg', ['icons.svg', 'image/svg+xml']],
  ['/favicon.svg', ['favicon.svg', 'image/svg+xml']],
  ['/geist-latin.woff2', ['geist-latin.woff2', 'font/woff2']],
  ['/geist-vietnamese.woff2', ['geist-vietnamese.woff2', 'font/woff2']],
]);
const sortOptions = new Set(['NGAY_TANG','NGAY_GIAM','TIEN_TANG','TIEN_GIAM']);
const digest = (value) => createHash('sha256').update(value).digest();
const expectedPassword = digest(config.DEMO_PASSWORD);
const sessionCookie = 'campaign_desk_session';
const sessionSeconds = 8 * 60 * 60;
const sessions = new Map();
let loginWindowEnd = 0;
let failedLogins = 0;
const failedByClient = new Map();

function activeSession(request) {
  const key = request.headers.cookie?.match(/(?:^|;\s*)campaign_desk_session=([a-f0-9]{64})(?:;|$)/)?.[1];
  if (!key || !sessions.has(key)) return null;
  if (sessions.get(key) > Date.now()) return key;
  sessions.delete(key);
  return null;
}

function setSessionCookie(request, response, value, seconds) {
  // Node only listens on loopback. cloudflared supplies the public scheme.
  const viaHttps = request.headers['x-forwarded-proto'] === 'https';
  response.setHeader('Set-Cookie', `${sessionCookie}=${value}; Path=/; HttpOnly; SameSite=Lax; Max-Age=${seconds}${viaHttps ? '; Secure' : ''}`);
}

async function login(request, response) {
  const body = await jsonBody(request);
  const now = Date.now();
  if (now >= loginWindowEnd) {
    loginWindowEnd = now + 60_000;
    failedLogins = 0;
  }
  // Mỗi người một bộ đếm riêng để một người nhập sai không khóa người khác; tổng chung giữ trần cho việc dò mật khẩu.
  // cf-connecting-ip do cloudflared đặt; Node chỉ nghe loopback nên không ai ngoài đường hầm tự đặt được.
  // Giá trị header không phải địa chỉ IP hợp lệ thì dùng địa chỉ kết nối thật, để không tạo khóa tùy ý.
  const forwarded = request.headers['cf-connecting-ip'];
  const client = isIP(forwarded ?? '') ? forwarded : (request.socket.remoteAddress ?? '');
  let mine = failedByClient.get(client);
  if (mine && now >= mine.windowEnd) { failedByClient.delete(client); mine = undefined; }
  if ((mine?.failures ?? 0) >= 12 || failedLogins >= 120) {
    const resetAt = (mine?.failures ?? 0) >= 12 ? mine.windowEnd : loginWindowEnd;
    response.setHeader('Retry-After', String(Math.max(1, Math.ceil((resetAt - now) / 1000))));
    return send(response, 429, { error: 'Đã thử đăng nhập quá nhiều lần. Vui lòng thử lại sau ít phút.' });
  }
  const username = string(body.username, 'Tên đăng nhập', 64);
  const password = string(body.password, 'Mật khẩu', 1024, { trim: false });
  const validPassword = timingSafeEqual(digest(password), expectedPassword);
  if (username !== 'demo' || !validPassword) {
    failedLogins++;
    if (!mine) {
      // Chỉ lưu người đã nhập sai, và giữ tối đa 1000 người: bỏ mục hết hạn trước, rồi bỏ mục cũ nhất.
      if (failedByClient.size >= 1000) {
        for (const [key, entry] of failedByClient) if (now >= entry.windowEnd) failedByClient.delete(key);
        while (failedByClient.size >= 1000) failedByClient.delete(failedByClient.keys().next().value);
      }
      mine = { failures: 0, windowEnd: now + 60_000 };
      failedByClient.set(client, mine);
    }
    mine.failures++;
    return send(response, 401, { error: 'Tên đăng nhập hoặc mật khẩu không đúng.' });
  }
  for (const [key, expiresAt] of sessions) {
    if (expiresAt <= now) sessions.delete(key);
  }
  const previous = activeSession(request);
  if (previous) sessions.delete(previous);
  if (sessions.size >= 256) return send(response, 503, { error: 'Phiên demo đã đầy. Vui lòng thử lại sau.' });
  const token = randomBytes(32).toString('hex');
  sessions.set(token, Date.now() + sessionSeconds * 1000);
  setSessionCookie(request, response, token, sessionSeconds);
  return send(response, 200, { ok: true });
}

class InputError extends Error {}
function string(value, label, limit, { required = true, trim = true } = {}) {
  if ((value === null || value === undefined) && !required) return null;
  if (typeof value !== 'string') throw new InputError(`${label} phải là văn bản.`);
  const clean = trim ? value.trim() : value;
  if (!clean.trim()) {
    if (!required) return null;
    throw new InputError(`Vui lòng nhập ${label.toLowerCase()}.`);
  }
  if ([...clean].length > limit) throw new InputError(`${label} tối đa ${limit} ký tự.`);
  return clean;
}

function code(value, label, required = true) {
  const clean = string(value, label, 20, { required, trim: false });
  if (clean && !/^[A-Za-z0-9_-]+$/.test(clean)) {
    throw new InputError(`${label} chỉ gồm chữ cái Latin, chữ số, dấu gạch ngang hoặc gạch dưới.`);
  }
  return clean;
}

function date(value, label) {
  const clean = string(value, label, 10);
  const parsed = new Date(`${clean}T00:00:00Z`);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(clean) || clean < '1000-01-01' ||
      !Number.isFinite(+parsed) || parsed.toISOString().slice(0,10) !== clean) {
    throw new InputError(`${label} phải là ngày hợp lệ.`);
  }
  return clean;
}

function period(params) {
  const start = date(params.get('from'), 'Từ ngày');
  const end = date(params.get('to'), 'Đến ngày');
  if (start > end) throw new InputError('Từ ngày phải trước hoặc bằng Đến ngày.');
  return [start, end];
}

function money(value, label, digits, allowZero = false) {
  const clean = string(value, label, digits);
  if (!/^\d+$/.test(clean) || (!allowZero && BigInt(clean) === 0n)) {
    throw new InputError(`${label} phải là số nguyên ${allowZero ? 'không âm' : 'lớn hơn 0'} (VND).`);
  }
  return BigInt(clean).toString();
}

async function jsonBody(request) {
  if (request.headers['content-type']?.split(';')[0] !== 'application/json') {
    throw new InputError('Yêu cầu phải chứa JSON.');
  }
  let length = 0;
  const chunks = [];
  for await (const chunk of request) {
    length += chunk.length;
    if (length <= 8192) chunks.push(chunk);
  }
  if (length > 8192) throw new InputError('Dữ liệu gửi lên quá dài.');
  let value;
  try { value = JSON.parse(Buffer.concat(chunks).toString('utf8')); }
  catch { throw new InputError('Nội dung JSON không hợp lệ.'); }
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new InputError('Dữ liệu phải là một đối tượng.');
  return value;
}

function expensePayload(body, creating) {
  const expense = {
    MaHoatDong: code(body.activity, 'Mã hoạt động'),
    NgayPhatSinh: date(body.date, 'Ngày phát sinh'),
    NoiDungChi: string(body.description, 'Nội dung chi', 500),
    MaChungTu: string(body.receipt, 'Mã chứng từ', 100, { required: false }),
  };
  if (creating) expense.MaKhoanChi = code(body.id, 'Mã khoản chi');
  const amount = money(body.amount, 'Số tiền', 18);
  // JSON number text preserves all 18 integer digits for the SQL JSON parameter.
  return JSON.stringify(expense).slice(0,-1) + `,"SoTien":${amount}}`;
}

async function rows(sql, values = []) {
  const [data] = await db.execute(sql, values);
  return data;
}

async function call(sql, parameters) {
  const result = await rows(sql, parameters);
  return result[0];
}

const dbErrors = {
  P2_DUP: [409,'Mã khoản chi đã tồn tại. Hãy dùng mã khác.'],
  P2_NOTFOUND: [404,'Khoản chi hoặc hoạt động đã chọn không còn tồn tại.'],
  P2_PERM: [403,'Chỉ người ghi nhận khoản chi mới được sửa hoặc xóa.'],
  P2_ACTOR: [403,'Tài khoản nhân viên dùng cho demo đang bị khóa.'],
  RB15: [403,'Nhân viên demo chưa được phân công vào chiến dịch này.'],
  RB16: [409,'Hoạt động hoặc chiến dịch đã kết thúc. Khoản chi ở đó được giữ lịch sử.'],
  P1_LOCK: [503,'Hệ thống đang ghi dữ liệu. Vui lòng thử lại.'],
  P2_FN_NOTFOUND: [404,'Chiến dịch hoặc hoạt động đã chọn không tồn tại.'],
  P2_FN_INPUT: [422,'Khoảng ngày phải nằm trong thời gian của hoạt động đã chọn.'],
};

function send(response, status, value) {
  response.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
  response.end(JSON.stringify(value));
}

function redirect(response, path) {
  response.writeHead(303, { Location: path });
  response.end();
}

async function sendFile(response, [file, type]) {
  const content = await readFile(new URL(`public/${file}`, import.meta.url));
  response.writeHead(200, { 'Content-Type': type });
  response.end(content);
}

async function route(request, response) {
  const url = new URL(request.url, 'http://localhost');
  const method = request.method;
  const params = url.searchParams;
  const pathname = url.pathname;
  if (method === 'GET' || method === 'HEAD') {
    if (staticFiles.has(pathname)) return sendFile(response, staticFiles.get(pathname));
    if (pathname === '/' || pathname === '/login') {
      const signedIn = Boolean(activeSession(request));
      if (pathname === '/' && !signedIn) return redirect(response, '/login');
      if (pathname === '/login' && signedIn) return redirect(response, '/');
      return sendFile(response, [signedIn ? 'index.html' : 'login.html', 'text/html; charset=utf-8']);
    }
  }
  if (method === 'POST' && pathname === '/api/login') return login(request, response);
  if (method === 'POST' && pathname === '/api/logout') {
    await jsonBody(request);
    const token = activeSession(request);
    if (token) sessions.delete(token);
    setSessionCookie(request, response, '', 0);
    return send(response, 200, { ok: true });
  }
  if (pathname.startsWith('/api/') && !activeSession(request)) {
    return send(response, 401, { error: 'Phiên đăng nhập đã hết. Vui lòng đăng nhập lại.' });
  }
  if (method === 'GET' && url.pathname === '/api/catalog') {
    const [campaigns, activities, assignments, dates] = await Promise.all([
      rows('SELECT MaChienDich,TenChienDich,TrangThai FROM ChienDich ORDER BY MaChienDich'),
      rows('SELECT MaHoatDong,TenHoatDong,MaChienDich,TrangThai,NgayBatDau,NgayKetThucDuKien FROM HoatDongTrienKhai ORDER BY MaHoatDong'),
      rows('SELECT MaChienDich FROM PhanCong WHERE MaNhanVien=?', [actor]),
      rows('SELECT MIN(NgayPhatSinh) AS firstDate, MAX(NgayPhatSinh) AS lastDate FROM KhoanChi'),
    ]);
    return send(response, 200, { actor, campaigns, activities, campaignsAssigned: assignments.map(a => a.MaChienDich), ...dates[0] });
  }
  if (method === 'GET' && url.pathname === '/api/expenses') {
    const campaign = code(params.get('campaign'), 'Mã chiến dịch', false);
    const activity = code(params.get('activity'), 'Mã hoạt động', false);
    const sort = params.get('sort') || 'NGAY_GIAM';
    if (!sortOptions.has(sort)) throw new InputError('Kiểu sắp xếp không hợp lệ.');
    const keyword = string(params.get('q'), 'Từ khóa', 255, { required: false });
    // Thủ tục 2.3 dùng LIKE nên % và _ là ký tự đại diện; thoát chúng để từ khóa được tìm đúng như đã gõ.
    const likeKeyword = keyword?.replace(/[\\%_]/g, '\\$&') ?? null;
    if (likeKeyword && likeKeyword.length > 255) throw new InputError('Từ khóa chứa quá nhiều ký tự đặc biệt.');
    const result = await call('CALL sp_P2_DanhSachKhoanChi(?, ?, ?, ?, ?, ?)', [
      campaign, activity, ...period(params), likeKeyword, sort,
    ]);
    return send(response, 200, { rows: result });
  }
  if (method === 'GET' && url.pathname === '/api/reports') {
    const campaign = code(params.get('campaign'), 'Mã chiến dịch', false);
    const result = await call('CALL sp_P2_TongChiTheoHoatDong(?, ?, ?, ?)', [
      campaign, ...period(params), money(params.get('min') || '0', 'Tổng chi tối thiểu', 38, true),
    ]);
    return send(response, 200, { rows: result });
  }
  if (method === 'GET' && url.pathname === '/api/metrics') {
    const campaign = code(params.get('campaign'), 'Mã chiến dịch');
    const activity = code(params.get('activity'), 'Mã hoạt động', false);
    const [start, end] = period(params);
    const result = activity
      ? await rows(`SELECT fn_P2_DemHoatDongVuotNganSach(?) AS overspent,
                       fn_P2_ChiPhiTrenChuyenDoi(MaHoatDong,?,?) AS cpa
                    FROM HoatDongTrienKhai WHERE MaHoatDong=? AND MaChienDich=?`, [campaign,start,end,activity,campaign])
      : await rows('SELECT fn_P2_DemHoatDongVuotNganSach(?) AS overspent, NULL AS cpa', [campaign]);
    if (!result.length) throw new InputError('Hoạt động đã chọn phải thuộc chiến dịch.');
    return send(response, 200, result[0]);
  }
  if (method === 'POST' && url.pathname === '/api/expenses') {
    const payload = expensePayload(await jsonBody(request), true);
    return send(response, 201, (await call('CALL sp_P2_ThemKhoanChi(?,?)', [actor,payload]))[0]);
  }
  const match = /^\/api\/expenses\/([^/]+)$/.exec(url.pathname);
  if (match && (method === 'PUT' || method === 'DELETE')) {
    const id = code(decodeURIComponent(match[1]), 'Mã khoản chi');
    const body = await jsonBody(request);
    const result = method === 'PUT'
      ? await call('CALL sp_P2_SuaKhoanChi(?,?,?)', [actor,id,expensePayload(body, false)])
      : await call('CALL sp_P2_XoaKhoanChi(?,?)', [actor,id]);
    return send(response, 200, result[0]);
  }
  return send(response, 404, { error: 'Không tìm thấy trang hoặc tác vụ.' });
}

// Node chỉ kiểm tra kết nối chậm mỗi 30 giây theo mặc định; rút ngắn để hai mốc timeout bên dưới có tác dụng.
const server = createServer({ connectionsCheckingInterval: 2_000 }, async (request, response) => {
  response.setHeader('Cache-Control','no-store');
  response.setHeader('X-Content-Type-Options','nosniff');
  response.setHeader('Content-Security-Policy', "default-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'");
  response.setHeader('Referrer-Policy','no-referrer');
  const fetchSite = request.headers['sec-fetch-site'];
  if (!['GET','HEAD'].includes(request.method) && fetchSite && fetchSite !== 'same-origin' && fetchSite !== 'none') {
    return send(response, 403, { error: 'Chỉ chấp nhận thao tác từ trang Campaign Desk.' });
  }
  try {
    await route(request, response);
  } catch (error) {
    if (error instanceof InputError || error instanceof URIError) {
      return send(response, 422, { error: error instanceof URIError ? 'Đường dẫn không hợp lệ.' : error.message });
    }
    const marker = error.sqlMessage?.match(/^([A-Z0-9_]+):\s*(.*)/);
    if (marker && dbErrors[marker[1]]) {
      const [status, message] = dbErrors[marker[1]];
      return send(response, status, { error: message, code: marker[1] });
    }
    if (marker?.[1] === 'P2_INPUT') return send(response, 422, { error: marker[2], code: marker[1] });
    console.error('Request failed:', error.code ?? error.name);
    return send(response, 503, { error: 'Không đọc hoặc ghi được dữ liệu MySQL. Hãy thử lại hoặc liên hệ người phụ trách demo.' });
  }
});

await rows('SELECT 1');
// Yêu cầu chậm không được giữ kết nối lâu: mặc định của Node là 5 phút cho cả yêu cầu.
server.headersTimeout = 10_000;
server.requestTimeout = 15_000;
const port = Number(config.PORT ?? 8080);
server.listen(port, '127.0.0.1', () => console.log(`Marketing demo: http://127.0.0.1:${port}`));
for (const signal of ['SIGINT','SIGTERM']) {
  process.on(signal, () => server.close(() => void db.end()));
}
