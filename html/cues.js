// mzb_arena - the desk's Cues tab (1.5.0): the show's cue list (client/cues.lua, server/cues.lua) - the set list of a
// concert or a DJ set, the entrances of a fight night, the cues of a game. Each cue fires its link (on the screens
// with its sound from the speakers, or the music alone), its light look and its pyro. GO (numpad + or Enter) fires
// the next, Back (numpad -) the one before; a cue's own button fires it; Auto next goes on when a track ends. Every
// edit is the whole list to the server, which keeps it for the show's kind.
(() => {
  const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'mzb_arena';
  const $ = (s) => document.querySelector(s);
  const post = (body) =>
    fetch(`https://${res}/cues`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body) }).catch(() => {});
  let kind = null, list = [], state = {}, words = {}, presets = [], pyro = [], editing = -1;

  const esc = (s) => String(s == null ? '' : s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const short = (link) => {
    if (!link) return '';
    const m = link.match(/(?:v=|youtu\.be\/|shorts\/)([\w-]{6,})/);
    return m ? 'YouTube ' + m[1] : link.replace(/^https?:\/\//, '').slice(0, 32);
  };
  const label = (arr, id) => (arr.find((x) => x.id === id) || {}).label || id;
  const save = () => post({ action: 'save', list });

  function options(sel, arr, none) {
    sel.innerHTML = '';
    const o = document.createElement('option');
    o.value = ''; o.textContent = none; sel.appendChild(o);
    arr.forEach((x) => { const e = document.createElement('option'); e.value = x.id; e.textContent = x.label; sel.appendChild(e); });
  }

  function clearForm() {
    editing = -1;
    $('#cue-name').value = ''; $('#cue-link').value = '';
    $('#cue-preset').value = words.preset || ''; $('#cue-pyro').value = ''; $('#cue-screens').checked = true;
  }

  function render() {
    $('#cues-title').textContent = words.title || 'Cues';
    $('#cue-name').placeholder = words.item || 'Name';
    $('#cue-pyro').classList.toggle('hidden', words.pyro === false);
    const at = state && state.kind === kind ? (state.index || 0) : 0;
    $('#cues-now').textContent = at > 0 && list[at - 1] ? `${at}. ${list[at - 1].name}`
      : list.length ? 'ready: GO fires the first' : 'empty: add the first below';
    const nxt = list[at];
    $('#cue-next').textContent = nxt ? `${at + 1}. ${nxt.name}` : '';
    $('#cue-go').disabled = !nxt;
    $('#cue-back').disabled = at <= 1;
    // (1.5.0) the wing's GO and BACK, under the faders on every tab
    $('#go').disabled = !nxt;
    $('#go-next').textContent = nxt ? `${at + 1}. ${nxt.name}` : list.length ? 'end of the list' : 'no cues';
    $('#go-back').disabled = at <= 1;
    $('#cue-auto').classList.toggle('on', !!(state && state.auto));
    $('#cue-auto-state').textContent = state && state.auto ? 'ON' : 'OFF';
    const ol = $('#cue-list');
    ol.innerHTML = '';
    list.forEach((c, i) => {
      const li = document.createElement('li');
      li.classList.toggle('current', i + 1 === at);
      li.classList.toggle('editing', i === editing);
      const what = [short(c.link), c.preset && label(presets, c.preset), c.pyro && label(pyro, c.pyro)].filter(Boolean).join(' · ');
      li.innerHTML = `<span class="cue-text"><b>${esc(c.name)}</b><small>${esc(what)}</small></span>`;
      const btns = document.createElement('span');
      btns.className = 'cue-btns';
      const mk = (txt, title, fn) => {
        const b = document.createElement('button');
        b.className = 'mini'; b.textContent = txt; b.title = title; b.onclick = fn; btns.appendChild(b);
      };
      mk('▶', 'Fire this cue', () => post({ action: 'go', how: i + 1 }));
      mk('↑', 'Up', () => { if (i > 0) { [list[i - 1], list[i]] = [list[i], list[i - 1]]; save(); } });
      mk('↓', 'Down', () => { if (i < list.length - 1) { [list[i + 1], list[i]] = [list[i], list[i + 1]]; save(); } });
      mk('✎', 'Edit it in the form below', () => {
        editing = i;
        $('#cue-name').value = c.name || ''; $('#cue-link').value = c.link || '';
        $('#cue-preset').value = c.preset || ''; $('#cue-pyro').value = c.pyro || ''; $('#cue-screens').checked = c.screens !== false;
        render();
      });
      mk('✕', 'Remove', () => { list.splice(i, 1); if (editing === i) clearForm(); save(); });
      li.appendChild(btns);
      ol.appendChild(li);
    });
    $('#cue-add').textContent = editing >= 0 ? 'SAVE' : 'ADD';
  }

  $('#cue-add').onclick = () => {
    const c = { name: $('#cue-name').value.trim(), link: $('#cue-link').value.trim(), preset: $('#cue-preset').value,
                pyro: $('#cue-pyro').value, screens: $('#cue-screens').checked };
    if (!c.name && !c.link && !c.preset && !c.pyro) return;
    if (editing >= 0 && list[editing]) list[editing] = c; else list.push(c);
    clearForm();
    save();
    render();
  };
  $('#cue-go').onclick = $('#go').onclick = () => post({ action: 'go', how: 'next' });
  $('#cue-back').onclick = $('#go-back').onclick = () => post({ action: 'go', how: 'back' });
  $('#cue-auto').onclick = () => post({ action: 'auto', on: !(state && state.auto) });
  // the numpad (html/app.js): + / Enter GO, - back
  window.addEventListener('mzbCue', (e) => post({ action: 'go', how: e.detail === 'back' ? 'back' : 'next' }));

  window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.type === 'cues') {
      kind = m.kind;
      list = Array.isArray(m.list) ? m.list : [];
      words = m.words || {}; presets = m.presets || []; pyro = m.pyro || [];
      if (m.state) state = m.state;
      options($('#cue-preset'), presets, 'No light change');
      options($('#cue-pyro'), pyro, 'No pyro');
      clearForm();
      render();
    } else if (m.type === 'cuesState') {
      state = m.state || {};
      render();
    }
  });
})();
