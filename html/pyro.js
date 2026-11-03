// mzb_arena - the desk's Pyro section: a button per cue the show that is up can fire, in their groups (client/pyro.lua
// sends them when the desk opens and when the show changes), and what the next cue goes off with: its size and, for
// the effects that take one, its colour. A press goes to the server, which checks who pressed and fires the cue for
// everyone in the arena. (1.5.0) The ARM key, as a pyro controller has: on SAFE no cue fires (GlobalState.mzbPyroSafe,
// /arenapyro arm | safe) - the cues are greyed and the lamp is green; ARMED, the lamp blinks red.
(() => {
  const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'mzb_arena';
  const nui = (name, body) =>
    fetch(`https://${res}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body || {}) }).catch(() => {});
  const $ = (s) => document.querySelector(s);
  const sec = $('#pyro'), box = $('#pyro-cues');
  if (!sec || !box) return;
  const sizes = Array.from(document.querySelectorAll('#pyro-size button')), swatches = $('#pyro-colour');
  const armBox = $('#pyro-armbox'), armKey = $('#pyro-arm');
  let size = 'normal', colour = null;                      // colour: null = the effect's own, 'lights', or a name
  let safe = false;

  sizes.forEach((b) => (b.onclick = () => { size = b.dataset.size; sizes.forEach((x) => x.classList.toggle('active', x === b)); }));

  function arm() {
    sec.classList.toggle('safe', safe);
    if (armBox) {
      armBox.classList.toggle('armed', !safe);
      armBox.classList.toggle('safe', safe);
      $('#pyro-arm-state').textContent = safe ? 'SAFE' : 'ARMED';
      $('#pyro-arm-hint').textContent = safe ? 'nothing fires: turn the key to arm' : 'the cues below fire, for everyone in the arena';
    }
    Array.from(box.querySelectorAll('button')).forEach((b) => (b.disabled = safe));
  }
  if (armKey) armKey.onclick = () => nui('pyroArm', { armed: safe });

  function colours(list) {
    if (!swatches) return;
    swatches.textContent = '';
    const add = (value, title, css, text) => {
      const b = document.createElement('button');
      b.title = title; b.textContent = text || '';
      if (css) b.style.setProperty('--pc', css);           // (1.5.0) a pad: the colour in its lens
      b.classList.toggle('active', colour === value);
      b.onclick = () => { colour = value; Array.from(swatches.children).forEach((x) => x.classList.toggle('active', x === b)); };
      swatches.appendChild(b);
    };
    add(null, 'OWN - the effect\'s own colour', '', 'OWN');
    add('lights', 'LIGHTS - the show lights\' first colour', 'linear-gradient(135deg, #e0203a, #2058e0)', '');
    for (const c of list) add(c.name, `${c.name.toUpperCase()} - the next cue in this colour`, `rgb(${c.rgb.join(',')})`, '');
  }

  function render(cues) {
    box.textContent = '';
    sec.classList.toggle('hidden', !cues.length);          // a show without pyro has no section
    let group = null, row = null;
    for (const c of cues) {
      if (!row || c.group !== group) {                      // a new group: its name, then its buttons
        group = c.group;
        if (group) { const h = document.createElement('h3'); h.textContent = group; box.appendChild(h); }
        row = document.createElement('div'); row.className = 'keys';
        box.appendChild(row);
      }
      const b = document.createElement('button');
      b.textContent = c.label || c.name;
      b.title = `${(c.label || c.name).toUpperCase()} - fire it, for everyone in the arena`;
      b.onclick = () => {
        nui('pyro', { cue: c.name, size, colour });
        b.classList.add('active');
        setTimeout(() => b.classList.remove('active'), 400);
      };
      row.appendChild(b);
    }
  }

  window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.type !== 'pyroDesk') return;
    const list = Array.isArray(m.cues) ? m.cues : Object.values(m.cues || {});
    render(list.filter((c) => c && typeof c.name === 'string'));
    if (m.colours) colours(Array.isArray(m.colours) ? m.colours : Object.values(m.colours));
    if (typeof m.safe === 'boolean') safe = m.safe;
    arm();
  });
})();
