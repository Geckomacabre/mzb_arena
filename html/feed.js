// mzb_arena - a camera feed's sending side (/arenascreen look; client/media.lua, server/media.lua).
// While this player is the camera, the page takes the game's own picture - the game view FiveM lets a NUI page draw:
// the 3D view and the game's HUD (which the client hides meanwhile), and nothing of NUI: no chat, no phone, no menus,
// not this desk - draws it small on a canvas and sends that canvas as video to the screens' page (html/screen.js) of
// each player near the arena: one WebRTC connection per watcher, the handshake passed on by the server, the picture
// itself from PC to PC. A red tally on this player's screen says the view is live; it is not in the picture.
(() => {
  const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'mzb_arena';
  const nui = (name, body) =>
    fetch(`https://${res}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body || {}) }).catch(() => {});
  const $ = (s) => document.querySelector(s);

  let rev = null, cfg = null, view = null, stream = null, error = null;
  let raf = 0, pump = null, stateTimer = null, lastDraw = 0;
  const peers = new Map();                 // a watcher's server id -> { pc, pending: [routes that came before its answer] }

  // ---- the game's picture as a WebGL texture. FiveM hands a page the game view through a texture that is set up
  // with exactly this run of wrap modes (the "game view" hook; screenshot-basic and the phones' cameras take their
  // pictures the same way). The game's picture is as big as the screen and this canvas is small, so every pixel of it
  // is the average of the block of the game's pixels it stands for (up to 4 x 4), not one picked out of them.
  function gameView(canvas, flip) {
    const gl = canvas.getContext('webgl', { antialias: false, depth: false, stencil: false, alpha: false,
                                            desynchronized: true, failIfMajorPerformanceCaveat: false });
    if (!gl) return null;
    const shader = (type, src) => {
      const s = gl.createShader(type);
      gl.shaderSource(s, src);
      gl.compileShader(s);
      return s;
    };
    const prog = gl.createProgram();
    gl.attachShader(prog, shader(gl.VERTEX_SHADER,
      'attribute vec2 a_pos; attribute vec2 a_uv; varying vec2 uv; void main() { gl_Position = vec4(a_pos, 0.0, 1.0); uv = a_uv; }'));
    gl.attachShader(prog, shader(gl.FRAGMENT_SHADER,
      'precision highp float; varying vec2 uv; uniform sampler2D tex; uniform vec2 texel; uniform float taps;' +
      'void main() { vec4 sum = vec4(0.0);' +
      '  for (int i = 0; i < 4; i++) { for (int j = 0; j < 4; j++) {' +
      '    if (float(i) < taps && float(j) < taps) sum += texture2D(tex, uv + (vec2(float(i), float(j)) - (taps - 1.0) * 0.5) * texel);' +
      '  } }' +
      '  gl_FragColor = vec4(sum.rgb / (taps * taps), 1.0); }'));
    gl.linkProgram(prog);
    if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) return null;
    gl.useProgram(prog);

    const tex = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, new Uint8Array([0, 0, 255, 255]));
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.MIRRORED_REPEAT);    // the hook: these two, in this order,
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);             // after the clamp above
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.uniform1i(gl.getUniformLocation(prog, 'tex'), 0);

    const buffer = (name, data) => {
      const loc = gl.getAttribLocation(prog, name);
      gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
      gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(data), gl.STATIC_DRAW);
      gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);
      gl.enableVertexAttribArray(loc);
    };
    buffer('a_pos', [-1, -1, 1, -1, -1, 1, 1, 1]);
    buffer('a_uv', flip ? [0, 1, 1, 1, 0, 0, 1, 0] : [0, 0, 1, 0, 0, 1, 1, 1]);
    gl.viewport(0, 0, canvas.width, canvas.height);
    // the game's picture is the size of this page (NUI covers the screen)
    const gw = Math.max(1, Math.round(window.innerWidth * (window.devicePixelRatio || 1)));
    const gh = Math.max(1, Math.round(window.innerHeight * (window.devicePixelRatio || 1)));
    gl.uniform2f(gl.getUniformLocation(prog, 'texel'), 1 / gw, 1 / gh);
    gl.uniform1f(gl.getUniformLocation(prog, 'taps'), Math.max(1, Math.min(4, Math.round(gw / canvas.width))));
    return {
      draw: () => { gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4); gl.finish(); },
      lose: () => { const x = gl.getExtension('WEBGL_lose_context'); if (x) x.loseContext(); },
    };
  }

  // ---- the tally: only this player sees it
  function tally() {
    const on = rev !== null;
    $('#feed-tally').classList.toggle('hidden', !on);
    if (!on) return;
    let live = 0;
    peers.forEach((p) => { if (p.pc.connectionState === 'connected') live++; });
    $('#feed-tally-info').textContent = error ? 'no picture: ' + error
      : live === 1 ? '1 screen' : `${live} screens`;
    $('#feed-tally').classList.toggle('bad', !!error);
  }

  function tellState() {
    if (rev === null) return;
    let live = 0;
    peers.forEach((p) => { if (p.pc.connectionState === 'connected') live++; });
    nui('feedState', { rev, capturing: !!stream && !error, error, viewers: peers.size, connected: live,
                       width: view ? view.canvas.width : 0, height: view ? view.canvas.height : 0 });
    tally();
  }

  // ---- one connection per watcher
  const send = (to, msg) => { if (rev !== null) nui('feedSignal', { rev, role: 'cam', to, msg }); };

  function peerClose(id, tell) {
    const p = peers.get(id);
    if (!p) return;
    peers.delete(id);
    p.pc.onicecandidate = p.pc.onconnectionstatechange = null;
    try { p.pc.close(); } catch (_) {}
    if (tell) send(id, { t: 'bye' });
    tally();
  }

  async function peerOpen(id) {
    peerClose(id);
    if (!stream) return;
    let pc;
    try {
      pc = new RTCPeerConnection({ iceServers: Array.isArray(cfg.ice) ? cfg.ice : [], iceTransportPolicy: cfg.relayOnly ? 'relay' : 'all' });
    } catch (err) { error = 'this game cannot send video (' + (err && err.message) + ')'; return tellState(); }
    const p = { pc, pending: [] };
    peers.set(id, p);
    stream.getVideoTracks().forEach((t) => pc.addTrack(t, stream));
    pc.onicecandidate = (e) => { if (e.candidate) send(id, { t: 'ice', c: e.candidate.toJSON() }); };
    pc.onconnectionstatechange = () => {
      if (peers.get(id) !== p) return;
      if (pc.connectionState === 'failed' || pc.connectionState === 'closed') peerClose(id);
      tally();
    };
    try {
      await pc.setLocalDescription(await pc.createOffer());
      if (peers.get(id) === p) send(id, { t: 'offer', sdp: pc.localDescription.sdp });
    } catch (err) { if (peers.get(id) === p) peerClose(id, true); }
  }

  async function signal(from, msg) {
    if (rev === null || !msg || typeof from !== 'number') return;
    if (msg.t === 'want') return peerOpen(from);
    const p = peers.get(from);
    if (!p) return;
    if (msg.t === 'answer' && typeof msg.sdp === 'string') {
      try {
        await p.pc.setRemoteDescription({ type: 'answer', sdp: msg.sdp });
        p.pending.splice(0).forEach((c) => p.pc.addIceCandidate(c).catch(() => {}));
        // no more than the feed's bitrate and frame rate to this watcher
        const sender = p.pc.getSenders()[0];
        const params = sender && sender.getParameters();
        if (params) {
          if (!params.encodings || !params.encodings.length) params.encodings = [{}];
          params.encodings[0].maxBitrate = Math.round((cfg.bitrate || 700) * 1000);
          params.encodings[0].maxFramerate = cfg.fps || 24;
          sender.setParameters(params).catch(() => {});
        }
      } catch (err) { if (peers.get(from) === p) peerClose(from, true); }
    } else if (msg.t === 'ice' && msg.c) {
      if (p.pc.remoteDescription && p.pc.remoteDescription.type) p.pc.addIceCandidate(msg.c).catch(() => {});
      else p.pending.push(msg.c);
    } else if (msg.t === 'bye') {
      peerClose(from);
    }
  }

  // ---- start / stop being the camera
  function draw(now) {
    if (!view) return;
    const period = 1000 / (cfg.fps || 24);
    if (now - lastDraw < period - 2) return;
    lastDraw = now;
    view.draw();
  }

  function stop() {
    Array.from(peers.keys()).forEach((id) => peerClose(id, true));
    cancelAnimationFrame(raf); clearInterval(pump); clearInterval(stateTimer);
    raf = 0; pump = stateTimer = null;
    if (stream) stream.getTracks().forEach((t) => t.stop());
    if (view) view.lose();
    rev = cfg = view = stream = error = null;
    tally();
  }

  function start(m) {
    stop();
    rev = m.rev; cfg = m.config || {};
    $('#feed-tally-hint').textContent = '/' + (m.command || 'arenascreen') + ' look off';
    try {
      // the canvas: the feed's width, the height that goes with this screen's shape (even numbers, for the encoder)
      const canvas = document.createElement('canvas');
      const w = Math.max(160, Math.min(1920, Math.round((cfg.width || 640) / 2) * 2));
      canvas.width = w;
      canvas.height = Math.max(90, Math.round(w * window.innerHeight / Math.max(1, window.innerWidth) / 2) * 2);
      const gv = gameView(canvas, cfg.flip === true);
      if (!gv) throw new Error('WebGL is not there');
      view = { canvas, draw: gv.draw, lose: gv.lose };
      if (typeof canvas.captureStream !== 'function') throw new Error('this game cannot take video off a canvas');
      stream = canvas.captureStream(cfg.fps || 24);
      stream.getVideoTracks().forEach((t) => { try { t.contentHint = 'motion'; } catch (_) {} });
      // drawn with the page's frames, and by a timer at the feed's rate should those not come (draw() takes whichever
      // is due first and lets the other pass)
      const frame = (ts) => { raf = requestAnimationFrame(frame); draw(ts); };
      raf = requestAnimationFrame(frame);
      pump = setInterval(() => draw(performance.now()), 1000 / (cfg.fps || 24));
    } catch (err) {
      error = String((err && err.message) || err);
    }
    stateTimer = setInterval(tellState, 2000);
    tellState();
  }

  window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.type !== 'feed') return;
    if (m.action === 'start') start(m);
    else if (m.action === 'stop') stop();
    else if (m.action === 'signal') signal(m.from, m.msg);
  });

  // this page is listening: if this player is the camera already, the client says so again
  nui('feedReady');
})();
