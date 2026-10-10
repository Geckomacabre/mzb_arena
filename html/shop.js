// mzb_arena - the merch stand's try-on (client/shop.lua): what is on the screen while a tee is on trial. 'shop'
// messages bring all of it - { open, style, tee, tees: [{ label, colour, owned } x 8], price, cash, status, index,
// count } - and { toast } a line on the right for a moment ("Purchased", or why not). Display only: the game reads
// the keys (the arrows, Enter, Backspace), this page takes no input and asks for no focus.
(() => {
  const $ = (s) => document.querySelector(s);
  const money = (n) => `$${Math.round(n).toLocaleString('en-US')}`;
  const ACTION = { 'Not owned': 'BUY & WEAR', Owned: 'WEAR', Wearing: 'REMOVE' };
  let cash = null;
  let toastTimer = null;

  // the stand's eight tees are one 4 x 2 sheet (img/tees/<style>.jpg): tee n is column (n - 1) % 4, row (n - 1) / 4
  function swatches(m) {
    const box = $('#shop-swatches');
    const key = `${m.style}:${m.tees.length}`;
    if (box.dataset.key !== key) {
      box.dataset.key = key;
      box.innerHTML = '';
      m.tees.forEach((t, i) => {
        const sw = document.createElement('i');
        sw.style.backgroundImage = `url(img/tees/${encodeURIComponent(m.style)}.jpg)`;
        sw.style.backgroundPosition = `${((i % 4) * 100) / 3}% ${Math.floor(i / 4) * 100}%`;
        box.appendChild(sw);
      });
    }
    Array.from(box.children).forEach((sw, i) => {
      sw.classList.toggle('on', i + 1 === m.tee);
      sw.classList.toggle('owned', !!(m.tees[i] && m.tees[i].owned));
    });
  }

  function show(m) {
    const t = m.tees[m.tee - 1] || {};
    $('#shop-price').textContent = m.price > 0 ? money(m.price) : 'FREE';
    $('#shop-name').textContent = t.label || '';
    $('#shop-colour').textContent = t.colour || '';
    const status = $('#shop-status');
    status.textContent = m.status || '';
    status.className = (m.status || '').toLowerCase().replace(/\s+/g, '-');
    $('#shop-show').textContent = `SHOW SHIRT (${m.index || m.tee}/${m.count || m.tees.length})`;
    $('#shop-action').textContent = ACTION[m.status] || ACTION['Not owned'];
    // the cash: there when the server has a framework to ask; it drops with a flash when something was bought
    const box = $('#shop-cash');
    const now = typeof m.cash === 'number' ? m.cash : null;
    box.textContent = now === null ? '' : money(now);
    if (now !== null && cash !== null && now < cash) {
      box.classList.remove('spent');
      void box.offsetWidth;                                // (so the flash starts again)
      box.classList.add('spent');
    }
    cash = now;
    swatches(m);
    $('#shop').classList.remove('hidden');
  }

  function toast(text, failed) {
    const box = $('#shop-toast');
    $('#shop-toast-text').textContent = text;
    $('#shop-toast-tick').classList.toggle('hidden', !!failed);
    box.classList.toggle('failed', !!failed);
    box.classList.remove('hidden');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => box.classList.add('hidden'), failed ? 4000 : 2500);
  }

  window.addEventListener('message', (e) => {
    const m = e.data && e.data.shop;
    if (!m) return;
    if (m.toast) return toast(String(m.toast), m.failed);
    if (m.open && Array.isArray(m.tees)) return show(m);
    cash = null;
    clearTimeout(toastTimer);
    $('#shop-toast').classList.add('hidden');
    $('#shop').classList.add('hidden');
  });
})();
