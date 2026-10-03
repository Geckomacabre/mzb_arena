// mzb_arena - the desk's Crowd section (client/crowd.lua). The crowd button and the mood buttons post a patch for
// the server, whose state comes back as 'crowd' messages; the slider is this player's own count (how many crowd peds
// they see), kept on their PC and never sent to the server.
(() => {
  const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'mzb_arena';
  const $ = (s) => document.querySelector(s);
  let state = { on: false, mood: 'show', staff: true, litter: 'clean' };

  const post = (name, body) =>
    fetch(`https://${res}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body || {}) }).catch(() => {});

  function render() {
    $('#crowd').classList.toggle('on', !!state.on);
    $('#crowd-state').textContent = state.on ? 'IN' : 'OUT';
    $('#crowd-staff').classList.toggle('on', state.staff !== false);
    $('#crowd-staff-state').textContent = state.staff !== false ? 'ON' : 'OFF';
    Array.from(document.querySelectorAll('#crowd-litter button')).forEach((b) =>
      b.classList.toggle('active', b.dataset.litter === (state.litter || 'clean')));
    Array.from(document.querySelectorAll('#crowd-moods button')).forEach((b) =>
      b.classList.toggle('active', b.dataset.mood === state.mood));
  }

  function moods(names) {
    const box = $('#crowd-moods');
    if (box.dataset.names === names.join(',')) return;
    box.dataset.names = names.join(',');
    box.innerHTML = '';
    names.forEach((name) => {
      const b = document.createElement('button');
      b.dataset.mood = name;
      b.textContent = name.charAt(0).toUpperCase() + name.slice(1);
      b.onclick = () => post('crowd', { mood: name });
      box.appendChild(b);
    });
  }

  $('#crowd').onclick = () => post('crowd', { on: !state.on });
  $('#crowd-staff').onclick = () => post('crowd', { staff: state.staff === false });
  Array.from(document.querySelectorAll('#crowd-litter button')).forEach((b) => {
    b.onclick = () => post('crowd', { litter: b.dataset.litter });
  });

  // your own count: shown as you drag, sent when you let go (the crowd is picked again on every change)
  $('#crowd-mine').oninput = (e) => { $('#crowd-mine-val').textContent = e.target.value; };
  $('#crowd-mine').onchange = (e) => post('crowdMine', { n: +e.target.value });

  window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.type !== 'crowd') return;
    state = m.state || state;
    if (Array.isArray(m.moods)) moods(m.moods);
    if (typeof m.staff === 'boolean') $('#crowd-staff').classList.toggle('hidden', !m.staff);
    if (typeof m.litter === 'boolean') $('#crowd-litter').classList.toggle('hidden', !m.litter);
    if (typeof m.limit === 'number') $('#crowd-mine').max = m.limit;
    if (typeof m.mine === 'number') {
      $('#crowd-mine').value = m.mine;
      $('#crowd-mine-val').textContent = m.mine;
    }
    render();
  });
})();
