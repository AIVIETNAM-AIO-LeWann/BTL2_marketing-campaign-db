// 60fps Interactive Canvas FX Engine:
// - Floating bioluminescent particles with subtle magnetic constellation web around cursor
// - Smooth spring-lerped aurora cursor glow
// - Celebratory luminous micro-sparkle bursts on key actions (save, login, theme flip, focus)
// Respects prefers-reduced-motion, [data-ambient='paused'], and document.hidden.

const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
const finePointer = window.matchMedia('(hover: hover) and (pointer: fine)');

let canvas = null;
let ctx = null;
let width = 0;
let height = 0;
let dpr = 1;
let rafId = 0;
let running = false;

const pointer = { x: -9999, y: -9999, tx: -9999, ty: -9999, active: false };
const ambientNodes = [];
const burstParticles = [];

function isDark() {
  return document.documentElement.dataset.theme === 'dark';
}

function ambientEnabled() {
  return !reducedMotion.matches && document.documentElement.dataset.ambient !== 'paused' && !document.hidden;
}

function palette() {
  if (isDark()) {
    return {
      node: [196, 238, 79],      // lime
      nodeAlt: [122, 214, 158],  // mint
      line: [196, 238, 79],
      aura: 'rgba(196, 238, 79, 0.085)',
      auraMid: 'rgba(92, 184, 134, 0.045)',
      burst: ['#c4ee4f', '#e2ff8f', '#7fd8a4', '#f3d479', '#ffffff'],
    };
  }
  return {
    node: [23, 96, 68],          // emerald
    nodeAlt: [186, 138, 69],     // warm sand
    line: [23, 96, 68],
    aura: 'rgba(23, 96, 68, 0.055)',
    auraMid: 'rgba(184, 232, 159, 0.065)',
    burst: ['#176044', '#4fa877', '#b8e89f', '#c99346', '#247351'],
  };
}

function seedAmbientNodes() {
  ambientNodes.length = 0;
  const area = width * height;
  const count = Math.max(22, Math.min(54, Math.round(area / 32000)));
  for (let i = 0; i < count; i++) {
    ambientNodes.push({
      x: Math.random() * width,
      y: Math.random() * height,
      vx: (Math.random() - 0.5) * 0.32,
      vy: (Math.random() - 0.5) * 0.28 - 0.05,
      r: 1.1 + Math.random() * 1.9,
      phase: Math.random() * Math.PI * 2,
      speed: 0.008 + Math.random() * 0.014,
      alt: Math.random() > 0.58,
    });
  }
}

function resize() {
  if (!canvas) return;
  dpr = Math.min(window.devicePixelRatio || 1, 2);
  width = window.innerWidth;
  height = window.innerHeight;
  canvas.width = Math.floor(width * dpr);
  canvas.height = Math.floor(height * dpr);
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  if (ambientNodes.length === 0) seedAmbientNodes();
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

  ctx.clearRect(0, 0, width, height);
  const colors = palette();

  // Smooth spring-lerped pointer position for liquid aurora trail
  if (pointer.active) {
    if (pointer.x < -1000) {
      pointer.x = pointer.tx;
      pointer.y = pointer.ty;
    } else {
      pointer.x += (pointer.tx - pointer.x) * 0.14;
      pointer.y += (pointer.ty - pointer.y) * 0.14;
    }
  }

  if (canAmbient) {
    // 1. Ethereal aurora follower behind cursor
    if (pointer.active && finePointer.matches) {
      const grad = ctx.createRadialGradient(pointer.x, pointer.y, 0, pointer.x, pointer.y, 260);
      grad.addColorStop(0, colors.aura);
      grad.addColorStop(0.45, colors.auraMid);
      grad.addColorStop(1, 'rgba(0, 0, 0, 0)');
      ctx.fillStyle = grad;
      ctx.beginPath();
      ctx.arc(pointer.x, pointer.y, 260, 0, Math.PI * 2);
      ctx.fill();
    }

    // 2. Floating bioluminescent particles + magnetic constellation links near cursor
    const linkRadius = 128;
    const cursorRadius = 185;

    for (let i = 0; i < ambientNodes.length; i++) {
      const p = ambientNodes[i];
      p.phase += p.speed;
      p.x += p.vx + Math.sin(p.phase) * 0.12;
      p.y += p.vy + Math.cos(p.phase * 0.8) * 0.08;

      // Soft magnetic attraction / orbital drift near cursor
      let cursorInfluence = 0;
      if (pointer.active && finePointer.matches) {
        const dx = pointer.x - p.x;
        const dy = pointer.y - p.y;
        const dist = Math.hypot(dx, dy);
        if (dist < cursorRadius && dist > 1) {
          cursorInfluence = 1 - dist / cursorRadius;
          // Gentle swirl + slight attraction
          const force = cursorInfluence * 0.028;
          p.x += dx * force * 0.45 - dy * force * 0.22;
          p.y += dy * force * 0.45 + dx * force * 0.22;
        }
      }

      // Wrap around edges gracefully
      if (p.x < -20) p.x = width + 20;
      else if (p.x > width + 20) p.x = -20;
      if (p.y < -20) p.y = height + 20;
      else if (p.y > height + 20) p.y = -20;

      const twinkle = 0.32 + 0.45 * (0.5 + 0.5 * Math.sin(p.phase * 1.7));
      const alpha = Math.min(0.88, twinkle + cursorInfluence * 0.48);
      const rgb = p.alt ? colors.nodeAlt : colors.node;

      // Soft halo for brighter nodes
      if (cursorInfluence > 0.15 || p.r > 2.2) {
        ctx.fillStyle = `rgba(${rgb[0]}, ${rgb[1]}, ${rgb[2]}, ${(alpha * 0.22).toFixed(3)})`;
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.r * (2.6 + cursorInfluence * 1.8), 0, Math.PI * 2);
        ctx.fill();
      }

      ctx.fillStyle = `rgba(${rgb[0]}, ${rgb[1]}, ${rgb[2]}, ${alpha.toFixed(3)})`;
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.r * (1 + cursorInfluence * 0.45), 0, Math.PI * 2);
      ctx.fill();

      // Delicate constellation filaments between nearby particles within cursor neighborhood
      if (cursorInfluence > 0.05) {
        for (let j = i + 1; j < ambientNodes.length; j++) {
          const q = ambientNodes[j];
          const d = Math.hypot(p.x - q.x, p.y - q.y);
          if (d < linkRadius) {
            const lineAlpha = (1 - d / linkRadius) * cursorInfluence * 0.26;
            if (lineAlpha > 0.012) {
              ctx.strokeStyle = `rgba(${colors.line[0]}, ${colors.line[1]}, ${colors.line[2]}, ${lineAlpha.toFixed(3)})`;
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

  // 3. Celebratory luminous sparkle bursts
  for (let i = burstParticles.length - 1; i >= 0; i--) {
    const b = burstParticles[i];
    b.life -= b.decay;
    if (b.life <= 0) {
      burstParticles.splice(i, 1);
      continue;
    }
    b.vx *= 0.962;
    b.vy = b.vy * 0.962 + b.gravity;
    b.x += b.vx;
    b.y += b.vy;
    b.rot += b.vrot;

    ctx.save();
    ctx.globalAlpha = Math.max(0, b.life);
    ctx.translate(b.x, b.y);
    ctx.rotate(b.rot);
    ctx.fillStyle = b.color;
    ctx.shadowColor = b.color;
    ctx.shadowBlur = 8;

    if (b.shape === 'star') {
      const s = b.size * (0.55 + b.life * 0.55);
      ctx.beginPath();
      ctx.moveTo(0, -s);
      ctx.quadraticCurveTo(0, 0, s, 0);
      ctx.quadraticCurveTo(0, 0, 0, s);
      ctx.quadraticCurveTo(0, 0, -s, 0);
      ctx.quadraticCurveTo(0, 0, 0, -s);
      ctx.fill();
    } else if (b.shape === 'pill') {
      ctx.beginPath();
      ctx.roundRect(-b.size, -b.size * 0.36, b.size * 2, b.size * 0.72, 2);
      ctx.fill();
    } else {
      ctx.beginPath();
      ctx.arc(0, 0, b.size * 0.55, 0, Math.PI * 2);
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

export function burstAt(x, y, { count = 26, spread = 6.2, intensity = 1 } = {}) {
  if (reducedMotion.matches || !canvas) return;
  const colors = palette().burst;
  const shapes = ['star', 'pill', 'dot'];
  for (let i = 0; i < count; i++) {
    const angle = (Math.PI * 2 * i) / count + (Math.random() - 0.5) * 0.5;
    const speed = (1.8 + Math.random() * spread) * intensity;
    burstParticles.push({
      x,
      y,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed - 1.4,
      gravity: 0.08 + Math.random() * 0.06,
      size: 2.6 + Math.random() * 3.8,
      rot: Math.random() * Math.PI * 2,
      vrot: (Math.random() - 0.5) * 0.22,
      life: 1,
      decay: 0.015 + Math.random() * 0.014,
      color: colors[i % colors.length],
      shape: shapes[i % shapes.length],
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
  ctx = canvas.getContext('2d');
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

  // React cleanly whenever ambient toggle or visibility or reduced-motion changes
  const observer = new MutationObserver(() => {
    if (ambientEnabled()) ensureLoop();
  });
  observer.observe(document.documentElement, { attributes: true, attributeFilter: ['data-ambient', 'data-theme'] });
  document.addEventListener('visibilitychange', () => { if (ambientEnabled()) ensureLoop(); });
  reducedMotion.addEventListener('change', () => { if (ambientEnabled()) ensureLoop(); });

  ensureLoop();
}
