// Thông báo kiểm tra của trình duyệt theo ngôn ngữ trình duyệt; đặt lại bằng tiếng Việt cho mọi ô của trang.
const verb = (field) => (field.tagName === 'SELECT' || ['date', 'checkbox', 'radio'].includes(field.type) ? 'chọn' : 'nhập');
// Nhãn thật của ô (kể cả nhãn bọc ngoài ô); chỉ lấy chữ của chính nhãn, không lấy chữ của các mục chọn bên trong.
const labelOf = (field) => {
  const label = field.labels?.[0];
  const own = label && [...label.childNodes].find(node => node.nodeType === Node.TEXT_NODE && node.textContent.trim());
  const text = (own?.textContent ?? label?.textContent ?? '').trim();
  return text.charAt(0).toLowerCase() + text.slice(1);
};

document.addEventListener('invalid', event => {
  const field = event.target;
  const state = field.validity;
  let message = '';
  if (state.valueMissing) message = `Vui lòng ${verb(field)} ${labelOf(field) || 'giá trị này'}.`;
  else if (state.patternMismatch) message = field.name === 'id'
    ? 'Mã khoản chi chỉ gồm chữ cái Latin, chữ số, dấu gạch ngang hoặc gạch dưới.'
    : 'Chỉ nhập chữ số, không dùng dấu phân cách.';
  else if (state.badInput) message = 'Giá trị chưa hợp lệ. Vui lòng kiểm tra lại.';
  field.setCustomValidity(message);
}, true);

// Xóa thông báo cũ khi người dùng sửa, nếu không ô sẽ bị coi là sai mãi.
for (const type of ['input', 'change']) {
  document.addEventListener(type, event => event.target.setCustomValidity?.(''), true);
}
