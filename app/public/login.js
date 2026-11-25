import './ambient.js';

const form = document.getElementById('login-form');
const password = document.getElementById('password');
const toggle = document.getElementById('password-toggle');
const submit = document.getElementById('login-submit');
const error = document.getElementById('login-error');

try {
  document.documentElement.dataset.theme = localStorage.getItem('campaign-desk-theme') === 'dark' ? 'dark' : 'light';
} catch { /* The default theme still works when browser storage is unavailable. */ }

toggle.addEventListener('click', () => {
  const reveal = password.type === 'password';
  password.type = reveal ? 'text' : 'password';
  const label = reveal ? 'Ẩn mật khẩu' : 'Hiện mật khẩu';
  toggle.title = label;
  toggle.setAttribute('aria-label', label);
  toggle.querySelector('use').setAttribute('href', reveal ? '/icons.svg#eye-off' : '/icons.svg#eye');
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
      window.location.replace('/');
      return;
    }
    const result = await response.json().catch(() => ({}));
    error.textContent = result.error ?? 'Chưa đăng nhập được. Vui lòng thử lại.';
  } catch {
    error.textContent = 'Chưa kết nối được với Campaign Desk. Vui lòng thử lại.';
  } finally {
    if (!navigating) {
      error.hidden = false;
      submit.disabled = false;
      submit.textContent = 'Đăng nhập';
      form.removeAttribute('aria-busy');
    }
  }
});
