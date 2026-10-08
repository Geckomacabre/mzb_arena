// mzb_arena - server: the music relay (server/music.lua asks it, html/music.js plays what it hands out).
// Optional: it is asked only with Config.Music.relay.enabled. As the arena ships, the players' pages take a YouTube
// player's or a file's sound into their sound graph themselves and this script stays idle; it is the fallback for a
// game browser that will not let a page do that.
// The music is only ever heard from the arena's speakers as a sound in the world, and the page can place a sound
// only when it may read the audio (Web Audio needs the audio's server to allow it: CORS). So before a track starts:
//   * a direct link whose server allows it          -> the players load it themselves (mode 'direct')
//   * a direct link whose server does not           -> fetched once into a cache here, served from this resource's
//                                                      own HTTP path with the header (mode 'relay')
//   * a YouTube link                                -> its Opus audio fetched once with yt-dlp, served the same way
// Nothing is ever played "flat": a link that can go neither way is refused with the reason.
// The players reach the cache at http://<server endpoint>/<resource>/music/<name> (ranges answered, so a late joiner
// starts mid-track). yt-dlp is looked for in Config.Music.relay.ytdlp, then <resource>/bin, then the PATH, then
// (Windows) where winget installs it; Deno, which yt-dlp wants for YouTube, the same way.
// The server's sandbox (its newer builds): a resource may write only inside its own folder and may start no program
// unless server.cfg allows it. So the cache is the system's temp folder where that is allowed and
// <resource>/music_cache where it is not, and YouTube needs this line in server.cfg:
//     add_unsafe_child_process_permission "<resource>"
// (it lets this resource start programs; the only one it starts is yt-dlp). Without it the reason is said.
// Runs in the server's own Node (no packages). Local events only - no player can reach them:
//   mzb_arena:relayFetch (rev, 'youtube' | 'file', id or url, options)  ->  mzb_arena:relayDone (rev, ok, info)

const fs = require('fs');
const os = require('os');
const path = require('path');
const http = require('http');
const https = require('https');
const dns = require('dns');
const net = require('net');
const crypto = require('crypto');
const { spawn } = require('child_process');

const RES = GetCurrentResourceName();
// the cache: the system's temp folder, or (a sandboxed server) a folder of this resource's own
const CACHE = (() => {
    for (const dir of [path.join(os.tmpdir(), RES + '_music'), path.join(GetResourcePath(RES), 'music_cache')]) {
        try {
            fs.mkdirSync(dir, { recursive: true });
            fs.writeFileSync(path.join(dir, '.probe'), '');
            fs.unlinkSync(path.join(dir, '.probe'));
            return dir;
        } catch (e) { /* not allowed here: the next one */ }
    }
    return path.join(GetResourcePath(RES), 'music_cache');
})();
const ORIGIN = 'https://cfx-nui-' + RES;
const TYPES = { webm: 'audio/webm', weba: 'audio/webm', ogg: 'audio/ogg', oga: 'audio/ogg', opus: 'audio/ogg',
                mp3: 'audio/mpeg', wav: 'audio/wav', flac: 'audio/flac', m4a: 'audio/mp4', aac: 'audio/aac' };
const EXT_OF = { 'audio/webm': 'webm', 'video/webm': 'webm', 'audio/ogg': 'ogg', 'application/ogg': 'ogg',
                 'video/ogg': 'ogg', 'audio/opus': 'opus', 'audio/mpeg': 'mp3', 'audio/mp3': 'mp3', 'audio/wav': 'wav',
                 'audio/x-wav': 'wav', 'audio/wave': 'wav', 'audio/flac': 'flac', 'audio/x-flac': 'flac',
                 'audio/mp4': 'm4a', 'audio/x-m4a': 'm4a', 'audio/aac': 'aac', 'audio/aacp': 'aac' };
const SLICE = 8 * 1024 * 1024;                    // the most one answer carries (the browser asks for the rest)

const tracks = new Map();                          // name -> { file, size, type }
let job = null;                                    // the fetch that is running: { rev, kill }

function clean(s, n) {
    return String(s === undefined || s === null ? '' : s).replace(/[\u0000-\u001f\u007f]/g, ' ').trim().slice(0, n || 120);
}

// ------------------------------------------------------------------ the cache
function register(file) {
    const name = path.basename(file);
    const ext = name.split('.').pop().toLowerCase();
    if (!TYPES[ext]) return null;
    let size = 0;
    try { size = fs.statSync(file).size; } catch (e) { return null; }
    if (size <= 0) return null;
    tracks.set(name, { file, size, type: TYPES[ext] });
    return name;
}

function sweep(keepHours, capMB, keep) {
    let list = [];
    try {
        list = fs.readdirSync(CACHE).map((n) => {
            const f = path.join(CACHE, n);
            const st = fs.statSync(f);
            return { n, f, size: st.size, at: st.mtimeMs };
        });
    } catch (e) { return; }
    list.sort((a, b) => a.at - b.at);              // the oldest first
    let total = list.reduce((s, x) => s + x.size, 0);
    const old = Date.now() - (keepHours || 24) * 3600000;
    for (const x of list) {
        if (keep && (x.n === keep || x.n === keep.replace(/\.[^.]+$/, '.json'))) continue;
        if (x.at < old || total > (capMB || 600) * 1048576) {
            try { fs.unlinkSync(x.f); total -= x.size; tracks.delete(x.n); } catch (e) { /* in use: next time */ }
        }
    }
}

sweep(24, 600);

// ------------------------------------------------------------------ fetching a direct link
// Addresses that are not the public internet: a link must not make this server read its own network for a player.
function privateAddress(ip) {
    if (net.isIPv4(ip)) {
        const p = ip.split('.').map(Number);
        return p[0] === 0 || p[0] === 10 || p[0] === 127 || p[0] >= 224 || (p[0] === 100 && p[1] >= 64 && p[1] <= 127)
            || (p[0] === 169 && p[1] === 254) || (p[0] === 172 && p[1] >= 16 && p[1] <= 31)
            || (p[0] === 192 && p[1] === 168) || (p[0] === 192 && p[1] === 0 && p[2] === 0)
            || (p[0] === 198 && (p[1] === 18 || p[1] === 19));
    }
    const s = ip.toLowerCase();
    const mapped = s.match(/^::ffff:(\d+\.\d+\.\d+\.\d+)$/);
    if (mapped) return privateAddress(mapped[1]);
    return s === '::' || s === '::1' || /^f[cd]/.test(s) || /^fe[89ab]/.test(s) || /^ff/.test(s) || s.startsWith('::ffff:');
}

function resolve(host, allowLan) {
    return new Promise((ok, fail) => {
        const bare = host.replace(/^\[|\]$/g, '');
        const done = (list) => {
            if (!list.length) return fail(new Error('the address does not resolve'));
            if (!allowLan && list.some((a) => privateAddress(a.address))) {
                return fail(new Error('links into a private network are not fetched (Config.Music.relay.allowLan)'));
            }
            ok(list[0]);
        };
        if (net.isIP(bare)) return done([{ address: bare, family: net.isIPv4(bare) ? 4 : 6 }]);
        dns.lookup(bare, { all: true }, (err, list) => (err ? fail(new Error('the address does not resolve')) : done(list || [])));
    });
}

// one GET, the connection pinned to the address that was checked; redirects are followed here (each one checked)
async function open(url, opts, hops) {
    let u;
    try { u = new URL(url); } catch (e) { throw new Error('not a usable link'); }
    if (u.protocol !== 'http:' && u.protocol !== 'https:') throw new Error('not an http(s) link');
    const addr = await resolve(u.hostname, opts.allowLan);
    const lib = u.protocol === 'https:' ? https : http;
    return new Promise((ok, fail) => {
        const req = lib.get(u, {
            headers: { 'User-Agent': 'Mozilla/5.0 (mzb_arena music relay)', Origin: ORIGIN, Accept: '*/*' },
            timeout: 15000,
            lookup: (h, o, cb) => (o && o.all ? cb(null, [addr]) : cb(null, addr.address, addr.family)),
        }, (res) => {
            const code = res.statusCode || 0;
            if (code >= 300 && code < 400 && res.headers.location) {
                res.destroy();
                if ((hops || 0) >= 5) return fail(new Error('too many redirects'));
                let next;
                try { next = new URL(res.headers.location, u).toString(); } catch (e) { return fail(new Error('a bad redirect')); }
                return open(next, opts, (hops || 0) + 1).then(ok, fail);
            }
            if (code !== 200) { res.destroy(); return fail(new Error('the link answers ' + code)); }
            ok({ res, req, url: u.toString() });
        });
        req.on('timeout', () => req.destroy(new Error('the link does not answer')));
        req.on('error', (e) => fail(new Error(clean(e.message, 80) || 'the link cannot be reached')));
    });
}

async function fetchFile(url, opts, alive) {
    const { res, req, url: final } = await open(url, opts);
    const h = res.headers;
    const type = String(h['content-type'] || '').split(';')[0].trim().toLowerCase();
    const urlExt = (new URL(final).pathname.split('.').pop() || '').toLowerCase();
    const ext = EXT_OF[type] || (TYPES[urlExt] ? urlExt : null);
    const audio = type.startsWith('audio/') || !!EXT_OF[type]
        || ((type === '' || type.endsWith('octet-stream')) && !!TYPES[urlExt]);
    if (!audio || !ext) { req.destroy(); throw new Error('the link is not an audio file (' + (clean(type, 40) || 'no type') + ')'); }
    const acao = String(h['access-control-allow-origin'] || '').trim();
    const len = parseInt(h['content-length'], 10);
    const live = !(len > 0) || h['icy-name'] !== undefined || h['icy-br'] !== undefined;
    if (acao === '*' || acao === ORIGIN) {         // the players may read it themselves
        req.destroy();
        return { mode: 'direct', url: final, live };
    }
    if (live) {
        req.destroy();
        throw new Error('this stream\'s server does not let a page read it (no CORS header), so it cannot be placed '
            + 'in the room: use a file or a YouTube link');
    }
    const max = (opts.maxMB || 100) * 1048576;
    if (len > max) { req.destroy(); throw new Error('the file is over ' + (opts.maxMB || 100) + ' MB'); }
    const name = 'f_' + crypto.createHash('sha1').update(final).digest('hex').slice(0, 16) + '.' + ext;
    const file = path.join(CACHE, name);
    if (tracks.has(name) && tracks.get(name).size === len) { req.destroy(); return { mode: 'relay', name, live: false }; }
    await new Promise((ok, fail) => {
        const out = fs.createWriteStream(file);
        let got = 0;
        const stop = (e) => { req.destroy(); out.destroy(); fs.unlink(file, () => {}); fail(e); };
        res.on('data', (c) => {
            got += c.length;
            if (got > max) stop(new Error('the file is over ' + (opts.maxMB || 100) + ' MB'));
            else if (!alive()) stop(new Error('another track was asked for'));
        });
        res.on('error', () => stop(new Error('the download broke off')));
        out.on('error', () => stop(new Error('the server cannot write its cache (' + CACHE + ')')));
        out.on('finish', ok);
        res.pipe(out);
    });
    if (!register(file)) throw new Error('the download is empty');
    return { mode: 'relay', name, live: false };
}

// ------------------------------------------------------------------ YouTube: the Opus audio, with yt-dlp
// Windows: where winget keeps a package (`winget install yt-dlp.yt-dlp DenoLand.Deno`). It also puts it on the PATH,
// but only of programs started afterwards - a server that was already running does not see it there
function wingetExe(pkg, exe) {
    if (process.platform !== 'win32' || !process.env.LOCALAPPDATA) return [];
    const root = path.join(process.env.LOCALAPPDATA, 'Microsoft', 'WinGet');
    const out = [path.join(root, 'Links', exe)];
    try {
        for (const d of fs.readdirSync(path.join(root, 'Packages'))) {
            if (d.toLowerCase().startsWith(pkg.toLowerCase() + '_')) out.push(path.join(root, 'Packages', d, exe));
        }
    } catch (e) { /* no winget packages, or a sandbox that does not let us look */ }
    return out.filter((f) => fs.existsSync(f));
}

// the folders yt-dlp and Deno are looked for in besides the server's own PATH: <resource>/bin and winget's (by
// their usual names too, for a sandboxed server that may start a program there but not list the folder)
function extraPath() {
    const out = [path.join(GetResourcePath(RES), 'bin')];
    if (process.platform === 'win32' && process.env.LOCALAPPDATA) {
        const root = path.join(process.env.LOCALAPPDATA, 'Microsoft', 'WinGet');
        out.push(path.join(root, 'Links'));
        for (const pkg of ['yt-dlp.yt-dlp', 'DenoLand.Deno']) out.push(path.join(root, 'Packages', pkg + '_Microsoft.Winget.Source_8wekyb3d8bbwe'));
        for (const f of wingetExe('yt-dlp.yt-dlp', 'yt-dlp.exe').concat(wingetExe('DenoLand.Deno', 'deno.exe'))) out.push(path.dirname(f));
    }
    return out;
}

// the server's environment with those folders on the PATH (the child finds yt-dlp there, and yt-dlp finds Deno)
function childEnv() {
    const env = Object.assign({}, process.env);
    const key = Object.keys(env).find((k) => k.toLowerCase() === 'path') || 'PATH';
    env[key] = extraPath().concat(env[key] ? [env[key]] : []).join(path.delimiter);
    return env;
}

function ytdlpCandidates(opts) {
    const exe = process.platform === 'win32' ? 'yt-dlp.exe' : 'yt-dlp';
    const list = [];
    if (opts.ytdlp) list.push(String(opts.ytdlp));
    list.push(exe);                                // the PATH, with the folders above
    return list;
}

function runYtdlp(bin, args, timeout, onChild) {
    return new Promise((ok, fail) => {
        let child;
        // a candidate that is not there or does not start: the next one is tried. Not allowed to start anything
        // (the server's sandbox) is its own answer
        const denied = (e) => e && (e.code === 'ERR_ACCESS_DENIED' || /permission|access denied/i.test(String(e.message)));
        try { child = spawn(bin, args, { windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'], env: childEnv() }); }
        catch (e) { return fail(Object.assign(new Error('it does not start'), { missing: true, denied: denied(e) })); }
        let out = '', err = '', over = false;
        const timer = setTimeout(() => { over = true; child.kill(); }, timeout * 1000);
        onChild(() => { over = true; child.kill(); });
        child.stdout.on('data', (d) => { if (out.length < 65536) out += d.toString('utf8'); });
        child.stderr.on('data', (d) => { if (err.length < 65536) err += d.toString('utf8'); });
        child.on('error', (e) => { clearTimeout(timer); fail(Object.assign(new Error('it does not start'), { missing: true, denied: denied(e) })); });
        child.on('close', (code) => {
            clearTimeout(timer);
            if (over) return fail(new Error('fetching it took longer than ' + timeout + ' s (or another track was asked for)'));
            ok({ code, out, err });
        });
    });
}

async function fetchYoutube(id, opts, onChild) {
    if (!/^[\w-]{11}$/.test(id)) throw new Error('not a YouTube video id');
    const meta = path.join(CACHE, 'yt_' + id + '.json');
    try {                                          // fetched before and still here
        const m = JSON.parse(fs.readFileSync(meta, 'utf8'));
        const now = new Date();
        if (m && m.name && register(path.join(CACHE, m.name))) {
            fs.utimes(path.join(CACHE, m.name), now, now, () => {});
            return { mode: 'relay', name: m.name, title: m.title, duration: m.duration, live: false };
        }
    } catch (e) { /* not in the cache */ }
    const mins = opts.maxMinutes || 90;
    // yt-dlp needs a JavaScript runtime for YouTube (Deno): one on the PATH is found by itself, one put next to
    // yt-dlp in <resource>/bin (or named in Config.Music.relay.deno) is pointed out to it
    const denoExe = process.platform === 'win32' ? 'deno.exe' : 'deno';
    const deno = [opts.deno, path.join(GetResourcePath(RES), 'bin', denoExe)].concat(wingetExe('DenoLand.Deno', denoExe))
        .find((f) => f && fs.existsSync(String(f)));
    const args = ['-f', 'bestaudio[acodec=opus]/bestaudio[ext=webm]', '--no-playlist', '--no-part', '--no-progress',
                  '--fixup', 'never', '--encoding', 'utf-8', '--socket-timeout', '15']
        .concat(deno ? ['--js-runtimes', 'deno:' + deno] : [])
        .concat(['--max-filesize', (opts.maxMB || 100) + 'M', '--match-filter', '!is_live & duration <=? ' + mins * 60,
                 '-o', path.join(CACHE, 'yt_' + id + '.%(ext)s'), '--no-simulate', '--no-quiet',
                 '--print', 'after_move:MZB\t%(duration)s\t%(ext)s\t%(title)s'])
        .concat(Array.isArray(opts.ytdlpArgs) ? opts.ytdlpArgs.map(String) : [])      // the owner's own (cookies ...)
        .concat(['--', 'https://www.youtube.com/watch?v=' + id]);
    let r = null, denied = false;
    for (const bin of ytdlpCandidates(opts)) {
        try { r = await runYtdlp(bin, args, opts.timeout || 180, onChild); break; }
        catch (e) { if (!e.missing) throw e; denied = denied || !!e.denied; }
    }
    if (!r && denied) {
        throw new Error('the server does not let ' + RES + ' start yt-dlp: add  add_unsafe_child_process_permission "'
            + RES + '"  to server.cfg and restart the server');
    }
    if (!r) {
        throw new Error('YouTube links need yt-dlp on the server: put ' + (process.platform === 'win32' ? 'yt-dlp.exe' : 'yt-dlp')
            + ' in ' + RES + '/bin (or on the PATH)');
    }
    const line = r.out.split(/\r?\n/).filter((l) => l.startsWith('MZB\t')).pop();
    if (!line) {
        const why = r.err.split(/\r?\n/).map((l) => l.trim()).filter((l) => l.startsWith('ERROR')).pop()
            || (/does not pass filter/.test(r.out + r.err) ? 'it is live or over ' + mins + ' minutes'
                : /larger than max-filesize/.test(r.out + r.err) ? 'its audio is over ' + (opts.maxMB || 100) + ' MB'
                    : 'yt-dlp fetched nothing (is it up to date? yt-dlp -U)');
        // without a JavaScript runtime YouTube refuses the download (403): the real reason is said with it
        const noJs = /No supported JavaScript runtime/i.test(r.err)
            ? ' (yt-dlp found no JavaScript runtime: install Deno on the server, or put ' + denoExe + ' in ' + RES + '/bin)' : '';
        throw new Error(clean(why.replace(/^ERROR:\s*(\[[^\]]+\]\s*)?([\w-]{11}:\s*)?/, ''), 70) + noJs);
    }
    const part = line.split('\t');
    const ext = clean(part[2], 8).toLowerCase();
    const name = register(path.join(CACHE, 'yt_' + id + '.' + ext));
    if (!name) throw new Error('YouTube has no Opus audio for this video');
    const info = { name, title: clean(part.slice(3).join(' '), 80) || 'YouTube ' + id, duration: parseFloat(part[1]) || 0 };
    try { fs.writeFileSync(meta, JSON.stringify(info)); } catch (e) { /* fetched again next time */ }
    return { mode: 'relay', name, title: info.title, duration: info.duration, live: false };
}

// ------------------------------------------------------------------ server/music.lua asks
on('mzb_arena:relayFetch', (rev, kind, value, options) => {
    const opts = options && typeof options === 'object' ? options : {};
    if (job) job.kill();
    const mine = { rev, kill: () => {} };
    job = mine;
    const alive = () => job === mine;
    const work = kind === 'youtube' ? fetchYoutube(String(value), opts, (k) => { mine.kill = k; })
        : fetchFile(String(value), opts, alive);
    work.then((info) => {
        if (alive()) job = null;
        sweep(opts.keepHours, opts.cacheMB, info.name);
        emit('mzb_arena:relayDone', rev, true, info);
    }, (e) => {
        if (alive()) job = null;
        emit('mzb_arena:relayDone', rev, false, { err: clean(e && e.message, 160) || 'it could not be fetched' });
    });
});

// ------------------------------------------------------------------ the players' pages ask: /<resource>/music/<name>
SetHttpHandler((req, res) => {
    const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'Range',
                   'Access-Control-Expose-Headers': 'Content-Range, Content-Length, Accept-Ranges',
                   'Cache-Control': 'no-store' };
    const say = (code, text) => { res.writeHead(code, Object.assign({ 'Content-Type': 'text/plain' }, cors)); res.send(text); };
    const m = /^\/music\/([\w-]{3,48}\.[a-z0-9]{2,5})(?:\?.*)?$/.exec(String(req.path || ''));
    const t = m && tracks.get(m[1]);
    if (req.method === 'OPTIONS') return say(204, '');
    if (!t) return say(404, 'no such track');
    if (req.method !== 'GET' && req.method !== 'HEAD') return say(405, 'GET');
    let range = null;
    for (const k of Object.keys(req.headers || {})) if (k.toLowerCase() === 'range') range = String(req.headers[k]);
    let a = 0, b = t.size - 1, code = 200;
    const r = range && /^bytes=(\d*)-(\d*)$/.exec(range.trim());
    if (r && (r[1] !== '' || r[2] !== '')) {
        if (r[1] === '') { a = Math.max(0, t.size - parseInt(r[2], 10)); }
        else { a = parseInt(r[1], 10); if (r[2] !== '') b = Math.min(b, parseInt(r[2], 10)); }
        if (!(a <= b) || a >= t.size) {
            res.writeHead(416, Object.assign({ 'Content-Range': 'bytes */' + t.size }, cors));
            return res.send('');
        }
        code = 206;
    }
    if (b - a + 1 > SLICE && code === 206) b = a + SLICE - 1;
    const head = Object.assign({ 'Content-Type': t.type, 'Accept-Ranges': 'bytes', 'Content-Length': String(b - a + 1) }, cors);
    if (code === 206) head['Content-Range'] = 'bytes ' + a + '-' + b + '/' + t.size;
    if (req.method === 'HEAD') { res.writeHead(code, head); return res.send(''); }
    const buf = Buffer.alloc(b - a + 1);
    let fd = null;
    try {
        fd = fs.openSync(t.file, 'r');
        fs.readSync(fd, buf, 0, buf.length, a);
    } catch (e) {
        if (fd !== null) { try { fs.closeSync(fd); } catch (x) { /* gone */ } }
        tracks.delete(m[1]);
        return say(404, 'no such track');
    }
    fs.closeSync(fd);
    res.writeHead(code, head);
    res.send(buf);
});
