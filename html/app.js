// mzb_arena - the light desk (NUI). Every touch posts a patch to the client (client/lights.lua), which hands it to
// the server; the server's state comes back as 'state' messages, so the desk always shows what the arena is doing.
(() => {
  const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'mzb_arena';
  const $ = (s) => document.querySelector(s);
  const $$ = (s) => Array.from(document.querySelectorAll(s));
  const desk = $('#desk');
  let state = null;
  let activeSlot = 0;
  // the old sweep / ballyhoo modes were a movement with a static colour: show them as such
  const MOVING = { sweep: 1, ballyhoo: 1 };
  const effMode = () => (MOVING[state.mode] ? 'static' : state.mode);
  const effMove = () => (state.move && state.move !== 'none' ? state.move : MOVING[state.mode] ? state.mode : 'none');
  const focusList = () => (Array.isArray(state.focus) ? state.focus : [state.focus || 'floor']);

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
    $('#ring').classList.toggle('on', !!state.ring);
    $('#ring-state').textContent = state.ring ? 'ON' : 'OFF';
    if (document.activeElement !== $('#ring-color') && state.ringColor) $('#ring-color').value = hex(state.ringColor);
    $('#ring-own').classList.toggle('active', !state.ringColor);
    const rl = Math.round((state.ringLevel == null ? 1 : state.ringLevel) * 100);
    if (document.activeElement !== $('#ring-level')) { $('#ring-level').value = rl; $('#ring-level-val').textContent = rl; }
    $$('#modes button').forEach((b) => b.classList.toggle('active', b.dataset.mode === effMode()));
    $$('#moves button').forEach((b) => b.classList.toggle('active', b.dataset.move === effMove()));
    const fl = focusList();
    $$('#focus button').forEach((b) => b.classList.toggle('active', fl.includes(b.dataset.focus)));
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
    $$('#follow button').forEach((b) => b.classList.toggle('active', b.dataset.follow === (state.follow || 'off')));
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
  $('#ring').onclick = () => post('lights', { ring: !state.ring });
  $('#ring-color').oninput = (e) => throttled('ringColor', { ring: true, ringColor: rgb(e.target.value) });
  $('#ring-own').onclick = () => post('lights', { ringColor: false });
  $('#ring-level').oninput = (e) => {
    $('#ring-level-val').textContent = e.target.value;
    throttled('ringLevel', { ringLevel: e.target.value / 100 });
  };
  // an effect keeps the movement that is running (an old sweep / ballyhoo mode becomes that movement)
  $$('#modes button').forEach((b) => (b.onclick = () => post('lights', { mode: b.dataset.mode, move: effMove(), on: true })));
  $$('#moves button').forEach((b) => (b.onclick = () => post('lights', { mode: effMode(), move: b.dataset.move, on: true })));
  // the aims toggle; one always stays
  $$('#focus button').forEach((b) => (b.onclick = () => {
    const fl = focusList().slice();
    const k = fl.indexOf(b.dataset.focus);
    if (k >= 0) { if (fl.length > 1) fl.splice(k, 1); } else fl.push(b.dataset.focus);
    post('lights', { focus: fl });
  }));
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
  // follow the music: the tempo and / or the colours of what is playing (html/follow.js finds them); the show lights
  // come on with it
  $$('#follow button').forEach((b) => (b.onclick = () =>
    post('lights', b.dataset.follow === 'off' ? { follow: 'off' } : { follow: b.dataset.follow, on: true })));
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
      $('[data-focus="stage"]').disabled = m.hasStage === false;
      $('[data-focus="stage"]').title = m.hasStage === false ? 'This show has no stage' : '';
      $('#follow-sec').classList.toggle('hidden', m.follow === false);
      $('#ring').disabled = m.hasRing === false;
      $('#ring').title = m.hasRing === false ? 'This show has no ring / cage / stage lights'
        : 'The ring / cage / stage lights: on, off, a colour, a level (below)';
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
