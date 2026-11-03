// mzb_arena - the light desk (NUI). Every touch posts a patch to the client (client/lights.lua), which hands it to
// the server; the server's state comes back as 'state' messages, so the desk always shows what the arena is doing.
// (1.5.0) drawn as a piece of show equipment, simple first. LIGHTS: the playbacks (a key per look, its name on tape,
// the live one's LED green), RANDOM (a new look on every light, picked by the server), the ZONES the beams point at
// (floor, stage, crowd), sound to light (AUTO, BEAT, MANUAL), one colour for every light. The wing: LIGHTS (the lights' master) with BLACKOUT, SPEED with TAP (its LED on
// the beat), HAZE, FOG with BURST, MASTER (the music's volume - html/music.js runs it) with MUTE, and GO. Each group of
// lights on its own is under ADVANCED. html/console.js has the groups, the help line and the faders' scales.
(() => {
  const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'mzb_arena';
  const $ = (s) => document.querySelector(s);
  const $$ = (s) => Array.from(document.querySelectorAll(s));
  const desk = $('#desk');
  let state = null;
  let activeSlot = 0;
  let running = [];          // the show's presets in running order: numpad 1-9
  let names = {};            // a look's id -> its label (the screen)
  let burstLen = 8;          // the wing's BURST, in seconds (Config.Fog.burst)
  let hazeLast = 0.4;        // the haze key brings back the level it was at
  let burstN = null, burstUntil = 0;
  let volume = null, unmute = 70;   // the music's volume for everyone (html/music.js has the fader), MUTE's way back
  // the old sweep / ballyhoo modes were a movement with a static colour: show them as such
  const MOVING = { sweep: 1, ballyhoo: 1 };
  const effMode = () => (MOVING[state.mode] ? 'static' : state.mode);
  const effMove = () => (state.move && state.move !== 'none' ? state.move : MOVING[state.mode] ? state.mode : 'none');
  const focusList = () => (Array.isArray(state.focus) ? state.focus : [state.focus || 'floor']);
  const SYNC = { off: 'MANUAL', both: 'BEAT+COL', tempo: 'BEAT', colour: 'COLOUR', auto: 'AUTO' };
  const SYNC_KEY = { auto: 'auto', tempo: 'beat', both: 'beat', off: 'manual', colour: 'manual' };

  const post = (name, body) =>
    fetch(`https://${res}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body || {}) }).catch(() => {});

  // faders: at most one patch every 120 ms per control, the last value always sent
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
  const same = (a, b) => Array.isArray(a) && Array.isArray(b) && a[0] === b[0] && a[1] === b[1] && a[2] === b[2];

  // a fader goes where the state has it - not while a hand is on it, nor for a moment after (the last patch is still
  // on its way back), and it lets go of the focus when the hand does (so html/music.js moves the MASTER again)
  let held = null, lastHeld = null, heldUntil = 0;
  const fader = (id, value, label) => {
    const el = $(id);
    if (el === held || (el === lastHeld && Date.now() < heldUntil)) return;
    el.value = value;
    if (label) $(label).textContent = Math.round(value);
  };
  document.addEventListener('pointerdown', (e) => { if (e.target.matches && e.target.matches('input[type=range]')) held = e.target; });
  document.addEventListener('pointerup', () => {
    if (!held) return;
    lastHeld = held; heldUntil = Date.now() + 700;
    held.blur(); held = null;
    setTimeout(render, 720);
  });
  const lit = (sel, on) => { const el = $(sel); if (el) el.classList.toggle('on', !!on); };

  function render() {
    if (!state) return;
    const pct = (v, d) => Math.round((v == null ? d : v) * 100);
    // the wing
    fader('#gm', pct(state.master, 1), '#gm-val');
    if (state.bo) $('#gm-val').textContent = 'B.O.';
    lit('#bo', state.bo);
    const hz = Math.max(0, Math.min(1, +state.haze || 0));
    if (hz > 0.001) hazeLast = hz;
    lit('#haze', hz > 0.001);
    fader('#haze-level', Math.round(hz * 100), '#haze-val');
    const fg = state.fog || {};
    fader('#fog-level', fg.on ? pct(fg.output, 0.6) : 0, '#fog-val');          // (down at nothing: off)
    fader('#bpm', state.bpm || 120, '#bpm-val');
    $('#strip-speed').classList.toggle('music', SYNC_KEY[state.follow || 'off'] !== 'manual');
    // a burst: the key lit while it lasts (ours, or one from another desk)
    const fb = state.fogBurst;
    if (fb && typeof fb === 'object' && fb.n !== burstN) {
      if (burstN !== null) burstUntil = Date.now() + (+fb.dur || burstLen) * 1000;
      burstN = fb.n;
    }
    $('#fog-burst').classList.toggle('active', Date.now() < burstUntil);
    // the screen and the SHOW lamp
    $('#live-dot').classList.toggle('live', !!state.on && !state.bo);
    const look = $('#lcd-look');
    look.textContent = state.bo ? 'BLACKOUT' : (state.look ? names[state.look] || state.look : '-');
    look.classList.toggle('dark', !!state.bo);
    $('#lcd-sync').textContent = SYNC[state.follow || 'off'] || 'MANUAL';
    // LIGHTS: the live playback, RANDOM, sound to light, the colour every light is in
    $$('#presets button, #presets-more button').forEach((b) => b.classList.toggle('live', !!state.look && b.dataset.look === state.look));
    lit('#random', state.look === 'random');
    const sync = SYNC_KEY[state.follow || 'off'] || 'manual';
    $$('#sync button').forEach((b) => b.classList.toggle('active', b.dataset.sync === sync));
    const one = (state.colors || []).length === 1 ? state.colors[0] : null;
    $$('#all-colours button').forEach((b) => b.classList.toggle('active', same(b.rgb, one)));
    // ADVANCED: the fixture keys' green dot while each group is on; LIGHTS' ZONES: the same groups' ON keys, lit while
    // on (the followspot's: html/spot.js)
    const bz = state.bars || {}, lz = state.lasers || {};
    const group = (g, on) => {
      const b = $(`#groups [data-grp="${g}"]`); if (b) b.classList.toggle('lit', !!on);
      lit(`#fixtures [data-fix="${g}"]`, on);
    };
    group('beams', state.on); group('ring', state.ring); group('bars', bz.on); group('lasers', lz.on);
    group('house', state.house !== 'off');
    // the beams
    lit('#power', state.on);
    fader('#intensity', pct(state.intensity, 0), '#int-val');
    $$('#modes button').forEach((b) => b.classList.toggle('active', b.dataset.mode === effMode()));
    $$('#moves button').forEach((b) => b.classList.toggle('active', b.dataset.move === effMove()));
    const fl = focusList();
    $$('#focus button').forEach((b) => b.classList.toggle('active', fl.includes(b.dataset.focus)));
    $$('#zones button').forEach((b) => b.classList.toggle('active', fl.includes(b.dataset.zone)));   // (LIGHTS' ZONES)
    const cs = state.colors || [];
    $$('#slots .slot').forEach((b) => {
      const i = +b.dataset.slot;
      const sw = b.querySelector('span');
      if (cs[i]) { sw.style.background = hex(cs[i]); b.classList.remove('empty'); }
      else { sw.style.background = ''; b.classList.add('empty'); }
      b.classList.toggle('active', i === activeSlot);
    });
    if (cs[activeSlot]) $('#picker').value = hex(cs[activeSlot]);
    $$('#palette button').forEach((b) => b.classList.toggle('active', same(b.rgb, cs[activeSlot])));
    $$('#gobos button').forEach((b) => b.classList.toggle('active', b.dataset.gobo === (state.gobo || 'none')));
    $$('#follow button').forEach((b) => b.classList.toggle('active', b.dataset.follow === (state.follow || 'off')));
    // the ring
    lit('#ring', state.ring);
    fader('#ring-level', pct(state.ringLevel, 1), '#ring-level-val');
    if (document.activeElement !== $('#ring-color') && state.ringColor) $('#ring-color').value = hex(state.ringColor);
    $('#ring-own').classList.toggle('active', !state.ringColor);
    $$('#ring-palette button').forEach((b) => b.classList.toggle('active', same(b.rgb, state.ringColor)));
    // the bars
    lit('#bars', bz.on);
    fader('#bars-level', pct(bz.level, 1), '#bars-level-val');
    $$('#bar-modes button').forEach((b) => b.classList.toggle('active', b.dataset.bmode === (bz.mode || 'video')));
    $$('#bar-where button').forEach((b) => b.classList.toggle('active', b.dataset.bwhere === (bz.where || 'all')));
    const bc = Array.isArray(bz.colour) ? bz.colour.join(',') : 'desk';
    $$('#bar-cols button').forEach((b) => b.classList.toggle('active', (b.dataset.rgb || 'desk') === bc));
    // the lasers, the house
    lit('#lasers', lz.on);
    $$('#laser-pats button').forEach((b) => b.classList.toggle('active', b.dataset.laser === (lz.pattern || 'fan')));
    const lc = Array.isArray(lz.colour) ? lz.colour.join(',') : 'desk';
    $$('#laser-cols button').forEach((b) => b.classList.toggle('active', (b.dataset.rgb || 'desk') === lc));
    $$('#house button').forEach((b) => b.classList.toggle('active', b.dataset.house === state.house));
    // the atmosphere's keys (PYRO / FOG)
    $$('#haze-steps button').forEach((b) => b.classList.toggle('active', Math.abs(+b.dataset.haze - hz * 100) < 1));
    $$('#fog-steps button').forEach((b) => b.classList.toggle('active',
      b.dataset.fog === 'off' ? !fg.on : !!fg.on && Math.abs(+b.dataset.fog - pct(fg.output, 0.6)) < 1));
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
  // (1.5.0) the numpad, while the desk is open: 1-9 the show's presets in running order, * RANDOM, 0 BLACKOUT,
  // + / Enter the next cue, - the one before (html/cues.js listens for those), . the beams on / off
  document.addEventListener('keydown', (e) => {
    if (desk.classList.contains('hidden') || !e.code || !e.code.startsWith('Numpad')) return;
    if (e.target && e.target.closest && e.target.closest('input[type=text], textarea, select')) return;
    const n = e.code.length === 7 ? +e.code.charAt(6) : NaN;            // Numpad0 .. Numpad9
    if (n >= 1 && n <= 9) { if (running[n - 1]) post('preset', { id: running[n - 1].id }); }
    else if (n === 0 && state) post('lights', { bo: !state.bo });
    else if (e.code === 'NumpadMultiply') post('preset', { id: 'random' });
    else if (e.code === 'NumpadAdd' || e.code === 'NumpadEnter') window.dispatchEvent(new CustomEvent('mzbCue', { detail: 'go' }));
    else if (e.code === 'NumpadSubtract') window.dispatchEvent(new CustomEvent('mzbCue', { detail: 'back' }));
    else if (e.code === 'NumpadDecimal' && state) post('lights', { on: !state.on });
    else return;
    e.preventDefault();
  });

  // LIGHTS. A look, RANDOM or a colour from here lifts a blackout and takes over from AUTO (server/lights.lua); the
  // colour goes to every light: the beams, the ring, the bars (off Video, which has the picture's), the lasers
  $('#random').onclick = () => post('preset', { id: 'random' });
  $$('#sync button').forEach((b) => (b.onclick = () =>
    post('lights', { follow: { auto: 'auto', beat: 'tempo', manual: 'off' }[b.dataset.sync], on: true })));
  const allColour = (c) => {
    const bz = state.bars || {};
    post('lights', { on: true, bo: false, colors: [c], ringColor: c, lasers: { colour: 'desk' },
      bars: { colour: 'desk', mode: bz.mode === 'video' ? 'steady' : bz.mode || 'steady' } });
  };

  // the wing: LIGHTS and BLACKOUT, SPEED and TAP, HAZE, FOG and BURST, MASTER and MUTE
  $('#gm').oninput = (e) => { $('#gm-val').textContent = e.target.value; throttled('master', { master: e.target.value / 100 }); };
  $('#bo').onclick = () => post('lights', { bo: !state.bo });
  $('#bpm').oninput = (e) => { $('#bpm-val').textContent = e.target.value; throttled('bpm', { bpm: +e.target.value }); };
  // tap tempo: the average of the last taps (reset after 2 s without one)
  let taps = [];
  $('#tap').onclick = () => {
    const now = performance.now();
    if (taps.length && now - taps[taps.length - 1] > 2000) taps = [];
    taps.push(now);
    if (taps.length > 5) taps.shift();
    if (taps.length >= 2) {
      const bpm = Math.round(60000 / ((taps[taps.length - 1] - taps[0]) / (taps.length - 1)));
      if (bpm >= 30 && bpm <= 240) { fader('#bpm', bpm, '#bpm-val'); post('lights', { bpm }); }
    }
  };
  // the haze: its level is whether it is on; the key takes it to nothing, or back to where it was
  $('#haze').onclick = () => post('lights', { haze: (+state.haze || 0) > 0.001 ? 0 : hazeLast });
  $('#haze-level').oninput = (e) => { $('#haze-val').textContent = e.target.value; throttled('haze', { haze: e.target.value / 100 }); };
  // the fog: up for more, down to nothing for off
  $('#fog-level').oninput = (e) => {
    const v = +e.target.value;
    $('#fog-val').textContent = v;
    throttled('fog', { fog: v > 0 ? { on: true, output: v / 100 } : { on: false } });
  };
  const burst = (s) => { burstUntil = Date.now() + s * 1000; render(); post('lights', { fogBurst: s }); };
  $('#fog-burst').onclick = () => burst(burstLen);
  // MUTE: the music's volume to nothing, and back
  $('#mute').onclick = () => {
    const v = volume == null ? +$('#mus-vol').value : volume;
    if (v > 0) unmute = v;
    post('music', { action: 'volume', value: v > 0 ? 0 : unmute || 70 });
  };

  // PYRO / FOG: the atmosphere
  $$('#haze-steps button').forEach((b) => (b.onclick = () => post('lights', { haze: +b.dataset.haze / 100 })));
  $$('#fog-steps button').forEach((b) => (b.onclick = () =>
    post('lights', b.dataset.fog === 'off' ? { fog: { on: false } } : { fog: { on: true, output: +b.dataset.fog / 100 } })));
  $$('#fog-bursts button').forEach((b) => (b.onclick = () => burst(+b.dataset.burst)));

  // ADVANCED: the beams. An effect keeps the movement that is running (an old sweep / ballyhoo mode becomes that
  // movement)
  $('#power').onclick = () => post('lights', { on: !state.on });
  $('#intensity').oninput = (e) => { $('#int-val').textContent = e.target.value; throttled('intensity', { intensity: e.target.value / 100 }); };
  $$('#modes button').forEach((b) => (b.onclick = () => post('lights', { mode: b.dataset.mode, move: effMove(), on: true })));
  $$('#moves button').forEach((b) => (b.onclick = () => post('lights', { mode: effMode(), move: b.dataset.move, on: true })));
  // the aims toggle; one always stays (ADVANCED's AIM and LIGHTS' ZONES are the same thing; the beams come on with it)
  const aim = (zone) => {
    const fl = focusList().slice();
    const k = fl.indexOf(zone);
    if (k >= 0) { if (fl.length > 1) fl.splice(k, 1); } else fl.push(zone);
    post('lights', { focus: fl, on: true });
  };
  $$('#focus button').forEach((b) => (b.onclick = () => aim(b.dataset.focus)));
  $$('#zones button').forEach((b) => (b.onclick = () => aim(b.dataset.zone)));
  $$('#slots .slot').forEach((b) => (b.onclick = () => { activeSlot = +b.dataset.slot; render(); }));
  $('#picker').oninput = (e) => setColour(rgb(e.target.value));
  $('#clear-slot').onclick = () => {
    const cs = (state.colors || []).slice(0, Math.max(1, (state.colors || []).length - 1));
    activeSlot = Math.min(activeSlot, cs.length - 1);
    post('lights', { colors: cs });
  };
  $$('#gobos button').forEach((b) => (b.onclick = () => post('lights', { gobo: b.dataset.gobo })));
  // follow the music: the tempo and / or the colours of what is playing (html/follow.js finds them); the show lights
  // come on with it
  $$('#follow button').forEach((b) => (b.onclick = () =>
    post('lights', b.dataset.follow === 'off' ? { follow: 'off' } : { follow: b.dataset.follow, on: true })));
  // the ring
  $('#ring').onclick = () => post('lights', { ring: !state.ring });
  $('#ring-level').oninput = (e) => { $('#ring-level-val').textContent = e.target.value; throttled('ringLevel', { ringLevel: e.target.value / 100 }); };
  $('#ring-color').oninput = (e) => throttled('ringColor', { ring: true, ringColor: rgb(e.target.value) });
  $('#ring-own').onclick = () => post('lights', { ringColor: false });
  // the bars, the lasers, the house
  $('#bars').onclick = () => post('lights', { bars: { on: !(state.bars || {}).on } });
  $('#bars-level').oninput = (e) => { $('#bars-level-val').textContent = e.target.value; throttled('barsLevel', { bars: { level: e.target.value / 100 } }); };
  $$('#bar-modes button').forEach((b) => (b.onclick = () => post('lights', { bars: { on: true, mode: b.dataset.bmode } })));
  $$('#bar-where button').forEach((b) => (b.onclick = () => post('lights', { bars: { on: true, where: b.dataset.bwhere } })));
  $$('#bar-cols button').forEach((b) => (b.onclick = () => post('lights', { bars: { colour: b.dataset.bcol } })));
  $('#lasers').onclick = () => post('lights', { lasers: { on: !(state.lasers || {}).on } });
  $$('#laser-pats button').forEach((b) => (b.onclick = () => post('lights', { lasers: { on: true, pattern: b.dataset.laser } })));
  $$('#laser-cols button').forEach((b) => (b.onclick = () => post('lights', { lasers: { colour: b.dataset.lcol } })));
  $$('#house button').forEach((b) => (b.onclick = () => post('lights', { house: b.dataset.house })));
  // (1.5.0) LIGHTS' ZONES: each group on / off, as its ON key under ADVANCED does (the followspot's: html/spot.js);
  // HOUSE goes off, or back to what the show has
  const FIX = {
    beams: () => post('lights', { on: !state.on }),
    ring: () => post('lights', { ring: !state.ring }),
    bars: () => post('lights', { bars: { on: !(state.bars || {}).on } }),
    lasers: () => post('lights', { lasers: { on: !(state.lasers || {}).on } }),
    house: () => post('lights', { house: state.house === 'off' ? 'show' : 'off' }),
  };
  $$('#fixtures button').forEach((b) => { if (FIX[b.dataset.fix]) b.onclick = FIX[b.dataset.fix]; });

  // while the desk is open: TAP's LED on the beat (the music's, while the lights follow its tempo and have it), the
  // SPEED screen with the music's tempo, the burst key going out
  let ticker = null;
  function tick() {
    if (!state) return;
    const f = window.mzbFollowNow && window.mzbFollowNow();
    const bpm = f ? f.bpm : state.bpm || 120;
    const beat = f ? f.beat : (performance.now() / 1000) * bpm / 60;
    $('#tap').classList.toggle('beat', ((beat % 1) + 1) % 1 < 0.16);
    $('#lcd-bpm').textContent = Math.round(bpm);
    if (f && held !== $('#bpm')) $('#bpm-val').textContent = Math.round(bpm);
    if (burstUntil && Date.now() >= burstUntil) { burstUntil = 0; $('#fog-burst').classList.remove('active'); }
  }

  // the show's part of the desk: its name, its running order of looks (the rest under ALL LOOKS), its aims, its ring
  // lights, its lasers. On opening, and again when the show changes while the desk is open
  function showPart(m) {
    $('#show-name').textContent = m.show || '';
    $('#presets-kind').textContent = m.kind || '';
    const fill = (box, list, keys) => {
      box.innerHTML = '';
      (list || []).forEach((p, i) => {
        const pb = document.createElement('div');
        pb.className = 'pb';
        const tape = document.createElement('span');
        tape.className = 'tape';
        tape.textContent = p.label;
        const b = document.createElement('button');
        b.dataset.look = p.id;
        b.textContent = keys && i < 9 ? i + 1 : '';
        b.title = keys && i < 9 ? `${p.label} - numpad ${i + 1}` : p.label;
        names[p.id] = p.label;
        b.onclick = () => post('preset', { id: p.id });
        pb.append(tape, b);
        box.appendChild(pb);
      });
    };
    running = m.presets || [];
    fill($('#presets'), m.presets, true);
    fill($('#presets-more'), m.more);
    $('#presets-all').classList.toggle('hidden', !(m.more && m.more.length));
    $$('[data-focus="stage"], [data-zone="stage"]').forEach((b) => {
      b.disabled = m.hasStage === false;
      b.title = m.hasStage === false ? 'STAGE - this show has no stage' : 'STAGE - the stage, the ring or the cage';
    });
    $('#lasers-sec').classList.toggle('hidden', !m.hasLasers);
    $('#gobo-sec').classList.toggle('hidden', m.gobos === false);
    $('#ring-sec').classList.toggle('hidden', m.hasRing === false);   // a show without ring / cage / stage lights
  }
  $('#presets-all').onclick = () => {
    const more = $('#presets-more');
    more.classList.toggle('hidden');
    $('#presets-all').classList.toggle('active', !more.classList.contains('hidden'));
  };

  // colour pads: the colour shows in the pad's lens
  const pads = (box, colours, pick, what) => {
    box.innerHTML = '';
    colours.forEach((c) => {
      const b = document.createElement('button');
      b.style.setProperty('--pc', hex(c.rgb));
      b.title = `${c.name.toUpperCase()} - ${what}`;
      b.rgb = c.rgb;
      b.onclick = () => pick(c.rgb);
      box.appendChild(b);
    });
  };

  window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.type === 'deskShow') { showPart(m); render(); return; }
    if (m.type === 'musicDesk' && m.music) {                       // (html/music.js runs the MASTER fader)
      volume = +m.music.volume || 0;
      lit('#mute', volume === 0);
      return;
    }
    if (m.type === 'open') {
      state = m.state;
      names = { blackout: 'Blackout', random: 'Random' };
      const fb = state && state.fogBurst;
      burstN = fb && typeof fb === 'object' ? fb.n : 0;                   // (a burst from before is not lit)
      showPart(m);
      pads($('#all-colours'), m.colours || [], allColour, 'every light in this colour');
      pads($('#palette'), m.colours || [], setColour, 'into the colour slot that is picked');
      pads($('#ring-palette'), m.colours || [], (c) => post('lights', { ring: true, ringColor: c }), 'all the ring lights in this colour');
      $('[data-mode="strobe"]').title = m.maxStrobe === 0 ? 'STROBE - off on this server (pulses instead)' : 'STROBE - fast flashes (the server caps how fast)';
      ['#follow-sec', '#sync-sec'].forEach((s) => $(s).classList.toggle('hidden', m.follow === false));
      // (1.5.0) what this server has: the atmosphere (Config.Fog), the bars (Config.LightBars)
      burstLen = +m.burst || 8;
      ['#atmo', '#strip-haze', '#strip-fog'].forEach((s) => $(s).classList.toggle('hidden', m.fog === false));
      $('#bars-sec').classList.toggle('hidden', m.bars === false);
      $('#strip-fog').title = `FOG - the fog machines at the stage: up for more, down to nothing for off. BURST: flat out for ${burstLen} seconds`;
      desk.classList.remove('hidden');
      render();
      if (!ticker) ticker = setInterval(tick, 40);
    } else if (m.type === 'state') {
      state = m.state;
      render();
    } else if (m.type === 'close') {
      desk.classList.add('hidden');
      if (ticker) { clearInterval(ticker); ticker = null; }
    }
  });
})();
