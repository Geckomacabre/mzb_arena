// mzb_arena - the desk's Cars section (Show tab): the real cars a show has standing on its floor (Config.ShowCars: the
// truck show's, there to be driven over). It is only there while the show that is up has cars (client/cars.lua says
// so when the desk opens, when the show changes and when the cars do). A press goes to the server, which checks who
// pressed and puts fresh cars down, or takes them away, for everyone.
(() => {
  const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'mzb_arena';
  const nui = (name, body) =>
    fetch(`https://${res}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body || {}) }).catch(() => {});
  const sec = document.querySelector('#cars'), now = document.querySelector('#cars-now');
  const fresh = document.querySelector('#cars-reset'), none = document.querySelector('#cars-clear');
  if (!sec || !fresh || !none) return;

  fresh.onclick = () => nui('cars', { action: 'reset' });
  none.onclick = () => nui('cars', { action: 'clear' });

  window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.type !== 'carsDesk') return;
    sec.classList.toggle('hidden', !m.has);                // a show without cars has no section
    const n = +m.n || 0;
    if (now) now.textContent = n > 0 ? n + ' down' : 'none down';
    none.disabled = n === 0;
  });
})();
