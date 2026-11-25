import './ambient.js';
import './validity-vi.js';
import { setupPalette } from './palette.js';
import { burstFromElement, initFX } from './fx.js';
import {
  animateNumber,
  hideTooltip,
  initMotion,
  motionAllowed,
  shakeElement,
  showTooltip,
  staggerChildren,
  transitionTheme,
} from './motion.js';

const $ = (id) => document.getElementById(id);
const filters = $('expense-filters');
const reportFilters = $('report-filters');
const editor = $('expense-editor');
const deleteForm = $('delete-form');
const expenseDialog = $('expense-dialog');
const deleteDialog = $('delete-dialog');
const num = new Intl.NumberFormat('vi-VN');
const decimalNum = new Intl.NumberFormat('vi-VN', { maximumFractionDigits: 2 });
const finished = new Set(['HOAN_THANH', 'HUY']);
const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
const DONUT_COLORS = ['#c4ee4f', '#5ed394', '#5ba5dc', '#e1b354', '#df7d6b'];
const DONUT_COLORS_LIGHT = ['#176044', '#2e8f66', '#4682b4', '#c18a45', '#b8675a'];

let catalog;
let expenseRequest;
let reportRequest;
let deletingId;
let activePage;
let pageTransition;
let lastExpenseItems = [];
let lastExpenseTotal = 0n;
let lastDailySpend = new Map();
let chartMode = 'bar';
let drawerItem = null;

initMotion();
initFX();

function preference(key, value) {
  try {
    if (value === undefined) return localStorage.getItem(key);
    localStorage.setItem(key, value);
  } catch { /* Preferences still apply for this page when browser storage is unavailable. */ }
}

function setupAppearance() {
  const root = document.documentElement;
  const theme = $('theme-toggle');
  const sidebar = $('sidebar-toggle');

  function applyTheme(dark) {
    root.dataset.theme = dark ? 'dark' : 'light';
    theme.setAttribute('aria-pressed', String(dark));
    theme.title = dark ? 'Chuyển sang giao diện sáng' : 'Bật giao diện tối';
    theme.querySelector('use').setAttribute('href', dark ? '/icons.svg#sun' : '/icons.svg#moon');
  }

  function applySidebar(compact) {
    root.dataset.sidebar = compact ? 'compact' : 'expanded';
    sidebar.setAttribute('aria-expanded', String(!compact));
    const label = compact ? 'Mở rộng thanh điều hướng' : 'Thu gọn thanh điều hướng';
    sidebar.title = `${label} (Ctrl+B)`;
    sidebar.setAttribute('aria-label', label);
    sidebar.querySelector('use').setAttribute('href', compact ? '/icons.svg#panel-left-open' : '/icons.svg#panel-left-close');
    hideTooltip();
  }

  applyTheme(preference('campaign-desk-theme') !== 'light');
  applySidebar(preference('campaign-desk-sidebar') === 'compact');
  theme.addEventListener('click', () => {
    const nextDark = root.dataset.theme !== 'dark';
    burstFromElement(theme, { count: 18, spread: 4.8 });
    transitionTheme(theme, () => {
      applyTheme(nextDark);
      preference('campaign-desk-theme', root.dataset.theme);
    });
  });
  sidebar.addEventListener('click', () => {
    applySidebar(root.dataset.sidebar !== 'compact');
    preference('campaign-desk-sidebar', root.dataset.sidebar);
  });
}

async function api(path, { signal, method = 'GET', data } = {}) {
  let response;
  try {
    response = await fetch(path, {
      method, signal,
      ...(data && { headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) }),
    });
  } catch (error) {
    if (error.name === 'AbortError') throw error;
    throw new Error('Chưa kết nối được với máy chủ. Hãy kiểm tra kết nối rồi thử lại.');
  }
  if (response.status === 401) window.location.replace('/login');
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(payload.error ?? 'Yêu cầu không thành công.');
  return payload;
}

let noticeTimer;
function dismissBanner(immediate = false) {
  const region = $('notice');
  clearTimeout(noticeTimer);
  const existing = region.querySelector('.notice');
  if (!existing) return;
  if (immediate || !motionAllowed()) {
    region.replaceChildren();
    return;
  }
  existing.dataset.leaving = 'true';
  existing.addEventListener('animationend', () => existing.remove(), { once: true });
  setTimeout(() => existing.remove(), 260);
}

function banner(message, isError = false) {
  const region = $('notice');
  clearTimeout(noticeTimer);
  if (!message) return dismissBanner();
  region.replaceChildren();
  region.setAttribute('aria-live', isError ? 'assertive' : 'polite');
  const node = document.createElement('div');
  node.className = isError ? 'notice error' : 'notice';

  const badge = document.createElement('span');
  badge.className = 'notice-icon';
  badge.append(icon(isError ? 'alert-circle' : 'check'));

  const text = document.createElement('span');
  text.className = 'notice-text';
  text.textContent = message;

  const close = document.createElement('button');
  close.type = 'button';
  close.className = 'notice-close';
  close.setAttribute('aria-label', 'Đóng thông báo');
  close.textContent = '×';
  close.addEventListener('click', () => dismissBanner());

  node.append(badge, text, close);
  if (!isError) {
    const progress = document.createElement('span');
    progress.className = 'notice-progress';
    progress.setAttribute('aria-hidden', 'true');
    node.append(progress);
    const startTimer = () => { noticeTimer = setTimeout(() => dismissBanner(), 7000); };
    node.addEventListener('pointerenter', () => clearTimeout(noticeTimer));
    node.addEventListener('pointerleave', startTimer);
    startTimer();
  }
  region.append(node);
}

function fieldError(id, message) {
  const node = $(id);
  node.hidden = !message;
  node.textContent = message ?? '';
  if (message) shakeElement(node);
}

function setBusy(form, busy) {
  form.querySelectorAll('button').forEach(button => { button.disabled = busy; });
  form.setAttribute('aria-busy', String(busy));
}

function currency(value) {
  const [whole, fraction] = String(value).split('.');
  return `${num.format(BigInt(whole))}${fraction ? ',' + fraction : ''} ₫`;
}

function compactCurrency(value) {
  const n = Number(value);
  if (!Number.isFinite(n)) return currency(value);
  if (n >= 1e9) return `${decimalNum.format(n / 1e9)} tỷ`;
  if (n >= 1e6) return `${decimalNum.format(n / 1e6)} tr`;
  if (n >= 1e3) return `${decimalNum.format(n / 1e3)}k`;
  return `${num.format(Math.round(n))} ₫`;
}

function day(value) {
  return value.split('-').reverse().join('/');
}

function icon(name) {
  const namespace = 'http://www.w3.org/2000/svg';
  const svg = document.createElementNS(namespace, 'svg');
  svg.setAttribute('aria-hidden', 'true');
  const use = document.createElementNS(namespace, 'use');
  use.setAttribute('href', `/icons.svg#${name}`);
  svg.append(use);
  return svg;
}

function option(value, label) {
  return new Option(label, value);
}

function replaceOptions(select, values, placeholder, current = select.value) {
  select.replaceChildren(...(placeholder ? [option('', placeholder)] : []), ...values);
  if ([...select.options].some(item => item.value === current)) select.value = current;
}

function activityOptions(campaign, editable = false) {
  return catalog.activities
    .filter(activity => (!campaign || activity.MaChienDich === campaign) && (!editable || canWrite(activity)))
    .map(activity => option(activity.MaHoatDong, `${activity.MaHoatDong} · ${activity.TenHoatDong}`));
}

function canWrite(activity) {
  const campaign = catalog.campaigns.find(item => item.MaChienDich === activity?.MaChienDich);
  return Boolean(campaign && catalog.campaignsAssigned.includes(campaign.MaChienDich) &&
    !finished.has(activity.TrangThai) && !finished.has(campaign.TrangThai));
}

function syncListActivity() {
  replaceOptions($('list-activity'), activityOptions($('list-campaign').value), 'Tất cả hoạt động');
}

function syncReportActivity() {
  const select = $('report-activity');
  replaceOptions(select, activityOptions($('report-campaign').value), 'Chọn hoạt động');
  if (!select.value && select.options.length > 1) select.selectedIndex = 1;
}

function parameters(form) {
  const params = new URLSearchParams(new FormData(form));
  if (!params.get('from') || !params.get('to')) throw new Error('Chọn ngày bắt đầu và ngày kết thúc.');
  if (params.get('from') > params.get('to')) throw new Error('Từ ngày phải trước hoặc bằng Đến ngày.');
  return params;
}

function cell(row, value, { secondary, className, label } = {}) {
  const td = row.insertCell();
  td.setAttribute('role', 'cell');
  td.textContent = value;
  if (className) td.className = className;
  if (label) td.dataset.label = label;
  if (secondary) {
    const detail = document.createElement('span');
    detail.className = 'meta';
    detail.textContent = secondary;
    td.append(detail);
  }
  return td;
}

function renderSkeletonRows(tbody, cols, count = 4) {
  if (tbody.children.length > 0) return;
  const frag = document.createDocumentFragment();
  for (let i = 0; i < count; i++) {
    const tr = document.createElement('tr');
    tr.className = 'skeleton-row';
    tr.setAttribute('aria-hidden', 'true');
    for (let c = 0; c < cols; c++) {
      const td = tr.insertCell();
      const bar = document.createElement('span');
      bar.className = 'skeleton-bar';
      td.append(bar);
      if (c < 2) {
        const sub = document.createElement('span');
        sub.className = 'skeleton-bar short';
        td.append(sub);
      }
    }
    frag.append(tr);
  }
  tbody.replaceChildren(frag);
}

// ==========================================================================
// Quick Sort Segmented Control (sliding liquid pill synced with sort select)
// ==========================================================================
function setupQuickSort() {
  const group = $('quick-sort');
  if (!group) return { sync: () => {} };
  const pill = group.querySelector('.seg-pill');
  const buttons = [...group.querySelectorAll('button[data-sort]')];

  function sync() {
    const current = filters.elements.sort.value;
    let activeBtn = buttons[0];
    for (const btn of buttons) {
      const active = btn.dataset.sort === current;
      btn.setAttribute('aria-pressed', String(active));
      if (active) activeBtn = btn;
    }
    if (activeBtn && pill) {
      pill.style.setProperty('--sx', `${activeBtn.offsetLeft}px`);
      pill.style.setProperty('--sw', `${activeBtn.offsetWidth}px`);
    }
  }

  for (const btn of buttons) {
    btn.addEventListener('click', () => {
      if (filters.elements.sort.value === btn.dataset.sort) return;
      filters.elements.sort.value = btn.dataset.sort;
      sync();
      void loadExpenses();
    });
  }
  filters.elements.sort.addEventListener('change', sync);
  window.addEventListener('resize', sync, { passive: true });
  requestAnimationFrame(sync);
  return { sync };
}

const quickSort = setupQuickSort();

// Active removable filter chips
function renderActiveChips() {
  const wrap = $('active-chips');
  if (!wrap) return;
  const chips = [];
  const q = filters.elements.q.value.trim();
  const camp = filters.elements.campaign.value;
  const act = filters.elements.activity.value;

  if (q) {
    chips.push({
      label: `Từ khóa: “${q}”`,
      clear: () => { filters.elements.q.value = ''; void loadExpenses(); },
    });
  }
  if (camp) {
    const cObj = catalog?.campaigns?.find(c => c.MaChienDich === camp);
    chips.push({
      label: `Chiến dịch: ${cObj ? `${cObj.MaChienDich} · ${cObj.TenChienDich}` : camp}`,
      clear: () => {
        filters.elements.campaign.value = '';
        $('campaign-switch').value = '';
        campaignSwitcher.sync();
        syncListActivity();
        void loadExpenses();
      },
    });
  }
  if (act) {
    const aObj = catalog?.activities?.find(a => a.MaHoatDong === act);
    chips.push({
      label: `Hoạt động: ${aObj ? `${aObj.MaHoatDong} · ${aObj.TenHoatDong}` : act}`,
      clear: () => { filters.elements.activity.value = ''; void loadExpenses(); },
    });
  }

  wrap.hidden = chips.length === 0;
  wrap.replaceChildren(...chips.map(ch => {
    const span = document.createElement('span');
    span.className = 'filter-chip';
    const text = document.createElement('span');
    text.textContent = ch.label;
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.setAttribute('aria-label', `Xóa bộ lọc ${ch.label}`);
    btn.textContent = '×';
    btn.addEventListener('click', ch.clear);
    span.append(text, btn);
    return span;
  }));
}

// ==========================================================================
// Quick Inspect Slide-Over Frosted Glass Drawer
// ==========================================================================
function closeDrawer() {
  const drawer = $('detail-drawer');
  const backdrop = $('drawer-backdrop');
  if (!drawer || drawer.hidden) return;
  drawerItem = null;
  if (!motionAllowed()) {
    drawer.hidden = true;
    backdrop.hidden = true;
    return;
  }
  drawer.dataset.closing = 'true';
  backdrop.dataset.closing = 'true';
  const done = () => {
    delete drawer.dataset.closing;
    delete backdrop.dataset.closing;
    drawer.hidden = true;
    backdrop.hidden = true;
  };
  drawer.addEventListener('animationend', done, { once: true });
  setTimeout(done, 280);
}

function openDrawer(item) {
  const drawer = $('detail-drawer');
  const backdrop = $('drawer-backdrop');
  if (!drawer || !item) return;
  drawerItem = item;
  delete drawer.dataset.closing;
  delete backdrop.dataset.closing;

  const activity = catalog.activities.find(a => a.MaHoatDong === item.MaHoatDong);
  const campaign = catalog.campaigns.find(c => c.MaChienDich === item.MaChienDich);
  const permitted = item.MaNguoiGhiNhan === catalog.actor && canWrite(activity);
  const locked = finished.has(activity?.TrangThai) || finished.has(campaign?.TrangThai);

  $('drawer-code').textContent = item.MaKhoanChi;
  const statusEl = $('drawer-status');
  statusEl.className = locked ? 'badge locked' : 'badge';
  statusEl.textContent = permitted ? 'Có thể sửa / xóa' : locked ? 'Đã khóa sổ' : 'Chỉ xem';

  $('drawer-title').textContent = item.NoiDungChi;
  $('drawer-activity').textContent = `${item.MaHoatDong} · ${item.TenHoatDong}`;
  $('drawer-campaign').textContent = campaign ? `${campaign.MaChienDich} · ${campaign.TenChienDich}` : item.MaChienDich;
  $('drawer-date').textContent = day(item.NgayPhatSinh);
  $('drawer-receipt').textContent = item.MaChungTu || 'Không có chứng từ';
  $('drawer-actor').textContent = item.MaNguoiGhiNhan;

  $('drawer-edit').hidden = !permitted;
  $('drawer-delete').hidden = !permitted;

  const amount = BigInt(item.SoTien);
  const pct = lastExpenseTotal > 0n ? Math.min(100, Number((amount * 1000n) / lastExpenseTotal) / 10) : 0;
  $('drawer-share-pct').textContent = `${decimalNum.format(pct)}%`;
  const fill = $('drawer-share-fill');
  fill.style.setProperty('--share-w', '0%');

  backdrop.hidden = false;
  drawer.hidden = false;
  delete $('drawer-amount').dataset.numCurrent;
  animateNumber($('drawer-amount'), amount, (v) => currency(v), { duration: 520, isBigInt: true });
  requestAnimationFrame(() => fill.style.setProperty('--share-w', `${Math.max(4, pct).toFixed(1)}%`));
  $('drawer-close').focus();
}

$('drawer-close')?.addEventListener('click', closeDrawer);
$('drawer-backdrop')?.addEventListener('click', closeDrawer);
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && !$('detail-drawer')?.hidden) {
    e.preventDefault();
    closeDrawer();
  }
});
$('drawer-copy')?.addEventListener('click', async () => {
  if (!drawerItem) return;
  const btn = $('drawer-copy');
  const label = btn.querySelector('span');
  const iconUse = btn.querySelector('use');
  try {
    await navigator.clipboard?.writeText(drawerItem.MaKhoanChi);
    burstFromElement(btn, { count: 16, spread: 4.5 });
    label.textContent = 'Đã sao chép!';
    iconUse.setAttribute('href', '/icons.svg#check');
    setTimeout(() => {
      label.textContent = 'Sao chép mã';
      iconUse.setAttribute('href', '/icons.svg#copy');
    }, 1600);
  } catch {
    banner(`Mã khoản chi: ${drawerItem.MaKhoanChi}`);
  }
});
$('drawer-filter-activity')?.addEventListener('click', () => {
  if (!drawerItem) return;
  const item = drawerItem;
  closeDrawer();
  filters.elements.campaign.value = item.MaChienDich;
  $('campaign-switch').value = item.MaChienDich;
  campaignSwitcher.sync();
  syncListActivity();
  filters.elements.activity.value = item.MaHoatDong;
  void loadExpenses();
});
$('drawer-edit')?.addEventListener('click', () => {
  if (!drawerItem) return;
  const item = drawerItem;
  closeDrawer();
  openEditor(item);
});
$('drawer-delete')?.addEventListener('click', () => {
  if (!drawerItem) return;
  const item = drawerItem;
  closeDrawer();
  openDelete(item);
});

// ==========================================================================
// Custom Sylva Frosted-Glass Campaign Switcher
// ==========================================================================
function setupCampaignSwitcher() {
  const select = $('campaign-switch');
  const trigger = $('switcher-trigger');
  const label = $('switcher-label');
  const menu = $('switcher-menu');
  if (!trigger || !menu) return { render: () => {}, sync: () => {} };

  function closeMenu() {
    if (menu.hidden) return;
    menu.hidden = true;
    trigger.setAttribute('aria-expanded', 'false');
  }

  function openMenu() {
    menu.hidden = false;
    trigger.setAttribute('aria-expanded', 'true');
    const selected = menu.querySelector('[aria-selected="true"]') ?? menu.firstElementChild;
    selected?.focus();
  }

  function statusLabel(status) {
    if (status === 'HOAN_THANH') return ['Hoàn thành', 'locked'];
    if (status === 'HUY') return ['Đã hủy', 'locked'];
    if (status === 'DANG_CHAY') return ['Đang chạy', 'active'];
    return [status || '', ''];
  }

  function render() {
    const current = select.value;
    const entries = [
      { value: '', label: 'Tất cả chiến dịch', status: '' },
      ...(catalog?.campaigns ?? []).map(c => ({
        value: c.MaChienDich,
        label: `${c.MaChienDich} · ${c.TenChienDich}`,
        status: c.TrangThai,
      })),
    ];
    menu.replaceChildren(...entries.map(entry => {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'campaign-option';
      btn.setAttribute('role', 'option');
      btn.setAttribute('aria-selected', String(entry.value === current));
      btn.dataset.value = entry.value;

      const copy = document.createElement('span');
      copy.className = 'campaign-option-copy';
      const title = document.createElement('span');
      title.textContent = entry.label;
      copy.append(title);

      const meta = document.createElement('span');
      meta.className = 'campaign-option-meta';
      if (entry.status) {
        const [stText, stClass] = statusLabel(entry.status);
        const chip = document.createElement('span');
        chip.className = `status-chip ${stClass}`.trim();
        chip.textContent = stText;
        meta.append(chip);
      }
      const check = icon('check');
      check.classList.add('check-icon');
      meta.append(check);

      btn.append(copy, meta);
      btn.addEventListener('click', () => {
        closeMenu();
        if (select.value !== entry.value) {
          select.value = entry.value;
          select.dispatchEvent(new Event('change', { bubbles: true }));
        }
        sync();
        trigger.focus();
      });
      return btn;
    }));
    sync();
  }

  function sync() {
    const selectedOption = select.selectedOptions[0];
    label.textContent = selectedOption ? selectedOption.textContent : 'Tất cả chiến dịch';
    for (const btn of menu.querySelectorAll('.campaign-option')) {
      btn.setAttribute('aria-selected', String(btn.dataset.value === select.value));
    }
  }

  trigger.addEventListener('click', () => {
    if (menu.hidden) openMenu();
    else closeMenu();
  });
  document.addEventListener('pointerdown', (e) => {
    if (!menu.hidden && !(e.target instanceof Element && e.target.closest('#campaign-switcher'))) closeMenu();
  });
  menu.addEventListener('keydown', (e) => {
    const opts = [...menu.querySelectorAll('.campaign-option')];
    const idx = opts.indexOf(document.activeElement);
    if (e.key === 'Escape') { e.preventDefault(); closeMenu(); trigger.focus(); }
    else if (e.key === 'ArrowDown') { e.preventDefault(); opts[(idx + 1) % opts.length]?.focus(); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); opts[(idx - 1 + opts.length) % opts.length]?.focus(); }
  });

  return { render, sync };
}

const campaignSwitcher = setupCampaignSwitcher();

// ==========================================================================
// Hero Dual-Mode Chart: Interactive Bars + Glowing Animated SVG Spline Area
// ==========================================================================
function setupChartModeToggle() {
  const toggle = $('chart-mode-toggle');
  if (!toggle) return;
  toggle.dataset.mode = chartMode;
  for (const btn of toggle.querySelectorAll('button[data-chart-mode]')) {
    btn.addEventListener('click', () => {
      const next = btn.dataset.chartMode;
      if (next === chartMode) return;
      chartMode = next;
      toggle.dataset.mode = chartMode;
      for (const b of toggle.querySelectorAll('button[data-chart-mode]')) {
        b.setAttribute('aria-pressed', String(b.dataset.chartMode === chartMode));
      }
      renderSpendChart(lastDailySpend);
    });
  }
}
setupChartModeToggle();

function renderSplineChart(visible, max) {
  const wrap = $('chart-spline');
  const ns = 'http://www.w3.org/2000/svg';
  const svg = document.createElementNS(ns, 'svg');
  svg.setAttribute('viewBox', '0 0 240 116');
  svg.setAttribute('class', 'spline-svg');

  const padX = 16;
  const topY = 12;
  const baseY = 92;
  const spanX = 240 - padX * 2;
  const spanY = baseY - topY;

  const pts = visible.map(([date, amount], i) => {
    const ratio = max > 0n ? Number((amount * 1000n) / max) / 1000 : 0;
    const x = visible.length === 1 ? 120 : padX + (spanX * i) / (visible.length - 1);
    const y = baseY - ratio * spanY;
    return { x, y, date, amount, pct: Math.round(ratio * 100) };
  });

  // Smooth Catmull-Rom / cubic Bezier path
  let lineD = `M ${pts[0].x.toFixed(1)} ${pts[0].y.toFixed(1)}`;
  for (let i = 0; i < pts.length - 1; i++) {
    const p0 = pts[Math.max(0, i - 1)];
    const p1 = pts[i];
    const p2 = pts[i + 1];
    const p3 = pts[Math.min(pts.length - 1, i + 2)];
    const cp1x = p1.x + (p2.x - p0.x) / 6;
    const cp1y = Math.min(baseY, Math.max(topY - 4, p1.y + (p2.y - p0.y) / 6));
    const cp2x = p2.x - (p3.x - p1.x) / 6;
    const cp2y = Math.min(baseY, Math.max(topY - 4, p2.y - (p3.y - p1.y) / 6));
    lineD += ` C ${cp1x.toFixed(1)} ${cp1y.toFixed(1)}, ${cp2x.toFixed(1)} ${cp2y.toFixed(1)}, ${p2.x.toFixed(1)} ${p2.y.toFixed(1)}`;
  }

  const areaD = `${lineD} L ${pts[pts.length - 1].x.toFixed(1)} ${baseY} L ${pts[0].x.toFixed(1)} ${baseY} Z`;

  const defs = document.createElementNS(ns, 'defs');
  const grad = document.createElementNS(ns, 'linearGradient');
  grad.id = 'spline-grad';
  grad.setAttribute('x1', '0'); grad.setAttribute('y1', '0');
  grad.setAttribute('x2', '0'); grad.setAttribute('y2', '1');
  const s1 = document.createElementNS(ns, 'stop');
  s1.setAttribute('offset', '0%'); s1.setAttribute('stop-color', '#c4ee4f'); s1.setAttribute('stop-opacity', '0.42');
  const s2 = document.createElementNS(ns, 'stop');
  s2.setAttribute('offset', '100%'); s2.setAttribute('stop-color', '#c4ee4f'); s2.setAttribute('stop-opacity', '0');
  grad.append(s1, s2);
  defs.append(grad);
  svg.append(defs);

  // Subtle horizontal guide lines
  for (let g = 0; g < 3; g++) {
    const gy = topY + (spanY * g) / 2;
    const guide = document.createElementNS(ns, 'line');
    guide.setAttribute('x1', String(padX));
    guide.setAttribute('x2', String(240 - padX));
    guide.setAttribute('y1', gy.toFixed(1));
    guide.setAttribute('y2', gy.toFixed(1));
    guide.setAttribute('stroke', '#d0eacd22');
    guide.setAttribute('stroke-dasharray', '3 3');
    svg.append(guide);
  }

  if (pts.length > 1) {
    const area = document.createElementNS(ns, 'path');
    area.setAttribute('d', areaD);
    area.setAttribute('fill', 'url(#spline-grad)');
    area.setAttribute('class', 'spline-area');
    svg.append(area);

    const line = document.createElementNS(ns, 'path');
    line.setAttribute('d', lineD);
    line.setAttribute('class', 'spline-line');
    svg.append(line);
  }

  pts.forEach((p, idx) => {
    if (idx === pts.length - 1) {
      const pulse = document.createElementNS(ns, 'circle');
      pulse.setAttribute('cx', p.x.toFixed(1));
      pulse.setAttribute('cy', p.y.toFixed(1));
      pulse.setAttribute('r', '5.5');
      pulse.setAttribute('class', 'spline-pulse');
      svg.append(pulse);
    }
    const dot = document.createElementNS(ns, 'circle');
    dot.setAttribute('cx', p.x.toFixed(1));
    dot.setAttribute('cy', p.y.toFixed(1));
    dot.setAttribute('r', '4.2');
    dot.setAttribute('class', 'spline-dot');
    dot.setAttribute('tabindex', '0');
    dot.setAttribute('aria-label', `Thực chi ngày ${day(p.date)}: ${currency(p.amount)}`);
    const openTip = () => showTooltip(dot, {
      title: currency(p.amount),
      detail: `Ngày ${day(p.date)} · ${p.pct}% mức đỉnh`,
      placement: 'top',
    });
    dot.addEventListener('pointerenter', openTip);
    dot.addEventListener('focus', openTip);
    dot.addEventListener('pointerleave', hideTooltip);
    dot.addEventListener('blur', hideTooltip);
    svg.append(dot);

    if (pts.length <= 3 || idx === 0 || idx === pts.length - 1) {
      const txt = document.createElementNS(ns, 'text');
      txt.setAttribute('x', p.x.toFixed(1));
      txt.setAttribute('y', '110');
      txt.setAttribute('text-anchor', idx === 0 ? 'start' : idx === pts.length - 1 ? 'end' : 'middle');
      txt.setAttribute('class', 'spline-label');
      txt.textContent = day(p.date).slice(0, 5);
      svg.append(txt);
    }
  });

  wrap.replaceChildren(svg);
}

function renderSpendChart(days) {
  lastDailySpend = days;
  const visible = [...days].sort(([a], [b]) => a.localeCompare(b)).slice(-6);
  const max = visible.reduce((largest, [, amount]) => amount > largest ? amount : largest, 0n);
  const chart = $('spend-chart');
  chart.hidden = max === 0n;
  chart.querySelector('figcaption').textContent = days.size > visible.length ? '6 ngày gần nhất' : 'Chi theo ngày';
  hideTooltip();

  const barsEl = $('chart-bars');
  const splineEl = $('chart-spline');
  barsEl.hidden = chartMode !== 'bar';
  splineEl.hidden = chartMode !== 'spline';

  if (max === 0n) return;

  if (chartMode === 'spline') {
    renderSplineChart(visible, max);
    return;
  }

  barsEl.replaceChildren(...visible.map(([date, amount], index) => {
    const pct = max > 0n ? Math.max(8, Number((amount * 1000n) / max) / 10) : 0;
    const column = document.createElement('div');
    column.className = 'chart-column';
    column.setAttribute('role', 'listitem');
    column.setAttribute('tabindex', '0');
    column.setAttribute('aria-label', `Thực chi ngày ${day(date)}: ${currency(amount)}`);

    const track = document.createElement('span');
    track.className = 'chart-track';
    const fill = document.createElement('span');
    fill.className = 'chart-bar-fill';
    fill.style.setProperty('--bar-pct', `${pct.toFixed(1)}%`);
    fill.style.setProperty('--stagger-i', String(index));
    track.append(fill);

    const dayLabel = document.createElement('span');
    dayLabel.className = 'chart-day';
    dayLabel.setAttribute('aria-hidden', 'true');
    if (visible.length <= 3 || index === 0 || index === visible.length - 1) dayLabel.textContent = day(date).slice(0, 5);

    const openTip = () => showTooltip(track, {
      title: currency(amount),
      detail: `Ngày ${day(date)} · ${Math.round(pct)}% mức đỉnh`,
      placement: 'top',
    });
    column.addEventListener('pointerenter', openTip);
    column.addEventListener('focus', openTip);
    column.addEventListener('pointerleave', hideTooltip);
    column.addEventListener('blur', hideTooltip);

    column.append(track, dayLabel);
    return column;
  }));
}

function renderExpenses(items, params) {
  lastExpenseItems = items;
  const fragment = document.createDocumentFragment();
  const dailySpend = new Map();
  let total = 0n;
  for (const item of items) {
    const row = document.createElement('tr');
    row.setAttribute('role', 'row');
    cell(row, item.NoiDungChi, { secondary: [item.MaKhoanChi, item.MaChungTu].filter(Boolean).join(' · ') });
    cell(row, item.TenHoatDong, { secondary: `${item.MaHoatDong} · ${item.MaChienDich}` });
    cell(row, day(item.NgayPhatSinh), { label: 'Ngày phát sinh' });
    cell(row, currency(item.SoTien), { className: 'number', label: 'Số tiền' });
    cell(row, item.MaNguoiGhiNhan, { label: 'Người ghi' });
    const actions = cell(row, '', { className: 'right' });
    const activity = catalog.activities.find(a => a.MaHoatDong === item.MaHoatDong);
    const permitted = item.MaNguoiGhiNhan === catalog.actor && canWrite(activity);
    if (permitted) {
      for (const [label, symbol, action] of [['Sửa', 'pencil', () => openEditor(item)], ['Xóa', 'trash-2', () => openDelete(item)]]) {
        const button = document.createElement('button');
        button.type = 'button';
        button.append(icon(symbol), label);
        button.className = `ghost row-action${label === 'Xóa' ? ' remove' : ''}`;
        button.setAttribute('aria-label', `${label} khoản chi ${item.MaKhoanChi}`);
        button.addEventListener('click', (e) => { e.stopPropagation(); action(); });
        actions.append(button);
      }
    } else {
      const detail = document.createElement('span');
      const campaign = catalog.campaigns.find(c => c.MaChienDich === item.MaChienDich);
      const locked = finished.has(activity?.TrangThai) || finished.has(campaign?.TrangThai);
      detail.className = locked ? 'badge locked' : 'badge';
      detail.textContent = locked ? 'Đã khóa sổ' : 'Chỉ xem';
      actions.append(detail);
    }
    row.addEventListener('click', () => openDrawer(item));
    const amount = BigInt(item.SoTien);
    total += amount;
    dailySpend.set(item.NgayPhatSinh, (dailySpend.get(item.NgayPhatSinh) ?? 0n) + amount);
    fragment.append(row);
  }
  lastExpenseTotal = total;
  const tbody = $('expense-rows');
  tbody.replaceChildren(fragment);
  staggerChildren(tbody, 'tr', 14);

  animateNumber($('list-amount'), total, (v) => currency(v), { duration: 640, isBigInt: true });
  const start = day(params.get('from'));
  const end = day(params.get('to'));
  $('list-period').textContent = start === end ? start : `${start} – ${end}`;

  // Live Hero Insight Pills (Average & Peak Day)
  const pills = $('hero-pills');
  if (items.length > 0) {
    pills.hidden = false;
    const avg = total / BigInt(items.length);
    const peak = [...dailySpend.values()].reduce((m, v) => (v > m ? v : m), 0n);
    $('list-avg').textContent = compactCurrency(avg);
    $('list-peak').textContent = compactCurrency(peak);
  } else {
    pills.hidden = true;
  }

  animateNumber($('list-count'), items.length, (v) => num.format(Math.round(v)), { duration: 480 });
  animateNumber($('list-activities'), new Set(items.map(item => item.MaHoatDong)).size, (v) => num.format(Math.round(v)), { duration: 480 });
  $('table-count').textContent = `${items.length} khoản chi`;
  $('expense-empty').textContent = 'Không có khoản chi khớp bộ lọc.';
  $('expense-state').hidden = items.length > 0;
  renderActiveChips();
  quickSort.sync();
  renderSpendChart(dailySpend);
  renderFocus(items);
}

function renderFocus(items) {
  const top = items.reduce((best, item) => !best || BigInt(item.SoTien) > BigInt(best.SoTien) ? item : best, null);
  $('focus-card').hidden = !top || items.length < 2;
  if (!top) return;
  animateNumber($('focus-amount'), BigInt(top.SoTien), (v) => currency(v), { duration: 560, isBigInt: true });
  $('focus-text').textContent = `${top.NoiDungChi} · ${top.MaKhoanChi}`;
}

async function loadExpenses() {
  if (!catalog) return;
  let params;
  try { params = parameters(filters); }
  catch (error) { return banner(error.message, true); }
  expenseRequest?.abort();
  const request = new AbortController();
  expenseRequest = request;
  const submit = filters.querySelector('[type=submit]');
  submit.disabled = true;
  $('expense-results').setAttribute('aria-busy', 'true');
  renderSkeletonRows($('expense-rows'), 6, 4);
  try {
    const result = await api(`/api/expenses?${params}`, { signal: request.signal });
    if (expenseRequest === request) renderExpenses(result.rows, params);
  } catch (error) {
    if (error.name !== 'AbortError' && expenseRequest === request) {
      banner(error.message, true);
      renderExpenses([], params);
      $('expense-empty').textContent = 'Chưa tải được khoản chi. Hãy thử lọc lại.';
    }
  } finally {
    if (expenseRequest === request) {
      submit.disabled = false;
      $('expense-results').setAttribute('aria-busy', 'false');
    }
  }
}

function setDates(form) {
  const today = new Date().toISOString().slice(0, 10);
  form.elements.from.value = catalog.firstDate ?? today;
  form.elements.to.value = catalog.lastDate ?? today;
}

function openEditor(item) {
  editor.reset();
  editor.dataset.editing = item ? 'yes' : 'no';
  $('dialog-title').textContent = item ? 'Sửa khoản chi' : 'Thêm khoản chi';
  const fields = editor.elements;
  fields.id.readOnly = Boolean(item);
  fields.id.value = item?.MaKhoanChi ?? '';
  replaceOptions(fields.activity, activityOptions('', true), 'Chọn hoạt động', item?.MaHoatDong ?? $('list-activity').value);
  fields.date.value = item?.NgayPhatSinh ?? filters.elements.to.value;
  fields.amount.value = item?.SoTien ?? '';
  fields.description.value = item?.NoiDungChi ?? '';
  fields.receipt.value = item?.MaChungTu ?? '';
  fieldError('editor-error');
  expenseDialog.showModal();
  (item ? fields.activity : fields.id).focus();
}

function openDelete(item) {
  deletingId = item.MaKhoanChi;
  $('delete-detail').textContent = `Xóa khoản ${item.MaKhoanChi} “${item.NoiDungChi}”, trị giá ${currency(item.SoTien)}?`;
  fieldError('delete-error');
  deleteDialog.showModal();
}

async function saveExpense(event) {
  event.preventDefault();
  const data = Object.fromEntries(new FormData(editor));
  const editing = editor.dataset.editing === 'yes';
  fieldError('editor-error');
  if (!data.description.trim()) return fieldError('editor-error', 'Nhập nội dung chi.');
  if (BigInt(data.amount) <= 0n) return fieldError('editor-error', 'Số tiền phải lớn hơn 0 VND.');
  setBusy(editor, true);
  try {
    const result = await api(editing ? `/api/expenses/${encodeURIComponent(data.id)}` : '/api/expenses', {
      method: editing ? 'PUT' : 'POST', data,
    });
    expenseDialog.close();
    const outside = data.date < filters.elements.from.value || data.date > filters.elements.to.value;
    banner(result.SoDongTacDong === 0 ? 'Khoản chi giữ nguyên vì dữ liệu chưa thay đổi.' :
      `Đã ${editing ? 'cập nhật' : 'thêm'} khoản chi ${data.id}.${outside ? ' Ngày phát sinh nằm ngoài kỳ đang lọc.' : ''}`);
    if (result.SoDongTacDong !== 0) burstFromElement($('open-create'), { count: 32, spread: 7 });
    await loadExpenses();
  } catch (error) {
    fieldError('editor-error', error.message);
  } finally { setBusy(editor, false); }
}

async function removeExpense(event) {
  event.preventDefault();
  fieldError('delete-error');
  const id = deletingId;
  setBusy(deleteForm, true);
  try {
    await api(`/api/expenses/${encodeURIComponent(id)}`, { method: 'DELETE', data: {} });
    deleteDialog.close();
    banner(`Đã xóa khoản chi ${id}.`);
    await loadExpenses();
  } catch (error) {
    fieldError('delete-error', error.message);
  } finally { setBusy(deleteForm, false); }
}

// ==========================================================================
// Reports: Interactive Animated SVG Donut Ring <-> Ranked Bars Cross-Highlight
// ==========================================================================
function renderRankedExpenses(items, params) {
  const top = items.slice(0, 5);
  const total = items.reduce((sum, item) => sum + BigInt(item.TongChiTrongKy), 0n);
  const max = top.reduce((largest, item) => {
    const amount = BigInt(item.TongChiTrongKy);
    return amount > largest ? amount : largest;
  }, 0n);
  animateNumber($('report-total'), total, (v) => currency(v), { duration: 640, isBigInt: true });
  $('ranked-scope').textContent = top.length < items.length ? '5 hoạt động chi nhiều nhất theo bộ lọc' :
    `Từ ${day(params.get('from'))} đến ${day(params.get('to'))}`;
  $('ranked-note').textContent = 'Không có khoản chi đạt ngưỡng lọc.';
  $('ranked-note').hidden = top.length > 0;

  const donutStage = $('donut-stage');
  const donutSvg = $('report-donut');
  const donutVal = $('donut-value');
  const donutLabel = $('donut-label');
  const barsEl = $('ranked-bars');

  if (top.length === 0 || total === 0n) {
    donutStage.hidden = true;
    barsEl.replaceChildren();
    return;
  }

  donutStage.hidden = false;
  delete donutStage.dataset.activeIdx;
  const dark = document.documentElement.dataset.theme === 'dark';
  const palette = dark ? DONUT_COLORS : DONUT_COLORS_LIGHT;

  const ns = 'http://www.w3.org/2000/svg';
  const radius = 70;
  const circumference = 2 * Math.PI * radius;
  donutSvg.replaceChildren();

  const track = document.createElementNS(ns, 'circle');
  track.setAttribute('cx', '90');
  track.setAttribute('cy', '90');
  track.setAttribute('r', String(radius));
  track.setAttribute('class', 'donut-track');
  donutSvg.append(track);

  const defaultValText = compactCurrency(total);
  const defaultLabelText = `${items.length} hoạt động`;
  donutVal.textContent = defaultValText;
  donutLabel.textContent = defaultLabelText;

  let offsetAcc = 0;
  const segments = [];
  const rows = [];

  function setHighlight(idx) {
    if (idx === null || idx === undefined) {
      delete donutStage.dataset.activeIdx;
      segments.forEach(s => { delete s.dataset.active; });
      rows.forEach(r => { delete r.dataset.active; });
      donutVal.textContent = defaultValText;
      donutLabel.textContent = defaultLabelText;
      return;
    }
    donutStage.dataset.activeIdx = String(idx);
    segments.forEach((s, i) => { s.dataset.active = String(i === idx); });
    rows.forEach((r, i) => { r.dataset.active = String(i === idx); });
    const item = top[idx];
    const sharePct = Math.round(Number((BigInt(item.TongChiTrongKy) * 1000n) / total) / 10);
    donutVal.textContent = `${sharePct}%`;
    donutLabel.textContent = item.MaHoatDong;
  }

  top.forEach((item, idx) => {
    const val = BigInt(item.TongChiTrongKy);
    const barPct = max > 0n ? Math.max(4, Number((val * 1000n) / max) / 10) : 0;
    const shareRatio = Number((val * 10000n) / total) / 10000;
    const sharePct = Math.round(shareRatio * 100);
    const color = palette[idx % palette.length];

    // Donut arc segment
    const segLen = Math.max(3, shareRatio * circumference - 3);
    const seg = document.createElementNS(ns, 'circle');
    seg.setAttribute('cx', '90');
    seg.setAttribute('cy', '90');
    seg.setAttribute('r', String(radius));
    seg.setAttribute('class', 'donut-seg');
    seg.setAttribute('stroke', color);
    seg.setAttribute('stroke-dasharray', `${segLen.toFixed(2)} ${(circumference - segLen).toFixed(2)}`);
    seg.setAttribute('stroke-dashoffset', (-offsetAcc).toFixed(2));
    seg.style.setProperty('--stagger-i', String(idx));
    seg.style.setProperty('--seg-glow', color);
    seg.addEventListener('pointerenter', () => setHighlight(idx));
    seg.addEventListener('pointerleave', () => setHighlight(null));
    donutSvg.append(seg);
    segments.push(seg);
    offsetAcc += shareRatio * circumference;

    // Ranked bar row
    const row = document.createElement('li');
    row.style.setProperty('--stagger-i', String(idx));

    const nameWrap = document.createElement('span');
    nameWrap.className = 'ranked-name-wrap';
    const swatch = document.createElement('span');
    swatch.className = 'ranked-swatch';
    swatch.style.setProperty('--seg-color', color);
    const name = document.createElement('span');
    name.className = 'ranked-name';
    name.textContent = `${item.MaHoatDong} · ${item.TenHoatDong}`;
    name.title = name.textContent;
    nameWrap.append(swatch, name);

    const share = document.createElement('span');
    share.className = 'ranked-share';
    share.textContent = `${sharePct}%`;

    const amount = document.createElement('strong');
    amount.textContent = currency(item.TongChiTrongKy);

    const trackBar = document.createElement('div');
    trackBar.className = 'ranked-bar-track';
    trackBar.setAttribute('aria-hidden', 'true');
    const fill = document.createElement('div');
    fill.className = 'ranked-bar-fill';
    fill.style.setProperty('--bar-pct', `${barPct.toFixed(1)}%`);
    fill.style.setProperty('--stagger-i', String(idx));
    trackBar.append(fill);

    row.addEventListener('pointerenter', () => setHighlight(idx));
    row.addEventListener('pointerleave', () => setHighlight(null));

    row.append(nameWrap, share, amount, trackBar);
    rows.push(row);
  });

  barsEl.replaceChildren(...rows);
}

function setReportBusy(busy) {
  reportFilters.querySelector('[type=submit]').disabled = busy;
  $('report-overview').setAttribute('aria-busy', String(busy));
  $('report-results').setAttribute('aria-busy', String(busy));
}

async function loadReports() {
  if (!catalog) return;
  if (!catalog.campaigns.length) {
    setReportBusy(false);
    $('ranked-note').textContent = 'Chưa có chiến dịch để lập báo cáo.';
    $('report-empty').textContent = 'Chưa có chiến dịch để lập báo cáo.';
    return;
  }
  let params;
  try { params = parameters(reportFilters); }
  catch (error) { return banner(error.message, true); }
  reportRequest?.abort();
  const request = new AbortController();
  reportRequest = request;
  setReportBusy(true);
  renderSkeletonRows($('report-rows'), 4, 3);
  if (!$('report-state').hidden) $('report-empty').textContent = 'Đang tải báo cáo…';
  const operations = await Promise.allSettled([
    api(`/api/reports?${params}`, { signal: request.signal }),
    api(`/api/metrics?${params}`, { signal: request.signal }),
  ]);
  if (reportRequest !== request) return;
  const [report, metrics] = operations;
  if (report.status === 'fulfilled') {
    renderRankedExpenses(report.value.rows, params);
    const fragment = document.createDocumentFragment();
    for (const item of report.value.rows) {
      const row = document.createElement('tr');
      row.setAttribute('role', 'row');
      cell(row, item.TenHoatDong, { secondary: item.MaHoatDong });
      cell(row, item.TenChienDich, { secondary: item.MaChienDich });
      cell(row, item.SoKhoanChiTrongKy, { className: 'number', label: 'Số khoản chi' });
      cell(row, currency(item.TongChiTrongKy), { className: 'number', label: 'Tổng chi trong kỳ' });
      fragment.append(row);
    }
    const tbody = $('report-rows');
    tbody.replaceChildren(fragment);
    staggerChildren(tbody, 'tr', 14);
    $('report-count').textContent = `${report.value.rows.length} hoạt động`;
    $('report-state').hidden = report.value.rows.length > 0;
    $('report-empty').textContent = 'Không có hoạt động đạt ngưỡng tổng chi trong kỳ.';
  } else {
    $('donut-stage').hidden = true;
    $('ranked-bars').replaceChildren();
    animateNumber($('report-total'), null, () => '—');
    $('ranked-scope').textContent = 'Theo các hoạt động đạt ngưỡng lọc';
    $('ranked-note').hidden = false;
    $('ranked-note').textContent = 'Chưa tải được thực chi.';
    $('report-rows').replaceChildren();
    $('report-count').textContent = '';
    $('report-state').hidden = false;
    $('report-empty').textContent = report.reason.message;
  }
  if (metrics.status === 'fulfilled') {
    animateNumber($('report-overspent'), Number(metrics.value.overspent), (v) => num.format(Math.round(v)), { duration: 480 });
    const cpa = metrics.value.cpa;
    if (cpa === null) {
      animateNumber($('report-cpa'), null, () => '—');
    } else {
      const numericCpa = Number(cpa);
      if (Number.isFinite(numericCpa) && numericCpa < 1e15) {
        animateNumber($('report-cpa'), numericCpa, (v) => `${decimalNum.format(v)} ₫`, { duration: 600 });
        setTimeout(() => {
          if ($('report-cpa').dataset.numCurrent === String(numericCpa)) $('report-cpa').textContent = currency(cpa);
        }, 620);
      } else {
        $('report-cpa').textContent = currency(cpa);
      }
    }
    $('cpa-note').textContent = !params.get('activity') ? 'Chọn một hoạt động để tính CPA.' :
      cpa === null ? 'Thiếu dữ liệu ngày hoặc tổng chuyển đổi bằng 0.' : 'VND cho mỗi lượt chuyển đổi';
  } else {
    animateNumber($('report-overspent'), null, () => '—');
    animateNumber($('report-cpa'), null, () => '—');
    $('cpa-note').textContent = metrics.reason.message;
  }
  setReportBusy(false);
}

function pageFromHash() {
  return location.hash === '#bao-cao' ? 'bao-cao' : 'khoan-chi';
}

function swapBreadcrumb(nextLabel) {
  const node = $('current-page');
  if (node.textContent === nextLabel) return;
  node.textContent = nextLabel;
  if (motionAllowed()) {
    node.animate?.([
      { opacity: 0, transform: 'translateY(10px)', filter: 'blur(3px)' },
      { opacity: 1, transform: 'none', filter: 'blur(0)' },
    ], { duration: 300, easing: 'cubic-bezier(.22, 1, .36, 1)' });
  }
}

function showPage(active = pageFromHash()) {
  activePage = active;
  swapBreadcrumb(active === 'bao-cao' ? 'Báo cáo' : 'Khoản chi');
  hideTooltip();
  closeDrawer();
  dismissBanner(true);
  for (const link of document.querySelectorAll('nav a[data-page]')) {
    const selected = link.dataset.page === active;
    if (selected) link.setAttribute('aria-current', 'page');
    else link.removeAttribute('aria-current');
    $(link.dataset.page).hidden = !selected;
  }
  if (active === 'bao-cao') void loadReports();
  else requestAnimationFrame(() => quickSort.sync());
}

function transitionToPage() {
  if (pageFromHash() === activePage) return;
  pageTransition?.skipTransition();
  const update = () => {
    showPage();
    window.scrollTo({ top: 0, behavior: 'instant' });
  };
  if (reducedMotion.matches || !document.startViewTransition) {
    update();
    if (!reducedMotion.matches) {
      $(activePage).animate?.(
        [{ opacity: 0, transform: 'translateY(12px)', filter: 'blur(3px)' }, { opacity: 1, transform: 'none', filter: 'blur(0)' }],
        { duration: 280, easing: 'cubic-bezier(.22, 1, .36, 1)' },
      );
    }
    return;
  }
  const root = document.documentElement;
  root.dataset.pageTransition = '';
  const transition = document.startViewTransition(update);
  pageTransition = transition;
  void transition.ready.catch(() => {});
  const clear = () => {
    if (pageTransition === transition) {
      delete root.dataset.pageTransition;
      pageTransition = null;
    }
  };
  void transition.finished.then(clear, clear);
}

filters.addEventListener('submit', event => {
  event.preventDefault(); dismissBanner(); void loadExpenses();
});
filters.addEventListener('reset', () => setTimeout(() => {
  if (!catalog) return;
  dismissBanner(); syncListActivity(); setDates(filters);
  $('campaign-switch').value = '';
  campaignSwitcher.sync();
  quickSort.sync();
  void loadExpenses();
}));
$('list-campaign').addEventListener('change', () => {
  if (!catalog) return;
  syncListActivity();
  $('campaign-switch').value = $('list-campaign').value;
  campaignSwitcher.sync();
});
$('report-campaign').addEventListener('change', () => { if (catalog) syncReportActivity(); });
reportFilters.addEventListener('submit', event => {
  event.preventDefault(); dismissBanner(); void loadReports();
});
for (const button of document.querySelectorAll('[data-close]')) {
  button.addEventListener('click', () => $(button.dataset.close).close());
}
for (const dialog of [expenseDialog, deleteDialog]) {
  dialog.addEventListener('cancel', event => {
    if (dialog.querySelector('form').getAttribute('aria-busy') === 'true') {
      event.preventDefault();
      shakeElement(dialog);
    }
  });
  dialog.addEventListener('click', event => {
    if (event.target === dialog) {
      if (dialog.querySelector('form').getAttribute('aria-busy') === 'true') shakeElement(dialog);
      else dialog.close();
    }
  });
}
$('open-create').addEventListener('click', () => openEditor());
editor.addEventListener('submit', saveExpense);
deleteForm.addEventListener('submit', removeExpense);
document.querySelector('.skip-link').addEventListener('click', event => {
  event.preventDefault();
  $(activePage === 'bao-cao' ? 'report-title' : 'expense-title').focus();
});
for (const link of document.querySelectorAll('nav a[data-page]')) {
  link.addEventListener('click', event => {
    if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    if (pageFromHash() === link.dataset.page) return;
    history.pushState(null, '', link.hash);
    transitionToPage();
  });
}
window.addEventListener('hashchange', transitionToPage);
window.addEventListener('pageshow', event => {
  if (event.persisted) window.location.reload();
});
$('logout').addEventListener('click', async () => {
  const button = $('logout');
  button.disabled = true;
  try {
    await api('/api/logout', { method: 'POST', data: {} });
    window.location.replace('/login');
  } catch (error) {
    banner(error.message, true);
    button.disabled = false;
  }
});
setupAppearance();

function goTo(page) {
  if (pageFromHash() !== page) { history.pushState(null, '', `#${page}`); transitionToPage(); }
}

const openPalette = setupPalette(() => [
  { label: 'Khoản chi', hint: 'Trang', icon: 'receipt-text', run: () => goTo('khoan-chi') },
  { label: 'Báo cáo chi phí', hint: 'Trang', icon: 'chart-column', run: () => goTo('bao-cao') },
  ...($('open-create').disabled ? [] : [{ label: 'Thêm khoản chi mới', hint: 'Lệnh', icon: 'plus', run: () => { goTo('khoan-chi'); openEditor(); } }]),
  { label: 'Chuyển kiểu biểu đồ (Cột / Đường)', hint: 'Biểu đồ', icon: 'chart-spline', run: () => {
    goTo('khoan-chi');
    const next = chartMode === 'bar' ? 'spline' : 'bar';
    document.querySelector(`[data-chart-mode="${next}"]`)?.click();
  } },
  { label: 'Đổi giao diện sáng / tối', hint: 'Giao diện', icon: 'sun', run: () => $('theme-toggle').click() },
  { label: 'Thu gọn / mở thanh điều hướng', hint: 'Bố cục · Ctrl+B', icon: 'panel-left-close', run: () => $('sidebar-toggle').click() },
  ...(catalog?.campaigns ?? []).map(c => ({
    label: `${c.MaChienDich} · ${c.TenChienDich}`,
    hint: 'Chiến dịch',
    icon: 'layers',
    run: () => {
      goTo('khoan-chi');
      $('campaign-switch').value = $('list-campaign').value = c.MaChienDich;
      campaignSwitcher.sync();
      syncListActivity();
      void loadExpenses();
    },
  })),
], query => ({
  label: `Tìm khoản chi “${query}”`,
  hint: 'Tìm kiếm',
  icon: 'search',
  run: () => {
    goTo('khoan-chi');
    filters.elements.q.value = query;
    void loadExpenses();
  },
}));
$('palette-open').addEventListener('click', openPalette);

$('focus-open').addEventListener('click', () => {
  burstFromElement($('focus-open'), { count: 22, spread: 5.5 });
  const top = lastExpenseItems.reduce((best, item) => !best || BigInt(item.SoTien) > BigInt(best.SoTien) ? item : best, null);
  if (top) {
    openDrawer(top);
    return;
  }
  filters.elements.sort.value = 'TIEN_GIAM';
  quickSort.sync();
  void loadExpenses().then(() => {
    const firstRow = document.querySelector('#expense-rows tr');
    firstRow?.animate?.([
      { background: 'var(--accent)', transform: 'scale(1.006)' },
      { background: 'transparent', transform: 'scale(1)' },
    ], { duration: 1500, easing: 'cubic-bezier(.22, 1, .36, 1)' });
  });
  $('expense-results').scrollIntoView({ behavior: reducedMotion.matches ? 'auto' : 'smooth', block: 'start' });
});

$('campaign-switch').addEventListener('change', event => {
  const code = event.target.value;
  $('list-campaign').value = code;
  syncListActivity();
  campaignSwitcher.sync();
  if (code && [...$('report-campaign').options].some(o => o.value === code)) {
    $('report-campaign').value = code;
    syncReportActivity();
  }
  const name = event.target.selectedOptions[0]?.textContent ?? 'Tất cả chiến dịch';
  document.title = code ? `${name} · Campaign Desk` : 'Campaign Desk · Khoản chi marketing';
  if (motionAllowed()) {
    $('workspace').animate?.(
      [{ opacity: .45, transform: 'translateY(10px) scale(.994)', filter: 'blur(3px)' }, { opacity: 1, transform: 'none', filter: 'blur(0)' }],
      { duration: 340, easing: 'cubic-bezier(.22, 1, .36, 1)' },
    );
  }
  void loadExpenses();
  if (activePage === 'bao-cao') void loadReports();
});

document.addEventListener('keydown', event => {
  if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'b' && !event.shiftKey && !event.altKey) {
    event.preventDefault();
    $('sidebar-toggle').click();
  }
});

try {
  catalog = await api('/api/catalog');
  $('operator').textContent = catalog.actor;
  $('operator-badge').title = `Nhân viên ${catalog.actor}`;
  const campaigns = () => catalog.campaigns.map(c => option(c.MaChienDich, `${c.MaChienDich} · ${c.TenChienDich}`));
  replaceOptions($('list-campaign'), campaigns(), 'Tất cả chiến dịch');
  replaceOptions($('report-campaign'), campaigns());
  replaceOptions($('campaign-switch'), campaigns(), 'Tất cả chiến dịch');
  campaignSwitcher.render();
  syncListActivity();
  syncReportActivity();
  setDates(filters);
  setDates(reportFilters);
  $('open-create').disabled = !catalog.activities.some(canWrite);
  showPage();
  await loadExpenses();
} catch (error) {
  $('expense-results').setAttribute('aria-busy', 'false');
  $('expense-rows').replaceChildren();
  $('expense-empty').textContent = 'Chưa tải được dữ liệu MySQL.';
  banner(error.message, true);
}
