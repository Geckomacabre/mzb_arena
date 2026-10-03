// mzb_arena - the desk's Followspot section (client/spot.lua, server/spot.lua). The state comes back as 'spotDesk'.
(() => {
  const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'mzb_arena';
  const $ = (s) => document.querySelector(s);
  let spot = null;
  const nui = (name, body) =>
    fetch(`https://${res}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body || {}) });
  const send = (patch) => nui('spot', { patch }).catch(() => {});
  const hex = (c) => '#' + c.map((v) => v.toString(16).padStart(2, '0')).join('');
  const rgb = (h) => [1, 3, 5].map((i) => parseInt(h.substr(i, 2), 16));
  let players = [];

  function render() {
    if (!spot) return;
    $('#spot-power').classList.toggle('on', !!spot.on);
    $('#spot-state').textContent = spot.on ? 'ON' : 'OFF';
    const who = players.find((p) => p.id === spot.target);
    $('#spot-now').textContent = !spot.on ? 'off'
      : spot.aim === 'player' ? 'following ' + (who ? who.name : '#' + spot.target) : 'aimed by hand';
    if (document.activeElement !== $('#spot-size')) { $('#spot-size').value = spot.size; $('#spot-size-val').textContent = spot.size; }
    const pct = Math.round((spot.intensity || 0) * 100);
    if (document.activeElement !== $('#spot-int')) { $('#spot-int').value = pct; $('#spot-int-val').textContent = pct; }
    if (spot.color && document.activeElement !== $('#spot-color')) $('#spot-color').value = hex(spot.color);
    const sel = $('#spot-target');
    if (document.activeElement !== sel) sel.value = spot.aim === 'player' ? String(spot.target) : '';
  }

  // the players in the arena, while the desk is open
  function refreshPlayers() {
    if ($('#desk').classList.contains('hidden')) return;
    nui('spotPlayers', {}).then((r) => r.json()).then((list) => {
      players = Array.isArray(list) ? list : [];
      const sel = $('#spot-target');
      if (document.activeElement === sel) return;
      sel.innerHTML = '<option value="">Follow a player...</option>';
      players.forEach((p) => {
        const o = document.createElement('option');
        o.value = String(p.id);
        o.textContent = `${p.name} (${p.id})`;
        sel.appendChild(o);
      });
      render();
    }).catch(() => {});
  }
  setInterval(refreshPlayers, 2000);

  $('#spot-power').onclick = () => send({ on: !(spot && spot.on) });
  $('#spot-target').onchange = (e) => { if (e.target.value) send({ on: true, aim: 'player', target: +e.target.value }); };
  $('#spot-look').onclick = () => nui('spot', { action: 'look' }).catch(() => {});
  $('#spot-free').onclick = () => nui('spot', { action: 'free' }).catch(() => {});
  const slider = (id, label, patch) => {
    let timer = null;
    $(id).oninput = (e) => {
      $(label).textContent = e.target.value;
      if (!timer) timer = setTimeout(() => { timer = null; send(patch(+$(id).value)); }, 150);
    };
  };
  slider('#spot-size', '#spot-size-val', (v) => ({ size: v }));
  slider('#spot-int', '#spot-int-val', (v) => ({ intensity: v / 100 }));
  let colTimer = null;
  $('#spot-color').oninput = () => {
    if (!colTimer) colTimer = setTimeout(() => { colTimer = null; send({ color: rgb($('#spot-color').value) }); }, 150);
  };

  window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.type !== 'spotDesk') return;
    if (m.spot) spot = m.spot;
    if (m.enabled !== undefined) { $('#spot').classList.toggle('hidden', !m.enabled); setTimeout(refreshPlayers, 50); }
    render();
  });
})();
