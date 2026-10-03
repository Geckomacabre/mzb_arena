// mzb_arena - fights (client/fights.lua, server/fights.lua):
//   * the fight bar at the top of the screen for everyone in the arena ('fight' messages, four a second while a bout
//     is on): the two names, how much each has left before they are down, the round and its clock, the result; the
//     next bout on the card between bouts;
//   * the desk's Fights section ('fightDesk'): the two corners (an NPC or a player in the arena), when the bout goes
//     on, the card, stop the bout on, clear the card.
(() => {
  const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'mzb_arena';
  const $ = (s) => document.querySelector(s);
  const nui = (name, body) =>
    fetch(`https://${res}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body || {}) });
  const send = (body) => nui('fight', body).catch(() => {});
  const clock = (ms) => {
    const s = Math.max(0, Math.ceil(ms / 1000));
    return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
  };
  const HOW = { 'count-out': 'by count-out', decision: 'on points', forfeit: 'by forfeit' };

  // ------------------------------------------------------------------ the bar
  function corner(side, f) {
    $(`#fh-${side}-name`).textContent = f ? f.name : '';
    $(`#fh-${side}-you`).classList.toggle('hidden', !(f && f.you));
    const hp = f && typeof f.hp === 'number' ? f.hp : null;
    $(`#fh-${side}-hp`).style.width = `${Math.round((hp === null ? 1 : hp) * 100)}%`;
    $(`#fh-${side}`).classList.toggle('unknown', hp === null);
    $(`#fh-${side}`).classList.toggle('low', hp !== null && hp < 0.25);
  }

  function result(m) {
    if (m.winner === 'draw') return m.how === 'no contest' || m.how === 'stopped' ? 'NO CONTEST' : `DRAW - ${m.how}`;
    const w = m[m.winner];
    const name = w ? w.name : m.winner;
    return m.how === 'KO' ? `KNOCKOUT! ${name} wins` : `${name} wins ${HOW[m.how] || m.how}`;
  }

  function hud(m) {
    const box = $('#fight-hud');
    if (m.hide) { box.classList.add('hidden'); return; }
    box.classList.remove('hidden');
    box.classList.toggle('side', !$('#desk').classList.contains('hidden'));   // clear of the open desk
    const live = m.state && m.state !== 'idle';
    $('#fh-bar').classList.toggle('hidden', !live);
    const next = $('#fh-next');
    next.classList.toggle('hidden', live || !m.next);
    if (!live) {
      $('#fh-banner').classList.add('hidden');
      if (m.next) {
        next.textContent = `NEXT BOUT  ${m.next.red}  vs  ${m.next.blue}` +
          (typeof m.next.inS === 'number' ? `  -  ${clock(m.next.inS * 1000)}` : '');
      }
      return;
    }
    corner('red', m.red);
    corner('blue', m.blue);
    const banner = $('#fh-banner');
    let title = '';
    if (m.state === 'intro') {
      $('#fh-round').textContent = 'WALK-OUT';
      title = `${m.red ? m.red.name : ''}  vs  ${m.blue ? m.blue.name : ''}`;
    } else if (m.state === 'round') {
      $('#fh-round').textContent = `ROUND ${m.round} / ${m.rounds}`;
    } else if (m.state === 'break') {
      $('#fh-round').textContent = `END OF ROUND ${m.round}`;
    } else if (m.state === 'over') {
      $('#fh-round').textContent = 'FINAL';
      title = result(m);
    }
    $('#fh-time').textContent = m.state === 'over' ? '' : clock(m.left);
    banner.textContent = title;
    banner.classList.toggle('hidden', !title);
    banner.classList.toggle('ko', m.state === 'over' && m.how === 'KO');
  }

  // ------------------------------------------------------------------ the desk
  let when = 0;
  let players = [];

  function fillPick(sel) {
    if (document.activeElement === sel) return;
    const keep = sel.value || 'npc';
    sel.innerHTML = '<option value="npc">NPC</option>';
    players.forEach((p) => {
      const o = document.createElement('option');
      o.value = String(p.id);
      o.textContent = `${p.name} (${p.id})`;
      sel.appendChild(o);
    });
    sel.value = Array.from(sel.options).some((o) => o.value === keep) ? keep : 'npc';
  }

  function refreshPlayers() {
    if ($('#desk').classList.contains('hidden') || $('#fights').classList.contains('folded')) return;
    nui('spotPlayers', {}).then((r) => r.json()).then((list) => {
      players = Array.isArray(list) ? list : [];
      fillPick($('#fight-red'));
      fillPick($('#fight-blue'));
    }).catch(() => {});
  }
  setInterval(refreshPlayers, 2500);

  function desk(m) {
    const f = m.fight || {};
    const now = $('#fight-now');
    if (f.state && f.state !== 'idle') {
      const names = `${f.red ? f.red.name : '?'} vs ${f.blue ? f.blue.name : '?'}`;
      now.textContent = f.state === 'over' ? `${names}: over` : `${names}: ${f.state === 'round' ? 'round ' + f.round : f.state}`;
    } else {
      now.textContent = f.last ? `last: ${f.last}` : 'no bout on';
    }
    $('#fight-stop').disabled = !(f.state && f.state !== 'idle' && f.state !== 'over');
    const list = $('#fight-card');
    list.innerHTML = '';
    (m.card || []).forEach((b) => {
      const li = document.createElement('li');
      li.textContent = `${b.red} vs ${b.blue}` + (typeof b.inS === 'number' ? ` - in ${Math.max(1, Math.ceil(b.inS / 60))} min` : '');
      list.appendChild(li);
    });
    $('#fight-clear').disabled = !(m.card && m.card.length);
  }

  Array.from(document.querySelectorAll('#fight-when button')).forEach((b) => {
    b.onclick = () => {
      when = +b.dataset.in;
      Array.from(document.querySelectorAll('#fight-when button')).forEach((x) => x.classList.toggle('active', x === b));
    };
  });
  $('#fight-add').onclick = () => send({ action: 'add', red: $('#fight-red').value, blue: $('#fight-blue').value, inMin: when });
  $('#fight-stop').onclick = () => send({ action: 'stop' });
  $('#fight-clear').onclick = () => send({ action: 'clear' });

  window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.type === 'fight') hud(m);
    else if (m.type === 'fightDesk') desk(m);
    else if (m.type === 'open') setTimeout(refreshPlayers, 50);
  });
})();
