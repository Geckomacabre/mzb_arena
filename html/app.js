// mzb_arena - the light desk (NUI). Every touch posts a patch to the client (client/lights.lua), which hands it to
// the server; the server's state comes back as 'state' messages, so the desk always shows what the arena is doing.
(() => {
  const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'mzb_arena';
  const $ = (s) => document.querySelector(s);
  const $$ = (s) => Array.from(document.querySelectorAll(s));
  const desk = $('#desk');
  let state = null;
  let activeSlot = 0;

  const post = (name, body) =>
    fetch(`https://${res}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body || {}) }).catch(() => {});

  // sliders: at most one patch every 120 ms per control, the last value always sent
  const throttled = (() => {
    const last = {}, pending = {}, timer = {};
    const send = (key) => { last[key] = Date.now(); post('lights', pending[key]); pending[key] = null; };
    return (key, patch) => {
      pending[key] = patch;
      const wait = 120 - (Date.now() - (last[key] || 0));
      if (wait <= 0) return send(key);
      if (!timer[key]) timer[key] = setTimeout(() => { timer[key] = null; if (pending[key]) send(key); }, wait);
    };
  })();

  const hex = (c) => '#' + c.map((v) => v.toString(16).padStart(2, '0')).join('');
  const rgb = (h) => [1, 3, 5].map((i) => parseInt(h.substr(i, 2), 16));

  function render() {
    if (!state) return;
    $('#power').classList.toggle('on', !!state.on);
    $('#power-state').textContent = state.on ? 'ON' : 'OFF';
    $('#live-dot').classList.toggle('live', !!state.on);
    $$('#house button').forEach((b) => b.classList.toggle('active', b.dataset.house === state.house));
    $$('#modes button').forEach((b) => b.classList.toggle('active', b.dataset.mode === state.mode));
    $$('#focus button').forEach((b) => b.classList.toggle('active', b.dataset.focus === state.focus));
    const cs = state.colors || [];
    $$('#slots .slot').forEach((b) => {
      const i = +b.dataset.slot;
      const sw = b.querySelector('span');
      if (cs[i]) { sw.style.background = hex(cs[i]); b.classList.remove('empty'); }
      else { sw.style.background = ''; b.classList.add('empty'); }
      b.classList.toggle('active', i === activeSlot);
    });
    if (cs[activeSlot]) $('#picker').value = hex(cs[activeSlot]);
    $('#bpm').value = state.bpm; $('#bpm-val').textContent = state.bpm;
    const pct = Math.round((state.intensity || 0) * 100);
    $('#intensity').value = pct; $('#int-val').textContent = pct;
  }

  function setColour(c) {
    const cs = (state.colors || []).slice(0, 3);
    const slot = Math.min(activeSlot, cs.length);           // fill the slots in order: no gaps
    cs[slot] = c;
    activeSlot = slot;
    state.colors = cs;
    render();
    throttled('colors', { colors: cs });
  }

  // ---- wiring
  $('#close').onclick = () => post('close');
  document.addEventListener('keyup', (e) => { if (e.key === 'Escape') post('close'); });
  $('#power').onclick = () => post('lights', { on: !state.on });
  $$('[data-preset]').forEach((b) => (b.onclick = () => post('preset', { id: b.dataset.preset })));
  $$('#house button').forEach((b) => (b.onclick = () => post('lights', { house: b.dataset.house })));
  $$('#modes button').forEach((b) => (b.onclick = () => post('lights', { mode: b.dataset.mode, on: true })));
  $$('#focus button').forEach((b) => (b.onclick = () => post('lights', { focus: b.dataset.focus })));
  $$('#slots .slot').forEach((b) => (b.onclick = () => { activeSlot = +b.dataset.slot; render(); }));
  $('#picker').oninput = (e) => setColour(rgb(e.target.value));
  $('#clear-slot').onclick = () => {
    const cs = (state.colors || []).slice(0, Math.max(1, (state.colors || []).length - 1));
    activeSlot = Math.min(activeSlot, cs.length - 1);
    post('lights', { colors: cs });
  };
  $('#bpm').oninput = (e) => { $('#bpm-val').textContent = e.target.value; throttled('bpm', { bpm: +e.target.value }); };
  $('#intensity').oninput = (e) => {
    $('#int-val').textContent = e.target.value;
    throttled('intensity', { intensity: e.target.value / 100 });
  };
  // tap tempo: the average of the last taps (reset after 2 s without one)
  let taps = [];
  $('#tap').onclick = () => {
    const now = performance.now();
    if (taps.length && now - taps[taps.length - 1] > 2000) taps = [];
    taps.push(now);
    if (taps.length > 5) taps.shift();
    if (taps.length >= 2) {
      const bpm = Math.round(60000 / ((taps[taps.length - 1] - taps[0]) / (taps.length - 1)));
      if (bpm >= 30 && bpm <= 240) { $('#bpm').value = bpm; $('#bpm-val').textContent = bpm; post('lights', { bpm }); }
    }
  };

  window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.type === 'open') {
      state = m.state;
      $('#show-name').textContent = m.show || '';
      const pal = $('#palette');
      pal.innerHTML = '';
      (m.colours || []).forEach((c) => {
        const b = document.createElement('button');
        b.style.background = hex(c.rgb);
        b.title = c.name;
        b.onclick = () => setColour(c.rgb);
        pal.appendChild(b);
      });
      const pr = $('#presets');
      pr.innerHTML = '';
      (m.presets || []).forEach((p) => {
        const b = document.createElement('button');
        b.textContent = p.label;
        b.onclick = () => post('preset', { id: p.id });
        pr.appendChild(b);
      });
      $('[data-mode="strobe"]').title = m.maxStrobe === 0 ? 'Strobe is off on this server (pulses instead)' : '';
      desk.classList.remove('hidden');
      render();
    } else if (m.type === 'state') {
      state = m.state;
      render();
    } else if (m.type === 'close') {
      desk.classList.add('hidden');
    }
  });
})();
