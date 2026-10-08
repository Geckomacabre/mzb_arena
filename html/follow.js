// mzb_arena - the lights follow the music (the desk's "Follow the music" buttons; client/lights.lua asks for it while
// this player is in the arena with the show lights on). It works on what this player's own game is playing, taken
// from the music player's sound graph (html/music.js):
//   * the tempo: the kick drum's hits, found in the track's low end, make a beat count that runs on between the hits
//     at the tempo they keep
//   * the colours: the picture of the video the sound comes from (a YouTube track, or the screens' video while its
//     sound comes from the speakers), looked at five times a second for its two or three main colours
// The game is told ten times a second and at every hit (lightsFollow). A file has no picture and a pause no beat:
// the desk's own colours and speed stay for whatever is not there.
(() => {
  // ---------------------------------------------------------------- the beat
  // push(low, all, t): the mean square of the last ~20 ms of the low end and of the whole track, at t ms.
  // Answers { kick } and keeps beat (a count, whole numbers on the beats), bpm and level (0..1).
  function beatTracker(o) {
    const lo = 60 / (2 * ((o && o.minBpm) || 80)), hi = 2 * lo;      // seconds a beat: lo <= interval < hi
    let interval = Math.min(hi * 0.999, Math.max(lo, 60 / ((o && o.bpm) || 120)));
    const sens = Math.max(0.3, Math.min(3, (o && o.sensitivity) || 1));
    const hist = [], gaps = [];
    let prev = 0, top = 0, lastKick = -1e9, lastT = null, off = 0, peak = 1e-4;
    const me = { beat: 0, bpm: 60 / interval, level: 0, found: false, push };

    // the beat's length from the gaps between the hits: each gap is the beat, half of it, twice it ... so they are
    // compared as octaves of one another, and the most common one wins (a syncopated hit is outvoted)
    function tempo() {
      const bins = new Array(24).fill(0), xs = gaps.map((s) => { const x = Math.log2(s) % 1; return x < 0 ? x + 1 : x; });
      for (const x of xs) bins[Math.floor(x * 24) % 24]++;
      let best = 0;
      for (let i = 1; i < 24; i++) if (bins[i] + 0.5 * (bins[(i + 1) % 24] + bins[(i + 23) % 24]) > bins[best] + 0.5 * (bins[(best + 1) % 24] + bins[(best + 23) % 24])) best = i;
      let sx = 0, sy = 0, n = 0;
      for (const x of xs) {
        let d = x - (best + 0.5) / 24; d -= Math.round(d);
        if (Math.abs(d) <= 1.5 / 24) { sx += Math.cos(2 * Math.PI * x); sy += Math.sin(2 * Math.PI * x); n++; }
      }
      if (n < 3 || n < xs.length * 0.45) return;               // hits at no steady pace: the tempo in use stays
      let x = Math.atan2(sy, sx) / (2 * Math.PI); if (x < 0) x += 1;
      let s = Math.pow(2, x); while (s >= hi) s /= 2; while (s < lo) s *= 2;
      // at the edge of the range the same tempo has two names (80 or 160): keep the one in use
      for (const c of [s * 2, s / 2]) if (c >= lo * 0.94 && c < hi * 1.06 && Math.abs(Math.log2(c / interval)) < Math.abs(Math.log2(s / interval))) s = c;
      interval += (s - interval) * (me.found ? 0.35 : 1);
      me.found = true;
    }

    function push(low, all, t) {
      const dt = lastT === null ? 0 : Math.max(0, Math.min(0.25, (t - lastT) / 1000));
      lastT = t;
      me.beat += dt / interval;
      // the level: how loud against the loudest of the last while
      const rms = Math.sqrt(Math.max(0, all));
      peak = Math.max(rms, peak * Math.pow(0.97, dt), 1e-4);
      const lv = rms > 2e-4 ? Math.min(1, rms / peak) : 0;
      me.level += (lv - me.level) * (lv > me.level ? 0.5 : Math.min(1, dt * 3));
      // a hit: the low end jumps well over what it has been doing for the last second, and near its loudest
      let kick = false;
      top = Math.max(low, top * Math.pow(0.6, dt));
      if (hist.length >= 15) {
        let m = 0; for (const e of hist) m += e; m /= hist.length;
        let v = 0; for (const e of hist) v += (e - m) * (e - m); v = Math.sqrt(v / hist.length);
        // a low end that hardly moves (a held bass, a voice, noise) has to jump much further than one with hits in it
        const steady = Math.max(0, Math.min(1, (1 - (m > 0 ? v / m : 0)) / 0.4));
        if (low > m * (1 + (0.3 + 1.9 * steady) / sens) && low > 0.4 * top && low > 1e-6 && low > prev && t - lastKick > 240) {
          kick = true;
          const gap = (t - lastKick) / 1000;
          lastKick = t;
          if (gap < 2.0) { gaps.push(gap); if (gaps.length > 14) gaps.shift(); if (gaps.length >= 4) tempo(); }
          // the count is pulled onto the hit, and never steps back over a beat
          const whole = Math.floor(me.beat), fr = me.beat - whole;
          if (fr < 0.25) { me.beat = whole + fr * 0.5; off = 0; }
          else if (fr > 0.75) { me.beat = whole + 1; off = 0; }
          else if (++off >= 3) { me.beat = whole + 1; off = 0; }       // the hits keep landing between the beats
        }
      }
      hist.push(low); if (hist.length > 60) hist.shift();
      prev = low;
      me.bpm = 60 / interval;
      return { kick };
    }
    return me;
  }

  // ---------------------------------------------------------------- the picture's colours
  // rgba: the picture, small (RGBA bytes). Answers its main colours as stage light (full, saturated; up to max of
  // them, at least 60 degrees of hue apart), [[255, 255, 255]] for a bright picture without colour, null for a dark
  // one (the lights keep what they had).
  function palette(rgba, max) {
    const N = 12, w = new Array(N).fill(0), vx = new Array(N).fill(0), vy = new Array(N).fill(0), sat = new Array(N).fill(0);
    const px = rgba.length / 4;
    let luma = 0, total = 0;
    for (let i = 0; i < rgba.length; i += 4) {
      const r = rgba[i] / 255, g = rgba[i + 1] / 255, b = rgba[i + 2] / 255;
      const mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn;
      luma += 0.2126 * r + 0.7152 * g + 0.0722 * b;
      if (mx < 0.12 || d / mx < 0.18) continue;
      let h = mx === r ? ((g - b) / d) % 6 : mx === g ? (b - r) / d + 2 : (r - g) / d + 4;
      h /= 6; if (h < 0) h += 1;
      const k = (d / mx) * mx, bin = Math.floor(h * N) % N;
      w[bin] += k; vx[bin] += Math.cos(2 * Math.PI * h) * k; vy[bin] += Math.sin(2 * Math.PI * h) * k; sat[bin] += (d / mx) * k;
      total += k;
    }
    if (px === 0) return null;
    if (total / px < 0.02) return luma / px > 0.3 ? [[255, 255, 255]] : null;
    const near = (i) => w[i] + 0.5 * (w[(i + 1) % N] + w[(i + N - 1) % N]);
    const order = [...Array(N).keys()].sort((a, b) => near(b) - near(a));
    const picked = [];
    for (const i of order) {
      if (picked.length >= (max || 3)) break;
      if (picked.length && near(i) < 0.22 * near(picked[0])) break;
      if (picked.some((p) => Math.min((i - p + N) % N, (p - i + N) % N) < 2)) continue;
      picked.push(i);
    }
    return picked.map((i) => {
      let x = 0, y = 0, s = 0, k = 0;
      for (const j of [i, (i + 1) % N, (i + N - 1) % N]) { x += vx[j]; y += vy[j]; s += sat[j]; k += w[j]; }
      let h = Math.atan2(y, x) / (2 * Math.PI); if (h < 0) h += 1;
      return hsv(h, Math.min(1, 0.55 + 0.6 * (k > 0 ? s / k : 1)));
    });
  }
  function hsv(h, s) {
    const i = Math.floor(h * 6), f = h * 6 - i, p = 1 - s, q = 1 - f * s, t = 1 - (1 - f) * s;
    const c = [[1, t, p], [q, 1, p], [p, 1, t], [p, q, 1], [t, p, 1], [1, p, q]][i % 6];
    return c.map((v) => Math.round(v * 255));
  }
  const hue = (c) => { const mx = Math.max(...c), d = mx - Math.min(...c); if (d === 0) return -1;
    const h = (mx === c[0] ? ((c[1] - c[2]) / d) % 6 : mx === c[1] ? (c[2] - c[0]) / d + 2 : (c[0] - c[1]) / d + 4) / 6; return h < 0 ? h + 1 : h; };
  const hueGap = (a, b) => { const x = hue(a), y = hue(b); if (x < 0 || y < 0) return x === y ? 0 : 0.5; const d = Math.abs(x - y); return Math.min(d, 1 - d); };

  // the colour slots move towards the picture's colours (a of the way each look), each slot towards the colour nearest
  // its own: two colours that change places in the picture do not make the fixtures change places
  function blend(slots, targets, a) {
    const left = targets.slice(), out = [];
    for (let i = 0; i < Math.min(slots.length, targets.length); i++) {
      let best = 0;
      for (let j = 1; j < left.length; j++) if (hueGap(slots[i], left[j]) < hueGap(slots[i], left[best])) best = j;
      const t = left.splice(best, 1)[0];
      out.push(slots[i].map((v, k) => v + (t[k] - v) * a));
    }
    for (const t of left) if (out.length < targets.length) out.push(t.slice());
    return out;
  }

  if (typeof module !== 'undefined' && module.exports) { module.exports = { beatTracker, palette, blend }; return; }

  // ---------------------------------------------------------------- the page
  const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'mzb_arena';
  const $ = (s) => document.querySelector(s);
  const nui = (name, body) =>
    fetch(`https://${res}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body || {}) }).catch(() => {});

  const W = 32, H = 18, STEP = 20;
  const canvas = document.createElement('canvas'); canvas.width = W; canvas.height = H;
  const c2d = canvas.getContext('2d', { willReadFrequently: true });
  const bufL = new Float32Array(1024), bufA = new Float32Array(1024);
  let want = null;          // what the game asked for: { tempo, colour, bpm, config }
  let chain = null;         // the analysers on the music player's graph
  let tracker = null, rev = null, slots = [], picture = 'none', ticks = 0, timer = null, heard = false;

  const meanSquare = (d) => { let s = 0; for (let i = 0; i < d.length; i++) s += d[i] * d[i]; return s / d.length; };

  // the low end (the kick drum lives under 160 Hz) and the whole track, each into an analyser
  function attach(tap) {
    if (chain && chain.node === tap.node) return chain;
    const low = tap.ctx.createBiquadFilter(); low.type = 'lowpass'; low.frequency.value = 160; low.Q.value = 0.7;
    const aLow = tap.ctx.createAnalyser(), aAll = tap.ctx.createAnalyser();
    aLow.fftSize = aAll.fftSize = 1024;
    tap.node.connect(low); low.connect(aLow); tap.node.connect(aAll);
    chain = { node: tap.node, aLow, aAll };
    return chain;
  }

  function look(video) {
    if (picture === 'blocked') return;
    if (!video || !video.videoWidth) { picture = 'none'; slots = []; return; }
    try {
      c2d.drawImage(video, 0, 0, W, H);
      const p = palette(c2d.getImageData(0, 0, W, H).data, (want.config && want.config.colours) || 3);
      if (p) slots = blend(slots, p, 0.5);
      picture = 'ok';
    } catch (e) {                       // a browser that will not hand over another site's picture
      picture = 'blocked'; slots = [];
    }
  }

  function step() {
    const tap = window.mzbMusicTap && window.mzbMusicTap();
    if (!tap || !tap.playing) { heard = false; return; }
    if (tap.rev !== rev || !tracker) {                       // another track: count and colours start again
      rev = tap.rev; slots = []; picture = 'none'; ticks = 0;
      tracker = beatTracker({ bpm: want.bpm, minBpm: want.config && want.config.minBpm });
    }
    const c = attach(tap);
    c.aLow.getFloatTimeDomainData(bufL); c.aAll.getFloatTimeDomainData(bufA);
    const r = tracker.push(meanSquare(bufL), meanSquare(bufA), performance.now());
    heard = true;
    ticks++;
    if (want.colour && ticks % 10 === 1) look(tap.video);
    if (r.kick || ticks % 5 === 0) {
      nui('lightsFollow', { beat: Math.round(tracker.beat * 1000) / 1000, bpm: Math.round(tracker.bpm * 10) / 10, kick: r.kick,
        level: Math.round(tracker.level * 100) / 100,
        colors: want.colour && slots.length ? slots.map((s) => s.map((v) => Math.round(v))) : null });
    }
  }

  // the desk's line under the buttons: what is being followed right now
  function readout() {
    const n = $('#follow-now');
    if (!n) return;
    if (!want || !want.on) { n.textContent = ''; return; }
    if (!heard || !tracker) { n.textContent = 'no track playing: the desk\'s speed and colours'; return; }
    const parts = [];
    if (want.tempo) parts.push(tracker.found ? Math.round(tracker.bpm) + ' bpm' : 'finding the beat');
    if (want.colour) parts.push(picture === 'ok' ? '' : picture === 'blocked' ? 'the picture cannot be read here: the desk\'s colours' : 'no picture: the desk\'s colours');
    n.textContent = parts.filter(Boolean).join(' · ');
    if (want.colour && picture === 'ok') {
      for (const s of slots) {
        const i = document.createElement('i');
        i.style.background = `rgb(${s.map((v) => Math.round(v)).join(',')})`;
        n.appendChild(i);
      }
    }
  }
  setInterval(readout, 500);

  window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.type !== 'follow') return;
    want = m;
    if (m.on && !timer) { tracker = null; rev = null; timer = setInterval(step, STEP); }
    else if (!m.on && timer) { clearInterval(timer); timer = null; heard = false; }
    else if (m.on && picture === 'blocked') picture = 'none';
    readout();
  });

  // this page is here now: the game says again what it wants followed
  nui('followReady');
})();
