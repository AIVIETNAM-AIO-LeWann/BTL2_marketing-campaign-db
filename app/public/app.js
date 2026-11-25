const $ = (id) => document.getElementById(id);
const filters = $('expense-filters');
const reportFilters = $('report-filters');
const editor = $('expense-editor');
const deleteForm = $('delete-form');
const expenseDialog = $('expense-dialog');
const deleteDialog = $('delete-dialog');
const num = new Intl.NumberFormat('vi-VN');
const finished = new Set(['HOAN_THANH', 'HUY']);
let catalog;
let expenseRequest;
let reportRequest;
let deletingId;

async function api(path, { signal, method = 'GET', data } = {}) {
  const response = await fetch(path, {
    method, signal,
    ...(data && { headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) }),
  });
  const payload = await response.json();
  if (!response.ok) throw new Error(payload.error ?? 'Yêu cầu không thành công.');
  return payload;
}

function banner(message, isError = false) {
  const node = $('notice');
  node.hidden = !message;
  node.textContent = message ?? '';
  node.classList.toggle('error', isError);
}

function fieldError(id, message) {
  const node = $(id);
  node.hidden = !message;
  node.textContent = message ?? '';
}

function setBusy(form, busy) {
  form.querySelectorAll('button').forEach(button => { button.disabled = busy; });
  form.setAttribute('aria-busy', String(busy));
}

function currency(value) {
  const [whole, fraction] = String(value).split('.');
  return `${num.format(BigInt(whole))}${fraction ? ',' + fraction : ''} ₫`;
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

function renderSpendChart(days) {
  const visible = [...days].sort(([a], [b]) => a.localeCompare(b)).slice(-6);
  const max = visible.reduce((largest, [, amount]) => amount > largest ? amount : largest, 0n);
  const chart = $('spend-chart');
  chart.hidden = max === 0n;
  chart.querySelector('figcaption').textContent = days.size > visible.length ? '6 ngày có chi gần nhất' : 'Chi theo ngày';
  $('chart-bars').replaceChildren(...visible.map(([date, amount], index) => {
    const column = document.createElement('div');
    column.className = 'chart-column';
    column.setAttribute('role', 'listitem');
    column.title = `${day(date)} · ${currency(amount)}`;
    const track = document.createElement('span');
    track.className = 'chart-track';
    const meter = document.createElement('meter');
    meter.className = 'chart-meter';
    meter.max = 1000;
    meter.value = Math.max(1, Number(amount * 1000n / max));
    meter.setAttribute('aria-label', `Thực chi ngày ${day(date)}`);
    meter.setAttribute('aria-valuetext', currency(amount));
    track.append(meter);
    const label = document.createElement('span');
    label.className = 'chart-day';
    label.setAttribute('aria-hidden', 'true');
    if (visible.length <= 3 || index === 0 || index === visible.length - 1) label.textContent = day(date).slice(0,5);
    column.append(track, label);
    return column;
  }));
}

function renderExpenses(items, params) {
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
        button.addEventListener('click', action);
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
    const amount = BigInt(item.SoTien);
    total += amount;
    dailySpend.set(item.NgayPhatSinh, (dailySpend.get(item.NgayPhatSinh) ?? 0n) + amount);
    fragment.append(row);
  }
  $('expense-rows').replaceChildren(fragment);
  $('list-amount').textContent = currency(total);
  const start = day(params.get('from'));
  const end = day(params.get('to'));
  $('list-period').textContent = start === end ? start : `${start} – ${end}`;
  $('list-count').textContent = num.format(items.length);
  $('list-activities').textContent = num.format(new Set(items.map(item => item.MaHoatDong)).size);
  $('table-count').textContent = `${items.length} khoản chi`;
  $('expense-empty').textContent = 'Không có khoản chi khớp bộ lọc.';
  $('expense-state').hidden = items.length > 0;
  renderSpendChart(dailySpend);
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
  try {
    const result = await api(`/api/expenses?${params}`, { signal: request.signal });
    if (expenseRequest === request) renderExpenses(result.rows, params);
  } catch (error) {
    if (error.name !== 'AbortError' && expenseRequest === request) {
      banner(error.message, true);
      $('expense-empty').textContent = 'Chưa tải được khoản chi. Hãy thử lọc lại.';
    }
  } finally {
    if (expenseRequest === request) submit.disabled = false;
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

async function loadReports() {
  if (!catalog?.campaigns.length) return;
  let params;
  try { params = parameters(reportFilters); }
  catch (error) { return banner(error.message, true); }
  reportRequest?.abort();
  const request = new AbortController();
  reportRequest = request;
  const submit = reportFilters.querySelector('[type=submit]');
  submit.disabled = true;
  $('report-overspent').textContent = '—';
  $('report-cpa').textContent = '—';
  $('cpa-note').textContent = 'CPA của hoạt động trong kỳ';
  $('report-count').textContent = '';
  $('report-rows').replaceChildren();
  $('report-state').hidden = false;
  $('report-empty').textContent = 'Đang tải báo cáo…';
  const operations = await Promise.allSettled([
    api(`/api/reports?${params}`, { signal: request.signal }),
    api(`/api/metrics?${params}`, { signal: request.signal }),
  ]);
  if (reportRequest !== request) return;
  const [report, metrics] = operations;
  if (report.status === 'fulfilled') {
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
    $('report-rows').replaceChildren(fragment);
    $('report-count').textContent = `${report.value.rows.length} hoạt động`;
    $('report-state').hidden = report.value.rows.length > 0;
    $('report-empty').textContent = 'Không có hoạt động đạt ngưỡng tổng chi trong kỳ.';
  } else { $('report-empty').textContent = report.reason.message; }
  if (metrics.status === 'fulfilled') {
    $('report-overspent').textContent = metrics.value.overspent;
    const cpa = metrics.value.cpa;
    $('report-cpa').textContent = cpa === null ? '—' : currency(cpa);
    $('cpa-note').textContent = !params.get('activity') ? 'Chọn một hoạt động để tính CPA.' :
      cpa === null ? 'Thiếu dữ liệu ngày hoặc tổng chuyển đổi bằng 0.' : 'VND cho mỗi lượt chuyển đổi';
  } else { $('cpa-note').textContent = metrics.reason.message; }
  submit.disabled = false;
}

function showPage() {
  const active = location.hash === '#bao-cao' ? 'bao-cao' : 'khoan-chi';
  $('current-page').textContent = active === 'bao-cao' ? 'Báo cáo' : 'Khoản chi';
  banner();
  for (const link of document.querySelectorAll('nav a[data-page]')) {
    const selected = link.dataset.page === active;
    if (selected) link.setAttribute('aria-current','page');
    else link.removeAttribute('aria-current');
    $(link.dataset.page).hidden = !selected;
  }
  if (active === 'bao-cao') void loadReports();
}

filters.addEventListener('submit', event => {
  event.preventDefault(); banner(); void loadExpenses();
});
filters.addEventListener('reset', () => setTimeout(() => {
  if (!catalog) return;
  banner(); syncListActivity(); setDates(filters); void loadExpenses();
}));
$('list-campaign').addEventListener('change', () => { if (catalog) syncListActivity(); });
$('report-campaign').addEventListener('change', () => { if (catalog) syncReportActivity(); });
reportFilters.addEventListener('submit', event => {
  event.preventDefault(); banner(); void loadReports();
});
for (const button of document.querySelectorAll('[data-close]')) {
  button.addEventListener('click', () => $(button.dataset.close).close());
}
for (const dialog of [expenseDialog, deleteDialog]) {
  dialog.addEventListener('cancel', event => {
    if (dialog.querySelector('form').getAttribute('aria-busy') === 'true') event.preventDefault();
  });
}
$('open-create').addEventListener('click', () => openEditor());
editor.addEventListener('submit', saveExpense);
deleteForm.addEventListener('submit', removeExpense);
document.querySelector('.skip-link').addEventListener('click', event => {
  event.preventDefault();
  $(location.hash === '#bao-cao' ? 'report-title' : 'expense-title').focus();
});
window.addEventListener('hashchange', showPage);

try {
  catalog = await api('/api/catalog');
  $('operator').textContent = catalog.actor;
  const campaigns = () => catalog.campaigns.map(c => option(c.MaChienDich, `${c.MaChienDich} · ${c.TenChienDich}`));
  replaceOptions($('list-campaign'), campaigns(), 'Tất cả chiến dịch');
  replaceOptions($('report-campaign'), campaigns());
  syncListActivity();
  syncReportActivity();
  setDates(filters);
  setDates(reportFilters);
  $('open-create').disabled = !catalog.activities.some(canWrite);
  showPage();
  await loadExpenses();
} catch (error) {
  $('expense-empty').textContent = 'Chưa tải được dữ liệu MySQL.';
  banner(error.message, true);
}
