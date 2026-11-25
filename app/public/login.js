import './ambient.js';
import './validity-vi.js';
import { burstFromElement, initFX } from './fx.js';
import { initMotion, revealWords, shakeElement, transitionTheme } from './motion.js';

const form = document.getElementById('login-form');
const password = document.getElementById('password');
const toggle = document.getElementById('password-toggle');
const themeBtn = document.getElementById('login-theme-toggle');
const submit = document.getElementById('login-submit');
const submitLabel = submit.querySelector('.submit-label');
const error = document.getElementById('login-error');
const root = document.documentElement;
const VALID_ACCENTS = new Set(['sapphire', 'emerald', 'amethyst', 'amber']);

initMotion({ navSelector: null });
revealWords(document.querySelector('.login-headline'), { delayOffset: 2 });

function applyTheme(dark) {
  root.dataset.theme = dark ? 'dark' : 'light';
  if (!themeBtn) return;
  themeBtn.setAttribute('aria-pressed', String(dark));
  themeBtn.title = dark ? 'Chuyển sang giao diện sáng' : 'Bật giao diện tối';
  themeBtn.querySelector('use').setAttribute('href', dark ? '/icons.svg#sun' : '/icons.svg#moon');
}

function applyAccent(name) {
  const accent = VALID_ACCENTS.has(name) ? name : 'amber';
  root.dataset.accent = accent;
  for (const dot of document.querySelectorAll('#login-accent-picker .accent-dot')) {
    dot.setAttribute('aria-pressed', String(dot.dataset.swatch === accent));
  }
}

try {
  applyTheme(localStorage.getItem('campaign-desk-theme') !== 'light');
  applyAccent(localStorage.getItem('campaign-desk-accent-v3') || 'amber');
} catch {
  applyTheme(true);
  applyAccent('amber');
}

initFX();

for (const dot of document.querySelectorAll('#login-accent-picker .accent-dot')) {
  dot.addEventListener('click', () => {
    const next = dot.dataset.swatch;
    if (root.dataset.accent === next) return;
    burstFromElement(dot, { count: 14, spread: 3.8 });
    transitionTheme(dot, () => {
      applyAccent(next);
      try { localStorage.setItem('campaign-desk-accent-v3', next); } catch { /* ignore */ }
    });
  });
}

themeBtn?.addEventListener('click', () => {
  const nextDark = root.dataset.theme !== 'dark';
  themeBtn.querySelector('svg')?.animate?.(
    [{ transform: 'rotate(0deg) scale(.85)' }, { transform: 'rotate(360deg) scale(1)' }],
    { duration: 560, easing: 'cubic-bezier(.16, 1, .3, 1)' },
  );
  burstFromElement(themeBtn, { count: 16, spread: 4.2 });
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
    { duration: 240, easing: 'cubic-bezier(.22, 1.06, .36, 1)' },
  );
});

form.addEventListener('submit', async event => {
  event.preventDefault();
  if (submit.disabled) return;
  error.hidden = true;
  submit.disabled = true;
  submitLabel.textContent = 'Đang xác thực…';
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
      submitLabel.textContent = 'Đang mở Campaign Desk…';
      burstFromElement(submit, { count: 32, spread: 6.4, intensity: 1.05 });
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
      submitLabel.textContent = 'Tiếp tục vào Campaign Desk';
      form.removeAttribute('aria-busy');
    }
  }
});
