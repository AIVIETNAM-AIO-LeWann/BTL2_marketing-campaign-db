// Hệ thống chuyển động và vi tương tác (Spotlight kính mờ, 3D micro-tilt, số cuộn, ripple, tooltip nổi, chuyển theme tròn).
const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
const finePointer = window.matchMedia('(hover: hover) and (pointer: fine)');

export function motionAllowed() {
  return !reducedMotion.matches;
}

export function setupInteractiveGlow() {
  let activePointerEvent = null;
  let rafId = 0;
  let hoveredTilt = null;
  let hoveredSpotlight = null;
  const root = document.documentElement;

  function clearTilt(el) {
    if (!el) return;
    el.style.setProperty('--rx', '0deg');
    el.style.setProperty('--ry', '0deg');
    el.dataset.tilting = 'false';
  }

  function flushPointer() {
    rafId = 0;
    const e = activePointerEvent;
    if (!e || !motionAllowed() || !finePointer.matches) return;

    // Gentle viewport parallax coordinates (-0.5 .. 0.5)
    const nx = (e.clientX / Math.max(window.innerWidth, 1)) - 0.5;
    const ny = (e.clientY / Math.max(window.innerHeight, 1)) - 0.5;
    root.style.setProperty('--px', nx.toFixed(4));
    root.style.setProperty('--py', ny.toFixed(4));

    // Parallax layers (e.g. login hero artwork)
    const parallaxNodes = document.querySelectorAll('[data-parallax]');
    for (const node of parallaxNodes) {
      const depth = Number(node.dataset.parallax) || 12;
      node.style.setProperty('--par-x', `${(nx * depth).toFixed(2)}px`);
      node.style.setProperty('--par-y', `${(ny * depth).toFixed(2)}px`);
    }

    // Cursor-tracked glass spotlight & border refraction
    const spotlight = e.target instanceof Element ? e.target.closest('[data-spotlight]') : null;
    if (hoveredSpotlight && hoveredSpotlight !== spotlight) {
      hoveredSpotlight.style.setProperty('--glow-o', '0');
    }
    hoveredSpotlight = spotlight;
    if (spotlight) {
      const rect = spotlight.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      spotlight.style.setProperty('--mx', `${x.toFixed(1)}px`);
      spotlight.style.setProperty('--my', `${y.toFixed(1)}px`);
      spotlight.style.setProperty('--glow-o', '1');
    }

    // Subtle 3D micro-tilt + studio glass glare angle on KPI cards & hero surfaces
    const tilt = e.target instanceof Element ? e.target.closest('[data-tilt]') : null;
    if (hoveredTilt && hoveredTilt !== tilt) clearTilt(hoveredTilt);
    hoveredTilt = tilt;
    if (tilt) {
      const rect = tilt.getBoundingClientRect();
      if (rect.width > 0 && rect.height > 0) {
        const px = (e.clientX - rect.left) / rect.width - 0.5;
        const py = (e.clientY - rect.top) / rect.height - 0.5;
        const maxDeg = Number(tilt.dataset.tilt) || 2.4;
        tilt.style.setProperty('--ry', `${(px * maxDeg * 2).toFixed(2)}deg`);
        tilt.style.setProperty('--rx', `${(-py * maxDeg * 2).toFixed(2)}deg`);
        tilt.style.setProperty('--gx', `${((px + 0.5) * 100).toFixed(1)}%`);
        tilt.style.setProperty('--gy', `${((py + 0.5) * 100).toFixed(1)}%`);
        tilt.dataset.tilting = 'true';
      }
    }
  }

  document.addEventListener('pointermove', (e) => {
    activePointerEvent = e;
    if (!rafId) rafId = requestAnimationFrame(flushPointer);
  }, { passive: true });

  document.addEventListener('pointerleave', () => {
    if (hoveredSpotlight) {
      hoveredSpotlight.style.setProperty('--glow-o', '0');
      hoveredSpotlight = null;
    }
    clearTilt(hoveredTilt);
    hoveredTilt = null;
  });
}

export function setupMagneticButtons() {
  if (!finePointer.matches) return;
  let current = null;

  document.addEventListener('pointermove', (e) => {
    if (!motionAllowed()) return;
    const btn = e.target instanceof Element ? e.target.closest('[data-magnetic]:not(:disabled)') : null;
    if (current && current !== btn) {
      current.style.setProperty('--mag-x', '0px');
      current.style.setProperty('--mag-y', '0px');
      current = null;
    }
    if (!btn) return;
    current = btn;
    const rect = btn.getBoundingClientRect();
    const strength = Number(btn.dataset.magnetic) || 4;
    const dx = ((e.clientX - (rect.left + rect.width / 2)) / (rect.width / 2)) * strength;
    const dy = ((e.clientY - (rect.top + rect.height / 2)) / (rect.height / 2)) * strength;
    btn.style.setProperty('--mag-x', `${dx.toFixed(2)}px`);
    btn.style.setProperty('--mag-y', `${dy.toFixed(2)}px`);
  }, { passive: true });

  document.addEventListener('pointerout', (e) => {
    if (!current) return;
    if (!e.relatedTarget || !current.contains(e.relatedTarget)) {
      current.style.setProperty('--mag-x', '0px');
      current.style.setProperty('--mag-y', '0px');
      current = null;
    }
  });
}

export function setupButtonRipples() {
  document.addEventListener('pointerdown', (e) => {
    if (!motionAllowed() || e.button !== 0) return;
    const target = e.target instanceof Element
      ? e.target.closest('button:not(:disabled), nav a, .campaign-option')
      : null;
    if (!target) return;
    const rect = target.getBoundingClientRect();
    const size = Math.max(rect.width, rect.height) * 1.9;
    const wave = document.createElement('span');
    wave.className = 'ripple-wave';
    wave.style.setProperty('--rx', `${(e.clientX - rect.left).toFixed(1)}px`);
    wave.style.setProperty('--ry', `${(e.clientY - rect.top).toFixed(1)}px`);
    wave.style.setProperty('--rs', `${size.toFixed(1)}px`);
    target.append(wave);
    wave.addEventListener('animationend', () => wave.remove(), { once: true });
    setTimeout(() => wave.remove(), 700);
  }, { passive: true });
}

export function setupScrollContext() {
  const root = document.documentElement;
  let ticking = false;
  function update() {
    ticking = false;
    const y = window.scrollY;
    root.dataset.scrolled = y > 10 ? 'true' : 'false';
    const max = Math.max(document.documentElement.scrollHeight - window.innerHeight, 1);
    const pct = Math.min(1, Math.max(0, y / max));
    root.style.setProperty('--scroll-progress', pct.toFixed(4));
  }
  window.addEventListener('scroll', () => {
    if (!ticking) {
      ticking = true;
      requestAnimationFrame(update);
    }
  }, { passive: true });
  window.addEventListener('resize', update, { passive: true });
  update();
}

export function setupNavHoverPill(nav) {
  if (!nav) return;
  const ghost = document.createElement('span');
  ghost.className = 'nav-hover-ghost';
  ghost.setAttribute('aria-hidden', 'true');
  nav.prepend(ghost);

  function moveTo(link) {
    if (!link) {
      ghost.dataset.visible = 'false';
      return;
    }
    const navRect = nav.getBoundingClientRect();
    const rect = link.getBoundingClientRect();
    ghost.style.setProperty('--gx', `${(rect.left - navRect.left).toFixed(1)}px`);
    ghost.style.setProperty('--gy', `${(rect.top - navRect.top).toFixed(1)}px`);
    ghost.style.setProperty('--gw', `${rect.width.toFixed(1)}px`);
    ghost.style.setProperty('--gh', `${rect.height.toFixed(1)}px`);
    ghost.dataset.visible = 'true';
  }

  nav.addEventListener('pointerover', (e) => {
    const link = e.target instanceof Element ? e.target.closest('a[data-page]') : null;
    if (link) moveTo(link);
  });
  nav.addEventListener('pointerleave', () => moveTo(null));
}

// Smooth number rolling animation supporting BigInt, integers, and decimal numbers.
const activeCounters = new WeakMap();

export function animateNumber(element, target, formatter, { duration = 580, isBigInt = false } = {}) {
  if (!element) return;
  const prevRaf = activeCounters.get(element);
  if (prevRaf) cancelAnimationFrame(prevRaf);

  if (target === null || target === undefined || Number.isNaN(target)) {
    delete element.dataset.numCurrent;
    element.textContent = '—';
    return;
  }

  if (!motionAllowed()) {
    element.dataset.numCurrent = String(target);
    element.textContent = formatter(target);
    return;
  }

  const startTime = performance.now();
  const hasPrev = element.dataset.numCurrent !== undefined;

  if (isBigInt) {
    const endVal = BigInt(target);
    const startVal = hasPrev ? BigInt(element.dataset.numCurrent) : 0n;
    if (startVal === endVal && hasPrev) {
      element.textContent = formatter(endVal);
      return;
    }
    const delta = endVal - startVal;
    const step = (now) => {
      const t = Math.min(1, (now - startTime) / duration);
      // Cubic ease-out with ultra-smooth tail
      const eased = 1 - Math.pow(1 - t, 3);
      const scale = BigInt(Math.round(eased * 10000));
      const current = startVal + (delta * scale) / 10000n;
      element.textContent = formatter(t < 1 ? current : endVal);
      if (t < 1) {
        activeCounters.set(element, requestAnimationFrame(step));
      } else {
        activeCounters.delete(element);
        element.dataset.numCurrent = String(endVal);
        pulseElement(element);
      }
    };
    activeCounters.set(element, requestAnimationFrame(step));
    return;
  }

  const endNum = Number(target);
  const startNum = hasPrev ? Number(element.dataset.numCurrent) : 0;
  if (startNum === endNum && hasPrev) {
    element.textContent = formatter(endNum);
    return;
  }
  const delta = endNum - startNum;
  const step = (now) => {
    const t = Math.min(1, (now - startTime) / duration);
    const eased = 1 - Math.pow(1 - t, 3);
    const current = startNum + delta * eased;
    element.textContent = formatter(t < 1 ? current : endNum);
    if (t < 1) {
      activeCounters.set(element, requestAnimationFrame(step));
    } else {
      activeCounters.delete(element);
      element.dataset.numCurrent = String(endNum);
      pulseElement(element);
    }
  };
  activeCounters.set(element, requestAnimationFrame(step));
}

export function pulseElement(el) {
  if (!el || !motionAllowed()) return;
  el.animate?.([
    { transform: 'scale(1)' },
    { transform: 'scale(1.03)' },
    { transform: 'scale(1)' },
  ], { duration: 280, easing: 'cubic-bezier(.22, 1, .36, 1)' });
}

// Circular View Transition reveal expanding right out of the theme button.
export function transitionTheme(triggerEl, applyThemeFn) {
  if (!motionAllowed() || !document.startViewTransition || !triggerEl) {
    applyThemeFn();
    return;
  }
  const rect = triggerEl.getBoundingClientRect();
  const x = rect.left + rect.width / 2;
  const y = rect.top + rect.height / 2;
  const endRadius = Math.hypot(
    Math.max(x, window.innerWidth - x),
    Math.max(y, window.innerHeight - y),
  );
  const root = document.documentElement;
  root.dataset.themeTransition = 'true';
  const transition = document.startViewTransition(() => {
    applyThemeFn();
  });
  transition.ready.then(() => {
    document.documentElement.animate(
      {
        clipPath: [
          `circle(0px at ${x}px ${y}px)`,
          `circle(${endRadius}px at ${x}px ${y}px)`,
        ],
      },
      {
        duration: 520,
        easing: 'cubic-bezier(.22, 1, .36, 1)',
        pseudoElement: '::view-transition-new(root)',
      },
    );
  }).catch(() => {});
  const clear = () => { delete root.dataset.themeTransition; };
  transition.finished.then(clear, clear);
}

// Floating frosted-glass tooltip singleton (used for compact dock icons & chart bars).
let tooltipEl = null;

function ensureTooltip() {
  if (tooltipEl) return tooltipEl;
  tooltipEl = document.createElement('div');
  tooltipEl.id = 'glass-tooltip';
  tooltipEl.className = 'glass-tooltip';
  tooltipEl.setAttribute('role', 'tooltip');
  tooltipEl.dataset.open = 'false';
  document.body.append(tooltipEl);
  return tooltipEl;
}

export function showTooltip(anchor, { title, detail = '', placement = 'top' }) {
  const tip = ensureTooltip();
  tip.replaceChildren();
  const strong = document.createElement('strong');
  strong.textContent = title;
  tip.append(strong);
  if (detail) {
    const sub = document.createElement('span');
    sub.textContent = detail;
    tip.append(sub);
  }
  tip.dataset.placement = placement;
  tip.dataset.open = 'true';

  const rect = anchor.getBoundingClientRect();
  const tipRect = tip.getBoundingClientRect();
  const pad = 10;
  let left = 0;
  let top = 0;

  if (placement === 'right') {
    left = rect.right + 12;
    top = rect.top + rect.height / 2 - tipRect.height / 2;
  } else {
    left = rect.left + rect.width / 2 - tipRect.width / 2;
    top = rect.top - tipRect.height - 10;
  }

  left = Math.max(pad, Math.min(window.innerWidth - tipRect.width - pad, left));
  top = Math.max(pad, Math.min(window.innerHeight - tipRect.height - pad, top));
  tip.style.setProperty('--tx', `${left.toFixed(1)}px`);
  tip.style.setProperty('--ty', `${top.toFixed(1)}px`);
}

export function hideTooltip() {
  if (tooltipEl) tooltipEl.dataset.open = 'false';
}

export function setupCompactDockTooltips() {
  document.addEventListener('pointerenter', (e) => {
    if (document.documentElement.dataset.sidebar !== 'compact') return;
    if (window.innerWidth <= 900) return;
    const target = e.target instanceof Element
      ? e.target.closest('.topbar nav a, .topbar .rail-button, .topbar .brand, .topbar .operator')
      : null;
    if (!target) return;
    const label = target.getAttribute('aria-label') || target.getAttribute('title') || target.textContent?.trim();
    if (!label) return;
    showTooltip(target, { title: label, placement: 'right' });
  }, true);

  document.addEventListener('pointerleave', (e) => {
    const target = e.target instanceof Element
      ? e.target.closest('.topbar nav a, .topbar .rail-button, .topbar .brand, .topbar .operator')
      : null;
    if (target) hideTooltip();
  }, true);

  window.addEventListener('scroll', hideTooltip, { passive: true });
}

export function staggerChildren(container, selector = ':scope > *', maxStagger = 14) {
  if (!container) return;
  const items = container.querySelectorAll(selector);
  items.forEach((node, idx) => {
    node.style.setProperty('--stagger-i', String(Math.min(idx, maxStagger)));
  });
}

export function shakeElement(el) {
  if (!el || !motionAllowed()) return;
  el.animate?.([
    { transform: 'translateX(0)' },
    { transform: 'translateX(-6px)' },
    { transform: 'translateX(5px)' },
    { transform: 'translateX(-4px)' },
    { transform: 'translateX(2px)' },
    { transform: 'translateX(0)' },
  ], { duration: 360, easing: 'cubic-bezier(.36, .07, .19, .97)' });
}

export function initMotion({ navSelector = 'nav' } = {}) {
  setupInteractiveGlow();
  setupMagneticButtons();
  setupButtonRipples();
  setupScrollContext();
  setupCompactDockTooltips();
  const nav = navSelector ? document.querySelector(navSelector) : null;
  if (nav) setupNavHoverPill(nav);
}
