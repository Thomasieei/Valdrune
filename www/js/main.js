/* UMBRA — démarrage */
import { init, loadAll, updateFx, camFollow, render, setQuality } from './engine.js';
import { load, save, S } from './state.js';
import * as GM from './game.js';
import { UI } from './ui.js';
import { SFX } from './audio.js';

const $ = id => document.getElementById(id);
async function boot() {
  load(); init($('c')); setQuality(S.hq);
  await loadAll(p => { $('lbar').style.width = Math.round(p * 100) + '%'; $('lpct').textContent = Math.round(p * 100) + '%'; });
  UI.bind(GM.G, { ...GM, setQuality }); UI.build(); GM.initGame();
  $('lstart').hidden = false; $('lbarw').hidden = true; $('lpct').hidden = true;
  $('lstart').onclick = () => {
    SFX.unlock(); SFX.music(['hub', 'zone0', 'zone1', 'dungeon'][S.world]); $('load').classList.add('out'); setTimeout(() => $('load').remove(), 700);
    if (!S.tuto) { S.tuto = 1; setTimeout(() => UI.toast('AUTO est activé : ton héros chasse tout seul. Joystick à gauche pour bouger.'), 900); setTimeout(() => UI.toast('Quand un ennemi tombe, son âme flotte : touche S\'ÉLEVER pour en faire ton ombre !', 'gold'), 5200); }
  };
  let last = performance.now();
  const loop = now => {
    const dt = Math.min(0.05, (now - last) / 1000); last = now; window.__frames = (window.__frames || 0) + 1;
    try { GM.update(dt); } catch (e) { console.error(e); }
    updateFx(dt); camFollow(GM.G.P.pos, dt); try { UI.update(dt); } catch (e) { console.error(e); } render();
    requestAnimationFrame(loop);
  };
  requestAnimationFrame(loop);
  setInterval(save, 5000); addEventListener('visibilitychange', () => document.hidden && save());
  window.__G = GM.G; window.__S = S; window.__GM = GM; window.__UI = UI;
}
boot().catch(e => { console.error(e); $('lpct').textContent = 'Erreur : ' + e.message; });
