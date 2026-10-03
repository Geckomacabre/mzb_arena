// mzb_arena - the arena's own sound (client/ambience.lua says where the listener is and what the crowd is doing).
// Made here, no files: a room tone (low rumble and air, the air handling of a big hall), the crowd's chatter (dozens
// of voices' worth of filtered noise in syllables, rendered once into a loop) and its roar (a swelling broadband
// noise) for the loud moods. Per Config.Listener zone a level for each and a low-pass (through the walls).
// The desk's "Room" slider (in the Music section) is your own level of it.
(() => {
  const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'mzb_arena';
  const $ = (s) => document.querySelector(s);
  const nui = (name, body) =>
    fetch(`https://${res}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body || {}) }).catch(() => {});

  let cfg = null, mine = 100, st = { zone: 'outside', crowd: false, mood: 'show' };
  let ctx = null, mix = null, building = false, idleTimer = null;

  // ---- the sounds, made once
  function noise(seconds, kind) {
    const rate = ctx.sampleRate, len = Math.floor(rate * seconds);
    const buf = ctx.createBuffer(2, len, rate);
    for (let ch = 0; ch < 2; ch++) {
      const d = buf.getChannelData(ch);
      let last = 0, b0 = 0, b1 = 0, b2 = 0;
      for (let i = 0; i < len; i++) {
        const w = Math.random() * 2 - 1;
        if (kind === 'brown') { last = (last + 0.02 * w) / 1.02; d[i] = last * 3.5; }
        else { b0 = 0.99765 * b0 + w * 0.099046; b1 = 0.963 * b1 + w * 0.2965164; b2 = 0.57 * b2 + w * 1.0526913;
               d[i] = (b0 + b1 + b2 + w * 0.1848) * 0.12; }
      }
    }
    return buf;
  }

  // a loop without a seam: the last `fade` seconds laid over the first ones
  function loopOf(rendered, seconds, fade) {
    const rate = rendered.sampleRate, len = Math.floor(rate * seconds), f = Math.floor(rate * fade);
    const out = ctx.createBuffer(2, len, rate);
    let sum = 0, n = 0;
    for (let ch = 0; ch < 2; ch++) {
      const src = rendered.getChannelData(ch), d = out.getChannelData(ch);
      for (let i = 0; i < len; i++) {
        let v = src[i];
        if (i < f) { const k = i / f; v = src[i] * k + src[len + i] * (1 - k); }
        d[i] = v; sum += v * v; n++;
      }
    }
    const g = 0.12 / Math.max(1e-6, Math.sqrt(sum / n));      // every loop at the same loudness
    for (let ch = 0; ch < 2; ch++) { const d = out.getChannelData(ch); for (let i = 0; i < len; i++) d[i] *= g; }
    return out;
  }

  // the chatter: voices of filtered noise, each talking in syllables (a vowel's two formants each), phrases, pauses
  async function chatter(seconds, voices) {
    const rate = 22050, total = seconds + 1.5;
    const off = new OfflineAudioContext(2, Math.floor(rate * total), rate);
    const nbuf = off.createBuffer(1, rate * 2, rate);
    const nd = nbuf.getChannelData(0);
    for (let i = 0; i < nd.length; i++) nd[i] = Math.random() * 2 - 1;
    for (let v = 0; v < voices; v++) {
      const src = off.createBufferSource(); src.buffer = nbuf; src.loop = true;
      const f1 = off.createBiquadFilter(), f2 = off.createBiquadFilter();
      f1.type = f2.type = 'bandpass'; f1.Q.value = 4 + Math.random() * 3; f2.Q.value = 6 + Math.random() * 4;
      const env = off.createGain(), pan = off.createStereoPanner();
      env.gain.value = 0; pan.pan.value = Math.random() * 1.8 - 0.9;
      const low = Math.random() < 0.5 ? 0.85 : 1.15;          // lower and higher voices
      src.connect(f1); src.connect(f2); f1.connect(env); f2.connect(env); env.connect(pan); pan.connect(off.destination);
      let t = Math.random() * 2;
      while (t < total) {
        const words = 3 + Math.floor(Math.random() * 10);   // a phrase
        for (let w = 0; w < words && t < total; w++) {
          const syl = 1 + Math.floor(Math.random() * 3);
          for (let s = 0; s < syl && t < total; s++) {
            const dur = 0.07 + Math.random() * 0.16, amp = (0.3 + Math.random() * 0.7) / Math.sqrt(voices);
            f1.frequency.setValueAtTime((280 + Math.random() * 600) * low, t);
            f2.frequency.setValueAtTime((900 + Math.random() * 1700) * low, t);
            env.gain.setValueAtTime(0, t);
            env.gain.linearRampToValueAtTime(amp, t + dur * 0.3);
            env.gain.linearRampToValueAtTime(amp * 0.6, t + dur * 0.75);
            env.gain.linearRampToValueAtTime(0, t + dur);
            t += dur + 0.01 + Math.random() * 0.04;
          }
          t += 0.04 + Math.random() * 0.12;                   // between words
        }
        t += 0.4 + Math.random() * 2.2;                       // between phrases
      }
      src.start(Math.random() * 0.5);
    }
    return loopOf(await off.startRendering(), seconds, 1.2);
  }

  // the roar: pink noise through a wide band, swelling and falling ("ohhh", "yeahhh")
  async function roar(seconds) {
    const rate = 22050, total = seconds + 2;
    const off = new OfflineAudioContext(2, Math.floor(rate * total), rate);
    const keep = ctx; ctx = off; const pn = noise(total, 'pink'); ctx = keep;
    const src = off.createBufferSource(); src.buffer = pn;
    const hp = off.createBiquadFilter(), lp = off.createBiquadFilter(), g = off.createGain();
    hp.type = 'highpass'; hp.frequency.value = 220; lp.type = 'lowpass'; lp.frequency.value = 3200;
    src.connect(hp); hp.connect(lp); lp.connect(g); g.connect(off.destination);
    let t = 0; g.gain.setValueAtTime(0.6, 0);
    while (t < total) { t += 0.6 + Math.random() * 1.6; g.gain.linearRampToValueAtTime(0.45 + Math.random() * 0.55, t); }
    src.start(0);
    return loopOf(await off.startRendering(), seconds, 1.5);
  }

  async function build() {
    if (building || mix) return;
    building = true;
    ctx = new (window.AudioContext || window.webkitAudioContext)();
    const master = ctx.createGain(); master.gain.value = 0; master.connect(ctx.destination);
    const walls = ctx.createBiquadFilter(); walls.type = 'lowpass'; walls.frequency.value = 9000; walls.connect(master);
    const loop = (buf, to, rate) => {
      const s = ctx.createBufferSource(); s.buffer = buf; s.loop = true; s.playbackRate.value = rate || 1;
      const g = ctx.createGain(); g.gain.value = 0; s.connect(g); g.connect(to); s.start(0, Math.random() * buf.duration);
      return g;
    };
    // the room tone: a low rumble and a little air, breathing slowly
    const rumble = ctx.createBiquadFilter(); rumble.type = 'lowpass'; rumble.frequency.value = 200; rumble.connect(master);
    const air = ctx.createBiquadFilter(); air.type = 'bandpass'; air.frequency.value = 700; air.Q.value = 0.4; air.connect(master);
    const tone = loop(noise(6, 'brown'), rumble);
    const hiss = loop(noise(5, 'pink'), air);
    const lfo = ctx.createOscillator(), lfoGain = ctx.createGain();
    lfo.frequency.value = 0.06; lfoGain.gain.value = 40; lfo.connect(lfoGain); lfoGain.connect(rumble.frequency); lfo.start();
    mix = { master, walls, tone, hiss, walla: null, walla2: null, roar: null };
    apply();
    // the crowd's sounds take a moment to render: they join when ready
    const [c1, c2, r] = await Promise.all([chatter(14, 28), chatter(11, 22), roar(10)]);
    mix.walla = loop(c1, walls, 1);
    mix.walla2 = loop(c2, walls, 0.94);
    mix.roar = loop(r, walls, 1);
    building = false;
    apply();
  }

  function apply() {
    if (!cfg) return;
    const inside = st.zone && st.zone !== 'outside' && mine > 0 && (cfg.volume || 0) > 0;
    if (inside && !ctx) { build(); return; }
    if (!mix) return;
    if (inside && ctx.state === 'suspended') ctx.resume().catch(() => {});
    const z = (cfg.zones || {})[st.zone] || { tone: 0, walla: 0, lowpass: 9000 };
    const m = (cfg.moods || {})[st.mood] || { walla: 0.6, roar: 0 };
    const t = ctx.currentTime;
    mix.master.gain.setTargetAtTime(inside ? (cfg.volume || 0.5) * mine / 100 : 0, t, 0.6);
    mix.walls.frequency.setTargetAtTime(z.lowpass || 9000, t, 0.4);
    mix.tone.gain.setTargetAtTime((z.tone || 0) * 1.0, t, 0.8);
    mix.hiss.gain.setTargetAtTime((z.tone || 0) * 0.35, t, 0.8);
    const crowd = st.crowd ? (z.walla || 0) : 0;
    if (mix.walla) mix.walla.gain.setTargetAtTime(crowd * (m.walla || 0), t, 1.2);
    if (mix.walla2) mix.walla2.gain.setTargetAtTime(crowd * (m.walla || 0) * 0.8, t, 1.2);
    if (mix.roar) mix.roar.gain.setTargetAtTime(crowd * (m.roar || 0), t, 1.5);
    // outside for a while: the sound stops working (suspended) until you are back
    clearTimeout(idleTimer);
    if (!inside) idleTimer = setTimeout(() => { if (ctx && ctx.state === 'running') ctx.suspend().catch(() => {}); }, 4000);
  }

  // the desk's slider: your own level
  const slider = $('#amb-mine');
  if (slider) {
    let timer = null;
    slider.oninput = (e) => {
      $('#amb-mine-val').textContent = e.target.value;
      mine = +e.target.value; apply();
      if (!timer) timer = setTimeout(() => { timer = null; nui('ambienceMine', { value: +slider.value }); }, 250);
    };
  }
  const renderMine = () => {
    if (slider && document.activeElement !== slider) { slider.value = mine; $('#amb-mine-val').textContent = mine; }
  };

  window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.type !== 'ambience') return;
    if (m.config) cfg = m.config;
    if (m.mine !== undefined) { mine = m.mine; renderMine(); }
    if (m.zone !== undefined) st = { zone: m.zone, crowd: !!m.crowd, mood: m.mood || 'show' };
    apply();
  });

  nui('ambienceReady');
})();
