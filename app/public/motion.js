// Hệ thống chuyển động Liquid Glass 60-120fps (Zero Layout Thrashing):
// - Cache bounding rect trên pointerover (không gọi getBoundingClientRect mỗi frame)
// - Nội suy quán tính mượt cho spotlight & 3D micro-tilt, tự dừng rAF khi con trỏ nghỉ
// - Word-by-word silk reveal, sliding table hover rail, magnetic buttons, ripples, smooth counters, circular theme reveal

const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
const finePointer = window.matchMedia('(hover: hover) and (pointer: fine)');

export function motionAllowed() {
  return !reducedMotion.matches;
}

export function revealWords(element, { delayOffset = 0 } = {}) {
  if (!element || !motionAllowed()) return;
  const raw = element.dataset.wordSource ?? element.textContent?.trim();
  if (!raw) return;
  element.dataset.wordSource = raw;
  const words = raw.split(/\s+/);
  element.replaceChildren();
  words.forEach((word, i) => {
    const span = document.createElement('span');
    span.className = 'word-reveal';
    span.style.setProperty('--word-i', String(i + delayOffset));
    span.textContent = word;
    element.append(span);
    if (i < words.length - 1) element.append(' ');
  });
}

export function setupInteractiveGlow() {
  const root = document.documentElement;
  let rafId = 0;
  let hoveredTilt = null;
  let hoveredTiltRect = null;
  let hoveredSpotlight = null;
  let hoveredSpotlightRect = null;
  let parallaxNodes = null;

  let targetX = window.innerWidth * 0.5;
  let targetY = window.innerHeight * 0.5;
  let curX = targetX;
  let curY = targetY;
  let pointerActive = false;

  function clearTilt(el) {
    if (!el) return;
    el.style.setProperty('--rx', '0deg');
    el.style.setProperty('--ry', '0deg');
    el.dataset.tilting = 'false';
  }

  function invalidateRects() {
    if (hoveredSpotlight) hoveredSpotlightRect = hoveredSpotlight.getBoundingClientRect();
    if (hoveredTilt) hoveredTiltRect = hoveredTilt.getBoundingClientRect();
  }

  function tick() {
    rafId = 0;
    if (!motionAllowed() || !finePointer.matches) return;

    curX += (targetX - curX) * 0.095;
    curY += (targetY - curY) * 0.095;

    if (!parallaxNodes) parallaxNodes = [...document.querySelectorAll('[data-parallax]')];
    if (parallaxNodes.length > 0) {
      const nx = (curX / Math.max(window.innerWidth, 1)) - 0.5;
      const ny = (curY / Math.max(window.innerHeight, 1)) - 0.5;
      for (const node of parallaxNodes) {
        const depth = Number(node.dataset.parallax) || 12;
        node.style.setProperty('--par-x', `${(nx * depth).toFixed(1)}px`);
        node.style.setProperty('--par-y', `${(ny * depth).toFixed(1)}px`);
      }
    }

    if (hoveredSpotlight && hoveredSpotlightRect) {
      const x = curX - hoveredSpotlightRect.left;
      const y = curY - hoveredSpotlightRect.top;
      hoveredSpotlight.style.setProperty('--mx', `${x.toFixed(1)}px`);
      hoveredSpotlight.style.setProperty('--my', `${y.toFixed(1)}px`);
      hoveredSpotlight.style.setProperty('--glow-o', '1');
    }

    if (hoveredTilt && hoveredTiltRect && hoveredTiltRect.width > 0 && hoveredTiltRect.height > 0) {
      const px = Math.max(-0.5, Math.min(0.5, (curX - hoveredTiltRect.left) / hoveredTiltRect.width - 0.5));
      const py = Math.max(-0.5, Math.min(0.5, (curY - hoveredTiltRect.top) / hoveredTiltRect.height - 0.5));
      const maxDeg = Number(hoveredTilt.dataset.tilt) || 2.0;
      hoveredTilt.style.setProperty('--ry', `${(px * maxDeg * 1.85).toFixed(2)}deg`);
      hoveredTilt.style.setProperty('--rx', `${(-py * maxDeg * 1.85).toFixed(2)}deg`);
      hoveredTilt.style.setProperty('--gx', `${((px + 0.5) * 100).toFixed(1)}%`);
      hoveredTilt.style.setProperty('--gy', `${((py + 0.5) * 100).toFixed(1)}%`);
      hoveredTilt.dataset.tilting = 'true';
    }

    if (pointerActive && (Math.abs(targetX - curX) > 0.5 || Math.abs(targetY - curY) > 0.5)) {
      rafId = requestAnimationFrame(tick);
    }
  }

  document.addEventListener('pointermove', (e) => {
    targetX = e.clientX;
    targetY = e.clientY;
    pointerActive = true;

    const spotlight = e.target instanceof Element ? e.target.closest('[data-spotlight]') : null;
    if (hoveredSpotlight !== spotlight) {
      if (hoveredSpotlight) hoveredSpotlight.style.setProperty('--glow-o', '0');
      hoveredSpotlight = spotlight;
      hoveredSpotlightRect = spotlight ? spotlight.getBoundingClientRect() : null;
    }

    const tilt = e.target instanceof Element ? e.target.closest('[data-tilt]') : null;
    if (hoveredTilt !== tilt) {
      clearTilt(hoveredTilt);
      hoveredTilt = tilt;
      hoveredTiltRect = tilt ? tilt.getBoundingClientRect() : null;
    }

    if (!rafId) rafId = requestAnimationFrame(tick);
  }, { passive: true });

  window.addEventListener('scroll', invalidateRects, { passive: true });
  window.addEventListener('resize', () => {
    parallaxNodes = null;
    invalidateRects();
  }, { passive: true });

  document.addEventListener('pointerleave', () => {
    pointerActive = false;
    if (hoveredSpotlight) {
      hoveredSpotlight.style.setProperty('--glow-o', '0');
      hoveredSpotlight = null;
      hoveredSpotlightRect = null;
    }
    clearTilt(hoveredTilt);
    hoveredTilt = null;
    hoveredTiltRect = null;
  });

  // Ensure root stays clean without unnecessary global custom property churn
  root.style.removeProperty('--px');
  root.style.removeProperty('--py');
}

export function setupMagneticButtons() {
  if (!finePointer.matches) return;
  let current = null;
  let currentRect = null;

  document.addEventListener('pointermove', (e) => {
    if (!motionAllowed()) return;
    const btn = e.target instanceof Element ? e.target.closest('[data-magnetic]:not(:disabled)') : null;
    if (current !== btn) {
      if (current) {
        current.style.setProperty('--mag-x', '0px');
        current.style.setProperty('--mag-y', '0px');
      }
      current = btn;
      currentRect = btn ? btn.getBoundingClientRect() : null;
    }
    if (!current || !currentRect || currentRect.width === 0) return;
    const strength = Number(current.dataset.magnetic) || 3.2;
    const dx = ((e.clientX - (currentRect.left + currentRect.width / 2)) / (currentRect.width / 2)) * strength;
    const dy = ((e.clientY - (currentRect.top + currentRect.height / 2)) / (currentRect.height / 2)) * strength;
    current.style.setProperty('--mag-x', `${dx.toFixed(1)}px`);
    current.style.setProperty('--mag-y', `${dy.toFixed(1)}px`);
  }, { passive: true });

  document.addEventListener('pointerout', (e) => {
    if (!current) return;
    if (!e.relatedTarget || !current.contains(e.relatedTarget)) {
      current.style.setProperty('--mag-x', '0px');
      current.style.setProperty('--mag-y', '0px');
      current = null;
      currentRect = null;
    }
  });
}

export function setupButtonRipples() {
  document.addEventListener('pointerdown', (e) => {
    if (!motionAllowed() || e.button !== 0) return;
    const target = e.target instanceof Element
      ? e.target.closest('button:not(:disabled), nav a, .campaign-option, #expense-rows tr:not(.skeleton-row)')
      : null;
    if (!target) return;
    if (target.tagName === 'TR') {
      target.animate?.(
        [{ transform: 'scale(1)' }, { transform: 'scale(.993)' }, { transform: 'scale(1)' }],
        { duration: 280, easing: 'cubic-bezier(.16, 1, .3, 1)' },
      );
      return;
    }
    const rect = target.getBoundingClientRect();
    const size = Math.max(rect.width, rect.height) * 2.1;
    const wave = document.createElement('span');
    wave.className = 'ripple-wave';
    wave.style.setProperty('--rx', `${(e.clientX - rect.left).toFixed(1)}px`);
    wave.style.setProperty('--ry', `${(e.clientY - rect.top).toFixed(1)}px`);
    wave.style.setProperty('--rs', `${size.toFixed(1)}px`);
    target.append(wave);
    wave.addEventListener('animationend', () => wave.remove(), { once: true });
    setTimeout(() => wave.remove(), 760);
  }, { passive: true });
}

export function setupScrollContext() {
  const root = document.documentElement;
  let ticking = false;
  let lastScrolled = '';
  function update() {
    ticking = false;
    const y = window.scrollY;
    const nextScrolled = y > 10 ? 'true' : 'false';
    if (nextScrolled !== lastScrolled) {
      lastScrolled = nextScrolled;
      root.dataset.scrolled = nextScrolled;
    }
    const max = Math.max(document.documentElement.scrollHeight - window.innerHeight, 1);
    const pct = Math.min(1, Math.max(0, y / max));
    root.style.setProperty('--scroll-progress', pct.toFixed(3));
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
    ghost.style.setProperty('--gx', `${link.offsetLeft}px`);
    ghost.style.setProperty('--gy', `${link.offsetTop}px`);
    ghost.style.setProperty('--gw', `${link.offsetWidth}px`);
    ghost.style.setProperty('--gh', `${link.offsetHeight}px`);
    ghost.dataset.visible = 'true';
  }

  nav.addEventListener('pointerover', (e) => {
    const link = e.target instanceof Element ? e.target.closest('a[data-page]') : null;
    if (link) moveTo(link);
  });
  nav.addEventListener('pointerleave', () => moveTo(null));
}

export function setupSlidingTableRails() {
  if (!finePointer.matches) return;
  for (const scrollBox of document.querySelectorAll('.table-scroll')) {
    if (scrollBox.querySelector('.table-hover-rail')) continue;
    const rail = document.createElement('span');
    rail.className = 'table-hover-rail';
    rail.setAttribute('aria-hidden', 'true');
    scrollBox.prepend(rail);

    let activeRow = null;
    function syncRail(row) {
      if (!row || !motionAllowed() || window.innerWidth <= 640) {
        rail.dataset.visible = 'false';
        activeRow = null;
        return;
      }
      activeRow = row;
      const boxRect = scrollBox.getBoundingClientRect();
      const rowRect = row.getBoundingClientRect();
      const top = rowRect.top - boxRect.top + scrollBox.scrollTop;
      rail.style.setProperty('--ry', `${top.toFixed(1)}px`);
      rail.style.setProperty('--rh', `${rowRect.height.toFixed(1)}px`);
      rail.dataset.visible = 'true';
    }

    scrollBox.addEventListener('pointerover', (e) => {
      const row = e.target instanceof Element ? e.target.closest('tbody tr:not(.skeleton-row)') : null;
      if (row && row !== activeRow) syncRail(row);
      else if (!row && activeRow) syncRail(null);
    });
    scrollBox.addEventListener('pointerleave', () => syncRail(null));
  }
}

export function setupScrollReveal() {
  if (!motionAllowed() || !('IntersectionObserver' in window)) return;
  const targets = document.querySelectorAll('.panel, .stat');
  const observer = new IntersectionObserver((entries) => {
    for (const entry of entries) {
      if (entry.isIntersecting) {
        entry.target.dataset.inView = 'true';
        observer.unobserve(entry.target);
      }
    }
  }, { rootMargin: '0px 0px -24px 0px', threshold: 0.04 });

  targets.forEach((el) => {
    const rect = el.getBoundingClientRect();
    if (rect.top < window.innerHeight * 0.96) el.dataset.inView = 'true';
    else observer.observe(el);
  });
}

const activeCounters = new WeakMap();

export function animateNumber(element, target, formatter, { duration = 960, isBigInt = false } = {}) {
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
  const easeOutQuart = (t) => 1 - Math.pow(1 - t, 4);

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
      const scale = BigInt(Math.round(easeOutQuart(t) * 10000));
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
    const current = startNum + delta * easeOutQuart(t);
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
    { transform: 'scale(1.028)' },
    { transform: 'scale(1)' },
  ], { duration: 420, easing: 'cubic-bezier(.16, 1, .3, 1)' });
}

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
        duration: 860,
        easing: 'cubic-bezier(.16, 1, .3, 1)',
        pseudoElement: '::view-transition-new(root)',
      },
    );
  }).catch(() => {});
  const clear = () => { delete root.dataset.themeTransition; };
  transition.finished.then(clear, clear);
}

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

export function staggerChildren(container, selector = ':scope > *', maxStagger = 16) {
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
    { transform: 'translateX(-5px)' },
    { transform: 'translateX(4px)' },
    { transform: 'translateX(-3px)' },
    { transform: 'translateX(1.5px)' },
    { transform: 'translateX(0)' },
  ], { duration: 400, easing: 'cubic-bezier(.22, .61, .36, 1)' });
}

export function initMotion({ navSelector = 'nav' } = {}) {
  setupInteractiveGlow();
  setupMagneticButtons();
  setupButtonRipples();
  setupScrollContext();
  setupCompactDockTooltips();
  setupSlidingTableRails();
  setupScrollReveal();
  const nav = navSelector ? document.querySelector(navSelector) : null;
  if (nav) setupNavHoverPill(nav);
}
