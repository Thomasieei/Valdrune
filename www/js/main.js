// Souverain des Ombres — brique 1 : relever ses ombres, les envoyer au bois, voir le royaume grandir.
import { THREE, G, V, initRendu, rendre, majCamera, initEntrees, solSous, directionVoulue, projeter, initAudio, chargerSons, son, emettre, texteFlottant, majFlottants } from './moteur.js';
import { chargerPersos, Perso } from './persos.js';
import { chargerNature, construireMonde, majMonde, majPile, hauteur, arbreProche, frapperArbre, libre, RESERVE, FEU, filons } from './monde.js';
import { Ombre, RANGS, NOMS, METIERS, parole, surParole, surSignal, xpNiveau, teinteOmbre } from './ombres.js';
import { initCombat, majCombat, heroOccupe, campLibre, zoneDangereuse, POUVOIRS, xpHeros, pvMaxHeros, heros } from './combat.js';
import { chargerMonstre } from './persos.js';
import { chargerBatiments, TYPES, CATS, batiments, creerBatiment, majBatiments, placementValide, fantomeBatiment, majEtiquettesChantiers, aBatiment, marteler, chantierProche, depotProche, ameliorer, enTravaux, niveauDe, prochain, meilleur, bloque, majInterieur, dedans } from './batiments.js';

const $ = (s) => document.querySelector(s);
const CLE = 'souverain-v1';
// ---------------- Sauvegarde ----------------
let J = null;
function nouvelleSauvegarde() { return { bois: 0, pierre: 0, mana: 100, ombres: [], depouilles: [0, 1, 2, 3, 4], batiments: [], quete: 0, total: 0 }; }
function charger() { try { const s = localStorage.getItem(CLE); return s ? JSON.parse(s) : null; } catch (e) { return null; } }
let sauveT = 0; function sauver() { J.vu = Date.now(); try { localStorage.setItem(CLE, JSON.stringify(J)); } catch (e) {} }
// ---------------- Le souverain ----------------
const joueur = { perso: null, pos: null, manaMax: 100, chop: null };
const DEP = [V(-9, 0, 6), V(-11.5, 0, 3), V(-8, 0, 9.5), V(-12.5, 0, 7.5), V(-10, 0, 11.5)];
const depouilles = []; const ombres = []; let selection = null;
function creerJoueur() {
  const p = joueur.perso = new Perso({ sexe: 'h', tenue: 'rodeur', cheveux: 1 });
  p.root.position.set(2, 0, 6); G.scene.add(p.root); joueur.pos = p.root.position; p.jouer('Idle_Loop');
}
function creerDepouilles() {
  for (const i of J.depouilles) {
    const p = new Perso({ sexe: i % 3 === 1 ? 'f' : 'h', tenue: 'paysan', cheveux: i, couleurTenue: ['#8a6a4a', '#5a6a8a', '#7a4a4a', '#6a7a5a', '#8a7a5a'][i] });
    p.root.position.copy(DEP[i]); p.root.position.y = hauteur(DEP[i].x, DEP[i].z); p.root.rotation.y = i * 1.3; G.scene.add(p.root);
    const a = p.jouer('Death01', { boucle: false }); if (a) { a.time = a.getClip().duration; } p.maj(0.01);
    // une lame brisée et une tache sombre : un champ de bataille, pas un décor
    const tache = new THREE.Mesh(new THREE.CircleGeometry(0.9, 20).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ color: '#1a0a14', transparent: true, opacity: 0.45, depthWrite: false })); tache.position.set(DEP[i].x, p.root.position.y + 0.03, DEP[i].z); G.scene.add(tache);
    depouilles.push({ i, p, tache });
  }
}
function ajouterOmbre(d, pos) { const o = new Ombre(d, pos); ombres.push(o); return o; }
// ---------------- Éveil (ARISE) ----------------
const COUT_EVEIL = 40;
function tirerRang() { const r = Math.random(); return r < 0.02 ? 'A' : r < 0.08 ? 'B' : r < 0.25 ? 'C' : r < 0.55 ? 'D' : 'E'; }
function eveiller(dep) {
  if (J.mana < COUT_EVEIL) { toast(`Pas assez de mana (${COUT_EVEIL})`); son('error_004', 0.4); return; }
  J.mana -= COUT_EVEIL; enScene = true;
  J.depouilles = J.depouilles.filter(i => i !== dep.i); depouilles.splice(depouilles.indexOf(dep), 1);
  const pos = dep.p.root.position.clone();
  $('#eveil').classList.add('on'); son('sov_possession', 0.7, 0.9); G.shake = 0.35;
  const cercle = new THREE.Mesh(new THREE.RingGeometry(0.2, 2.2, 40).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ color: '#7a3aff', transparent: true, opacity: 0.7, blending: THREE.AdditiveBlending, depthWrite: false })); cercle.position.set(pos.x, pos.y + 0.05, pos.z); G.scene.add(cercle);
  let t = 0; const id = (J.ombres.reduce((m, o) => Math.max(m, o.id), 0) || 0) + 1;
  const d = { id, nom: NOMS[(id - 1) % NOMS.length], rang: tirerRang(), metier: 'suivre', sexe: dep.i % 3 === 1 ? 'f' : 'h', cheveux: dep.i, maitrise: { bois: { niv: 1, xp: 0 } } };
  const anim = (dt) => {
    t += dt; cercle.rotation.y += dt * 2; cercle.scale.setScalar(1 + Math.sin(t * 6) * 0.06);
    if (Math.random() < 0.9) emettre(V(pos.x + (Math.random() - 0.5) * 2, pos.y + 0.1, pos.z + (Math.random() - 0.5) * 2), { n: 3, c1: '#b48aff', c2: '#140820', vit: 0.6, vie: 1.2, taille: 0.35, grav: -3, haut: 2 });
    if (t > 1.1 && dep.p) { G.scene.remove(dep.p.root); G.scene.remove(dep.tache); dep.p = null; const o = ajouterOmbre(d, pos); o.p.root.rotation.y = Math.atan2(joueur.pos.x - pos.x, joueur.pos.z - pos.z); o.p.jouer('LayToIdle', { boucle: false, forcer: true, fondu: 0 }); o.scene = () => {}; nouvelle = o; son('sov_onde', 0.6, 0.8); emettre(V(pos.x, pos.y + 1, pos.z), { n: 70, c1: '#d8c0ff', c2: '#3a0a7a', vit: 5, vie: 1, taille: 0.3, grav: 0 }); }
    if (t > 3.2 && nouvelle && !nouvelle._kneel) { nouvelle._kneel = true; nouvelle.p.jouer('Fixing_Kneeling', { boucle: true }); nouvelle.dire(parole('eveil')); revelerRang(d); }
    if (t > 6.2) { G.scene.remove(cercle); $('#eveil').classList.remove('on'); if (nouvelle) { nouvelle.scene = null; nouvelle.p.jouer('Idle_Loop'); } nouvelle = null; enScene = false; J.ombres.push(d); sauver(); majQuete(); return true; }
  };
  let nouvelle = null; scenes.push(anim);
}
function revelerRang(d) {
  const R = RANGS[d.rang], el = $('#rangRevele');
  el.innerHTML = `<small>Nouvelle ombre</small><b>${d.nom}</b><span class="rang" style="--c:${R.c}">RANG ${d.rang}</span><em>Bûcheronnage ×${R.coupe.toFixed(2)} · porte ${R.charge} bûches</em>`;
  el.classList.remove('on'); void el.offsetWidth; el.classList.add('on'); son('CBAS'.includes(d.rang) ? 'jingles_PIZZI03' : 'confirmation_001', 0.5);
  setTimeout(() => el.classList.remove('on'), 3800);
}
// ---------------- Économie ----------------
const ICONES = { bois: '🪵', pierre: '🪨' };
const jeu = {
  ajouter(res, n, pos) {
    J[res] = (J[res] || 0) + n; if (res === 'bois') { J.total += n; majPile(J.bois); }
    son(res === 'bois' ? 'drop_002' : 'impactPunch_medium_001', 0.35, 1, pos);
    texteFlottant(V(pos.x, (pos.y || 0) + 2.4, pos.z), `+${n} ${ICONES[res]}`, 'bois'); majHud(res); majQuete();
  },
  batimentFini(b, o) {
    son('jingles_PIZZI03', 0.5); toast(b.s.niv > 1 ? `${b.T.icone} ${b.T.nom} passe niveau ${b.s.niv} ! ${'⭐'.repeat(b.s.niv)}` : `${b.T.icone} ${b.T.nom} terminé${b.T.nom.endsWith('e') ? 'e' : ''} !`);
    emettre(V(b.g.position.x, b.g.position.y + 2, b.g.position.z), { n: 80, c1: '#ffe9a0', c2: '#b36bff', vit: 5, vie: 1.1, taille: 0.25, grav: 1 });
    if (o && !b.T.segment) o.dire('C’est fait, maître.'); appliquerBatiments(); sauver(); majQuete(); if ($('#panneau').classList.contains('on') && $('#panneau').dataset.vue === 'ombres') ouvrirOmbres();
  },
};
function appliquerBatiments() {
  joueur.manaMax = 100 + batiments.reduce((m, b) => m + (b.fini && b.s.type === 'puits' ? niveauDe(b).mana : 0), 0); joueur.regen = Math.max(1, meilleur('puits', 'regen'));
  G.repousseBois = Math.max(1, meilleur('scierie', 'repousse')); G.repoussePierre = Math.max(1, meilleur('mine', 'repousse'));
  G.chargeBonus = { bois: meilleur('scierie', 'charge'), pierre: meilleur('mine', 'charge') };
  J.habMax = batiments.reduce((m, b) => m + (b.fini ? niveauDe(b).habitants || 0 : 0), 0);
}
Object.defineProperty(jeu, 'pos', { get: () => joueur.pos }); Object.defineProperty(jeu, 'perso', { get: () => joueur.perso });
// ---------------- Quête guidée (on comprend en 10 secondes quoi faire) ----------------
const QUETES = [
  { t: 'Éveille une ombre', s: 'Approche-toi d’un corps sur le champ de bataille et touche ÉVEILLE-TOI.', fait: () => J.ombres.length >= 1 },
  { t: 'Envoie-la au bois', s: 'Touche 👑, touche ton ombre, puis touche un arbre.', fait: () => J.ombres.some(o => o.metier === 'bois'),
    guide: () => G.mode !== 'souverain' ? '#btnMode' : !selection ? ombres[0] && ombres[0].pos : arbreProche(selection.pos, a => a.etat === 'debout', 30)?.pos },
  { t: 'Remplis la réserve', s: 'Regarde-la abattre, débiter et porter le bois. Objectif : 60 bûches.', fait: () => J.bois >= 60, prog: () => [J.bois, 60] },
  { t: 'Une armée de bûcherons', s: 'Éveille 3 ombres et mets-les toutes au bois : la réserve monte bien plus vite.', fait: () => J.ombres.filter(o => o.metier === 'bois').length >= 3 },
  { t: 'Le premier bâtiment', s: 'Touche CONSTRUIRE → ⚒️ Métiers → Scierie et pose-la. Puis touche une ombre et le chantier.', fait: () => aBatiment('scierie'),
    guide: () => { const ch = batiments.find(b => b.s.type === 'scierie'); if (!ch) return placement ? '#btnPoser' : $('#panneau').classList.contains('on') ? (document.querySelector('[data-poser=scierie]') ? '[data-poser=scierie]' : '[data-onglet=metier]') : '#btnConstruire'; if (ombres.some(o => o.d.metier === 'construire')) return null; if (G.mode !== 'souverain') return '#btnMode'; return !selection ? ombres[0] && ombres[0].pos : ch.g.position; } },
  { t: 'Ouvrir la carrière', s: 'Construis le Camp de mineurs : il débloque la pierre (la carrière est au nord-est).', fait: () => aBatiment('mine') },
  { t: 'Libérer la carrière', s: 'Des diablotins gardent la carrière (zone rouge). Entre et combats : ⚔️ pour frapper, tes pouvoirs autour. Le cercle rouge au sol annonce leur coup : PARADE au bon moment !', fait: () => campLibre('carriere') || J.pierre >= 60, guide: () => G.mode === 'souverain' ? '#btnMode' : null },
  { t: 'Tailler la pierre', s: 'Mets des ombres en ⛏️ Tailleur. Objectif : 60 pierres.', fait: () => J.pierre >= 60, prog: () => [J.pierre, 60] },
  { t: 'Protéger le camp', s: 'Pose 6 segments de Palissade autour du camp. Les raids arrivent bientôt…', fait: () => batiments.filter(b => b.fini && b.s.type === 'palissade').length >= 6, prog: () => [batiments.filter(b => b.fini && b.s.type === 'palissade').length, 6] },
  { t: 'Un toit pour ton peuple', s: 'Construis une Maison (onglet 🏠 Ville) : elle loge 10 habitants.', fait: () => aBatiment('maison') },
  { t: 'Le cœur du village', s: 'Construis un Puits (bois + pierre) : +20 mana max.', fait: () => aBatiment('puits') },
  { t: 'Ton armée d’ombres', s: 'Bats des monstres (les Puglins de la clairière, à l’ouest) et utilise ARISE sur leur corps : 10 % de chance, qui grandit avec le pouvoir.', fait: () => (J.armee || []).length >= 1 },
  { t: 'Agrandir la scierie', s: 'Touche ta scierie et améliore-la au niveau 2 : plus de bois, arbres plus rapides.', fait: () => batiments.some(b => b.s.type === 'scierie' && b.s.niv >= 2), guide: () => { const b = batiments.find(x => x.s.type === 'scierie'); return $('#panneau').classList.contains('on') ? '[data-amel]' : b && b.g.position; } },
];
function majQuete() {
  while (J.quete < QUETES.length && QUETES[J.quete].fait()) { J.quete++; son('maximize_006', 0.5); if (J.quete < QUETES.length) toast('Objectif accompli !'); }
  const q = QUETES[J.quete], el = $('#quete');
  if (!q) { el.innerHTML = '<b>Royaume en marche</b><span>Ton camp est bâti. Prochaine étape : le premier vrai donjon.</span>'; return; }
  const p = q.prog ? q.prog() : null;
  el.innerHTML = `<b>${q.t}</b><span>${q.s}</span>${p ? `<i><u style="width:${Math.min(100, p[0] / p[1] * 100)}%"></u></i>` : ''}`;
}
// ---------------- Interface ----------------
function toast(t) { const d = document.createElement('div'); d.className = 'toast'; d.textContent = t; $('#toasts').appendChild(d); setTimeout(() => d.remove(), 2600); }
let boisAff = -1;
function majHud(pop = false) {
  const txt = `🪵 <b>${J.bois}</b>${J.pierre || aBatiment('mine') ? ` <span class="sep"></span> 🪨 <b>${J.pierre}</b>` : ''}${J.habMax ? ` <span class="sep"></span> 👥 <b>${J.habitants || 0}/${J.habMax}</b>` : ''}`;
  if (txt !== boisAff) { $('#bois').innerHTML = txt; boisAff = txt; if (pop) { const b = $('#bois'); b.classList.remove('pop'); void b.offsetWidth; b.classList.add('pop'); } }
  $('#mana i').style.width = (J.mana / joueur.manaMax * 100) + '%'; $('#mana b').textContent = `${Math.floor(J.mana)} / ${joueur.manaMax}`;
  if (J.heros) { const pm = pvMaxHeros(); $('#pv i').style.width = (joueur.pv / pm * 100) + '%'; $('#pv b').textContent = `${Math.ceil(joueur.pv)} / ${pm}`; $('#moi h1').innerHTML = `Le Souverain <em>Nv ${J.heros.niv}</em>${J.heros.pts ? ' <span class="pts">+' + J.heros.pts + '</span>' : ''}`; $('#xp').style.width = (J.heros.xp / xpHeros(J.heros.niv) * 100) + '%'; }
  $('#btnOmbres small').textContent = J.ombres.length;
}
const bulles = new Map();
surSignal((o, t) => toast(t));
surParole((o, t) => { let b = bulles.get(o); if (!b) { b = document.createElement('div'); b.className = 'bulle'; $('#bulles').appendChild(b); bulles.set(o, b); } b.textContent = t; b.dataset.t = String(G.t + 3.2); b.style.display = ''; });
const etiquettes = new Map();
function majEtiquettes() {
  for (const o of ombres) {
    let e = etiquettes.get(o); if (!e) { e = document.createElement('div'); e.className = 'eti'; $('#bulles').appendChild(e); etiquettes.set(o, e); }
    const s = projeter(V(o.pos.x, o.pos.y + 2.15, o.pos.z)), loin = Math.hypot(o.pos.x - joueur.pos.x, o.pos.z - joueur.pos.z) > 22;
    const html = `<span class="rg" style="--c:${o.R.c}">${o.d.rang}</span>${o.d.nom}${o.charge ? ` <em>🪵${o.charge}</em>` : ''}`; if (e._h !== html) { e.innerHTML = html; e._h = html; }
    e.style.display = s.devant && !loin ? '' : 'none'; e.classList.toggle('sel', selection === o); e.style.transform = `translate(${s.x}px,${s.y}px) translate(-50%,-100%)`;
    const b = bulles.get(o); if (b && b.style.display !== 'none') { if (G.t > +b.dataset.t || !s.devant || loin) b.style.display = 'none'; else b.style.transform = `translate(${s.x}px,${s.y - 26}px) translate(-50%,-100%)`; }
  }
}
// liste des ombres pensée pour le téléphone : filtres par métier, petites pastilles, sélection multiple et ordres groupés
let filtreO = 'tout'; const choisies = new Set();
const NOMS_M = { bois: 'Bois', pierre: 'Pierre', construire: 'Bâtir', suivre: 'Suivre', repos: 'Repos' };
function ouvrirOmbres() {
  const p = $('#panneau'), dejaOuvert = p.classList.contains('on') && p.dataset.vue === 'ombres';
  p.classList.add('on'); p.dataset.vue = 'ombres'; p.querySelector('h2').textContent = `Tes ombres · ${J.ombres.length}`; if (!dejaOuvert) son('confirmation_001', 0.3);
  if (!J.ombres.length) { p.querySelector('.liste').innerHTML = '<p class="vide">Aucune ombre. Approche-toi d’un corps sur le champ de bataille et éveille-le.</p>'; return; }
  if (selection && !dejaOuvert) { choisies.clear(); choisies.add(selection.d.id); }
  for (const id of [...choisies]) if (!J.ombres.some(d => d.id === id)) choisies.delete(id);
  const mine = aBatiment('mine'), compte = (m) => J.ombres.filter(d => d.metier === m).length;
  const filtres = `<div class="filtres">${['tout', 'bois', 'pierre', 'construire', 'suivre', 'repos'].map(f => { const n = f === 'tout' ? J.ombres.length : compte(f); return n || f === 'tout' ? `<button data-filtre="${f}" class="${filtreO === f ? 'on' : ''}">${f === 'tout' ? 'Toutes' : METIERS[f].icone} <b>${n}</b></button>` : ''; }).join('')}</div>`;
  const liste = J.ombres.filter(d => filtreO === 'tout' || d.metier === filtreO);
  const pastilles = `<div class="pastilles">${liste.map(d => { const R = RANGS[d.rang], k = ['bois', 'pierre', 'construire'].includes(d.metier) ? d.metier : 'bois', mt = d.maitrise[k] || { niv: 1 };
    return `<button class="pastille ${choisies.has(d.id) ? 'sel' : ''}" data-pid="${d.id}"><span class="rg" style="--c:${R.c}">${d.rang}</span><b>${d.nom}</b><small>${METIERS[d.metier].icone} ${mt.niv}</small></button>`; }).join('')}</div>`;
  let bas = '';
  if (choisies.size) {
    const un = choisies.size === 1 ? J.ombres.find(d => choisies.has(d.id)) : null;
    const det = un ? (() => { const R = RANGS[un.rang]; return `<div class="detail">Force ×${R.coupe.toFixed(2)} · porte ${R.charge} · vitesse ${R.vit} · ${['bois', 'pierre', 'construire'].map(k => `${METIERS[k].icone}${(un.maitrise[k] || { niv: 1 }).niv}`).join(' ')}</div>`; })() : `<div class="detail">${choisies.size} ombres choisies · un ordre pour toutes</div>`;
    bas = `<div class="barreOrdres">${det}<div class="ordres">${['bois', 'pierre', 'construire', 'suivre', 'repos'].map(o => `<button data-go="${o}" ${o === 'pierre' && !mine ? 'disabled' : ''}>${METIERS[o].icone}<small>${o === 'pierre' && !mine ? 'Camp requis' : NOMS_M[o]}</small></button>`).join('')}</div></div>`;
  } else bas = `<p class="vide">Touche une ou plusieurs ombres pour leur donner un ordre. <button class="lien" data-toutes>Tout choisir</button></p>`;
  p.querySelector('.liste').innerHTML = filtres + pastilles + bas;
}
// mode construction : trois onglets, de grosses tuiles, et ce qui arrive bientôt (le joueur voit où il va)
const BIENTOT = {
  ville: [['📦', 'Entrepôt'], ['🍺', 'Taverne'], ['⛪', 'Autel des ombres']],
  metier: [['⚒️', 'Forge'], ['🥖', 'Boulangerie'], ['🥩', 'Boucherie'], ['🛒', 'Épicerie']],
  militaire: [['🗼', 'Tour de défense'], ['🛡️', 'Caserne'], ['🏹', 'Archerie']],
};
let ongletC = 'ville';
function ouvrirConstruire(onglet) {
  if (onglet) ongletC = onglet;
  const p = $('#panneau'); p.classList.add('on'); p.dataset.vue = 'construire'; p.querySelector('h2').textContent = 'Construire'; son('confirmation_001', 0.3);
  const onglets = `<div class="onglets">${Object.entries(CATS).map(([k, c]) => `<button data-onglet="${k}" class="${k === ongletC ? 'on' : ''}" style="--c:${c.c}">${c.icone}<small>${c.nom}</small></button>`).join('')}</div>`;
  const tuiles = Object.entries(TYPES).filter(([, T]) => T.cat === ongletC).map(([k, T]) => {
    const ok = Object.entries(T.cout).every(([r, n]) => (J[r] || 0) >= n), nb = batiments.filter(b => b.s.type === k).length;
    return `<button class="tuile ${ok ? '' : 'non'}" data-poser="${k}" style="--c:${CATS[T.cat].c}"><i>${T.icone}</i><b>${T.nom}</b>${nb ? `<em>× ${nb}</em>` : ''}
      <span class="cout">${Object.entries(T.cout).map(([r, n]) => `<span class="${(J[r] || 0) >= n ? '' : 'manque'}">${ICONES[r]}${n}</span>`).join(' ')}</span><small>${T.niveaux[0].effet}</small></button>`;
  }).join('') + BIENTOT[ongletC].map(([i, n]) => `<div class="tuile verrou"><i>${i}</i><b>${n}</b><span class="cout">🔒 Bientôt</span></div>`).join('');
  p.querySelector('.liste').innerHTML = onglets + `<div class="tuiles">${tuiles}</div>`;
}
// ---------------- Pouvoirs du héros (touche ton portrait) ----------------
const SYMB = { lame: '🗡️', tele: '🌀', parade: '🛡️', arise: '🜏' };
function ouvrirPouvoirs() {
  const p = $('#panneau'), h = J.heros; p.classList.add('on'); p.dataset.vue = 'pouvoirs'; p.querySelector('h2').textContent = `Le Souverain · Nv ${h.niv}`; son('confirmation_001', 0.3);
  p.querySelector('.liste').innerHTML = `<p class="vide">❤️ ${pvMaxHeros()} PV · ⭐ ${h.xp}/${xpHeros(h.niv)} XP · <b>${h.pts || 0}</b> point${(h.pts || 0) > 1 ? 's' : ''} à dépenser</p>` + Object.entries(POUVOIRS).map(([k, P]) => {
    const n = h.pw[k]; return `<div class="carte bat"><div class="tete"><span class="ico">${SYMB[k]}</span><b>${P.nom}</b><small class="et">Niveau ${n}</small></div>
      <div class="stats">${P.effet(n)}${P.cd ? ` · recharge ${P.cd} s` : ''}${P.mana ? ` · ${P.mana} mana` : ''}</div>
      <div class="stats suivant">Niveau ${n + 1} : ${P.effet(n + 1)}</div><div class="cout"><button data-pw="${k}" ${h.pts ? '' : 'disabled'}>Améliorer · 1 point</button></div></div>`; }).join('');
}
$('#moi').onclick = () => ouvrirPouvoirs();
function batimentSous(q) { let best = null, bd = 1e9; for (const b of batiments) { if (b.T.segment) continue; const d = Math.hypot(b.g.position.x - q.x, b.g.position.z - q.z); if (d < b.T.rayon && d < bd) { bd = d; best = b; } } return best; }
const etoiles = (n, max) => '★'.repeat(n) + '<i>' + '★'.repeat(max - n) + '</i>';
let batOuvert = null;
function ouvrirBatiment(b) {
  batOuvert = b; const p = $('#panneau'); p.classList.add('on'); p.dataset.vue = 'batiment'; p.querySelector('h2').textContent = b.T.nom; son('confirmation_001', 0.3);
  const n = niveauDe(b), nx = prochain(b), max = b.T.niveaux.length, niv = b.s.niv || 1;
  let bas;
  if (!b.fini) bas = `<p class="vide">🔨 En construction · ${Math.floor((b.s.prog || 0) * 100)} % — mets des ombres en Bâtir.</p>`;
  else if (b.s.amel) bas = `<p class="vide">⬆️ Amélioration en cours · ${Math.floor((b.s.prog || 0) * 100)} % — tes bâtisseurs y travaillent.</p>`;
  else if (!nx) bas = '<p class="vide">👑 Niveau maximum atteint.</p>';
  else { const ok = Object.entries(nx.cout).every(([r, k]) => (J[r] || 0) >= k);
    bas = `<div class="carte bat ${ok ? '' : 'non'}"><div class="tete"><span class="ico">⬆️</span><b>Niveau ${niv + 1}</b><small class="et">${etoiles(niv + 1, max)}</small></div>
      <div class="stats">${nx.effet}</div><div class="cout">${Object.entries(nx.cout).map(([r, k]) => `<span class="${(J[r] || 0) >= k ? '' : 'manque'}">${ICONES[r]} ${k}</span>`).join(' ')}<button data-amel ${ok ? '' : 'disabled'}>Améliorer</button></div></div>`; }
  p.querySelector('.liste').innerHTML = `<div class="carte bat"><div class="tete"><span class="ico">${b.T.icone}</span><b>Niveau ${niv}</b><small class="et">${etoiles(niv, max)}</small></div><div class="stats">${n.effet}</div></div>` + bas;
}
$('#panneau').addEventListener('click', (e) => {
  if (e.target.closest('[data-x]')) { $('#panneau').classList.remove('on'); return; }
  if (e.target.closest('[data-amel]') && batOuvert) {
    const b = batOuvert, nx = prochain(b); if (!nx || !Object.entries(nx.cout).every(([r, k]) => (J[r] || 0) >= k)) return;
    for (const [r, k] of Object.entries(nx.cout)) J[r] -= k; ameliorer(b); son('impactPunch_medium_001', 0.5); majHud(); sauver();
    $('#panneau').classList.remove('on'); toast(J.ombres.some(o => o.metier === 'construire') ? '⬆️ Échafaudages montés : tes bâtisseurs s’y mettent' : '⬆️ Échafaudages montés ! Mets une ombre en 🔨 Bâtir'); return;
  }
  const pw = e.target.closest('[data-pw]'); if (pw && J.heros.pts > 0) { J.heros.pts--; J.heros.pw[pw.dataset.pw]++; son('jingles_PIZZI01', 0.5); emettre(V(joueur.pos.x, joueur.pos.y + 1, joueur.pos.z), { n: 40, c1: '#ffe9a0', c2: '#b36bff', vit: 3, vie: 0.9, taille: 0.22, grav: -1 }); sauver(); majHud(); ouvrirPouvoirs(); return; }
  const og = e.target.closest('[data-onglet]'); if (og) { ouvrirConstruire(og.dataset.onglet); return; }
  const pz = e.target.closest('[data-poser]'); if (pz) { if (pz.classList.contains('non')) { son('error_004', 0.4); toast('Pas assez de ressources'); return; } $('#panneau').classList.remove('on'); commencerPlacement(pz.dataset.poser); return; }
  const fl = e.target.closest('[data-filtre]'); if (fl) { filtreO = fl.dataset.filtre; son('cloth1', 0.25); ouvrirOmbres(); return; }
  const pa = e.target.closest('[data-pid]'); if (pa) { const id = +pa.dataset.pid; choisies.has(id) ? choisies.delete(id) : choisies.add(id); son('cloth1', 0.3); ouvrirOmbres(); return; }
  if (e.target.closest('[data-toutes]')) { J.ombres.filter(d => filtreO === 'tout' || d.metier === filtreO).forEach(d => choisies.add(d.id)); ouvrirOmbres(); return; }
  const b = e.target.closest('[data-go]'); if (!b || b.disabled) return;
  let premier = true;
  for (const id of choisies) { const d = J.ombres.find(x => x.id === id), o = ombres.find(x => x.d === d); if (!d) continue; if (o) { o.changerMetier(b.dataset.go); if (premier) o.dire(parole(b.dataset.go)); premier = false; } else d.metier = b.dataset.go; }
  son('confirmation_001', 0.4); toast(`${METIERS[b.dataset.go].icone} Ordre donné à ${choisies.size} ombre${choisies.size > 1 ? 's' : ''}`);
  choisies.clear(); sauver(); majQuete(); ouvrirOmbres();
});
$('#btnOmbres').onclick = () => ouvrirOmbres();
$('#btnConstruire').onclick = () => ouvrirConstruire();
// ---------------- Placement d'un bâtiment (fantôme vert = OK, rouge = impossible) ----------------
let placement = null;
function commencerPlacement(type) { changerMode('souverain'); const q = solSous(innerWidth / 2, innerHeight / 2) || G.focus; placement = { type, r: 0, x: q.x, z: q.z };
  for (let i = 0; i < 160; i++) { const an = i * 2.4, rr = Math.sqrt(i) * 1.6, x = q.x + Math.cos(an) * rr, z = q.z + Math.sin(an) * rr; if (placementValide(type, x, z)) { placement.x = x; placement.z = z; G.focus.set(x, 0, z); break; } } /* premier endroit libre près du centre */ $('#placement').hidden = false; indice('Fais glisser le bâtiment, puis touche POSER'); }
function finPlacement() { if (placement) indice(''); placement = null; fantomeBatiment(null); $('#placement').hidden = true; }
function majPlacement() {
  if (!placement) return;
  const T = TYPES[placement.type];
  const assez = Object.entries(T.cout).every(([r, n]) => (J[r] || 0) >= n);
  placement.ok = assez && placementValide(placement.type, placement.x, placement.z);
  fantomeBatiment(placement.type, placement.x, placement.z, placement.r, placement.ok);
  const b = $('#btnPoser'); b.disabled = !placement.ok; b.textContent = !assez ? 'Pas assez de ressources' : placement.ok ? `Poser · ${Object.entries(T.cout).map(([r, n]) => ICONES[r] + n).join(' ')}` : 'Place occupée';
}
function poser() {
  if (!placement || !placement.ok) { son('error_004', 0.4); return; }
  const T = TYPES[placement.type]; for (const [r, n] of Object.entries(T.cout)) J[r] -= n;
  const s = { type: placement.type, x: +placement.x.toFixed(2), z: +placement.z.toFixed(2), r: placement.r, prog: 0, fini: false };
  J.batiments.push(s); creerBatiment(s, false); son('impactPunch_medium_001', 0.5); emettre(V(s.x, hauteur(s.x, s.z) + 0.2, s.z), { n: 30, c1: '#d8c8a8', c2: '#6a5a4a', vit: 3, vie: 0.7, taille: 0.3, grav: 4 });
  majHud(); sauver();
  if (!J.ombres.some(o => o.metier === 'construire')) toast('Chantier posé ! Mets une ombre en 🔨 Bâtir');
  if (T.segment && Object.entries(T.cout).every(([r, n]) => (J[r] || 0) >= n)) { placement.x += Math.sin(placement.r + Math.PI / 2) * 2.1; placement.z += Math.cos(placement.r + Math.PI / 2) * 2.1; } // segment suivant juste à côté
  else finPlacement();
}
$('#btnPoser').onclick = () => { initAudio(); poser(); };
$('#btnTourner').onclick = () => { if (placement) placement.r += Math.PI / 4; son('cloth1', 0.3); };
$('#btnAnnuler').onclick = () => finPlacement();
// ---------------- Action contextuelle (un seul gros bouton, comme Roblox) ----------------
let actionCb = null;
function action(txt, cb, cls = '') { const b = $('#action'); if (!txt) { b.hidden = true; actionCb = null; return; } if (b.textContent !== txt) b.textContent = txt; b.className = cls; b.hidden = false; actionCb = cb; }
$('#action').onclick = () => { initAudio(); actionCb && actionCb(); };
function majAction() {
  if (enScene || placement || G.mode === 'souverain') return action(null);
  const dep = depouilles.find(d => Math.hypot(d.p.root.position.x - joueur.pos.x, d.p.root.position.z - joueur.pos.z) < 2.6);
  if (dep) return action(`ÉVEILLE-TOI · ${COUT_EVEIL} mana`, () => eveiller(dep), 'eveil');
  const ch = chantierProche(joueur.pos); if (ch && Math.hypot(ch.g.position.x - joueur.pos.x, ch.g.position.z - joueur.pos.z) < ch.T.rayon + 1.5) return action(joueur.bati ? 'Tu construis…' : `Aider à bâtir · ${Math.floor((ch.s.prog || 0) * 100)} %`, () => { joueur.bati = ch; }, 'bois');
  const a = arbreProche(joueur.pos, x => x.etat === 'debout', 2.4);
  if (a) return action(joueur.chop ? 'Tu coupes…' : 'Couper l’arbre', () => { joueur.chop = a; }, 'bois');
  action(null);
}
// ---------------- Sélection au doigt ----------------
function ombreSous(x, y) { let best = null, bd = 60; for (const o of ombres) { const s = projeter(V(o.pos.x, o.pos.y + 1, o.pos.z)); const d = Math.hypot(s.x - x, s.y - y); if (s.devant && d < bd) { bd = d; best = o; } } return best; }
function toucher(x, y) {
  const best = ombreSous(x, y);
  if (G.mode !== 'souverain') { if (best) { selection = best; best.dire(`${best.d.nom}, rang ${best.d.rang}. J’écoute.`); son('cloth1', 0.4); ouvrirOmbres(); } else { const q = solSous(x, y), bt = q && batimentSous(q); if (bt) ouvrirBatiment(bt); } return; }
  const q = solSous(x, y);
  if (placement) { if (q) { placement.x = q.x; placement.z = q.z; } return; }
  if (best) { selection = best; son('cloth1', 0.4); best.dire(parole('eveil')); indice('Touche un arbre 🪓, un rocher ⛏️ ou un chantier 🔨'); return; }
  if (!selection || !q) { if (selection) { selection = null; indice(''); return; } const bt = q && batimentSous(q); if (bt) ouvrirBatiment(bt); return; }
  // ordre direct dans le monde : on touche la cible, l'ombre y va
  const ch = batiments.find(b => enTravaux(b) && Math.hypot(b.g.position.x - q.x, b.g.position.z - q.z) < b.T.rayon + 0.5);
  const ar = !ch && arbreProche(q, a => a.etat === 'debout' || (a.etat === 'abattu' && a.bois > 0), 2.4);
  const fi = !ch && !ar && filons.find(f => f.pierre > 0 && Math.hypot(f.pos.x - q.x, f.pos.z - q.z) < 0.75 * f.e + 1.2);
  let m = null, cible = null, cp = q;
  if (ch) { m = 'construire'; cible = ch; cp = ch.g.position; }
  else if (ar) { m = 'bois'; cible = ar; cp = ar.pos; }
  else if (fi) { if (zoneDangereuse(fi.pos)) { son('error_004', 0.4); toast('👹 Des monstres gardent ces rochers : libère la zone d’abord'); return; } if (!aBatiment('mine')) { son('error_004', 0.4); toast('⛏️ Construis d’abord le Camp de mineurs'); return; } m = 'pierre'; cible = fi; cp = fi.pos; }
  if (!m) { selection = null; indice(''); return; }
  selection.ordonner(m, cible); selection.dire(parole(m)); son('confirmation_001', 0.35);
  emettre(V(cp.x, (cp.y || 0) + 0.3, cp.z), { n: 24, c1: '#c8a8ff', c2: '#5a2aff', vit: 2.5, vie: 0.6, taille: 0.2, grav: 0 });
  sauver(); majQuete(); selection = null; indice('');
}
// le fantôme du bâtiment se fait glisser au doigt
function saisir(x, y) { if (!placement) return false; const q = solSous(x, y); return !!q && Math.hypot(q.x - placement.x, q.z - placement.z) < TYPES[placement.type].rayon + 1.2; }
function glisser(x, y) { const q = solSous(x, y); if (q && placement) { placement.x = q.x; placement.z = q.z; } }
function indice(t) { const e = $('#indice'); e.textContent = t; e.classList.toggle('on', !!t); }
// ---------------- Mode Héros ⇄ Souverain ----------------
function changerMode(m) {
  if (m === G.mode) return; G.mode = m; document.body.classList.toggle('souverain', m === 'souverain'); son('maximize_006', 0.35);
  if (m === 'souverain') { G.focus.copy(joueur.pos); joueur.chop = null; joueur.bati = null; $('#btnMode').innerHTML = '⚔️<small>Héros</small>'; indice('Glisse pour bouger · touche une ombre pour lui donner un ordre'); setTimeout(() => { if ($('#indice').textContent.startsWith('Glisse')) indice(''); }, 4500); }
  else { selection = null; indice(''); finPlacement(); $('#btnMode').innerHTML = '👑<small>Souverain</small>'; }
}
$('#btnMode').onclick = () => { initAudio(); changerMode(G.mode === 'souverain' ? 'heros' : 'souverain'); };
const anneau = new THREE.Mesh(new THREE.RingGeometry(0.55, 0.72, 32), new THREE.MeshBasicMaterial({ color: '#c8a8ff', transparent: true, opacity: 0.9, depthWrite: false }));
anneau.rotation.x = -Math.PI / 2;
function majAnneau() { anneau.visible = !!selection && G.mode === 'souverain'; if (anneau.visible) { if (!anneau.parent) G.scene.add(anneau); anneau.position.set(selection.pos.x, selection.pos.y + 0.06, selection.pos.z); const s = 1 + Math.sin(G.t * 6) * 0.08; anneau.scale.set(s, s, s); } }
// ---------------- Boucle ----------------
const scenes = []; let enScene = false; let dernier = performance.now();
const dir = V();
function majJoueur(dt) {
  const p = joueur.perso;
  if (heroOccupe()) { joueur.chop = null; joueur.bati = null; joueur.pos.y = hauteur(joueur.pos.x, joueur.pos.z); p.maj(dt); J.mana = Math.min(joueur.manaMax, J.mana + dt * 2.2 * (joueur.regen || 1)); return; }
  const f = directionVoulue(dir);
  if (f > 0.05) {
    joueur.chop = null; joueur.bati = null; const v = f > 0.85 ? 6.2 : 3.4;
    const nx = joueur.pos.x + dir.x * v * dt, nz = joueur.pos.z + dir.z * v * dt;
    if (Math.hypot(nx, nz) < 78 && libre(nx, nz)) { if (!bloque(nx, nz)) { joueur.pos.x = nx; joueur.pos.z = nz; } else if (!bloque(nx, joueur.pos.z)) joueur.pos.x = nx; else if (!bloque(joueur.pos.x, nz)) joueur.pos.z = nz; } /* glisse le long des murs */
    let da = Math.atan2(dir.x, dir.z) - p.root.rotation.y; da = Math.atan2(Math.sin(da), Math.cos(da)); p.root.rotation.y += da * Math.min(1, dt * 12);
    p.jouer(f > 0.85 ? 'Jog_Fwd_Loop' : 'Walk_Loop', { vitesse: f > 0.85 ? 1.15 : 1.1 });
  } else if (joueur.bati) {
    const b = joueur.bati; if (!enTravaux(b)) { joueur.bati = null; p.jouer('Idle_Loop'); }
    else { p.root.rotation.y = Math.atan2(b.g.position.x - joueur.pos.x, b.g.position.z - joueur.pos.z); p.jouer('Fixing_Kneeling', { vitesse: 1.3 }); joueur.bt = (joueur.bt || 0) - dt; if (joueur.bt <= 0) { joueur.bt = 0.7; if (marteler(b, 1.5, joueur.pos)) { jeu.batimentFini(b, null); joueur.bati = null; } } }
  } else if (joueur.chop) {
    const a = joueur.chop; if (a.etat !== 'debout') { joueur.chop = null; p.jouer('Idle_Loop'); }
    else { const ang = Math.atan2(a.pos.x - joueur.pos.x, a.pos.z - joueur.pos.z); p.root.rotation.y = ang; p.jouer('TreeChopping_Loop', { vitesse: 1.3 }); const ph = p.phase(); if (joueur.ph < 0.5 && ph >= 0.5) frapperArbre(a, joueur.pos, 2); joueur.ph = ph; }
  } else p.jouer('Idle_Loop');
  joueur.pos.y = hauteur(joueur.pos.x, joueur.pos.z); G.interieur = G.mode !== 'souverain' && !!majInterieur(joueur.pos.x, joueur.pos.z);
  p.maj(dt);
  J.mana = Math.min(joueur.manaMax, J.mana + dt * 2.2 * (joueur.regen || 1));
}
// ---------------- Main qui guide (on montre où toucher plutôt que d'expliquer) ----------------
let guideT = 0;
function majGuide(dt) {
  if ((guideT -= dt) > 0) return; guideT = 0.1;
  const m = $('#guide'), q = QUETES[J.quete], c = q && q.guide && !enScene ? q.guide() : null;
  let x = null, y = null;
  if (typeof c === 'string') { const e = document.querySelector(c); if (e && e.offsetWidth) { const r = e.getBoundingClientRect(); x = r.x + r.width / 2; y = r.y + r.height / 2; } }
  else if (c) { const s = projeter(V(c.x, (c.y || 0) + 1, c.z)); if (s.devant && s.x > 0 && s.x < innerWidth && s.y > 0 && s.y < innerHeight) { x = s.x; y = s.y; } }
  m.classList.toggle('on', x !== null); if (x !== null) m.style.transform = `translate(${x}px,${y}px)`;
}
// ---------------- Retour du joueur : ce que les ombres ont fait pendant son absence ----------------
let retourPret = null;
function horsLigne() {
  const sec = Math.min(8 * 3600, ((Date.now() - (J.vu || Date.now())) / 1000)); if (sec < 90) return;
  const g = { bois: 0, pierre: 0 }; let coups = 0;
  for (const o of ombres) {
    const m = o.d.metier;
    if (m === 'bois' || m === 'pierre') { const dep = depotProche(o.pos, m), n = Math.floor(sec * o.capacite(m) * dep.bonus * o.vitesse(m) / 45); g[m] += n; o.gagnerXp(m, n); }
    else if (m === 'construire') coups += sec * o.vitesse('construire') / 0.9;
  }
  for (const b of batiments) { if (coups <= 0) break; if (!enTravaux(b)) continue; const T = b.s.amel ? prochain(b) : b.T, reste = (1 - (b.s.prog || 0)) * (T.travail || b.T.travail), f = Math.min(coups, reste); coups -= f; if (marteler(b, f, b.g.position)) jeu.batimentFini(b, null); }
  for (const r in g) { J[r] += g[r]; if (r === 'bois') J.total += g[r]; }
  majPile(J.bois); appliquerBatiments();
  const h = Math.floor(sec / 3600), mn = Math.floor(sec % 3600 / 60), e = $('#retour');
  e.querySelector('p').textContent = `Tu es parti ${h ? h + ' h ' : ''}${mn} min. Tes ombres n’ont pas chômé :`;
  e.querySelector('.gains').innerHTML = (g.bois || g.pierre) ? `${g.bois ? `<span>🪵 +${g.bois}</span>` : ''}${g.pierre ? `<span>🪨 +${g.pierre}</span>` : ''}` : '<span>😴 Rien… aucune ombre ne travaillait</span>';
  retourPret = () => { e.hidden = false; }; e.onclick = () => { e.hidden = true; son('handleCoins2', 0.5); majHud(true); majQuete(); };
}
function boucle() {
  requestAnimationFrame(boucle);
  const now = performance.now(), dtR = Math.min(G.accel ? 0.25 : 0.1, (now - dernier) / 1000); dernier = now; const dt = dtR * (G.accel || 1) * (G.ralenti || 1); G.dt = dt; G.t += dt;
  majJoueur(dt); majCombat(dt);
  for (let i = scenes.length - 1; i >= 0; i--) if (scenes[i](dt)) scenes.splice(i, 1);
  let rangSuivre = 0; for (const o of ombres) o.maj(dt, jeu, o.d.metier === 'suivre' ? rangSuivre++ : 0);
  for (const d of depouilles) if (d.p && Math.random() < dt * 1.5) emettre(V(d.p.root.position.x, d.p.root.position.y + 0.3, d.p.root.position.z), { n: 1, c1: '#7a4aff', c2: '#100418', vit: 0.2, vie: 1.4, taille: 0.25, grav: -0.8 });
  majMonde(dt); majBatiments(dt); majPlacement(); majCamera(dt, V(joueur.pos.x, joueur.pos.y, joueur.pos.z)); majFlottants(dt); majEtiquettes(); majEtiquettesChantiers(); majAction(); majAnneau(); majGuide(dt);
  if ((sauveT -= dt) <= 0) { sauveT = 5; sauver(); majHud(); }
  else if (Math.floor(G.t * 10) !== Math.floor((G.t - dt) * 10)) majHud();
  rendre(dtR);
}
// ---------------- Démarrage ----------------
async function demarrer() {
  initRendu($('#scene'));
  const barre = $('#charge i'), pr = { p: 0, n: 0 }, avance = () => { barre.style.width = Math.round((pr.p + pr.n) / 2 * 100) + '%'; };
  await Promise.all([chargerPersos((k) => { pr.p = k; avance(); }), chargerNature((k) => { pr.n = k; avance(); }), chargerBatiments(), chargerMonstre('imp'), chargerMonstre('puglin'), chargerSons(['chop.ogg', 'drop_002.ogg', 'handleCoins.ogg', 'cloth1.ogg', 'confirmation_001.ogg', 'maximize_006.ogg', 'impactSoft_heavy_000.ogg', 'knifeSlice.ogg', 'jingles_PIZZI01.ogg', 'jingles_PIZZI03.ogg', 'sov_possession.wav', 'sov_onde.wav', 'error_004.ogg', 'impactMetal_light_000.ogg', 'impactPunch_medium_001.ogg', 'handleCoins2.ogg'])]);
  J = charger() || nouvelleSauvegarde(); J.pierre ??= 0; J.batiments ??= [];
  construireMonde(); creerJoueur(); creerDepouilles(); for (const s of J.batiments) creerBatiment(s, !!s.fini); appliquerBatiments();
  J.ombres.forEach((d, k) => ajouterOmbre(d, V(RESERVE.x + Math.cos(k) * 3, 0, RESERVE.z + Math.sin(k) * 3)));
  initCombat({ J, joueur, jeu, toast, sauver, majQuete, majHud });
  horsLigne();
  majPile(J.bois); majHud(); majQuete();
  initEntrees({ toucher, saisir, glisser });
  G.camYaw = 0.9; G.camCible.copy(joueur.pos);
  $('#charge').classList.add('pret'); $('#charge').onclick = () => { if (!$('#charge').classList.contains('pret')) return; initAudio(); $('#charge').classList.add('fini'); setTimeout(() => $('#charge').remove(), 700); if (retourPret) setTimeout(retourPret, 500); };
  boucle();
}
window.__s = { get J() { return J; }, get ombres() { return ombres; }, G, joueur, eveiller: (k = 0) => depouilles[k] && eveiller(depouilles[k]), mana: () => { J.mana = 100; }, toucher, mode: changerMode, bats: batiments, amel: (b) => { ameliorer(b); }, finir: (b) => marteler(b, 9999, b.g.position), ouvrirBat: ouvrirBatiment, proj: projeter, arbres: () => import('./monde.js') };
demarrer().catch(e => { document.body.insertAdjacentHTML('beforeend', `<pre style="position:fixed;inset:0;color:#fff;background:#300;z-index:99;padding:2em;white-space:pre-wrap">${e.stack || e}</pre>`); });
