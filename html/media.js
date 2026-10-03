// mzb_arena - the desk's Screens section: what the video screens show (client/media.lua, server/media.lua).
// Every touch goes to the server; its state comes back as 'media' messages.
(() => {
  const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'mzb_arena';
  const $ = (s) => document.querySelector(s);
  let media = { kind: 'off' };
  const post = (body) =>
    fetch(`https://${res}/media`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body) }).catch(() => {});

  function render() {
    const m = media || { kind: 'off' };
    const now = m.kind === 'youtube' ? `YouTube ${m.id}` : m.kind === 'images' ? `${(m.urls || []).length} pictures`
      : m.kind === 'image' ? 'one picture' : 'off';
    $('#scr-now').textContent = now + (m.paused ? ' (paused)' : '');
    $('#scr-pause').textContent = m.paused ? 'Resume' : 'Pause';
    $('#scr-pause').disabled = m.kind === 'off';
    if (document.activeElement !== $('#scr-vol')) { $('#scr-vol').value = m.volume || 0; $('#scr-vol-val').textContent = m.volume || 0; }
  }

  const play = () => { const u = $('#scr-url').value.trim(); if (u) post({ action: 'play', url: u }); };
  $('#scr-play').onclick = play;
  $('#scr-url').addEventListener('keyup', (e) => { if (e.key === 'Enter') play(); });
  $('#scr-pause').onclick = () => post({ action: media.paused ? 'resume' : 'pause' });
  $('#scr-stop').onclick = () => post({ action: 'stop' });
  // the volume: at most one change every 200 ms, the last one always sent
  let volTimer = null;
  $('#scr-vol').oninput = (e) => {
    $('#scr-vol-val').textContent = e.target.value;
    if (!volTimer) volTimer = setTimeout(() => { volTimer = null; post({ action: 'volume', value: +$('#scr-vol').value }); }, 200);
  };

  window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.type !== 'media') return;
    if (m.media) media = m.media;
    if (m.enabled !== undefined) $('#screens').classList.toggle('hidden', !m.enabled);
    if (m.sets) {
      const box = $('#scr-sets');
      box.innerHTML = '';
      m.sets.forEach((name) => {
        const b = document.createElement('button');
        b.textContent = name;
        b.title = 'Picture set ' + name;
        b.onclick = () => post({ action: 'set', set: name });
        box.appendChild(b);
      });
    }
    render();
  });
})();
