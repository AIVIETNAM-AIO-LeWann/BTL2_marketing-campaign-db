// Bảng lệnh nhanh (Ctrl/⌘ + K) với thanh chọn trượt mượt, biểu tượng theo nhóm và hiệu ứng kính mờ.
const fold = text => text.normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/đ/g, 'd').toLowerCase();

function makeIcon(name) {
  const ns = 'http://www.w3.org/2000/svg';
  const svg = document.createElementNS(ns, 'svg');
  svg.setAttribute('aria-hidden', 'true');
  const use = document.createElementNS(ns, 'use');
  use.setAttribute('href', `/icons.svg#${name}`);
  svg.append(use);
  return svg;
}

export function setupPalette(getCommands, searchCommand) {
  const dialog = document.createElement('dialog');
  dialog.id = 'palette';
  dialog.dataset.spotlight = '';
  dialog.setAttribute('aria-label', 'Bảng lệnh nhanh');
  dialog.innerHTML = `<div class="palette-search"><svg aria-hidden="true"><use href="/icons.svg#search"/></svg>
    <input type="text" role="combobox" aria-expanded="true" aria-controls="palette-list" aria-autocomplete="list" autocomplete="off" spellcheck="false" placeholder="Tìm trang, chiến dịch hoặc lệnh…" aria-label="Tìm lệnh">
    <kbd class="palette-esc">Esc</kbd></div>
    <div class="palette-list-wrap"><span class="palette-active-pill" aria-hidden="true"></span><ul id="palette-list" role="listbox" aria-label="Kết quả"></ul></div>
    <p class="palette-hint"><span><kbd>↑</kbd><kbd>↓</kbd> di chuyển</span><span><kbd>Enter</kbd> thực thi</span><span><kbd>Esc</kbd> đóng</span></p>`;
  document.body.append(dialog);
  const input = dialog.querySelector('input');
  const list = dialog.querySelector('ul');
  const pill = dialog.querySelector('.palette-active-pill');
  let items = [];
  let active = 0;

  function syncPill(instant = false) {
    const target = list.children[active];
    if (!target) {
      pill.dataset.visible = 'false';
      return;
    }
    pill.dataset.visible = 'true';
    if (instant) pill.dataset.instant = 'true';
    else delete pill.dataset.instant;
    pill.style.setProperty('--py', `${target.offsetTop - list.scrollTop}px`);
    pill.style.setProperty('--ph', `${target.offsetHeight}px`);
  }

  function render() {
    const query = fold(input.value.trim());
    items = getCommands().filter(c => !query || fold(`${c.label} ${c.hint ?? ''}`).includes(query));
    if (input.value.trim()) items.push(searchCommand(input.value.trim()));
    active = Math.max(0, Math.min(active, items.length - 1));
    list.replaceChildren(...items.map((c, index) => {
      const li = document.createElement('li');
      li.id = `palette-option-${index}`;
      li.setAttribute('role', 'option');
      li.setAttribute('aria-selected', String(index === active));
      li.style.setProperty('--stagger-i', String(Math.min(index, 10)));
      const left = document.createElement('span');
      left.className = 'palette-item-main';
      if (c.icon) {
        const ic = document.createElement('span');
        ic.className = 'palette-item-icon';
        ic.append(makeIcon(c.icon));
        left.append(ic);
      }
      const label = document.createElement('span');
      label.textContent = c.label;
      left.append(label);
      const hint = document.createElement('small');
      hint.textContent = c.hint ?? '';
      li.append(left, hint);
      li.addEventListener('pointerenter', () => {
        if (active !== index) setActive(index, false);
      });
      li.addEventListener('click', () => run(c));
      return li;
    }));
    if (items.length) input.setAttribute('aria-activedescendant', `palette-option-${active}`);
    else input.removeAttribute('aria-activedescendant');
    requestAnimationFrame(() => syncPill(true));
  }

  function setActive(nextIndex, scroll = true) {
    if (!items.length) return;
    active = (nextIndex + items.length) % items.length;
    for (const [index, li] of [...list.children].entries()) {
      li.setAttribute('aria-selected', String(index === active));
    }
    input.setAttribute('aria-activedescendant', `palette-option-${active}`);
    if (scroll) list.children[active]?.scrollIntoView({ block: 'nearest' });
    requestAnimationFrame(() => syncPill(false));
  }

  function run(command) {
    dialog.close();
    command.run();
  }

  function open() {
    if (dialog.open) return;
    input.value = '';
    active = 0;
    render();
    dialog.showModal();
    input.focus();
    requestAnimationFrame(() => syncPill(true));
  }

  list.addEventListener('scroll', () => syncPill(true), { passive: true });
  input.addEventListener('input', () => { active = 0; render(); });
  input.addEventListener('keydown', event => {
    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      event.preventDefault();
      setActive(active + (event.key === 'ArrowDown' ? 1 : -1));
    } else if (event.key === 'Enter' && items[active]) {
      event.preventDefault();
      run(items[active]);
    }
  });
  dialog.addEventListener('click', event => { if (event.target === dialog) dialog.close(); });
  document.addEventListener('keydown', event => {
    if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'k') {
      event.preventDefault();
      open();
    }
  });
  return open;
}
