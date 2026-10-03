// mzb_arena - the music player's sound (client/music.lua tells it what to play, where in it to be and where the
// listener is) and the desk's Music section. The sound runs in this page whether the desk is open or not.
// Two ways to play: an <audio> fed through Web Audio when the audio's server allows it (CORS) - in the bowl the track
// comes out of every PA hang of the show as a sound in 3D (a PannerNode each; the listener is the game's camera),
// elsewhere through the walls (the room's filter and echo) - and a plain <audio> / a hidden YouTube player that only
// get the level when it does not (YouTube can't be fed through Web Audio).
(() => {
  const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'mzb_arena';
  const $ = (s) => document.querySelector(s);
  const nui = (name, body) =>
    fetch(`https://${res}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body || {}) }).catch(() => {});

  let music = null, cfg = null, mine = 100;
  let listen = { zone: 'outside', level: 0, dist: 0, pan: 0 };
  let mode = null;            // 'graph' | 'plain' | 'youtube' | null
  let failed = false;

  // ---- Web Audio: source -> low-pass -> (the hangs in 3D | flat, the echo) -> level -> out
  let ctx = null, graph = null;
  const graphEl = new Audio(); graphEl.crossOrigin = 'anonymous'; graphEl.preload = 'auto';
  const plainEl = new Audio(); plainEl.preload = 'auto';

  function impulse(seconds) {
    const rate = ctx.sampleRate, len = Math.floor(rate * seconds);
    const buf = ctx.createBuffer(2, len, rate);
    for (let ch = 0; ch < 2; ch++) {
      const d = buf.getChannelData(ch);
      for (let i = 0; i < len; i++) {
        const t = i / len;
        // a few early reflections, then a dense tail dying away: a big hard-walled room
        const early = i < rate * 0.12 && Math.random() < 0.004 ? 0.8 : 0;
        d[i] = ((Math.random() * 2 - 1) * Math.pow(1 - t, 3.2) + early) * (ch ? 0.92 : 1);
      }
    }
    return buf;
  }

  function buildGraph() {
    if (graph) return graph;
    ctx = new (window.AudioContext || window.webkitAudioContext)();
    const src = ctx.createMediaElementSource(graphEl);
    const lp = ctx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 20000; lp.Q.value = 0.5;
    const dry = ctx.createGain(), wet = ctx.createGain(), conv = ctx.createConvolver();
    conv.buffer = impulse((cfg && cfg.reverbSeconds) || 3.2);
    const pan = ctx.createStereoPanner(), master = ctx.createGain();
    const spatial = ctx.createGain(), flat = ctx.createGain();
    master.gain.value = 0; spatial.gain.value = 0; flat.gain.value = 1;
    src.connect(lp); lp.connect(conv); conv.connect(wet); wet.connect(master);
    lp.connect(dry); dry.connect(flat); flat.connect(pan); pan.connect(master);
    spatial.connect(master); master.connect(ctx.destination);
    graph = { lp, dry, wet, pan, master, spatial, flat, panners: [] };
    return graph;
  }

  // the game's x, y, z (z up) as Web Audio's (y up, -z ahead)
  const wa = (v) => [v[0], v[2], -v[1]];
  const setParam = (p, v, t) => { if (p) p.setTargetAtTime(v, t, 0.05); };

  // one panner per hang of the show, fed from the low-pass, into the spatial bus
  function setHangs(hangs) {
    const g = graph;
    if (!g || !hangs) return;
    while (g.panners.length > hangs.length) { const p = g.panners.pop(); p.node.disconnect(); p.gain.disconnect(); }
    while (g.panners.length < hangs.length) {
      const node = ctx.createPanner(), gain = ctx.createGain();
      node.panningModel = (cfg && cfg.panning) || 'HRTF';
      node.distanceModel = 'inverse';
      node.refDistance = (cfg && cfg.refDistance) || 12;
      node.rolloffFactor = (cfg && cfg.rolloff) || 0.7;
      node.maxDistance = 10000;
      g.lp.connect(gain); gain.connect(node); node.connect(g.spatial);
      g.panners.push({ node, gain });
    }
    const t = ctx.currentTime, share = 1 / Math.max(1, hangs.length);
    hangs.forEach((h, i) => {
      const p = g.panners[i], [x, y, z] = wa(h);
      if (p.node.positionX) { p.node.positionX.value = x; p.node.positionY.value = y; p.node.positionZ.value = z; }
      else p.node.setPosition(x, y, z);
      p.gain.gain.setTargetAtTime(share * 1.6, t, 0.05);
    });
  }

  function setListener(cam, fwd, up) {
    if (!ctx || !cam || !fwd || !up) return;
    const L = ctx.listener, t = ctx.currentTime;
    const [x, y, z] = wa(cam), [fx, fy, fz] = wa(fwd), [ux, uy, uz] = wa(up);
    if (L.positionX) {
      setParam(L.positionX, x, t); setParam(L.positionY, y, t); setParam(L.positionZ, z, t);
      setParam(L.forwardX, fx, t); setParam(L.forwardY, fy, t); setParam(L.forwardZ, fz, t);
      setParam(L.upX, ux, t); setParam(L.upY, uy, t); setParam(L.upZ, uz, t);
    } else {
      L.setPosition(x, y, z);
      L.setOrientation(fx, fy, fz, ux, uy, uz);
    }
  }

  // the level for where the listener is: the operator's volume, your own, the zone, and (without the 3D hangs, which
  // fall off by themselves) the distance to the nearest PA
  const spatialOn = () => mode === 'graph' && listen.zone === 'bowl' && listen.hangs && listen.hangs.length > 0;
  function level() {
    if (!music || !cfg || music.kind === 'off') return 0;
    const ref = cfg.refDistance || 12;
    const byDist = listen.zone === 'bowl' && !spatialOn()
      ? Math.max(cfg.minGain || 0.3, Math.min(1, ref / Math.max(ref, listen.dist || 0))) : 1;
    return (music.volume || 0) / 100 * (mine / 100) * (cfg.volume || 0.8) * (listen.level || 0) * byDist;
  }

  function apply() {
    const g = level();
    if (mode === 'graph' && graph) {
      const room = (cfg.rooms || {})[listen.zone] || { lowpass: 20000, wet: 0 };
      const t = ctx.currentTime, k = 0.08, sp = spatialOn();
      if (sp) { setHangs(listen.hangs); setListener(listen.cam, listen.fwd, listen.up); }
      graph.master.gain.setTargetAtTime(g, t, k);
      graph.spatial.gain.setTargetAtTime(sp ? 1 : 0, t, 0.25);
      graph.flat.gain.setTargetAtTime(sp ? 0 : 1, t, 0.25);
      graph.pan.pan.setTargetAtTime(Math.max(-1, Math.min(1, listen.pan || 0)), t, k);
      graph.lp.frequency.setTargetAtTime(room.lowpass || 20000, t, 0.15);
      graph.wet.gain.setTargetAtTime(room.wet || 0, t, 0.15);
      graph.dry.gain.setTargetAtTime(1 - (room.wet || 0) * 0.5, t, 0.15);
    } else if (mode === 'plain') {
      plainEl.volume = Math.max(0, Math.min(1, g));
    } else if (mode === 'youtube' && yt && ytReady) {
      yt.setVolume(Math.round(Math.max(0, Math.min(1, g)) * 100));
    }
  }

  function report(msg) {
    if (failed || !music) return;
    failed = true;
    nui('musicError', { rev: music.rev, msg: String(msg) });
    deskError(msg);
  }

  // ---- files and streams
  let want = 0, wantAt = 0;   // the position we were given and when
  const now = () => want + (music && music.paused ? 0 : (performance.now() - wantAt) / 1000);

  function seekPlay(el) {
    const live = !isFinite(el.duration);
    if (!live) {
      if (now() >= el.duration) { el.pause(); return; }          // the track is over by now
      if (Math.abs(el.currentTime - now()) > 1.0) el.currentTime = now();
    }
    if (music.paused) { el.pause(); return; }
    if (ctx && ctx.state === 'suspended') ctx.resume().catch(() => {});
    const p = el.play();
    if (p && p.catch) p.catch((e) => report(e && e.name === 'NotAllowedError' ? 'the browser blocked playback' : (e && e.message) || 'play failed'));
  }

  function loadFile(url) {
    // first through Web Audio (needs CORS); if the server refuses, again without it
    mode = 'graph';
    buildGraph();
    graphEl.onerror = () => {
      if (mode !== 'graph') return;
      graphEl.removeAttribute('src'); graphEl.load();
      mode = 'plain';
      plainEl.onerror = () => { if (mode === 'plain') report('the link does not play (dead, or not audio)'); };
      plainEl.onloadedmetadata = () => { apply(); seekPlay(plainEl); };
      plainEl.src = url;
    };
    graphEl.onloadedmetadata = () => { apply(); seekPlay(graphEl); };
    graphEl.src = url;
  }

  // ---- YouTube (a hidden player; the IFrame API loads the first time it is needed)
  let yt = null, ytReady = false, ytApi = false, ytWanted = null;
  const prevReady = window.onYouTubeIframeAPIReady;
  window.onYouTubeIframeAPIReady = () => { if (prevReady) prevReady(); ytApi = true; if (ytWanted) loadYoutube(ytWanted); };
  function loadYoutube(id) {
    mode = 'youtube';
    if (!ytApi) {
      ytWanted = id;
      if (!document.getElementById('yt-api')) {
        const s = document.createElement('script'); s.id = 'yt-api'; s.src = 'https://www.youtube.com/iframe_api';
        document.head.appendChild(s);
      }
      return;
    }
    ytWanted = null;
    if (yt && ytReady) { yt.loadVideoById({ videoId: id, startSeconds: Math.floor(now()) }); syncYoutube(true); return; }
    yt = new YT.Player('music-yt-player', {
      width: '200', height: '200', videoId: id,
      playerVars: { autoplay: 1, controls: 0, disablekb: 1, playsinline: 1, start: Math.floor(now()) },
      events: {
        onReady: () => { ytReady = true; syncYoutube(true); },
        onError: (e) => report('YouTube refused the video (error ' + e.data + ')'),
      },
    });
  }
  function syncYoutube(seek) {
    if (!yt || !ytReady || mode !== 'youtube') return;
    apply();
    if (seek || Math.abs((yt.getCurrentTime() || 0) - now()) > 1.5) yt.seekTo(now(), true);
    if (music.paused) yt.pauseVideo(); else yt.playVideo();
  }

  function unload() {
    [graphEl, plainEl].forEach((el) => { el.onerror = null; el.pause(); el.removeAttribute('src'); el.load(); });
    if (yt && ytReady) yt.stopVideo();
    ytWanted = null;
    mode = null;
    if (graph) graph.master.gain.value = 0;
  }

  function load(m, pos) {
    unload();
    music = m; failed = false;
    want = pos || 0; wantAt = performance.now();
    if (m.kind === 'youtube') loadYoutube(m.id);
    else if (m.kind === 'file') loadFile(m.url);
  }

  function sync(m, pos) {
    music = m;
    want = pos || 0; wantAt = performance.now();
    if (mode === 'graph' && graphEl.src) seekPlay(graphEl);
    else if (mode === 'plain' && plainEl.src) seekPlay(plainEl);
    else if (mode === 'youtube') syncYoutube(false);
    apply();
  }

  // ---- the desk's Music section
  let desk = { kind: 'off' };
  function deskError(msg) { const n = $('#mus-now'); if (n) { n.textContent = 'will not play: ' + msg; n.classList.add('err'); } }
  function renderDesk() {
    const n = $('#mus-now');
    n.classList.remove('err');
    n.textContent = desk.kind === 'off' ? 'off' : (desk.title || '') + (desk.paused ? ' (paused)' : '');
    $('#mus-pause').textContent = desk.paused ? 'Resume' : 'Pause';
    $('#mus-pause').disabled = desk.kind === 'off';
    if (document.activeElement !== $('#mus-vol')) { $('#mus-vol').value = desk.volume || 0; $('#mus-vol-val').textContent = desk.volume || 0; }
    if (document.activeElement !== $('#mus-mine')) { $('#mus-mine').value = mine; $('#mus-mine-val').textContent = mine; }
  }
  const play = () => { const u = $('#mus-url').value.trim(); if (u) nui('music', { action: 'play', url: u }); };
  $('#mus-play').onclick = play;
  $('#mus-url').addEventListener('keyup', (e) => { if (e.key === 'Enter') play(); });
  $('#mus-pause').onclick = () => nui('music', { action: desk.paused ? 'resume' : 'pause' });
  $('#mus-stop').onclick = () => nui('music', { action: 'stop' });
  const slider = (id, label, send) => {
    let timer = null;
    $(id).oninput = (e) => {
      $(label).textContent = e.target.value;
      if (!timer) timer = setTimeout(() => { timer = null; send(+$(id).value); }, 200);
    };
  };
  slider('#mus-vol', '#mus-vol-val', (v) => nui('music', { action: 'volume', value: v }));
  slider('#mus-mine', '#mus-mine-val', (v) => { mine = v; apply(); nui('music', { action: 'mine', value: v }); });

  window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.type === 'musicDesk') {
      if (m.music) desk = m.music;
      if (m.mine !== undefined) mine = m.mine;
      if (m.enabled !== undefined) $('#music').classList.toggle('hidden', !m.enabled);
      renderDesk();
      return;
    }
    if (m.type !== 'music') return;
    if (m.action === 'load') { cfg = m.config; mine = m.mine; load(m.music, m.pos); }
    else if (m.action === 'sync') sync(m.music, m.pos);
    else if (m.action === 'unload') { unload(); music = null; }
    else if (m.action === 'mine') { mine = m.mine; apply(); }
    else if (m.action === 'listen') {
      listen = m;
      apply();
    }
  });

  // this page is listening now: a track sent before it was (the resource just started) is sent again
  nui('musicReady');
})();
