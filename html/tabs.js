// mzb_arena - the desk's tabs: Show (the looks, the pyro, the crowd), Lights, Screens & music, Fights. The head - the
// three big buttons, what is on the screens and in the speakers with its way out, the tabs - stays where it is while
// a tab scrolls. The tab chosen is remembered; keys 1-4 pick one while no text field has the cursor. A tab with
// nothing in it (a feature switched off in the config, a show without pyro and without a crowd) is left out.
(() => {
  const KEY = 'mzb_desk_tab';
  const desk = document.querySelector('#desk');
  const tabs = Array.from(document.querySelectorAll('#tabs button'));
  const panes = Array.from(document.querySelectorAll('#desk .pane'));
  if (!desk || !tabs.length) return;
  let cur = null;
  try { cur = localStorage.getItem(KEY); } catch (_) { cur = null; }

  const filled = (name) => {
    const p = panes.find((x) => x.dataset.pane === name);
    return !!p && Array.from(p.children).some((c) => !c.classList.contains('hidden'));
  };

  function show(name, keep) {
    const live = tabs.filter((t) => filled(t.dataset.tab));
    tabs.forEach((t) => t.classList.toggle('hidden', !live.includes(t)));
    if (!live.some((t) => t.dataset.tab === name) && live.length) name = live[0].dataset.tab;
    tabs.forEach((t) => t.classList.toggle('active', t.dataset.tab === name));
    panes.forEach((p) => p.classList.toggle('hidden', p.dataset.pane !== name));
    if (keep) { cur = name; try { localStorage.setItem(KEY, name); } catch (_) {} }
  }

  tabs.forEach((t) => (t.onclick = () => show(t.dataset.tab, true)));
  document.addEventListener('keydown', (e) => {
    if (desk.classList.contains('hidden')) return;
    if (e.target && e.target.closest && e.target.closest('input[type=text], textarea, select')) return;
    const i = '1234'.indexOf(e.key);
    if (i >= 0 && e.key.length === 1 && tabs[i] && !tabs[i].classList.contains('hidden')) show(tabs[i].dataset.tab, true);
  });

  // sections come and go with the config and the show (the pyro's, the screens', the music's): the tabs follow
  const again = () => show(cur || 'show');
  const watch = new MutationObserver(again);
  panes.forEach((p) => Array.from(p.children).forEach((c) => watch.observe(c, { attributes: true, attributeFilter: ['class'] })));
  again();
})();
