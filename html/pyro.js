// mzb_arena - the desk's Pyro section: a button per cue the show that is up can fire, in their groups (client/pyro.lua
// sends them when the desk opens and when the show changes), and what the next cue goes off with: its size and, for
// the effects that take one, its colour. A press goes to the server, which checks who pressed and fires the cue for
// everyone in the arena.
(() => {
  const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'mzb_arena';
  const nui = (name, body) =>
    fetch(`https://${res}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body || {}) }).catch(() => {});
  const sec = document.querySelector('#pyro'), box = document.querySelector('#pyro-cues');
  if (!sec || !box) return;
  const sizes = Array.from(document.querySelectorAll('#pyro-size button')), swatches = document.querySelector('#pyro-colour');
  let size = 'normal', colour = null;                      // colour: null = the effect's own, 'lights', or a name

  sizes.forEach((b) => (b.onclick = () => { size = b.dataset.size; sizes.forEach((x) => x.classList.toggle('active', x === b)); }));

  function colours(list) {
    if (!swatches) return;
    swatches.textContent = '';
    const add = (value, title, css, text) => {
      const b = document.createElement('button');
      b.title = title; b.textContent = text || '';
      if (css) b.style.background = css;
      b.classList.toggle('active', colour === value);
      b.onclick = () => { colour = value; Array.from(swatches.children).forEach((x) => x.classList.toggle('active', x === b)); };
      swatches.appendChild(b);
    };
    add(null, 'The effect\'s own colour', '', 'own');
    add('lights', 'The show lights\' first colour', 'linear-gradient(135deg, #e0203a, #2058e0)', '');
    for (const c of list) add(c.name, c.name, `rgb(${c.rgb.join(',')})`, '');
  }

  function render(cues) {
    box.textContent = '';
    sec.classList.toggle('hidden', !cues.length);          // a show without pyro has no section
    let group = null, row = null;
    for (const c of cues) {
      if (!row || c.group !== group) {                      // a new group: its name, then its buttons
        group = c.group;
        if (group) { const h = document.createElement('h3'); h.textContent = group; box.appendChild(h); }
        row = document.createElement('div'); row.className = 'seg';
        box.appendChild(row);
      }
      const b = document.createElement('button');
      b.textContent = c.label || c.name;
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
  });
})();
