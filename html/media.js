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
    const off = m.kind === 'off';
    const now = m.kind === 'youtube' ? `YouTube ${m.id}` : m.kind === 'images' ? `${(m.urls || []).length} pictures`
      : m.kind === 'image' ? 'one picture' : m.kind === 'look' ? `the ${m.look} look`
      : m.kind === 'feed' ? `camera: ${m.camName || '?'}` : m.black ? 'off (dark)' : 'own graphics';
    Array.from(document.querySelectorAll('#scr-looks button')).forEach((b) =>
      b.classList.toggle('active', m.kind === 'look' && b.dataset.look === m.look));
    const video = m.kind === 'youtube';                                // Loop is a video's: the rest has no end
    const text = now + (video && m.loop ? ', looped' : '') + (m.fade ? ' (fading out)' : m.paused ? ' (paused)' : '');
    $('#scr-now').textContent = text; $('#q-scr-now').textContent = text;
    $('#scr-pause').textContent = m.paused ? 'Resume' : 'Pause';
    $('#scr-pause').disabled = off;
    $('#scr-loop').disabled = !video;
    $('#scr-loop').classList.toggle('active', video && !!m.loop);
    $('#scr-fade').disabled = $('#q-scr-fade').disabled = off || !!m.fade;
    $('#scr-stop').classList.toggle('active', off && !!m.black);       // dark
    $('#scr-own').classList.toggle('active', off && !m.black);         // the show's own graphics
    $('#scr-cam').classList.toggle('active', m.kind === 'feed');       // a camera feed
    $('#q-scr-off').disabled = off && !!m.black;
    if (document.activeElement !== $('#scr-vol')) { $('#scr-vol').value = m.volume || 0; $('#scr-vol-val').textContent = m.volume || 0; }
  }

  const play = () => { const u = $('#scr-url').value.trim(); if (u) post({ action: 'play', url: u }); };
  $('#scr-play').onclick = play;
  $('#scr-url').addEventListener('keyup', (e) => { if (e.key === 'Enter') play(); });
  $('#scr-pause').onclick = () => post({ action: media.paused ? 'resume' : 'pause' });
  $('#scr-loop').onclick = () => post({ action: 'loop', on: !media.loop });
  $('#scr-stop').onclick = $('#q-scr-off').onclick = () => post({ action: 'stop' });
  $('#scr-fade').onclick = $('#q-scr-fade').onclick = () => post({ action: 'fade' });
  $('#scr-own').onclick = () => post({ action: 'own' });
  $('#scr-cam').onclick = () => post({ action: 'feed' });               // this player's own view, live
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
    if (m.enabled !== undefined) { $('#screens').classList.toggle('hidden', !m.enabled); $('#q-scr').classList.toggle('hidden', !m.enabled); }
    if (m.feed !== undefined) $('#scr-cam').classList.toggle('hidden', !m.feed);
    if (m.looks) {
      const box = $('#scr-looks');
      box.innerHTML = '';
      m.looks.forEach((name) => {
        const b = document.createElement('button');
        b.dataset.look = name;
        b.textContent = name.charAt(0).toUpperCase() + name.slice(1);
        b.title = 'A look drawn in step with the lights: ' + name;
        b.onclick = () => post({ action: 'look', look: name });
        box.appendChild(b);
      });
    }
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
