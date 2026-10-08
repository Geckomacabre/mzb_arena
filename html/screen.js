// mzb_arena - the video screens' page (a DUI, client/media.lua). It is told what to show and where in it to be;
// it never decides that itself, so every player's screens show the same thing.
(() => {
  const $ = (s) => document.querySelector(s);
  let media = null;          // GlobalState.mzbMedia as last sent
  let base = 0;              // performance.now() at position 0 (pictures)
  let volume = 0;            // 0..1, from where the listener is
  let yt = null, ytReady = false, ytApi = false, ytWanted = null;
  let shown = -1, front = 'a';

  // something will not play: the client is told (it tells whoever put the item on, once) - the screens only go black
  const res = location.hostname.replace(/^cfx-nui-/, '');
  let reported = null;
  function report(msg) {
    if (!media || reported === media.rev) return;
    reported = media.rev;
    fetch(`https://${res}/screenError`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ rev: media.rev, msg: String(msg) }) }).catch(() => {});
  }

  // ---- YouTube (the IFrame API, loaded the first time a video is wanted)
  window.onYouTubeIframeAPIReady = () => { ytApi = true; if (ytWanted) startYoutube(ytWanted.id, ytWanted.pos); };
  function loadApi() {
    if (document.getElementById('yt-api')) return;
    const s = document.createElement('script');
    s.id = 'yt-api';
    s.src = 'https://www.youtube.com/iframe_api';
    document.head.appendChild(s);
  }
  // where the video should be now: the position we were given plus the time since. A new video is given a moment
  // before its start (Config.Media.leadIn: the position is below 0 until then): it is loaded, kept dark and held at
  // its start, and started when the moment comes, so its first second is not lost to the loading
  let ytPos = 0, ytAt = 0, ytTimer = null;
  const ytNow = () => ytPos + (media && media.paused ? 0 : (performance.now() - ytAt) / 1000);
  const ytFrom = () => Math.max(0, Math.floor(ytNow()));

  function startYoutube(id, pos) {
    ytPos = pos; ytAt = performance.now();
    ytOver = false;
    if (!ytApi) { ytWanted = { id, pos }; loadApi(); return; }
    ytWanted = null;
    $('#yt').classList.remove('hidden');
    $('#yt').classList.toggle('dark', ytNow() < 0);
    if (yt && !ytReady) { ytWanted = { id, pos }; return; }   // the player is still being made: it takes this one when ready
    if (yt && ytReady) {
      yt.loadVideoById({ videoId: id, startSeconds: ytFrom() });
      applyYoutube();
      return;
    }
    yt = new YT.Player('yt-player', {
      width: '100%', height: '100%', videoId: id,
      playerVars: { autoplay: 1, controls: 0, disablekb: 1, fs: 0, rel: 0, playsinline: 1, iv_load_policy: 3,
                    modestbranding: 1, start: Math.max(0, Math.floor(pos)) },
      events: {
        onReady: () => {
          ytReady = true;
          if (ytWanted) {                                        // another video was asked for while this one was made
            const w = ytWanted;
            ytWanted = null;
            yt.loadVideoById({ videoId: w.id, startSeconds: ytFrom() });
          }
          applyYoutube(true);
        },
        // a player that starts by itself before its moment is held again; playing: its length is known now; its
        // end: the screens go dark rather than show YouTube's end card (the server switches them off: it is told
        // the length)
        onStateChange: (e) => {
          if (e.data === 1 && ytNow() < -0.1) applyYoutube();
          if (e.data === 1) tellLength();
          if (e.data === 0 && ytNow() > 1) { ytOver = true; $('#yt').classList.add('dark'); }
        },
        // a dead or blocked video: the screens go black rather than show YouTube's error card
        onError: (e) => { $('#yt').classList.add('hidden'); report('YouTube will not play it here (error ' + (e && e.data) + ')'); },
      },
    });
  }
  let ytOver = false, lengthTold = null;
  function tellLength() {
    const len = yt && yt.getDuration ? +yt.getDuration() : 0;
    if (!media || !(len >= 1) || lengthTold === media.rev) return;
    lengthTold = media.rev;
    fetch(`https://${res}/screenLength`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ rev: media.rev, len }) }).catch(() => {});
  }
  function applyYoutube(seek) {
    if (!yt || !ytReady || ytOver) return;
    clearTimeout(ytTimer);
    const want = ytNow();
    if (want < 0) {                                              // not yet: loaded, dark and waiting at its start
      $('#yt').classList.add('dark');
      yt.mute();
      if ((yt.getCurrentTime() || 0) > 0.05) yt.seekTo(0, true);
      yt.pauseVideo();
      if (!media.paused) ytTimer = setTimeout(() => applyYoutube(), -want * 1000);
      return;
    }
    $('#yt').classList.remove('dark');
    applyVolume();
    if (seek || Math.abs((yt.getCurrentTime() || 0) - want) > 1.0) yt.seekTo(want, true);
    if (media.paused) yt.pauseVideo(); else yt.playVideo();
  }
  function stopYoutube() {
    clearTimeout(ytTimer);
    if (yt && ytReady) yt.stopVideo();
    $('#yt').classList.add('hidden');
    $('#yt').classList.remove('dark');
    ytWanted = null;
  }

  // ---- a fade-out (the desk's Fade out, /arenascreen fade): the picture goes to black over its seconds, and this
  // page's own sound with it where it has one; the server turns the screens off when it is there
  let fadeEnd = 0, fadeMs = 0, fadeTimer = null;
  const fadeLevel = () => (fadeMs ? Math.max(0, Math.min(1, (fadeEnd - performance.now()) / fadeMs)) : 1);
  function applyVolume() {
    if (!yt || !ytReady) return;
    const v = ytNow() < 0 ? 0 : volume * fadeLevel() * fadeLevel();
    yt.setVolume(Math.round(v * 100));
    if (v > 0) yt.unMute(); else yt.mute();
  }
  // (stepped by a timer, not a CSS transition: it runs the same whether or not anything is painting the page)
  function fadeStep() {
    $('#fade').style.opacity = fadeMs ? 1 - fadeLevel() : 0;
    applyVolume();
    if (fadeTimer && performance.now() >= fadeEnd) { clearInterval(fadeTimer); fadeTimer = null; }
  }
  function setFade(f) {
    clearInterval(fadeTimer); fadeTimer = null;
    if (!f || !(f.dur > 0)) fadeMs = 0;
    else { fadeMs = f.dur * 1000; fadeEnd = performance.now() + Math.max(0, f.left) * 1000; fadeTimer = setInterval(fadeStep, 33); }
    fadeStep();
  }

  // ---- pictures: a cross-fade between two <img>, the one to show worked out from the position
  function picAt() {
    const urls = media.urls || [];
    if (urls.length === 0) return -1;
    if (urls.length === 1) return 0;
    const pos = media.paused ? (media.at || 0) : (performance.now() - base) / 1000;
    return Math.floor(pos / Math.max(2, media.interval || 8)) % urls.length;
  }
  function showPic(i) {
    if (i === shown) return;
    shown = i;
    const next = front === 'a' ? 'b' : 'a';
    const img = $('#pic-' + next);
    img.onload = () => { img.classList.add('on'); $('#pic-' + front).classList.remove('on'); front = next; };
    img.onerror = () => report('a picture does not load');   // a dead picture: the last one stays up
    img.src = media.urls[i];
  }
  function clearPics() {
    shown = -1;
    $('#pic-a').classList.remove('on'); $('#pic-b').classList.remove('on');
  }
  setInterval(() => {
    if (media && (media.kind === 'images' || media.kind === 'image')) { const i = picAt(); if (i >= 0) showPic(i); }
  }, 250);

  // ---- looks: LED-wall pictures this page draws itself, in step with the light desk (the colours, the effect and its
  // speed, from the network clock the client sends, like the lights): show = the show's artwork breathing, the lights'
  // colour over it; pulse = a ring of colour bursting out on every beat; colour = the screens are one more light;
  // bars = level bars in the colours; stripes = bands sliding across; waves = slow waves rolling up. (After the
  // Vinewood Bowl's LED wall.)
  const cv = $('#look');
  const g = cv.getContext('2d');
  const W = cv.width, H = cv.height;
  let L = { on: false, mode: 'static', colors: [[255, 255, 255]], bpm: 120, intensity: 0.8 };
  let info = { backdrop: null, logo: null, title: 'MAZE BANK ARENA' };
  const art = new Image(), logo = new Image();
  let netAt = 0, perfAt = performance.now();
  const tnow = () => (netAt + (performance.now() - perfAt)) / 1000;
  const ok = (img) => img.complete && img.naturalWidth > 0;
  const frac = (x) => x - Math.floor(x);
  const rgb = (c, k) => `rgb(${Math.round(c[0] * k)},${Math.round(c[1] * k)},${Math.round(c[2] * k)})`;
  const hsv = (h, s, v) => {
    const i = Math.floor(h * 6), f = h * 6 - i, p = v * (1 - s), q = v * (1 - f * s), t = v * (1 - (1 - f) * s);
    return [[v, t, p], [q, v, p], [p, v, t], [p, q, v], [t, p, v], [v, p, q]][((i % 6) + 6) % 6].map((x) => x * 255);
  };
  const hsh = (a, b) => { const x = Math.sin(a * 127.1 + b * 311.7) * 43758.5453; return x - Math.floor(x); };

  // the light desk's colour and level now (its effect, for one fixture: client/lights.lua's look())
  function lightLook(t, beat) {
    const cs = (L.colors && L.colors.length) ? L.colors : [[255, 255, 255]];
    const mode = L.mode || 'static';
    if (!L.on) return [cs[0], 0.55];
    if (mode === 'chase' || mode === 'alternate') return [cs[Math.floor(beat * (mode === 'chase' ? 2 : 1)) % cs.length], 1];
    if (mode === 'strobe') { const hz = Math.min((L.bpm || 120) / 30, 8); return [cs[Math.floor(t * hz) % cs.length], frac(t * hz) < 0.3 ? 1 : 0]; }
    if (mode === 'pulse') { const l = 0.5 + 0.5 * Math.cos(beat * Math.PI * 2); return [cs[0], 0.12 + 0.88 * l * l]; }
    if (mode === 'rainbow') return [hsv(frac(beat / 8), 1, 1), 1];
    if (mode === 'random' || mode === 'twinkle') return [cs[Math.floor(beat * 7.31) % cs.length], frac(beat) < 0.5 ? 1 : 0.2];
    if (mode === 'police') return [Math.floor(t * 4) % 2 ? [255, 20, 20] : [20, 40, 255], 1];
    if (mode === 'wave') { const l = 0.5 + 0.5 * Math.sin(beat * Math.PI); return [cs[0], 0.05 + 0.95 * l * l * l]; }
    if (mode === 'flash') return [cs[Math.floor(beat) % cs.length], Math.exp(-frac(beat) * 5)];
    if (mode === 'lightning') return [[235, 240, 255], hsh(Math.floor(beat / 2), 5) < 0.45 && frac(beat / 2) < 0.2 ? 1 : 0.04];
    if (mode === 'fire') { const fl = 0.5 + 0.5 * Math.sin(t * 7.3) * Math.sin(t * 3.1 + beat); return [[255, 30 + 130 * fl, 10 * fl], 0.45 + 0.55 * fl]; }
    if (mode === 'fade') {
      const q0 = beat / 4, k = Math.floor(q0); let q = q0 - k; q = q * q * (3 - 2 * q);
      const a = cs[k % cs.length], b = cs[(k + 1) % cs.length];
      return [[0, 1, 2].map((j) => a[j] + (b[j] - a[j]) * q), 1];
    }
    return [cs[0], 1];
  }

  function drawTitle(k, scale) {
    if (ok(logo)) {
      const w = W * 0.62 * scale, h = w * logo.naturalHeight / logo.naturalWidth;
      g.globalAlpha = k;
      g.globalCompositeOperation = 'lighter';                // the logo's black is see-through
      g.drawImage(logo, (W - w) / 2, (H - h) / 2, w, h);
      g.globalCompositeOperation = 'source-over';
      g.globalAlpha = 1;
      return;
    }
    const text = info.title || 'MAZE BANK ARENA';
    g.globalAlpha = k;
    g.fillStyle = '#ffffff';
    g.textAlign = 'center';
    g.textBaseline = 'middle';
    let size = Math.round(150 * scale);
    g.font = `900 ${size}px "Segoe UI", Arial, sans-serif`;
    const w = g.measureText(text).width;
    if (w > W - 80) { size = Math.floor(size * (W - 80) / w); g.font = `900 ${size}px "Segoe UI", Arial, sans-serif`; }
    g.shadowColor = 'rgba(0,0,0,0.6)'; g.shadowBlur = 18;
    g.fillText(text, W / 2, H / 2);
    g.shadowBlur = 0;
    g.globalAlpha = 1;
  }

  function drawLook() {
    const t = tnow();
    const beat = t * (L.bpm || 120) / 60;
    const cs = (L.colors && L.colors.length) ? L.colors : [[255, 255, 255]];
    const inten = 0.35 + 0.65 * (L.intensity == null ? 0.8 : L.intensity);
    const kind = (media && media.look) || 'show';
    const [c, lvl] = lightLook(t, beat);
    const kick = L.on ? Math.max(0, 1 - frac(beat) * 2.5) : 0;
    g.globalCompositeOperation = 'source-over';
    g.globalAlpha = 1;
    g.fillStyle = '#000';
    g.fillRect(0, 0, W, H);
    if (kind === 'show') {
      if (ok(art)) {
        const s = 1.04 + 0.02 * Math.sin(t * 0.21), w = W * s, h = H * s;
        g.globalAlpha = 0.85 + 0.1 * Math.sin(t * 0.8);
        g.drawImage(art, (W - w) / 2 + Math.sin(t * 0.13) * 10, (H - h) / 2 + Math.cos(t * 0.17) * 6, w, h);
        g.globalAlpha = 1;
      } else {
        drawTitle(inten, 1);
      }
      if (L.on) {
        g.globalCompositeOperation = 'overlay';
        g.globalAlpha = 0.5;
        g.fillStyle = rgb(c, 0.4 + 0.6 * lvl);
        g.fillRect(0, 0, W, H);
        g.globalAlpha = 1;
        g.globalCompositeOperation = 'lighter';
        g.fillStyle = rgb(c, 0.22 * kick * inten);
        g.fillRect(0, 0, W, H);
      }
    } else if (kind === 'pulse') {
      const r = 60 + frac(beat) * 900;
      const grd = g.createRadialGradient(W / 2, H / 2, r * 0.55, W / 2, H / 2, r);
      grd.addColorStop(0, 'rgba(0,0,0,0)');
      grd.addColorStop(0.7, rgb(c, (1 - frac(beat)) * inten * Math.max(0.3, lvl)));
      grd.addColorStop(1, 'rgba(0,0,0,0)');
      g.fillStyle = grd;
      g.fillRect(0, 0, W, H);
      g.globalCompositeOperation = 'lighter';
      g.fillStyle = rgb(c, 0.18 * kick * inten);
      g.fillRect(0, 0, W, H);
      g.globalCompositeOperation = 'source-over';
      drawTitle(inten, 1 + 0.035 * kick);
    } else if (kind === 'colour') {
      g.fillStyle = rgb(c, lvl * inten);
      g.fillRect(0, 0, W, H);
      drawTitle(0.45, 1);
    } else if (kind === 'bars') {
      const N = 32, bw = W / N, step = Math.floor(beat * 2), f = frac(beat * 2);
      for (let i = 0; i < N; i++) {
        const mid = 1 - Math.abs(i - (N - 1) / 2) / (N / 2) * 0.45;
        const h = (0.18 + 0.82 * hsh(step, i)) * mid * (1 - 0.45 * f) * (L.on ? 1 : 0.4);
        g.fillStyle = rgb(cs[i % cs.length], inten);
        g.fillRect(i * bw + 3, H - h * H * 0.92, bw - 6, h * H * 0.92);
      }
      drawTitle(0.9 * inten, 0.8);
    } else if (kind === 'stripes') {
      const bw = 140, off = frac(beat) * bw * cs.length;
      g.save();
      g.transform(1, 0, -0.5, 1, 0, 0);
      for (let x = -bw * cs.length * 2, i = 0; x < W + H; x += bw, i++) {
        g.fillStyle = rgb(cs[i % cs.length], inten * (0.35 + 0.65 * lvl));
        g.fillRect(x + off, 0, bw * 0.62, H);
      }
      g.restore();
      drawTitle(inten, 0.9 + 0.03 * kick);
    } else if (kind === 'waves') {
      for (let j = 0; j < 4; j++) {
        g.fillStyle = rgb(cs[j % cs.length], inten * (0.28 + 0.14 * j));
        g.beginPath();
        g.moveTo(0, H);
        for (let x = 0; x <= W; x += 16) {
          g.lineTo(x, H * (0.25 + 0.17 * j) + Math.sin(x * 0.005 * (1 + j * 0.3) + beat * 0.5 * (j % 2 ? -1 : 1) + j * 1.7) * (56 - j * 7) - kick * 12);
        }
        g.lineTo(W, H);
        g.closePath();
        g.fill();
      }
      drawTitle(0.92 * inten, 0.8);
    }
  }

  let lastDraw = 0;
  function lookFrame(ts) {
    requestAnimationFrame(lookFrame);
    if (!media || media.kind !== 'look' || ts - lastDraw < 33) return;   // ~30 fps is plenty for a texture
    lastDraw = ts;
    try { drawLook(); } catch (err) { g.fillStyle = '#000'; g.fillRect(0, 0, W, H); }
  }
  requestAnimationFrame(lookFrame);

  // ---- a camera feed (kind 'feed'): another player's view of the game, sent by that player's own page
  // (html/feed.js) straight to this one - WebRTC, the server only passes the handshake on. This page asks the camera
  // for its picture, answers its offer and shows what comes; it asks again when the connection fails or goes. While
  // there is no picture for a while (the camera is not up, the feed is full, the two PCs cannot reach each other)
  // the screens show the show's artwork.
  const fv = $('#feed');
  let pc = null, feedOn = false, feedCfg = null, feedTimer = null, waitTimer = null, pendingIce = [];
  const feedPost = (msg) => {
    if (media) fetch(`https://${res}/feedSignal`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ rev: media.rev, role: 'view', msg }) }).catch(() => {});
  };
  function feedStandby(ms) {
    clearTimeout(waitTimer);
    waitTimer = setTimeout(() => {
      if (!feedOn || !fv.classList.contains('hidden') || !info.backdrop) return;
      $('#feed-wait').src = info.backdrop;
      $('#feed-wait').classList.add('on');
    }, ms);
  }
  function feedClose() {
    if (pc) {
      pc.ontrack = pc.onicecandidate = pc.onconnectionstatechange = null;
      try { pc.close(); } catch (_) {}
    }
    pc = null; pendingIce = [];
    fv.srcObject = null;
    fv.classList.add('hidden');
  }
  // ask the camera (again) in ms, unless the picture is coming by then
  function feedAsk(ms) {
    clearTimeout(feedTimer);
    feedTimer = setTimeout(() => {
      if (!feedOn || (pc && pc.connectionState === 'connected')) return;
      feedClose();
      feedPost({ t: 'want' });
      feedAsk(6000);
    }, ms);
  }
  fv.addEventListener('playing', () => { clearTimeout(waitTimer); $('#feed-wait').classList.remove('on'); });
  function feedStart(cfg) {
    feedStop();
    feedOn = true; feedCfg = cfg || {};
    feedStandby(6000);
    feedAsk(0);
  }
  function feedStop() {
    clearTimeout(feedTimer); clearTimeout(waitTimer);
    feedOn = false;
    feedClose();
    $('#feed-wait').classList.remove('on');
  }
  async function feedSignal(msg) {
    if (!feedOn || !msg) return;
    if (msg.t === 'offer' && typeof msg.sdp === 'string') {
      feedClose();
      let mine;
      try {
        mine = pc = new RTCPeerConnection({ iceServers: Array.isArray(feedCfg.ice) ? feedCfg.ice : [], iceTransportPolicy: feedCfg.relayOnly ? 'relay' : 'all' });
      } catch (err) { report('the camera feed cannot be received here: ' + (err && err.message)); return; }
      mine.ontrack = (e) => {
        fv.srcObject = (e.streams && e.streams[0]) || new MediaStream([e.track]);
        fv.classList.remove('hidden');
        const p = fv.play();
        if (p && p.catch) p.catch(() => {});
      };
      mine.onicecandidate = (e) => { if (e.candidate) feedPost({ t: 'ice', c: e.candidate.toJSON() }); };
      mine.onconnectionstatechange = () => {
        if (pc !== mine) return;
        const s = mine.connectionState;
        if (s === 'connected') clearTimeout(feedTimer);
        else if (s === 'failed' || s === 'closed') { feedStandby(3000); feedAsk(2000); }
        else if (s === 'disconnected') feedAsk(5000);
      };
      feedAsk(15000);                                    // not connected by then: from the start
      try {
        await mine.setRemoteDescription({ type: 'offer', sdp: msg.sdp });
        if (pc !== mine) return;
        pendingIce.splice(0).forEach((c) => mine.addIceCandidate(c).catch(() => {}));
        await mine.setLocalDescription(await mine.createAnswer());
        if (pc !== mine) return;
        feedPost({ t: 'answer', sdp: mine.localDescription.sdp });
      } catch (err) { if (pc === mine) feedAsk(3000); }
    } else if (msg.t === 'ice' && msg.c) {
      if (pc && pc.remoteDescription && pc.remoteDescription.type) pc.addIceCandidate(msg.c).catch(() => {});
      else pendingIce.push(msg.c);
    } else if (msg.t === 'bye') {                        // the camera let go of this connection
      feedClose(); feedStandby(3000); feedAsk(3000);
    } else if (msg.t === 'full') {                       // the feed has all the watchers it takes
      feedClose(); feedStandby(0); feedAsk(20000);
    }
  }

  function setInfo(m) {
    if (m.lights) L = m.lights;
    if (typeof m.now === 'number') { netAt = m.now; perfAt = performance.now(); }
    if (m.backdrop !== info.backdrop) { info.backdrop = m.backdrop; if (m.backdrop) art.src = m.backdrop; else art.removeAttribute('src'); }
    if (m.logo !== info.logo) { info.logo = m.logo; if (m.logo) logo.src = m.logo; else logo.removeAttribute('src'); }
    info.title = m.title || 'MAZE BANK ARENA';
  }

  function load(m, pos, feed) {
    media = m;
    base = performance.now() - pos * 1000;
    $('#look').classList.toggle('hidden', m.kind !== 'look');
    if (m.kind === 'feed') feedStart(feed); else feedStop();
    if (m.kind === 'youtube') { clearPics(); startYoutube(m.id, pos); }
    else if (m.kind === 'images' || m.kind === 'image') { stopYoutube(); shown = -1; }
    else { stopYoutube(); clearPics(); }
  }

  window.addEventListener('message', (e) => {
    let m = e.data;
    if (typeof m === 'string') { try { m = JSON.parse(m); } catch (_) { return; } }
    if (!m || typeof m !== 'object') return;
    if (m.type === 'load') {
      // the same item again (the client sends it a few times, in case the first came before this page listened):
      // only its state and the position are taken, nothing is loaded twice
      if (media && m.media && media.rev === m.media.rev) {
        const pos = m.pos || 0;
        media = Object.assign({}, media, m.media);
        base = performance.now() - pos * 1000;
        if (media.paused) media.at = pos;
        $('#look').classList.toggle('hidden', media.kind !== 'look');
        if (media.kind === 'youtube') { ytPos = pos; ytAt = performance.now(); applyYoutube(); }
      } else load(m.media, m.pos || 0, m.feed);
      setFade(m.fade);
    } else if (m.type === 'state' && media) {
      media = Object.assign({}, media, m.media);
      $('#look').classList.toggle('hidden', media.kind !== 'look');
      if (media.kind === 'youtube') applyYoutube();
      setFade(m.fade);
    } else if (m.type === 'sync' && media) {
      media.paused = !!m.paused;
      base = performance.now() - m.pos * 1000;
      if (media.paused) media.at = m.pos;
      if (media.kind === 'youtube') { ytPos = m.pos; ytAt = performance.now(); applyYoutube(); }
    } else if (m.type === 'lights') {
      setInfo(m);
    } else if (m.type === 'feed') {
      feedSignal(m.msg);
    } else if (m.type === 'volume') {
      volume = Math.max(0, Math.min(1, +m.volume || 0));
      applyVolume();
    }
  });

  // this page is listening now: the client sends the item again (a message sent before this was lost)
  fetch(`https://${res}/screenReady`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' })
    .catch(() => {});
})();
