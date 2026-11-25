const preferenceKey = 'campaign-desk-ambient';
const reduced = window.matchMedia('(prefers-reduced-motion: reduce)');
const controls = [...document.querySelectorAll('[data-ambient-toggle]')];
let paused = false;

try { paused = localStorage.getItem(preferenceKey) === 'paused'; } catch { /* In-memory controls still work. */ }

function update() {
  document.documentElement.dataset.ambient = paused || reduced.matches ? 'paused' : 'playing';
  for (const button of controls) {
    button.hidden = reduced.matches;
    button.setAttribute('aria-pressed', String(paused));
    button.title = paused ? 'Bật lại chuyển động nền' : 'Tạm dừng nền chuyển động';
    button.querySelector('use').setAttribute('href', paused ? '/icons.svg#play' : '/icons.svg#pause');
  }
}

for (const button of controls) {
  button.addEventListener('click', () => {
    paused = !paused;
    try { localStorage.setItem(preferenceKey, paused ? 'paused' : 'playing'); } catch { /* Apply without persistence. */ }
    update();
  });
}
reduced.addEventListener('change', update);
update();
