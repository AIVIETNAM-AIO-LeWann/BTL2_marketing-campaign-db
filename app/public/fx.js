// Ultra-Light 60-120fps Multi-Palette Liquid Canvas FX Engine:
// Syncs live with [data-accent] (sapphire | emerald | amethyst | amber) and [data-theme] (dark | light).

const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
const finePointer = window.matchMedia('(hover: hover) and (pointer: fine)');

let canvas = null;
let ctx = null;
let width = 0;
let height = 0;
let rafId = 0;
let running = false;
let time = 0;
let colorsCache = null;

const pointer = { x: -9999, y: -9999, tx: -9999, ty: -9999, active: false };
const ambientNodes = [];
const burstParticles = [];

const PALETTES = {
  sapphire: {
    dark: {
      nodes: ['rgba(56,228,255,', 'rgba(110,168,255,', 'rgba(124,242,216,'],
      line: 'rgba(56,228,255,',
      ribbonA: 'rgba(56,228,255,0.085)',
      ribbonB: 'rgba(99,138,255,0.075)',
      ribbonC: 'rgba(45,212,191,0.06)',
      aura: 'rgba(56,228,255,0.115)',
      auraMid: 'rgba(68,128,255,0.06)',
      burst: ['#38e4ff', '#8ef4ff', '#6398ff', '#5eead4', '#ffffff'],
    },
    light: {
      nodes: ['rgba(15,82,186,', 'rgba(14,148,186,', 'rgba(99,102,241,'],
      line: 'rgba(15,82,186,',
      ribbonA: 'rgba(15,82,186,0.065)',
      ribbonB: 'rgba(14,165,212,0.075)',
      ribbonC: 'rgba(99,102,241,0.055)',
      aura: 'rgba(15,82,186,0.075)',
      auraMid: 'rgba(56,189,248,0.075)',
      burst: ['#0f52ba', '#0ea5e9', '#38bdf8', '#6366f1', '#1d4ed8'],
    },
  },
  emerald: {
    dark: {
      nodes: ['rgba(198,242,86,', 'rgba(108,224,182,', 'rgba(236,200,114,'],
      line: 'rgba(196,238,79,',
      ribbonA: 'rgba(196,238,79,0.08)',
      ribbonB: 'rgba(84,214,174,0.07)',
      ribbonC: 'rgba(126,196,255,0.055)',
      aura: 'rgba(196,238,79,0.11)',
      auraMid: 'rgba(86,208,166,0.055)',
      burst: ['#c4ee4f', '#e8ffaa', '#78e6be', '#f7dd8e', '#ffffff'],
    },
    light: {
      nodes: ['rgba(23,108,76,', 'rgba(54,162,134,', 'rgba(198,146,68,'],
      line: 'rgba(23,108,76,',
      ribbonA: 'rgba(23,118,82,0.065)',
      ribbonB: 'rgba(82,188,140,0.08)',
      ribbonC: 'rgba(218,178,104,0.065)',
      aura: 'rgba(32,138,96,0.08)',
      auraMid: 'rgba(154,224,164,0.075)',
      burst: ['#176044', '#38a878', '#b8e89f', '#d4a352', '#26805c'],
    },
  },
  amethyst: {
    dark: {
      nodes: ['rgba(243,200,107,', 'rgba(184,142,255,', 'rgba(236,154,212,'],
      line: 'rgba(243,200,107,',
      ribbonA: 'rgba(243,200,107,0.08)',
      ribbonB: 'rgba(168,120,255,0.08)',
      ribbonC: 'rgba(232,146,206,0.055)',
      aura: 'rgba(243,200,107,0.10)',
      auraMid: 'rgba(162,112,255,0.065)',
      burst: ['#f3c86b', '#ffe6a8', '#b88eff', '#f0a6da', '#ffffff'],
    },
    light: {
      nodes: ['rgba(109,62,186,', 'rgba(180,126,38,', 'rgba(168,85,200,'],
      line: 'rgba(109,62,186,',
      ribbonA: 'rgba(109,62,186,0.065)',
      ribbonB: 'rgba(198,144,54,0.075)',
      ribbonC: 'rgba(168,85,200,0.055)',
      aura: 'rgba(109,62,186,0.075)',
      auraMid: 'rgba(224,178,96,0.075)',
      burst: ['#6d3eba', '#b47e26', '#9b6ef3', '#e0b260', '#5b2ea6'],
    },
  },
  amber: {
    dark: {
      nodes: ['rgba(255,164,92,', 'rgba(255,212,130,', 'rgba(128,186,232,'],
      line: 'rgba(255,164,92,',
      ribbonA: 'rgba(255,164,92,0.08)',
      ribbonB: 'rgba(120,174,224,0.07)',
      ribbonC: 'rgba(255,208,124,0.055)',
      aura: 'rgba(255,164,92,0.105)',
      auraMid: 'rgba(116,166,216,0.055)',
      burst: ['#ffa45c', '#ffd48a', '#7eb8e8', '#ff8c69', '#ffffff'],
    },
    light: {
      nodes: ['rgba(186,86,28,', 'rgba(66,114,162,', 'rgba(212,140,46,'],
      line: 'rgba(186,86,28,',
      ribbonA: 'rgba(186,86,28,0.065)',
      ribbonB: 'rgba(72,124,174,0.07)',
      ribbonC: 'rgba(216,154,66,0.065)',
      aura: 'rgba(186,86,28,0.07)',
      auraMid: 'rgba(118,168,214,0.07)',
      burst: ['#ba561c', '#d88c2e', '#4676a6', '#f0a668', '#9c4312'],
    },
  },
};

function ambientEnabled() {
  return !reducedMotion.matches && document.documentElement.dataset.ambient !== 'paused' && !document.hidden;
}

function refreshPalette() {
  const accent = document.documentElement.dataset.accent || 'amber';
  const mode = document.documentElement.dataset.theme === 'dark' ? 'dark' : 'light';
  colorsCache = (PALETTES[accent] ?? PALETTES.amber)[mode];
}

function seedAmbientNodes() {
  ambientNodes.length = 0;
  const count = Math.max(18, Math.min(28, Math.round((width * height) / 58000)));
  for (let i = 0; i < count; i++) {
    ambientNodes.push({
      x: Math.random() * width,
      y: Math.random() * height,
      vx: (Math.random() - 0.5) * 0.13,
      vy: (Math.random() - 0.5) * 0.11 - 0.02,
      r: 1.25 + Math.random() * 1.85,
      phase: Math.random() * Math.PI * 2,
      speed: 0.0032 + Math.random() * 0.005,
      kind: i % 5 === 0 ? 2 : i % 2 === 0 ? 1 : 0,
    });
  }
}

function resize() {
  if (!canvas) return;
  width = window.innerWidth;
  height = window.innerHeight;
  canvas.width = width;
  canvas.height = height;
  if (ambientNodes.length === 0) seedAmbientNodes();
}

function drawLiquidRibbon(baseY, amp, freq, phaseShift, strokeColor, lineWidth) {
  ctx.beginPath();
  const steps = 16;
  const stepX = width / steps;
  let prevX = 0;
  let prevY = baseY + Math.sin(time * 0.42 + phaseShift) * amp;
  ctx.moveTo(prevX, prevY);
  for (let i = 1; i <= steps; i++) {
    const t = i / steps;
    const x = i * stepX;
    const y = baseY
      + Math.sin(t * Math.PI * freq + time * 0.42 + phaseShift) * amp
      + Math.cos(t * Math.PI * (freq * 1.5) - time * 0.28 + phaseShift) * (amp * 0.42);
    const midX = (prevX + x) * 0.5;
    const midY = (prevY + y) * 0.5;
    ctx.quadraticCurveTo(prevX, prevY, midX, midY);
    prevX = x;
    prevY = y;
  }
  ctx.lineTo(prevX, prevY);
  ctx.strokeStyle = strokeColor;
  ctx.lineWidth = lineWidth;
  ctx.stroke();
}

function drawFrame() {
  rafId = 0;
  if (!ctx) return;

  const canAmbient = ambientEnabled();
  const hasBursts = burstParticles.length > 0 && !reducedMotion.matches && !document.hidden;
  if (!canAmbient && !hasBursts) {
    ctx.clearRect(0, 0, width, height);
    running = false;
    return;
  }

  time += 0.0085;
  ctx.clearRect(0, 0, width, height);
  const colors = colorsCache;

  if (pointer.active) {
    if (pointer.x < -1000) {
      pointer.x = pointer.tx;
      pointer.y = pointer.ty;
    } else {
      pointer.x += (pointer.tx - pointer.x) * 0.065;
      pointer.y += (pointer.ty - pointer.y) * 0.065;
    }
  }

  if (canAmbient) {
    drawLiquidRibbon(height * 0.24, 38, 1.7, 0.0, colors.ribbonA, 2.3);
    drawLiquidRibbon(height * 0.54, 42, 1.4, 2.6, colors.ribbonC, 1.9);
    drawLiquidRibbon(height * 0.80, 36, 1.6, 4.1, colors.ribbonB, 2.1);

    if (pointer.active && finePointer.matches) {
      const grad = ctx.createRadialGradient(pointer.x, pointer.y, 0, pointer.x, pointer.y, 280);
      grad.addColorStop(0, colors.aura);
      grad.addColorStop(0.5, colors.auraMid);
      grad.addColorStop(1, 'rgba(0,0,0,0)');
      ctx.fillStyle = grad;
      ctx.beginPath();
      ctx.arc(pointer.x, pointer.y, 280, 0, Math.PI * 2);
      ctx.fill();
    }

    const linkSq = 145 * 145;
    const cursorRadius = 215;
    const cursorSq = cursorRadius * cursorRadius;

    for (let i = 0; i < ambientNodes.length; i++) {
      const p = ambientNodes[i];
      p.phase += p.speed;
      p.x += p.vx + Math.sin(p.phase) * 0.14;
      p.y += p.vy + Math.cos(p.phase * 0.8) * 0.1;

      let cursorInfluence = 0;
      if (pointer.active && finePointer.matches) {
        const dx = pointer.x - p.x;
        const dy = pointer.y - p.y;
        const dSq = dx * dx + dy * dy;
        if (dSq < cursorSq && dSq > 1) {
          const dist = Math.sqrt(dSq);
          cursorInfluence = 1 - dist / cursorRadius;
          const force = cursorInfluence * 0.017;
          p.x += dx * force * 0.36 - dy * force * 0.26;
          p.y += dy * force * 0.36 + dx * force * 0.26;
        }
      }

      if (p.x < -20) p.x = width + 20;
      else if (p.x > width + 20) p.x = -20;
      if (p.y < -20) p.y = height + 20;
      else if (p.y > height + 20) p.y = -20;

      const alpha = Math.min(0.88, 0.34 + 0.36 * (0.5 + 0.5 * Math.sin(p.phase * 1.4)) + cursorInfluence * 0.42);
      const baseRgb = colors.nodes[p.kind];

      if (cursorInfluence > 0.1 || p.r > 2.0) {
        ctx.fillStyle = `${baseRgb}${(alpha * 0.22).toFixed(2)})`;
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.r * (2.8 + cursorInfluence * 1.6), 0, Math.PI * 2);
        ctx.fill();
      }

      ctx.fillStyle = `${baseRgb}${alpha.toFixed(2)})`;
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.r * (1 + cursorInfluence * 0.35), 0, Math.PI * 2);
      ctx.fill();

      if (cursorInfluence > 0.06) {
        for (let j = i + 1; j < ambientNodes.length; j++) {
          const q = ambientNodes[j];
          const lx = p.x - q.x;
          const ly = p.y - q.y;
          const lSq = lx * lx + ly * ly;
          if (lSq < linkSq) {
            const lineAlpha = (1 - Math.sqrt(lSq) / 145) * cursorInfluence * 0.24;
            if (lineAlpha > 0.015) {
              ctx.strokeStyle = `${colors.line}${lineAlpha.toFixed(2)})`;
              ctx.lineWidth = 0.85;
              ctx.beginPath();
              ctx.moveTo(p.x, p.y);
              ctx.lineTo(q.x, q.y);
              ctx.stroke();
            }
          }
        }
      }
    }
  }

  for (let i = burstParticles.length - 1; i >= 0; i--) {
    const b = burstParticles[i];
    b.life -= b.decay;
    if (b.life <= 0) {
      burstParticles.splice(i, 1);
      continue;
    }
    b.vx *= 0.968;
    b.vy = b.vy * 0.968 + b.gravity;
    b.x += b.vx + Math.sin(time * 3.6 + b.sway) * 0.16;
    b.y += b.vy;
    b.rot += b.vrot;

    const easeAlpha = b.life * b.life;
    ctx.save();
    ctx.translate(b.x, b.y);
    ctx.rotate(b.rot);
    ctx.fillStyle = b.color;
    ctx.globalAlpha = easeAlpha * 0.24;
    ctx.beginPath();
    ctx.arc(0, 0, b.size * 2.1, 0, Math.PI * 2);
    ctx.fill();

    ctx.globalAlpha = easeAlpha;
    if (b.shape === 'star') {
      const s = b.size * (0.55 + easeAlpha * 0.5);
      ctx.beginPath();
      ctx.moveTo(0, -s);
      ctx.quadraticCurveTo(0, 0, s, 0);
      ctx.quadraticCurveTo(0, 0, 0, s);
      ctx.quadraticCurveTo(0, 0, -s, 0);
      ctx.quadraticCurveTo(0, 0, 0, -s);
      ctx.fill();
    } else {
      ctx.beginPath();
      ctx.arc(0, 0, b.size * 0.65, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }

  rafId = requestAnimationFrame(drawFrame);
}

function ensureLoop() {
  if (!canvas || running) return;
  if (!ambientEnabled() && burstParticles.length === 0) return;
  running = true;
  rafId = requestAnimationFrame(drawFrame);
}

export function burstAt(x, y, { count = 18, spread = 3.2, intensity = 0.85 } = {}) {
  if (reducedMotion.matches || !canvas) return;
  const colors = colorsCache.burst;
  for (let i = 0; i < count; i++) {
    const angle = (Math.PI * 2 * i) / count + (Math.random() - 0.5) * 0.55;
    const speed = (0.85 + Math.random() * spread) * intensity;
    burstParticles.push({
      x,
      y,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed - 0.85,
      gravity: 0.018 + Math.random() * 0.02,
      size: 2.5 + Math.random() * 3.2,
      rot: Math.random() * Math.PI * 2,
      vrot: (Math.random() - 0.5) * 0.075,
      sway: Math.random() * Math.PI * 2,
      life: 1,
      decay: 0.0085 + Math.random() * 0.007,
      color: colors[i % colors.length],
      shape: i % 2 === 0 ? 'star' : 'dot',
    });
  }
  ensureLoop();
}

export function burstFromElement(el, options = {}) {
  if (!el) return;
  const rect = el.getBoundingClientRect();
  if (rect.width === 0 && rect.height === 0) {
    burstAt(window.innerWidth - 120, window.innerHeight - 60, options);
    return;
  }
  burstAt(rect.left + rect.width / 2, rect.top + rect.height / 2, options);
}

export function initFX() {
  if (canvas) return;
  canvas = document.createElement('canvas');
  canvas.id = 'fx-canvas';
  canvas.className = 'fx-canvas';
  canvas.setAttribute('aria-hidden', 'true');
  document.body.prepend(canvas);
  ctx = canvas.getContext('2d', { alpha: true });
  refreshPalette();
  resize();

  window.addEventListener('resize', () => {
    resize();
    seedAmbientNodes();
  }, { passive: true });

  document.addEventListener('pointermove', (e) => {
    pointer.tx = e.clientX;
    pointer.ty = e.clientY;
    pointer.active = true;
  }, { passive: true });

  document.addEventListener('pointerleave', () => {
    pointer.active = false;
  });

  const observer = new MutationObserver(() => {
    refreshPalette();
    if (ambientEnabled()) ensureLoop();
  });
  observer.observe(document.documentElement, { attributes: true, attributeFilter: ['data-ambient', 'data-theme', 'data-accent'] });
  document.addEventListener('visibilitychange', () => { if (ambientEnabled()) ensureLoop(); });
  reducedMotion.addEventListener('change', () => { if (ambientEnabled()) ensureLoop(); });

  ensureLoop();
}
