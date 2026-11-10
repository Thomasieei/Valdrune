/* NOCTALIS — démarrage */
import { init, loadAll, updateFx, camFollow, render, setQuality, E } from './engine.js';
import { load, save, S } from './core.js';
import { G, initGame, update } from './game.js';
import { UI } from './ui.js';
import { SFX } from './audio.js';

const $ = id => document.getElementById(id);
async function boot() {
  load(); init($('c')); setQuality(S.hq);
  await loadAll(p => { $('lbar').style.width = Math.round(p * 100) + '%'; $('lpct').textContent = Math.round(p * 100) + '%'; });
  UI.build(); initGame();
  $('lstart').hidden = false; $('lbarw').hidden = true;
  $('lstart').onclick = () => { SFX.unlock(); $('load').classList.add('out'); setTimeout(() => $('load').remove(), 700); if (!S.tuto) { S.tuto = 1; setTimeout(() => UI.toast('Déplace-toi avec le joystick à gauche — tes attaques sont automatiques', ''), 800); setTimeout(() => UI.toast('Franchis un portail pour aller chasser. Abats un monstre puis touche ÉVEIL pour le relever !', ''), 4500); } };
  let last = performance.now();
  const loop = now => {
    const dt = Math.min(0.05, (now - last) / 1000); last = now; window.__frames = (window.__frames || 0) + 1;
    try { update(dt); } catch (e) { console.error(e); }
    updateFx(dt); camFollow(G.P.pos, dt); UI.update(dt); render();
    requestAnimationFrame(loop);
  };
  requestAnimationFrame(loop);
  setInterval(save, 5000); addEventListener('visibilitychange', () => document.hidden && save());
  window.__G = G; window.__S = S;
}
boot().catch(e => { console.error(e); $('lpct').textContent = 'Erreur : ' + e.message; });
