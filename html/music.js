// mzb_arena - the music player's sound (client/music.lua tells it what to play, where in it to be and where the
// listener is) and the desk's Music section. The sound runs in this page whether the desk is open or not.
// There is one way to play, and it is in the world: the track goes through Web Audio, out of every speaker of the
// show as a source of its own (a PannerNode each; the listener is the game's camera), through the walls when the
// listener is not in the bowl, with the arena on top of it (a reverb and an echo off the far end, both fed from the
// placed sound, so they come from where the speakers are and fall away with them).
// Where the sound comes from:
//   * a YouTube link: a hidden YouTube player. The game's browser lets this page reach into it, so the player's own
//     <video> element is taken into the Web Audio graph (the player stays muted until it is: never heard "flat")
//   * a file or stream: an <audio> element taken into the graph the same way, from the link itself or, when the
//     server has fetched it (Config.Music.relay), from the server's relay
// A track whose sound cannot be taken into the graph is reported and stays silent.
(() => {
  const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'mzb_arena';
  const $ = (s) => document.querySelector(s);
  const nui = (name, body) =>
    fetch(`https://${res}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body || {}) }).catch(() => {});

  let music = null, cfg = null, mine = 100;
  let listen = { zone: 'outside', level: 0, speakers: [] };
  let failed = null;            // why this track does not play here
  let tries = [];               // the addresses still to try for this file: { url, cors }
  const playing = () => music && (music.kind === 'file' || music.kind === 'youtube');

  const el = new Audio(); el.preload = 'auto';
  let ctx = null, g = null, elNode = null;

  // the arena's reverb: a few early reflections, then a dense tail that dies away, its top end first
  function impulse(seconds) {
    const rate = ctx.sampleRate, len = Math.max(1, Math.floor(rate * seconds));
    const buf = ctx.createBuffer(2, len, rate);
    for (let ch = 0; ch < 2; ch++) {
      const d = buf.getChannelData(ch);
      let lp = 0;
      for (let i = 0; i < len; i++) {
        const t = i / len;
        const early = i < rate * 0.14 && Math.random() < 0.003 ? (Math.random() < 0.5 ? -0.9 : 0.9) : 0;
        lp += ((Math.random() * 2 - 1) - lp) * (0.85 - 0.7 * t);       // darker as it decays
        d[i] = lp * Math.exp(-6.9 * t) + early * (1 - t);
      }
    }
    return buf;
  }

  // Config.Music.boost: how many times louder the whole of it leaves the page (1 = as it was before the setting)
  const boostOf = () => Math.max(0.1, Math.min(8, (cfg && +cfg.boost) || 1));

  // a source (the <audio> element, the YouTube player's <video>) -> mono -> a gain and a panner per speaker -> the
  // house bus -> walls (low-pass) -> dry, and walls -> reverb, echo; speakers in the listener's own room -> their own
  // bus (no walls, no arena); then the level, the boost and the limiter
  function build() {
    if (g) return g;
    ctx = new (window.AudioContext || window.webkitAudioContext)();
    const mono = ctx.createGain();
    mono.channelCount = 1; mono.channelCountMode = 'explicit'; mono.channelInterpretation = 'speakers';
    const meter = ctx.createAnalyser(); meter.fftSize = 256;
    const house = ctx.createGain(), own = ctx.createGain(), zone = ctx.createGain(), master = ctx.createGain();
    const walls = ctx.createBiquadFilter(); walls.type = 'lowpass'; walls.frequency.value = 20000; walls.Q.value = 0.5;
    const dry = ctx.createGain(), wet = ctx.createGain();
    const pre = ctx.createDelay(0.5), conv = ctx.createConvolver();
    pre.delayTime.value = Math.max(0, Math.min(0.4, (cfg && cfg.preDelay) || 0.035));
    conv.buffer = impulse((cfg && cfg.reverbSeconds) || 3.0);
    const echo = ctx.createDelay(1.5), echoLp = ctx.createBiquadFilter(), echoBack = ctx.createGain(), echoOut = ctx.createGain();
    echoLp.type = 'lowpass'; echoLp.frequency.value = 2600;
    const e = (cfg && cfg.echo) || null;
    echo.delayTime.value = e ? Math.max(0.03, Math.min(1.4, e.delay || 0.21)) : 0.21;
    echoBack.gain.value = e ? Math.max(0, Math.min(0.7, e.feedback || 0)) : 0;
    master.gain.value = 0; zone.gain.value = 0; wet.gain.value = 0; echoOut.gain.value = 0;
    mono.connect(meter);
    house.connect(walls); walls.connect(dry); dry.connect(zone);
    walls.connect(pre); pre.connect(conv); conv.connect(wet); wet.connect(zone);
    walls.connect(echo); echo.connect(echoLp); echoLp.connect(echoOut); echoOut.connect(zone);
    echoLp.connect(echoBack); echoBack.connect(echo);
    // louder without touching the mix: one gain after everything (speakers, walls, reverb and echo keep their
    // balance), then a limiter that only works on the peaks a loud track would otherwise clip
    const boost = ctx.createGain(), limit = ctx.createDynamicsCompressor();
    boost.gain.value = boostOf();
    limit.threshold.value = -4; limit.knee.value = 3; limit.ratio.value = 20;
    limit.attack.value = 0.002; limit.release.value = 0.12;
    zone.connect(master); own.connect(master); master.connect(boost); boost.connect(limit); limit.connect(ctx.destination);
    g = { mono, meter, house, own, zone, master, boost, walls, dry, wet, echoOut, sp: [] };
    return g;
  }

  // the game's x, y, z (z up) as Web Audio's (y up, -z ahead)
  const wa = (v) => [v[0], v[2], -v[1]];
  const setParam = (p, v, t) => { if (p) p.setTargetAtTime(v, t, 0.05); };

  // one panner per speaker: { x, y, z, gain, ref (0 = the config's), in a room of its own (1) }
  function setSpeakers(list) {
    while (g.sp.length > list.length) { const p = g.sp.pop(); p.gain.disconnect(); p.node.disconnect(); }
    while (g.sp.length < list.length) {
      const node = ctx.createPanner(), gain = ctx.createGain();
      node.panningModel = (cfg && cfg.panning) || 'HRTF';
      node.distanceModel = 'inverse';
      node.rolloffFactor = (cfg && cfg.rolloff) || 0.7;
      node.maxDistance = 10000;
      gain.gain.value = 0;
      g.mono.connect(gain); gain.connect(node);
      g.sp.push({ node, gain, to: null });
    }
    const t = ctx.currentTime;
    const weight = list.reduce((a, s) => a + (s[5] ? 0 : (s[3] || 1)), 0);     // the house's speakers share one level
    list.forEach((s, i) => {
      const p = g.sp[i], [x, y, z] = wa(s), to = s[5] ? g.own : g.house;
      if (p.to !== to) { if (p.to) p.node.disconnect(); p.node.connect(to); p.to = to; }
      if (p.node.positionX) { p.node.positionX.value = x; p.node.positionY.value = y; p.node.positionZ.value = z; }
      else p.node.setPosition(x, y, z);
      p.node.refDistance = s[4] > 0 ? s[4] : (cfg.refDistance || 12);
      p.gain.gain.setTargetAtTime(s[5] ? (s[3] || 1) : 1.6 * (s[3] || 1) / Math.max(1, weight), t, 0.05);
    });
  }

  function setListener(cam, fwd, up) {
    if (!cam || !fwd || !up) return;
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

  // how far the listener is from the nearest speaker of the house (m)
  function nearest() {
    let best = Infinity;
    const c = listen.cam;
    if (!c) return 0;
    for (const s of listen.speakers || []) {
      if (s[5]) continue;
      best = Math.min(best, Math.hypot(s[0] - c[0], s[1] - c[1], s[2] - c[2]));
    }
    return isFinite(best) ? best : 0;
  }

  // a fade-out (the desk's Fade out, /arenamusic fade): the level comes down to nothing over its seconds - quickly
  // at first, as a hand on a fader does - and the server stops the track when it is there
  let fadeEnd = 0, fadeMs = 0, fadeTimer = null;
  const fadeLevel = () => { if (!fadeMs) return 1; const x = Math.max(0, Math.min(1, (fadeEnd - performance.now()) / fadeMs)); return x * x; };
  function setFade(f) {
    clearInterval(fadeTimer); fadeTimer = null;
    if (!f || !(f.dur > 0)) { fadeMs = 0; return; }
    fadeMs = f.dur * 1000; fadeEnd = performance.now() + Math.max(0, f.left) * 1000;
    fadeTimer = setInterval(() => { apply(); if (performance.now() >= fadeEnd) { clearInterval(fadeTimer); fadeTimer = null; } }, 50);
  }

  function apply() {
    if (!g || !cfg) return;
    const t = ctx.currentTime, on = playing() && !failed;
    const room = (cfg.rooms || {})[listen.zone] || { lowpass: 20000, wet: 0 };
    setSpeakers(on ? (listen.speakers || []) : []);
    setListener(listen.cam, listen.fwd, listen.up);
    const ref = cfg.refDistance || 12;
    const far = Math.max(0, Math.min(1, (nearest() - ref) / 40));        // far from every speaker: more of the room
    const wet = Math.min(0.9, (room.wet || 0) * (1 + (cfg.farWet || 0) * far));
    g.master.gain.setTargetAtTime(on ? (music.volume || 0) / 100 * (mine / 100) * (cfg.volume || 0.8) * fadeLevel() : 0, t, fadeMs ? 0.03 : 0.08);
    g.boost.gain.setTargetAtTime(boostOf(), t, 0.08);
    g.zone.gain.setTargetAtTime(listen.level || 0, t, 0.15);
    g.walls.frequency.setTargetAtTime(room.lowpass || 20000, t, 0.15);
    g.wet.gain.setTargetAtTime(wet, t, 0.2);
    g.dry.gain.setTargetAtTime(1 - wet * 0.35, t, 0.2);
    g.echoOut.gain.setTargetAtTime(cfg.echo ? (cfg.echo.level || 0) * (listen.zone === 'bowl' ? 1 : 0.5) : 0, t, 0.2);
  }

  // ---- what this page is doing, for /arenamusic status (sent when it changes)
  let lastState = '', signal = null;
  function state() {
    if (!music) return;
    const s = { rev: music.rev, zone: listen.zone, speakers: g ? g.sp.length : 0, signal, error: failed || undefined };
    const key = JSON.stringify(s);
    if (key !== lastState) { lastState = key; nui('musicState', s); }
  }
  // is there sound in the graph at all? (a source Web Audio may not read comes out as silence)
  const position = () => (music && music.kind === 'youtube' ? (yt && ytIn && yt.getCurrentTime ? yt.getCurrentTime() || 0 : 0) : (el.paused ? 0 : el.currentTime));
  setInterval(() => {
    if (!g || !playing() || failed || music.paused || !(position() > 0)) return;
    const d = new Uint8Array(g.meter.fftSize);
    g.meter.getByteTimeDomainData(d);
    let heard = false;
    for (let i = 0; i < d.length; i++) if (d[i] !== 128) { heard = true; break; }
    if (heard) signal = true; else if (signal === null && position() > 4) signal = false;
    state();
  }, 1000);

  function report(msg) {
    if (failed || !music) return;
    failed = String(msg);
    el.pause();
    if (yt && yt.mute) { try { yt.mute(); yt.pauseVideo(); } catch (e) { /* the player is gone */ } }
    apply();
    nui('musicError', { rev: music.rev, msg: failed });
    deskError(failed);
    state();
  }

  // ---- keeping time
  let want = 0, wantAt = 0;   // the position we were given and when
  const now = () => want + (music && music.paused ? 0 : (performance.now() - wantAt) / 1000);
  // A new track is given a moment before its start (Config.Music.leadIn: the position is below 0 until then): it is
  // loaded and held at its start, and started when the moment comes, so its first second is not lost to the loading
  let startTimer = null;
  const startLater = (fn) => { clearTimeout(startTimer); startTimer = setTimeout(fn, Math.max(0, -now() * 1000)); };

  // ---- files and streams: the <audio> element, in the graph from the start
  function seekPlay() {
    if (!music || failed) return;
    clearTimeout(startTimer);
    const live = music.live || !isFinite(el.duration);
    if (!live && now() < 0) {                                    // not yet: loaded and waiting at its start
      el.pause();
      if (el.currentTime > 0.05) el.currentTime = 0;
      if (!music.paused) startLater(seekPlay);
      return;
    }
    if (!live) {
      if (now() >= el.duration) { el.pause(); return; }          // the track is over by now
      if (Math.abs(el.currentTime - now()) > 1.0) el.currentTime = now();
    }
    if (music.paused) { el.pause(); return; }
    if (ctx.state === 'suspended') ctx.resume().catch(() => {});
    const p = el.play();
    if (p && p.catch) p.catch((e) => { if (e && e.name === 'NotAllowedError') report('the browser blocked playback'); });
  }

  // where the audio is: the link itself or the server's relay (at each address this player can reach it by). Each
  // is asked for the way a server that names who may read it wants, then plainly (the game's browser reads it anyway)
  function sources(m) {
    const urls = m.relay ? ((cfg && cfg.bases) || []).map((b) => String(b).replace(/\/+$/, '') + '/music/' + encodeURIComponent(m.relay))
      : (m.url ? [m.url] : []);
    const out = [];
    for (const url of urls) { out.push({ url, cors: true }); if (!m.relay) out.push({ url, cors: false }); }
    return out;
  }
  function tryNext() {
    const t = tries.shift();
    if (!t) {
      return report(music.relay ? 'the server\'s music relay cannot be reached from here (its HTTP port)'
        : 'the link does not play here (dead, not audio, or a format the game\'s browser does not have)');
    }
    if (t.cors) el.crossOrigin = 'anonymous'; else el.removeAttribute('crossorigin');
    el.src = t.url;
  }
  el.onerror = () => { if (music && music.kind === 'file' && !failed && el.getAttribute('src')) tryNext(); };
  el.onloadedmetadata = () => { if (music && music.kind === 'file') { apply(); seekPlay(); state(); } };

  // ---- YouTube: a hidden player whose own <video> element is taken into the graph
  let yt = null, ytIn = false, ytNode = null, ytVideo = null, ytApi = false, ytWanted = null, ytSeq = 0;
  const holder = document.createElement('div');
  holder.style.cssText = 'position:absolute;left:-400px;top:0;width:200px;height:200px;overflow:hidden';
  document.body.appendChild(holder);
  const prevReady = window.onYouTubeIframeAPIReady;
  window.onYouTubeIframeAPIReady = () => { if (prevReady) prevReady(); ytApi = true; if (ytWanted) loadYoutube(ytWanted); };

  // the player's <video>, out of its frame and into the graph; only then is the player unmuted
  function takeIn(player, seq) {
    let doc = null;
    try { const f = player.getIframe(); doc = f.contentDocument || f.contentWindow.document; } catch (e) { doc = null; }
    if (!doc) {
      return report('the browser does not let this page take the YouTube player\'s sound (Config.Music.relay.enabled fetches it on the server instead)');
    }
    let waited = 0;
    const timer = setInterval(() => {
      if (seq !== ytSeq) return clearInterval(timer);            // another track since
      const video = doc.querySelector('video');
      waited += 50;
      if (!video) { if (waited > 5000) { clearInterval(timer); report('the YouTube player has no video to take the sound from'); } return; }
      clearInterval(timer);
      try {
        ytNode = ctx.createMediaElementSource(video);
        ytNode.connect(g.mono);
        ytIn = true; ytVideo = video;
        syncYoutube(true);                                       // (held at its start first, if it is not time yet)
        player.setVolume(100); player.unMute();
        state();
      } catch (e) {
        report('the YouTube player\'s sound could not be taken into the room (' + ((e && e.name) || 'error') + ')');
      }
    }, 50);
  }

  function loadYoutube(id) {
    if (!ytApi) {
      ytWanted = id;
      if (!document.getElementById('yt-api')) {
        const s = document.createElement('script'); s.id = 'yt-api'; s.src = 'https://www.youtube.com/iframe_api';
        s.onerror = () => report('YouTube cannot be reached from here');
        document.head.appendChild(s);
      }
      return;
    }
    ytWanted = null;
    const seq = ++ytSeq;
    // a player that never gets going (a video that may not be embedded, YouTube out of reach) is said, not waited for
    setTimeout(() => {
      if (seq === ytSeq && !ytIn && !failed && music && !music.paused) report('the YouTube player did not start (the video may not allow being embedded)');
    }, 15000);
    holder.innerHTML = '<div id="mzb-yt"></div>';
    yt = new YT.Player('mzb-yt', {
      width: '200', height: '200', videoId: id,
      // it starts muted and is started by hand once it is ready: not a moment of it is heard outside the graph
      playerVars: { autoplay: 0, mute: 1, controls: 0, disablekb: 1, playsinline: 1, start: Math.max(0, Math.floor(now())) },
      events: {
        onReady: (e) => { if (seq !== ytSeq) return; e.target.mute(); e.target.playVideo(); },
        onStateChange: (e) => { if (seq === ytSeq && !ytIn && !failed && e.data === 1) takeIn(e.target, seq); },   // playing
        onError: (e) => { if (seq === ytSeq) report('YouTube refused the video (error ' + e.data + ')'); },
      },
    });
  }
  function syncYoutube(seek) {
    if (!yt || !ytIn || !music || music.kind !== 'youtube' || failed) return;
    clearTimeout(startTimer);
    apply();
    if (ctx.state === 'suspended') ctx.resume().catch(() => {});
    if (now() < 0) {                                             // not yet: loaded and waiting at its start
      if ((yt.getCurrentTime() || 0) > 0.05) yt.seekTo(0, true);
      yt.pauseVideo();
      if (!music.paused) startLater(() => syncYoutube(false));
      return;
    }
    if (seek || Math.abs((yt.getCurrentTime() || 0) - now()) > 1.2) yt.seekTo(now(), true);
    if (music.paused) yt.pauseVideo(); else yt.playVideo();
  }

  function unload() {
    tries = [];
    clearTimeout(startTimer);
    setFade(null);
    el.pause(); el.removeAttribute('src'); el.load();
    ytSeq++; ytWanted = null; ytIn = false; ytVideo = null;
    if (ytNode) { try { ytNode.disconnect(); } catch (e) { /* gone */ } ytNode = null; }
    if (yt) { try { yt.mute(); yt.stopVideo(); yt.destroy(); } catch (e) { /* gone */ } yt = null; }
    holder.innerHTML = '';
    if (g) { g.master.gain.value = 0; setSpeakers([]); }
  }

  function load(m, pos) {
    unload();
    music = m; failed = null; signal = null; lastState = '';
    want = pos || 0; wantAt = performance.now();
    if (!playing()) return;
    build();
    if (m.kind === 'youtube') return loadYoutube(m.id);
    if (!elNode) { elNode = ctx.createMediaElementSource(el); elNode.connect(g.mono); }
    tries = sources(m);
    tryNext();
  }

  function sync(m, pos) {
    music = m;
    want = pos || 0; wantAt = performance.now();
    if (m.kind === 'youtube') syncYoutube(false);
    else if (el.getAttribute('src')) seekPlay();
    apply();
  }

  // (html/follow.js: the lights follow the music) the track as it goes into the graph, and the picture it comes with
  window.mzbMusicTap = () => (g && music && playing() && !failed
    ? { ctx, node: g.mono, rev: music.rev, video: ytIn ? ytVideo : null, playing: !music.paused && position() > 0 } : null);

  // ---- the desk's Music section
  let desk = { kind: 'off' };
  function deskError(msg) {
    for (const n of [$('#mus-now'), $('#q-mus-now')]) if (n) { n.textContent = 'will not play: ' + msg; n.classList.add('err'); }
  }
  function renderDesk() {
    const on = desk.kind === 'file' || desk.kind === 'youtube';
    const text = desk.kind === 'off' ? 'off' : desk.kind === 'loading' ? 'fetching ' + (desk.title || '') + ' ...'
      : (desk.title || '') + (desk.fade ? ' (fading out)' : desk.paused ? ' (paused)' : '');
    for (const n of [$('#mus-now'), $('#q-mus-now')]) { n.classList.remove('err'); n.textContent = text; }
    $('#mus-pause').textContent = desk.paused ? 'Resume' : 'Pause';
    $('#mus-pause').disabled = !on || !!desk.live;
    $('#mus-fade').disabled = $('#q-mus-fade').disabled = !on || !!desk.fade;
    $('#q-mus-stop').disabled = desk.kind === 'off';
    if (document.activeElement !== $('#mus-vol')) { $('#mus-vol').value = desk.volume || 0; $('#mus-vol-val').textContent = desk.volume || 0; }
    if (document.activeElement !== $('#mus-mine')) { $('#mus-mine').value = mine; $('#mus-mine-val').textContent = mine; }
  }
  const play = () => { const u = $('#mus-url').value.trim(); if (u) nui('music', { action: 'play', url: u }); };
  $('#mus-play').onclick = play;
  $('#mus-url').addEventListener('keyup', (e) => { if (e.key === 'Enter') play(); });
  $('#mus-pause').onclick = () => nui('music', { action: desk.paused ? 'resume' : 'pause' });
  $('#mus-stop').onclick = $('#q-mus-stop').onclick = () => nui('music', { action: 'stop' });
  $('#mus-fade').onclick = $('#q-mus-fade').onclick = () => nui('music', { action: 'fade' });
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
      if (m.enabled !== undefined) { $('#music').classList.toggle('hidden', !m.enabled); $('#q-mus').classList.toggle('hidden', !m.enabled); }
      renderDesk();
      return;
    }
    if (m.type !== 'music') return;
    if (m.action === 'load') { cfg = m.config; mine = m.mine; load(m.music, m.pos); setFade(m.fade); apply(); }
    else if (m.action === 'sync') { setFade(m.fade); sync(m.music, m.pos); }
    else if (m.action === 'unload') { unload(); music = null; }
    else if (m.action === 'mine') { mine = m.mine; apply(); }
    else if (m.action === 'listen') {
      listen = m;
      apply();
      state();
    }
  });

  // this page is listening now: a track sent before it was (the resource just started) is sent again
  nui('musicReady');
})();
