// mzb_arena - the desk as a piece of equipment (1.5.0): the fixture keys under ADVANCED (pick a group and its
// settings show, as a console selects its fixtures first; the pick is remembered), the screen's last line (what the
// control under the pointer does - the game's browser draws no tooltips, so the titles show there), the scales
// printed beside the faders, the colour keys' LEDs in their own colour, and the mouse wheel on the faders.
(() => {
  const KEY = 'mzb_desk_group';
  const desk = document.querySelector('#desk');
  const groups = Array.from(document.querySelectorAll('#groups button'));
  const fixes = Array.from(document.querySelectorAll('#fixtures button'));     // (LIGHTS' ZONES: the groups' ON keys)
  const pages = Array.from(document.querySelectorAll('#desk .grp'));
  if (!desk) return;
  let cur = null;
  try { cur = localStorage.getItem(KEY); } catch (_) { cur = null; }

  // a group whose page is not on this server or in this show (no lasers, no followspot) is left out, here and in ZONES
  const page = (name) => pages.find((p) => p.dataset.grp === name);
  const here = (name) => !!page(name) && !page(name).classList.contains('hidden');
  function pick(name, keep) {
    const live = groups.filter((b) => here(b.dataset.grp));
    groups.forEach((b) => b.classList.toggle('hidden', !live.includes(b)));
    fixes.forEach((b) => b.classList.toggle('hidden', !here(b.dataset.fix)));
    if (!live.some((b) => b.dataset.grp === name) && live.length) name = live[0].dataset.grp;
    groups.forEach((b) => b.classList.toggle('active', b.dataset.grp === name));
    pages.forEach((p) => p.classList.toggle('idle', p.dataset.grp !== name));
    if (keep) { cur = name; try { localStorage.setItem(KEY, name); } catch (_) {} }
  }
  groups.forEach((b) => (b.onclick = () => pick(b.dataset.grp, true)));
  let seen = '';
  const watch = new MutationObserver(() => {
    const now = pages.map((p) => (p.classList.contains('hidden') ? 1 : 0)).join('');
    if (now !== seen) { seen = now; pick(cur || 'beams'); }
  });
  pages.forEach((p) => watch.observe(p, { attributes: true, attributeFilter: ['class'] }));
  pick(cur || 'beams');

  // the screen's last line: the title of whatever the pointer is over, else how the desk works
  const help = document.querySelector('#help'), text = document.querySelector('#help-text');
  const IDLE = 'Point at a control and this line says what it does. Keys 1-7: the pages. Numpad 1-9: the looks, '
    + '* random, 0 blackout, + GO. Esc closes.';
  let over = null;
  function say(el) {
    const t = el && el.closest && el.closest('[title]');
    const s = t && desk.contains(t) && t.getAttribute('title');
    text.textContent = s || IDLE;
    help.classList.toggle('tip', !!s);
  }
  if (help && text) {
    desk.addEventListener('mouseover', (e) => { if (e.target !== over) { over = e.target; say(over); } });
    desk.addEventListener('mouseleave', () => { over = null; say(null); });
    say(null);
  }

  // the faders' scales, 10 at the top to 0 at the bottom, where the cap's line sits
  document.querySelectorAll('#desk .fader').forEach((f) => {
    const sc = document.createElement('div');
    sc.className = 'scale';
    for (let n = 10; n >= 0; n -= 2) {
      const i = document.createElement('i');
      i.textContent = n;
      i.style.top = (10 - n) * 10 + '%';
      sc.appendChild(i);
    }
    f.prepend(sc);
  });

  // a colour key's LED is its colour (the bars' and the lasers' colour keys)
  document.querySelectorAll('#desk button[data-rgb]').forEach((b) => {
    b.classList.add('ckey');
    b.style.setProperty('--lc', `rgb(${b.dataset.rgb})`);
  });

  // the wheel moves a fader a step at a time (a fiftieth of its travel)
  document.querySelectorAll('#desk .fader input').forEach((el) => el.addEventListener('wheel', (e) => {
    if (el.disabled) return;
    e.preventDefault();
    const lo = +el.min || 0, hi = +el.max || 100, step = Math.max(+el.step || 1, Math.round((hi - lo) / 50));
    el.value = Math.max(lo, Math.min(hi, +el.value + (e.deltaY < 0 ? step : -step)));
    el.dispatchEvent(new Event('input', { bubbles: true }));
  }, { passive: false }));
})();
