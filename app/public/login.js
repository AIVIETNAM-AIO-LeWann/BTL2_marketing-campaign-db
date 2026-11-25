import './ambient.js';
import './validity-vi.js';
import { burstFromElement, initFX } from './fx.js';
import { initMotion, shakeElement, transitionTheme } from './motion.js';

const form = document.getElementById('login-form');
const password = document.getElementById('password');
const toggle = document.getElementById('password-toggle');
const themeBtn = document.getElementById('login-theme-toggle');
const submit = document.getElementById('login-submit');
const error = document.getElementById('login-error');
const root = document.documentElement;

initMotion({ navSelector: null });
initFX();

function applyTheme(dark) {
  root.dataset.theme = dark ? 'dark' : 'light';
  if (!themeBtn) return;
  themeBtn.setAttribute('aria-pressed', String(dark));
  themeBtn.title = dark ? 'Chuyển sang giao diện sáng' : 'Bật giao diện tối';
  themeBtn.querySelector('use').setAttribute('href', dark ? '/icons.svg#sun' : '/icons.svg#moon');
}

try {
  applyTheme(localStorage.getItem('campaign-desk-theme') !== 'light');
} catch {
  applyTheme(true);
}

themeBtn?.addEventListener('click', () => {
  const nextDark = root.dataset.theme !== 'dark';
  burstFromElement(themeBtn, { count: 18, spread: 4.8 });
  transitionTheme(themeBtn, () => {
    applyTheme(nextDark);
    try { localStorage.setItem('campaign-desk-theme', root.dataset.theme); } catch { /* ignore */ }
  });
});

toggle.addEventListener('click', () => {
  const reveal = password.type === 'password';
  password.type = reveal ? 'text' : 'password';
  const label = reveal ? 'Ẩn mật khẩu' : 'Hiện mật khẩu';
  toggle.title = label;
  toggle.setAttribute('aria-label', label);
  const use = toggle.querySelector('use');
  use.setAttribute('href', reveal ? '/icons.svg#eye-off' : '/icons.svg#eye');
  toggle.querySelector('svg')?.animate?.(
    [{ transform: 'scale(.72) rotate(-14deg)' }, { transform: 'scale(1) rotate(0deg)' }],
    { duration: 240, easing: 'cubic-bezier(.32, 1.24, .5, 1)' },
  );
});

form.addEventListener('submit', async event => {
  event.preventDefault();
  if (submit.disabled) return;
  error.hidden = true;
  submit.disabled = true;
  submit.textContent = 'Đang đăng nhập…';
  form.setAttribute('aria-busy', 'true');
  let navigating = false;
  try {
    const response = await fetch('/api/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(Object.fromEntries(new FormData(form))),
    });
    if (response.ok) {
      navigating = true;
      password.type = 'password';
      password.value = '';
      submit.textContent = 'Đang mở Campaign Desk…';
      burstFromElement(submit, { count: 38, spread: 7.5, intensity: 1.15 });
      setTimeout(() => window.location.replace('/'), 340);
      return;
    }
    const result = await response.json().catch(() => ({}));
    error.textContent = result.error ?? 'Chưa đăng nhập được. Vui lòng thử lại.';
  } catch {
    error.textContent = 'Chưa kết nối được với Campaign Desk. Vui lòng thử lại.';
  } finally {
    if (!navigating) {
      error.hidden = false;
      shakeElement(error);
      submit.disabled = false;
      submit.textContent = 'Đăng nhập';
      form.removeAttribute('aria-busy');
    }
  }
});
