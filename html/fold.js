// mzb_arena - the desk's sections fold: a click on a section's title shuts or opens it, and the desk remembers which
// ones are shut (the desk has grown to a dozen sections; an operator who only runs the lights can put the rest away).
// The top row of buttons and the two sliders have no title of their own and always stay open.
(() => {
  const KEY = 'mzb_desk_folded';
  let folded = {};
  try { folded = JSON.parse(localStorage.getItem(KEY) || '{}') || {}; } catch (_) { folded = {}; }
  const save = () => { try { localStorage.setItem(KEY, JSON.stringify(folded)); } catch (_) {} };

  document.querySelectorAll('#desk section').forEach((sec) => {
    const h = sec.querySelector(':scope > h2');
    if (!h) return;
    // the title's own words (not the live text beside it) name the section between sessions
    const name = (h.firstChild && h.firstChild.textContent || '').trim() || sec.id;
    if (!name) return;
    h.classList.add('fold');
    if (folded[name]) sec.classList.add('folded');
    h.addEventListener('click', (e) => {
      if (e.target.closest('input, button, select, a')) return;
      folded[name] = sec.classList.toggle('folded');
      save();
    });
  });
})();
