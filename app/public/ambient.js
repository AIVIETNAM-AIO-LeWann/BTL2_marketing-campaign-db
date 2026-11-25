const preferenceKey = 'campaign-desk-ambient';
const reduced = window.matchMedia('(prefers-reduced-motion: reduce)');
const controls = [...document.querySelectorAll('[data-ambient-toggle]')];
let paused = false;
let glowTimer;
let litBar;
let lastBar;

try { paused = localStorage.getItem(preferenceKey) === 'paused'; } catch { /* In-memory controls still work. */ }

function scheduleGlow() {
  glowTimer = setTimeout(() => {
    const bars = [...document.querySelectorAll('.art-bars i, .chart-meter, .ranked-bars meter')]
      .filter(bar => bar.getBoundingClientRect().height > 0 && !bar.closest('[aria-busy="true"]'));
    const choices = bars.length > 1 ? bars.filter(bar => bar !== lastBar) : bars;
    litBar = choices[Math.floor(Math.random() * choices.length)];
    if (!litBar) return scheduleGlow();
    lastBar = litBar;
    litBar.dataset.glow = '';
    glowTimer = setTimeout(() => {
      delete litBar.dataset.glow;
      litBar = undefined;
      scheduleGlow();
    }, 1300);
  }, 4500 + Math.random() * 4500);
}

function update() {
  const playing = !paused && !reduced.matches && !document.hidden;
  document.documentElement.dataset.ambient = playing ? 'playing' : 'paused';
  clearTimeout(glowTimer);
  if (litBar) delete litBar.dataset.glow;
  litBar = undefined;
  if (playing) scheduleGlow();
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
document.addEventListener('visibilitychange', update);
update();
