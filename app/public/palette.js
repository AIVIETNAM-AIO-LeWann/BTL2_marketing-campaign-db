// Bảng lệnh nhanh (Ctrl/⌘ + K): nhảy trang, đổi chiến dịch, tìm khoản chi, đổi giao diện.
const fold = text => text.normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/đ/g, 'd').toLowerCase();

export function setupPalette(getCommands, searchCommand) {
  const dialog = document.createElement('dialog');
  dialog.id = 'palette';
  dialog.setAttribute('aria-label', 'Bảng lệnh nhanh');
  dialog.innerHTML = `<div class="palette-search"><svg aria-hidden="true"><use href="/icons.svg#search"/></svg>
    <input type="text" role="combobox" aria-expanded="true" aria-controls="palette-list" aria-autocomplete="list" autocomplete="off" spellcheck="false" placeholder="Tìm trang, chiến dịch hoặc lệnh…" aria-label="Tìm lệnh"></div>
    <ul id="palette-list" role="listbox" aria-label="Kết quả"></ul>
    <p class="palette-hint"><kbd>↑</kbd><kbd>↓</kbd> di chuyển · <kbd>Enter</kbd> chọn · <kbd>Esc</kbd> đóng</p>`;
  document.body.append(dialog);
  const input = dialog.querySelector('input');
  const list = dialog.querySelector('ul');
  let items = [];
  let active = 0;

  function render() {
    const query = fold(input.value.trim());
    items = getCommands().filter(c => !query || fold(`${c.label} ${c.hint ?? ''}`).includes(query));
    if (input.value.trim()) items.push(searchCommand(input.value.trim()));
    active = Math.min(active, items.length - 1);
    list.replaceChildren(...items.map((c, index) => {
      const li = document.createElement('li');
      li.id = `palette-option-${index}`;
      li.setAttribute('role', 'option');
      li.setAttribute('aria-selected', String(index === active));
      const label = document.createElement('span'); label.textContent = c.label;
      const hint = document.createElement('small'); hint.textContent = c.hint ?? '';
      li.append(label, hint);
      li.addEventListener('click', () => run(c));
      return li;
    }));
    input.setAttribute('aria-activedescendant', `palette-option-${active}`);
  }
  function move(step) {
    active = (active + step + items.length) % items.length;
    for (const [index, li] of [...list.children].entries()) li.setAttribute('aria-selected', String(index === active));
    input.setAttribute('aria-activedescendant', `palette-option-${active}`);
    list.children[active]?.scrollIntoView({ block: 'nearest' });
  }
  function run(command) { dialog.close(); command.run(); }
  function open() { if (dialog.open) return; input.value = ''; active = 0; render(); dialog.showModal(); input.focus(); }

  input.addEventListener('input', () => { active = 0; render(); });
  input.addEventListener('keydown', event => {
    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') { event.preventDefault(); move(event.key === 'ArrowDown' ? 1 : -1); }
    else if (event.key === 'Enter' && items[active]) { event.preventDefault(); run(items[active]); }
  });
  dialog.addEventListener('click', event => { if (event.target === dialog) dialog.close(); });
  document.addEventListener('keydown', event => {
    if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'k') { event.preventDefault(); open(); }
  });
  return open;
}
