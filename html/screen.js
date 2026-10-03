// mzb_arena - the video screens' page (a DUI, client/media.lua). It is told what to show and where in it to be;
// it never decides that itself, so every player's screens show the same thing.
(() => {
  const $ = (s) => document.querySelector(s);
  let media = null;          // GlobalState.mzbMedia as last sent
  let base = 0;              // performance.now() at position 0 (pictures)
  let volume = 0;            // 0..1, from where the listener is
  let yt = null, ytReady = false, ytApi = false, ytWanted = null;
  let shown = -1, front = 'a';

  // ---- YouTube (the IFrame API, loaded the first time a video is wanted)
  window.onYouTubeIframeAPIReady = () => { ytApi = true; if (ytWanted) startYoutube(ytWanted.id, ytWanted.pos); };
  function loadApi() {
    if (document.getElementById('yt-api')) return;
    const s = document.createElement('script');
    s.id = 'yt-api';
    s.src = 'https://www.youtube.com/iframe_api';
    document.head.appendChild(s);
  }
  // where the video should be now: the position we were given plus the time since
  let ytPos = 0, ytAt = 0;
  const ytNow = () => ytPos + (media && media.paused ? 0 : (performance.now() - ytAt) / 1000);

  function startYoutube(id, pos) {
    ytPos = pos; ytAt = performance.now();
    if (!ytApi) { ytWanted = { id, pos }; loadApi(); return; }
    ytWanted = null;
    $('#yt').classList.remove('hidden');
    if (yt && ytReady) {
      yt.loadVideoById({ videoId: id, startSeconds: Math.floor(ytNow()) });
      applyYoutube();
      return;
    }
    yt = new YT.Player('yt-player', {
      width: '100%', height: '100%', videoId: id,
      playerVars: { autoplay: 1, controls: 0, disablekb: 1, fs: 0, rel: 0, playsinline: 1, iv_load_policy: 3,
                    modestbranding: 1, start: Math.floor(pos) },
      events: {
        onReady: () => { ytReady = true; applyYoutube(true); },
        // a dead or blocked video: the screens go black rather than show YouTube's error card
        onError: () => $('#yt').classList.add('hidden'),
      },
    });
  }
  function applyYoutube(seek) {
    if (!yt || !ytReady) return;
    yt.setVolume(Math.round(volume * 100));
    if (volume > 0) yt.unMute(); else yt.mute();
    const want = ytNow();
    if (seek || Math.abs((yt.getCurrentTime() || 0) - want) > 1.0) yt.seekTo(want, true);
    if (media.paused) yt.pauseVideo(); else yt.playVideo();
  }
  function stopYoutube() {
    if (yt && ytReady) yt.stopVideo();
    $('#yt').classList.add('hidden');
    ytWanted = null;
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
    img.onerror = () => {};   // a dead picture: the last one stays up
    img.src = media.urls[i];
  }
  function clearPics() {
    shown = -1;
    $('#pic-a').classList.remove('on'); $('#pic-b').classList.remove('on');
  }
  setInterval(() => {
    if (media && (media.kind === 'images' || media.kind === 'image')) { const i = picAt(); if (i >= 0) showPic(i); }
  }, 250);

  function load(m, pos) {
    media = m;
    base = performance.now() - pos * 1000;
    if (m.kind === 'youtube') { clearPics(); startYoutube(m.id, pos); }
    else if (m.kind === 'images' || m.kind === 'image') { stopYoutube(); shown = -1; }
    else { stopYoutube(); clearPics(); }
  }

  window.addEventListener('message', (e) => {
    let m = e.data;
    if (typeof m === 'string') { try { m = JSON.parse(m); } catch (_) { return; } }
    if (!m || typeof m !== 'object') return;
    if (m.type === 'load') load(m.media, m.pos || 0);
    else if (m.type === 'state' && media) {
      media = Object.assign({}, media, m.media);
      if (media.kind === 'youtube') applyYoutube();
    } else if (m.type === 'sync' && media) {
      media.paused = !!m.paused;
      base = performance.now() - m.pos * 1000;
      if (media.paused) media.at = m.pos;
      if (media.kind === 'youtube') { ytPos = m.pos; ytAt = performance.now(); applyYoutube(); }
    } else if (m.type === 'volume') {
      volume = Math.max(0, Math.min(1, +m.volume || 0));
      if (yt && ytReady) { yt.setVolume(Math.round(volume * 100)); if (volume > 0) yt.unMute(); else yt.mute(); }
    }
  });
})();
