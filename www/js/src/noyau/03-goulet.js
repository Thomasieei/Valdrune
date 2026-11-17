// ---------------- Le Goulet des Braises (champ de bataille 10 contre 10, règles du Goulet des Chanteguerres) ----------------
// 20 minutes, 3 captures ; égalité départagée par la dernière capture ; drapeaux remis en place 20 s après une capture ;
// drapeau lâché : rendu d'un contact par sa propre équipe ou de lui-même au bout de 10 s ; celui qui l'a lâché ne peut le reprendre qu'après 3 s ;
// quand les deux drapeaux sont hors de leur socle, les porteurs prennent « Assaut ciblé » (+10 % de dégâts subis toutes les 30 s), puis « Assaut brutal » après 5 cumuls ;
// 20 s au cimetière après chaque mort ; bonus de vitesse, de soins et berserk qui réapparaissent.
let goulet = null;
let _ciel = null;
function cielGoulet() {
  if (_ciel) return _ciel;
  const c = document.createElement('canvas'); c.width = 4; c.height = 256; const g = c.getContext('2d');
  const gr = g.createLinearGradient(0, 0, 0, 256); gr.addColorStop(0, '#6a9ad8'); gr.addColorStop(0.55, '#c8d8e8'); gr.addColorStop(0.8, '#f2d2a8'); gr.addColorStop(1, '#e8b888');
  g.fillStyle = gr; g.fillRect(0, 0, 4, 256);
  _ciel = new THREE.CanvasTexture(c); _ciel.colorSpace = THREE.SRGBColorSpace; return _ciel;
}
const CYCLE_GOULET = 300, OUVERT_GOULET = 120; // un portail s'ouvre toutes les 5 minutes et reste 2 minutes
const DUREE_GOULET = 1200, PREPA_GOULET = 20, VAGUE_GOULET = 30;
function etatPortailGoulet() { const s = (Date.now() / 1000) % CYCLE_GOULET; return s < OUVERT_GOULET ? { ouvert: true, reste: OUVERT_GOULET - s } : { ouvert: false, reste: CYCLE_GOULET - s }; }
function majPortailGoulet() {
  const pg = monde && monde.portailGoulet; if (!pg) return;
  const e = etatPortailGoulet();
  if (pg.groupe.visible !== e.ouvert) {
    pg.groupe.visible = e.ouvert;
    if (e.ouvert) { UI.toast('LE GOULET DES BRAISES EST OUVERT', true); UI.toast('Portail bleu et rouge à l’est de la Place · 10 contre 10'); son('jingle_legend', 0.5, 0.8); onde(pg.pos, '#7ab8ff', 6, 1); }
  }
}
// listes des équipes, calculées une seule fois par image (évite des milliers de petits tableaux → pas d'à-coups du ramasse-miettes)
const _equipes = { t: -1, bleu: null, rouge: null, advBleu: null, advRouge: null };
function equipesGoulet() {
  if (_equipes.t !== G.t || !_equipes.bleu) {
    _equipes.t = G.t; _equipes.bleu = [joueur, ...allies.filter(a => a.bg)]; _equipes.rouge = ennemis.filter(e => e.bg);
    _equipes.advBleu = _equipes.rouge.filter(x => x && !x.mort); _equipes.advRouge = _equipes.bleu.filter(x => x && !x.mort);
  }
  return _equipes;
}
const membresGoulet = (camp) => equipesGoulet()[camp];
const adversairesGoulet = (camp) => camp === 'bleu' ? equipesGoulet().advBleu : equipesGoulet().advRouge;
const campDe = (x) => x === joueur ? 'bleu' : x && x.bg ? x.bg.camp : null;
const estPorteur = (x) => goulet && (goulet.drapeaux.bleu.porteur === x || goulet.drapeaux.rouge.porteur === x);
const pvMaxDe = (x) => x === joueur ? joueur.st.pvMax : x.pvMax;
const COUL_CAMP = { bleu: '#3a7aff', rouge: '#ff3a3a' };
function drapeauMesh(coul) {
  const g = new THREE.Group();
  const mat = new THREE.MeshStandardMaterial({ color: '#d8c8a8', roughness: 0.6, metalness: 0.3 });
  const mat2 = new THREE.MeshStandardMaterial({ color: coul, emissive: coul, emissiveIntensity: 0.7, side: THREE.DoubleSide });
  const hampe = new THREE.Mesh(new THREE.CylinderGeometry(0.07, 0.07, 3.6, 8), mat); hampe.position.y = 1.8; g.add(hampe);
  const tissu = new THREE.Mesh(new THREE.PlaneGeometry(1.6, 1.0, 8, 4), mat2); tissu.position.set(0.82, 3, 0); g.add(tissu);
  const boule = new THREE.Mesh(new THREE.SphereGeometry(0.16, 10, 8), new THREE.MeshStandardMaterial({ color: '#ffd27a', emissive: '#ffb02a', emissiveIntensity: 1 })); boule.position.y = 3.65; g.add(boule);
  const pos0 = tissu.geometry.attributes.position.array.slice();
  G.anims.push((t) => { const p = tissu.geometry.attributes.position; for (let i = 0; i < p.count; i++) { const x = pos0[i * 3]; p.array[i * 3 + 2] = Math.sin(t * 6 + x * 3) * 0.12 * (x + 0.8); } p.needsUpdate = true; });
  monde.groupe.add(g);
  // colonne de lumière visible de tout le champ + cercle au sol : on repère le porteur de loin
  const rayon = new THREE.Mesh(new THREE.CylinderGeometry(0.45, 0.45, 60, 14, 1, true), new THREE.MeshBasicMaterial({ color: coul, transparent: true, opacity: 0.32, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide }));
  rayon.position.y = 30; rayon.visible = false; monde.groupe.add(rayon);
  const cercle = new THREE.Mesh(new THREE.RingGeometry(0.95, 1.35, 36), new THREE.MeshBasicMaterial({ color: coul, transparent: true, opacity: 0.8, blending: THREE.AdditiveBlending, depthWrite: false }));
  cercle.rotation.x = -Math.PI / 2; cercle.position.y = 0.07; cercle.visible = false; monde.groupe.add(cercle);
  G.anims.push((t) => { rayon.material.opacity = 0.24 + 0.12 * Math.sin(t * 4); cercle.scale.setScalar(1 + 0.12 * Math.sin(t * 6)); });
  return { g, rayon, cercle };
}
// icône flottante des bonus
function meshBonus(type) {
  const c = document.createElement('canvas'); c.width = c.height = 128; const g = c.getContext('2d');
  const coul = { vitesse: '#ffd23a', soin: '#4aff7a', berserk: '#ff4a2a' }[type];
  const gr = g.createRadialGradient(64, 64, 10, 64, 64, 62); gr.addColorStop(0, '#ffffff'); gr.addColorStop(0.35, coul); gr.addColorStop(1, 'rgba(0,0,0,0)');
  g.fillStyle = gr; g.beginPath(); g.arc(64, 64, 62, 0, 7); g.fill();
  g.fillStyle = '#1a1208'; g.strokeStyle = '#fff'; g.lineWidth = 5; g.lineJoin = 'round';
  g.beginPath();
  if (type === 'soin') { g.rect(54, 30, 20, 68); g.rect(30, 54, 68, 20); }
  else if (type === 'vitesse') { for (const o of [-16, 10]) { g.moveTo(36 + o, 34); g.lineTo(64 + o, 64); g.lineTo(36 + o, 94); g.lineTo(48 + o, 94); g.lineTo(76 + o, 64); g.lineTo(48 + o, 34); g.closePath(); } }
  else { g.moveTo(64, 26); g.lineTo(76, 54); g.lineTo(104, 50); g.lineTo(82, 72); g.lineTo(94, 100); g.lineTo(64, 84); g.lineTo(34, 100); g.lineTo(46, 72); g.lineTo(24, 50); g.lineTo(52, 54); g.closePath(); }
  g.stroke(); g.fill();
  const tex = new THREE.CanvasTexture(c); tex.colorSpace = THREE.SRGBColorSpace;
  const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, transparent: true, depthWrite: false })); sp.scale.set(1.6, 1.6, 1);
  return { sp, coul };
}
async function entrerGoulet() {
  memoriserMode('Goulet des Braises · 10 contre 10', () => entrerGoulet());
  if (!assetsSylvePrets) { UI.toast('Ouverture du Goulet…'); try { await chargerAssets(ASSETS_SYLVE.map(k => [k, `assets/sylve/${k}.json`]), () => {}); assetsSylvePrets = true; } catch (e) {} }
  fondu(() => {
    viderMonde(); invasion = null; arene = null; selection = null;
    modeActuel = { id: 'goulet', nom: 'Goulet', lieu: 'Goulet des Braises', argent: 0, xp: 3, tiers: [1, 1], mobTier: 1, goulet: true };
    monde = construireGoulet(); G.solH = monde.solH;
    grilleGoulet();
    for (const b of Object.values(monde.bases)) monde.collisions.push(...b.portes); // herses fermées pendant la préparation
    construireJoueur(pointLibrePres(monde.bases.bleu.spawn, 0, 4));
    joueur.pv = joueur.st.pvMax; joueur.energie = joueur.st.energieMax; joueur.cds = {};
    joueur.angle = Math.PI / 2; joueur.root.rotation.y = joueur.angle;
    // fin d'après-midi dorée : ciel en dégradé, brume chaude, soleil rasant
    G.camTarget.copy(joueur.pos); G.scene.fog.color.set('#e8c9a0'); G.scene.fog.density = 0.0085; G.scene.background = cielGoulet();
    G.hemi.color.set('#cfe0ff'); G.hemi.groundColor.set('#5a4a2a'); G.hemi.intensity = 1.0; G.sun.color.set('#ffd9a0'); G.sun.intensity = 2.1;
    const dr = (camp) => ({ camp, etat: 'base', porteur: null, sol: null, t: 0, ...(() => { const m = drapeauMesh(COUL_CAMP[camp]); return { mesh: m.g, rayon: m.rayon, cercle: m.cercle }; })() });
    goulet = { score: { bleu: 0, rouge: 0 }, t: DUREE_GOULET, debut: PREPA_GOULET, fini: false, vague: VAGUE_GOULET, morts: new Set(), sc: new Map(), assaut: 0, assautT: 0, dernierCap: null,
      drapeaux: { bleu: dr('bleu'), rouge: dr('rouge') }, bonus: [] };
    for (const b of monde.bonus) { const m = meshBonus(b.type); m.sp.position.set(b.pos.x, 1.4 + solY(b.pos.x, b.pos.z), b.pos.z); monde.groupe.add(m.sp); goulet.bonus.push({ ...b, sp: m.sp, coul: m.coul, t: 0 }); }
    const ipJ = statsHeros(J.equip).ip, rg = rangDe('arene').i, pris = [];
    const roles = ['att', 'att', 'att', 'att', 'def', 'def', 'def', 'mil', 'mil', 'mil'];
    for (let i = 0; i < 9; i++) {
      const d = calerSurJoueur(donneesBot(ipJ + rnd(-40, 40), pris, rg)); pris.push(d.nom);
      const a = creerCombattant(pointLibrePres(monde.bases.bleu.spawn, 1, 7), d, 'allie');
      Object.assign(a, { bg: { camp: 'bleu', role: roles[i + 1], via: Math.random() < 0.35 ? 'tunnel' : 'porte' }, potions: 1, skill: Math.min(0.95, 0.6 + 0.06 * rg + rnd(-0.05, 0.1)) });
    }
    for (let i = 0; i < 10; i++) {
      const d = calerSurJoueur(donneesBot(ipJ + rnd(-40, 40) + 12 * rg, pris, rg), 3, rg); pris.push(d.nom);
      d.skill = Math.max([0.55, 0.7, 0.8, 0.9, 0.95, 0.98][rg] || 0.55, Math.min(0.98, 0.6 + 0.07 * rg + rnd(-0.05, 0.12)));
      const r = creerCombattant(pointLibrePres(monde.bases.rouge.spawn, 1, 7), d, 'ennemi');
      Object.assign(r, { bg: { camp: 'rouge', role: roles[i], via: Math.random() < 0.35 ? 'tunnel' : 'porte' }, potions: 1, skill: d.skill, chasseur: false });
      r.angle = -Math.PI / 2; r.root.rotation.y = r.angle;
    }
    _equipes.t = -1;
    for (const x of [...membresGoulet('bleu'), ...membresGoulet('rouge')]) scoreDe(x);
    UI.journal('Goulet des Braises', 'Entre dans le château rouge, prends leur drapeau dans la salle du fond et ramène-le à ton socle. Impossible de marquer tant que ton propre drapeau est volé. 3 captures pour gagner.');
    UI.zone('Goulet des Braises', '10 contre 10');
    $('#btnQuitter').hidden = false;
    UI.toast(`Les portes s’ouvrent dans ${PREPA_GOULET} secondes`, true);
  });
}
// grille de passage (2 m) pour que les combattants contournent remparts, portes et tunnel
function grilleGoulet() {
  const C = 1, X0 = -80, Z0 = -32, W = 160, H = 64, g = new Uint8Array(W * H);
  for (let z = 0; z < H; z++) for (let x = 0; x < W; x++) g[z * W + x] = libre(X0 + x * C + C / 2, Z0 + z * C + C / 2, 0.6) ? 1 : 0;
  Object.assign(monde, { grille: g, grilleW: W, grilleH: H, grilleC: C, grilleX0: X0, grilleZ0: Z0 });
}
function scoreDe(x) {
  if (!x) return null; if (x.invoc) x = joueur;
  let s = goulet.sc.get(x);
  if (!s) { s = { nom: x === joueur ? J.nom : x.nom, camp: campDe(x), moi: x === joueur, arme: x === joueur ? (J.equip.arme && J.equip.arme.type) : x.data && x.data.equip && x.data.equip.arme && x.data.equip.arme.type, kb: 0, hk: 0, morts: 0, caps: 0, ret: 0, deg: 0, soin: 0 }; goulet.sc.set(x, s); }
  return s;
}
const renomDe = (s, bonus = 0) => s.kb * 8 + s.hk * 3 + s.caps * 60 + s.ret * 15 + bonus;
function lignesClassement() { return [...goulet.sc.values()].map(s => ({ ...s, renom: renomDe(s) })); }
// modificateurs du champ de bataille appliqués à chaque coup (berserk, assaut ciblé) + statistiques du tableau des scores
function modBG(src, cible, d) {
  if (!goulet || !(d > 0)) return d;
  if (src && src.invoc) src = joueur;
  if (src && src.berserkT > 0) d *= 1.3;
  if (cible.berserkT > 0) d *= 1.1;
  if (goulet.assaut > 0 && estPorteur(cible)) d *= 1 + 0.1 * goulet.assaut;
  cible.restoT = 0;
  if (src && campDe(src) && campDe(src) !== campDe(cible)) { scoreDe(src).deg += Math.min(d, Math.max(0, cible.pv)); cible.dernierCoup = src; cible.dernierCoupT = G.t; (cible._agg || (cible._agg = new Map())).set(src, G.t); }
  return d;
}
// ---- stratégie d'équipe : chaque camp a un plan (rassemblement → assaut par la porte ou le tunnel → escorte du porteur) ----
function planGoulet(camp) {
  const P = goulet.plans || (goulet.plans = {});
  if (!P[camp]) { const sx = camp === 'bleu' ? 1 : -1; P[camp] = { phase: 'rassemblement', via: Math.random() < 0.5 ? 'porte' : 'tunnel', t: 0, vague: 0, rally: V(sx * 30, 0, 6) }; }
  return P[camp];
}
function majPlansGoulet(dt) {
  for (const camp of ['bleu', 'rouge']) {
    const P = planGoulet(camp), adv = camp === 'bleu' ? 'rouge' : 'bleu', sx = camp === 'bleu' ? 1 : -1; // sx : direction de la base adverse
    const Fadv = goulet.drapeaux[adv];
    const atts = membresGoulet(camp).filter(x => x && x !== joueur && !x.loup && !x.mort && x.bg && x.bg.role === 'att');
    P.t += dt;
    // point de ralliement : devant la porte adverse, ou à l'entrée nord pour le tunnel
    P.rally = P.via === 'porte' ? V(sx * 30, 0, (P.vague % 2 ? -6 : 6)) : V(sx * 52, 0, 26);
    if (Fadv.etat === 'porte' && campDe(Fadv.porteur) === camp) { P.phase = 'escorte'; P.t = 0; continue; }
    if (P.phase === 'escorte') { P.phase = 'rassemblement'; P.t = 0; }
    if (P.phase === 'rassemblement') {
      const prets = atts.filter(x => dist2D(x.pos, P.rally) < 9).length;
      if ((prets >= Math.min(3, atts.length) && atts.length) || P.t > 14) { P.phase = 'assaut'; P.t = 0; }
    } else if (P.phase === 'assaut') {
      // l'assaut échoue (attaquants tous tombés ou trop long) : on change d'entrée pour la vague suivante
      if (!atts.length || P.t > 50) { P.phase = 'rassemblement'; P.t = 0; P.vague++; if (Math.random() < 0.65) P.via = P.via === 'porte' ? 'tunnel' : 'porte'; }
    }
  }
}
// trajet d'un combattant vers une base : par la grande porte ou par le tunnel
function versBase(e, base, via) {
  if (base.dans(e.pos.x, e.pos.z)) return base.pos;
  if (via === 'tunnel') return dist2D(base.tunnel, e.pos) > 3.5 ? base.tunnel : V(base.tunnel.x, 0, 12);
  return dist2D(base.porte, e.pos) > 4 && Math.abs(e.pos.x) < Math.abs(base.porte.x) ? base.porte : base.pos;
}
function iaGoulet(e, dt) {
  const def = e.armeDef;
  if (goulet.debut > 0 || goulet.fini) { e.jouer(def.idle); return true; }
  const camp = e.bg.camp, adv = camp === 'bleu' ? 'rouge' : 'bleu';
  const B = monde.bases[camp], Badv = monde.bases[adv];
  const Fadv = goulet.drapeaux[adv], Fmien = goulet.drapeaux[camp];
  const P = planGoulet(camp);
  const v = e.st.vitesse * (e.slowT > 0 ? 0.6 : 1);
  const idx = membresGoulet(camp).indexOf(e);
  // anti-blocage : immobile 4 s sans combattre → on le décale et on recalcule son chemin
  e._bgT = (e._bgT || 0) + dt;
  if (e._bgT > 4) { if (e._bgP && dist2D(e._bgP, e.pos) < 1.2) { e.chemin = null; e.bgPoste = null; e._bgDetour = pointLibrePres(e.pos, 3, 7); e._bgDetourT = 1.5; } e._bgP = e.pos.clone(); e._bgT = 0; }
  if (e._bgDetourT > 0) { e._bgDetourT -= dt; allerVers(e, e._bgDetour, dt, v); e.jouer(def.run); return true; }
  if (Fadv.porteur === e) { // je porte leur drapeau : retour à mon socle (ou je me cache dans ma salle si mon drapeau est volé)
    const proche = adversairesGoulet(camp).filter(x => dist2D(x.pos, e.pos) < 3.2).length;
    if (proche && Math.random() < 0.35) return false;
    const resto = goulet.bonus.find(b => b.t <= 0 && b.type === 'soin' && dist2D(b.pos, e.pos) < 14);
    const obj = resto && e.pv < e.pvMax * 0.6 ? resto.pos : versBase(e, B, e.bg.via);
    allerVers(e, obj, dt, v * 0.95); e.jouer(def.run); return true;
  }
  const role = e.bg.role;
  // à portée du drapeau adverse sur son socle : on fonce le prendre, sans s'arrêter pour se battre
  if (Fadv.etat === 'base' && dist2D(Badv.pos, e.pos) < 11 && Badv.dans(e.pos.x, e.pos.z)) { allerVers(e, Badv.pos, dt, v); e.jouer(def.run); return true; }
  const engage = role === 'def' ? 14 : role === 'att' ? (P.phase === 'assaut' ? 5 : 9) : 11;
  const foe = adversairesGoulet(camp).find(x => dist2D(x.pos, e.pos) < (estPorteur(x) ? 18 : engage) && (estPorteur(x) || ligneLibre(x.pos, e.pos)));
  if (foe) return false; // combat (esquives, sorts, replis…)
  const bon = goulet.bonus.find(b => b.t <= 0 && dist2D(b.pos, e.pos) < 12 && (b.type === 'soin' ? e.pv < e.pvMax * 0.65 : b.type === 'berserk' ? role !== 'def' : role === 'att' || role === 'mil'));
  let obj = null;
  const fcAmi = Fadv.etat === 'porte' ? Fadv.porteur : null;
  const decal = (p, r = 2.5) => V(p.x + Math.cos(idx * 2.1) * r, 0, p.z + Math.sin(idx * 2.1) * r); // chacun sa place : pas de paquet
  if (bon) obj = bon.pos;
  else if (Fmien.etat === 'porte' && Fmien.porteur && (role !== 'att' || !fcAmi || idx % 2)) obj = Fmien.porteur.pos; // on traque leur porteur
  else if (Fmien.etat === 'sol' && dist2D(Fmien.sol, e.pos) < 50) obj = Fmien.sol; // on ramène notre drapeau
  else if (fcAmi && (role === 'att' || (role === 'mil' && idx % 2 === 0))) obj = decal(fcAmi.pos, 3); // escorte serrée du porteur
  else if (Fadv.etat === 'sol' && dist2D(Fadv.sol, e.pos) < 40) obj = Fadv.sol;
  else if (role === 'att') {
    if (Fadv.etat === 'attente') obj = decal(P.rally, 4);
    else if (P.phase === 'rassemblement') obj = decal(P.rally, 3.5);
    else obj = versBase(e, Badv, P.via);
  } else if (role === 'def') {
    // 2 dans la salle du drapeau, 1 à la porte de la cour ; tous sur les intrus
    const intrus = adversairesGoulet(camp).find(x => B.dans(x.pos.x, x.pos.z));
    if (intrus) obj = intrus.pos;
    else { if (!e.bgPoste || G.t > (e.bgPosteT || 0)) { e.bgPosteT = G.t + rnd(5, 9); const k = idx % 3; e.bgPoste = k === 2 ? pointLibrePres(V(B.porte.x * 0.93, 0, 0), 0, 4) : pointLibrePres(V(B.pos.x, 0, k ? 5 : -5), 0, 3); } obj = e.bgPoste; }
  } else { // milieu : tient le centre, intercepte, renforce l'assaut
    if (P.phase === 'assaut' && idx % 3 === 0) obj = versBase(e, Badv, P.via);
    else { if (!e.bgPoste || G.t > (e.bgPosteT || 0)) { e.bgPosteT = G.t + rnd(5, 9); const sx = camp === 'bleu' ? 1 : -1; e.bgPoste = pointLibrePres(V(sx * rnd(-14, 18), 0, rnd(-18, 18)), 0, 3); } obj = e.bgPoste; }
  }
  if (dist2D(obj, e.pos) > (bon && obj === bon.pos ? 0.5 : 1.8)) { allerVers(e, obj, dt, v * (role === 'att' && P.phase === 'rassemblement' ? 0.9 : 1)); e.jouer(def.run); }
  else { e.jouer(def.idle); e._bgP = e.pos.clone(); e._bgT = 0; } // à son poste : ce n'est pas un blocage
  return true;
}
function finBuffs(x) {
  if (x.vitBuffT > 0) { x.vitBuffT = 0; if (x._vitBase) { x.st.vitesse = x._vitBase; x._vitBase = null; } }
  if (x.berserkT > 0) { x.berserkT = 0; x.root.scale.divideScalar(1.1); }
  x.restoT = 0;
}
function lacherDrapeaux(x) {
  for (const F of Object.values(goulet.drapeaux)) if (F.porteur === x) {
    F.porteur = null; F.etat = 'sol'; F.sol = V(x.pos.x, 0, x.pos.z); F.t = 10; x.dropT = G.t + 3; x.drapeauPorte = null;
    UI.toast(`Drapeau ${F.camp} lâché !`, campDe(x) === 'bleu' ? false : true); onde(F.sol, COUL_CAMP[F.camp], 4, 0.6); cor('lache');
  }
}
function mortGoulet(x) {
  x.mort = true; x.pv = 0;
  if (x !== joueur) x.jouer('Death_A', { boucle: false });
  lacherDrapeaux(x); finBuffs(x);
  const c = campDe(x);
  scoreDe(x).morts++;
  // coup fatal et victoires honorables (tous ceux qui ont participé ou étaient à portée)
  const tueur = x.dernierCoup && G.t - (x.dernierCoupT || -99) < 10 ? (x.dernierCoup.invoc ? joueur : x.dernierCoup) : null;
  if (tueur) {
    scoreDe(tueur).kb++;
    const ct = campDe(tueur);
    for (const m of membresGoulet(ct)) if (m && (m === tueur || (x._agg && G.t - (x._agg.get(m) || -99) < 12) || (!m.mort && dist2D(m.pos, x.pos) < 25))) { scoreDe(m).hk++; if (m === joueur) UI.nombre(V(x.pos.x, 2.9, x.pos.z), m === tueur ? 'Coup fatal · +11 honneur' : 'Victoire honorable · +3', 'info'); }
  }
  x._agg = null; x.dernierCoup = null;
  x.resT = 20;
  if (x === joueur) UI.toast('Tu es tombé · ton esprit rejoint le cimetière, retour au combat dans 20 s', true);
  goulet.morts.add(x);
  // après la chute, l'esprit apparaît au cimetière de son camp et y attend
  programmer(2.2, () => { if (!goulet || goulet.fini || !x.mort || !goulet.morts.has(x)) return; const cm = monde.bases[c].cimetiere; x.pos.copy(pointLibrePres(V(cm.x, 0, cm.z - 0.5), 0, 3.5)); x.root.position.y = 0; fantome(x, true); x.jouer('Sit_Floor_Idle', { forcer: true }); emettre(V(x.pos.x, 1, x.pos.z), { n: 20, c1: '#ffffff', c2: '#9ad8ff', vit: 2, vie: 0.8, taille: 0.35, grav: -2 }); if (x === joueur) G.camTarget.copy(x.pos); });
}
function fantome(x, on) {
  x._fantome = on; x._cv = undefined; if (x._contour) for (const c of x._contour) c.visible = !on;
  for (const m of x.mats || []) { if (on) { if (!m.userData.op0) m.userData.op0 = [m.transparent, m.opacity]; m.transparent = true; m.opacity = 0.42; } else if (m.userData.op0) { [m.transparent, m.opacity] = m.userData.op0; m.userData.op0 = null; } }
}
function relever(x) {
  fantome(x, false);
  const c = campDe(x), sp = pointLibrePres(monde.bases[c].cimetiere, 0, 4);
  x.pos.copy(sp); x.mort = false; x.root.position.y = 0;
  if (x === joueur) { joueur.pv = joueur.st.pvMax; joueur.energie = joueur.st.energieMax; joueur.invuln = 2; joueur.jouer(joueur.def.idle); G.camTarget.copy(sp); }
  else { x.pv = x.pvMax; x.tc = null; x.chemin = null; x.jouer(x.armeDef.idle); x.potions = 1; }
  emettre(V(sp.x, 1, sp.z), { n: 24, c1: '#ffffff', c2: '#9ad8ff', vit: 3, vie: 0.8, taille: 0.4, grav: -3 });
}
function prendreBonus(x, b) {
  b.t = 90; b.sp.visible = false; onde(b.pos, b.coul, 3, 0.4);
  if (x === joueur) son('confirmation_001', 0.5);
  if (b.type === 'vitesse') { if (!(x.vitBuffT > 0)) { x._vitBase = x.st.vitesse; x.st.vitesse *= 2; } x.vitBuffT = 10; if (x === joueur) UI.toast('Vitesse ! +100 % de vitesse pendant 10 s'); }
  else if (b.type === 'berserk') { if (!(x.berserkT > 0)) x.root.scale.multiplyScalar(1.1); x.berserkT = 60; if (x === joueur) UI.toast('Berserk ! +30 % de dégâts, +10 % de dégâts subis · 1 min'); }
  else { x.restoT = 10; if (x === joueur) UI.toast('Restauration : 10 % de vie par seconde · annulé si on te frappe'); }
}
const dernierAgresseurDe = (x) => G.t - (x.coupJoueurT || -99) < 2 ? joueur : null;
function majGoulet(dt) {
  if (!goulet || goulet.fini) return;
  const bases = monde.bases;
  if (goulet.debut > 0) {
    const avant = Math.ceil(goulet.debut); goulet.debut -= dt; const n = Math.ceil(goulet.debut);
    if (n !== avant && goulet.debut > 0 && (n <= 5 || n === 10)) UI.toast(n === 10 ? 'Les portes s’ouvrent dans 10 secondes' : String(n));
    if (goulet.debut <= 0) {
      UI.toast('LES PORTES SONT OUVERTES · À L’ATTAQUE !', true); son('jingle_win', 0.5); son('doorOpen_1', 0.7, 0.7);
      for (const b of Object.values(bases)) { for (const c of b.portes) { const i = monde.collisions.indexOf(c); if (i >= 0) monde.collisions.splice(i, 1); } for (const h of b.herses) G.anims.push((t, d) => { if (h.position.y < 6.2) h.position.y += d * 3; }); }
    }
    UI.scoreGoulet(goulet); return;
  }
  goulet.t -= dt;
  majPlansGoulet(dt);
  if (Math.random() < dt * 9) { const c = G.camTarget; emettre(V(c.x + rnd(-16, 16), rnd(0.5, 3), c.z + rnd(-12, 12)), { n: 1, c1: '#fff8d0', c2: '#ffe08a', vit: 0.3, vie: 3, taille: 0.09, grav: -0.15, frein: 0.2 }); }
  // résurrection au cimetière (20 s)
  for (const x of goulet.morts) { x.resT -= dt; if (x.resT <= 0) { relever(x); goulet.morts.delete(x); } }
  // bonus
  for (const b of goulet.bonus) {
    if (b.t > 0) { b.t -= dt; if (b.t <= 0) { b.sp.visible = true; onde(b.pos, b.coul, 2.5, 0.4); } continue; }
    b.sp.position.y = 1.4 + Math.sin(G.t * 3) * 0.2 + solY(b.pos.x, b.pos.z);
    const x = [...adversairesGoulet('rouge'), ...adversairesGoulet('bleu')].find(m => !m.loup && dist2D(m.pos, b.pos) < 1.4);
    if (x) prendreBonus(x, b);
  }
  for (const x of [...adversairesGoulet('rouge'), ...adversairesGoulet('bleu')]) {
    if (x.loup) continue;
    if (x.vitBuffT > 0) { x.vitBuffT -= dt; if (Math.random() < 0.3) emettre(V(x.pos.x, 0.3, x.pos.z), { n: 1, c1: '#fff8c0', c2: '#ffd23a', vit: 1, vie: 0.4, taille: 0.25 }); if (x.vitBuffT <= 0 && x._vitBase) { x.st.vitesse = x._vitBase; x._vitBase = null; } }
    if (x.berserkT > 0) { x.berserkT -= dt; if (Math.random() < 0.25) emettre(V(x.pos.x, 1.2, x.pos.z), { n: 1, c1: '#ffb08a', c2: '#ff2a0a', vit: 1.5, vie: 0.4, taille: 0.3 }); if (x.berserkT <= 0) x.root.scale.divideScalar(1.1); }
    if (x.restoT > 0) { x.restoT -= dt; const pm = pvMaxDe(x), h = Math.min(pm * 0.1 * dt, pm - x.pv); if (h > 0) { x.pv += h; scoreDe(x).soin += h; } if (Math.random() < 0.3) emettre(V(x.pos.x, 0.4, x.pos.z), { n: 1, c1: '#d0ffd8', c2: '#3aff6a', vit: 1, vie: 0.6, taille: 0.25, grav: -2 }); }
  }
  // assaut ciblé / brutal quand les deux drapeaux ont quitté leur socle
  const dehors = Object.values(goulet.drapeaux).every(F => F.etat === 'porte' || F.etat === 'sol');
  if (dehors) {
    goulet.assautT += dt; const n = Math.min(10, Math.floor(goulet.assautT / 30));
    if (n > goulet.assaut) { goulet.assaut = n; UI.toast(n <= 5 ? `Assaut ciblé ×${n} : les porteurs subissent +${n * 10} % de dégâts` : `ASSAUT BRUTAL ×${n} : porteurs à +${n * 10} % de dégâts subis`, true); for (const F of Object.values(goulet.drapeaux)) if (F.porteur && n > 5) { const p = F.porteur; if (p.vitBuffT > 0) { p.vitBuffT = 0.01; } } }
  } else { goulet.assautT = 0; goulet.assaut = 0; }
  for (const F of Object.values(goulet.drapeaux)) {
    const sonSocle = bases[F.camp].pos;
    if (F.etat === 'attente') { F.t -= dt; if (F.t <= 0) { F.etat = 'base'; UI.toast(`Le drapeau ${F.camp} est de retour sur son socle`); } }
    else if (F.etat === 'base' || F.etat === 'sol') {
      const pos = F.etat === 'base' ? sonSocle : F.sol;
      const voleur = adversairesGoulet(F.camp).find(x => !x.loup && dist2D(x.pos, pos) < 2.2 && !(x.dropT > G.t) && !estPorteur(x));
      if (voleur) {
        F.etat = 'porte'; F.porteur = voleur; F.sol = null; voleur.drapeauPorte = F.camp;
        const amis = campDe(voleur) === 'bleu';
        UI.toast(voleur === joueur ? 'TU AS LE DRAPEAU ! Ramène-le à ton socle' : amis ? `${voleur.nom} a pris le drapeau rouge !` : `${voleur.nom} a volé ton drapeau !`, true);
        cor(amis ? 'pris' : 'vole');
      } else if (F.etat === 'sol') {
        F.t -= dt;
        const gardien = membresGoulet(F.camp).find(x => x && !x.loup && !x.mort && dist2D(x.pos, pos) < 2.2);
        if (gardien || F.t <= 0) {
          F.etat = 'base'; F.sol = null;
          if (gardien) { scoreDe(gardien).ret++; if (gardien === joueur) UI.nombre(V(joueur.pos.x, 2.8, joueur.pos.z), 'Drapeau ramené · +15 honneur', 'info'); }
          UI.toast(gardien ? `${gardien === joueur ? 'Tu as' : gardien.nom + ' a'} ramené le drapeau ${F.camp} !` : `Le drapeau ${F.camp} est rentré au château`); cor('retour');
        }
      }
    } else if (F.etat === 'porte') {
      const p = F.porteur; const sonCamp = campDe(p);
      if (dist2D(p.pos, bases[sonCamp].pos) < 3) { // le porteur arrive à son socle : il marque si son propre drapeau y est
        if (goulet.drapeaux[sonCamp].etat === 'base') {
          goulet.score[sonCamp]++; goulet.dernierCap = sonCamp; p.drapeauPorte = null; F.porteur = null;
          for (const D of Object.values(goulet.drapeaux)) { D.etat = 'attente'; D.t = 20; D.porteur = null; D.sol = null; }
          scoreDe(p).caps++;
          if (p === joueur && sonCamp === 'bleu') exploit('goulet_capture');
          UI.toast(sonCamp === 'bleu' ? `${p === joueur ? 'TU AS CAPTURÉ' : p.nom.toUpperCase() + ' A CAPTURÉ'} LE DRAPEAU ROUGE ! ${goulet.score.bleu} – ${goulet.score.rouge}` : `${p.nom} a capturé ton drapeau… ${goulet.score.bleu} – ${goulet.score.rouge}`, true);
          UI.toast('Les drapeaux reviennent dans 20 secondes');
          cor(sonCamp === 'bleu' ? 'capture' : 'perdu'); onde(bases[sonCamp].pos, COUL_CAMP[sonCamp], 10, 1.2); G.shake = 0.6;
          if (goulet.score[sonCamp] >= 3) return finGoulet(sonCamp === 'bleu');
        } else if (!p._msgBloque || G.t - p._msgBloque > 6) { p._msgBloque = G.t; if (p === joueur) UI.toast('Impossible de marquer : ton drapeau a été volé ! Tes alliés doivent le récupérer'); }
      }
    }
    // affichage : socle, à terre, ou sur le dos du porteur
    const m = F.mesh; m.visible = F.etat !== 'attente';
    if (F.etat === 'porte') {
      const p = F.porteur, a = p.angle ?? p.root.rotation.y;
      m.position.set(p.pos.x - Math.sin(a) * 0.38, 0.7 + (p.root.position.y || 0) + solY(p.pos.x, p.pos.z), p.pos.z - Math.cos(a) * 0.38);
      m.rotation.set(0, Math.atan2(Math.cos(a), -Math.sin(a)), 0); m.rotateZ(-0.28); m.scale.setScalar(0.8);
    } else {
      const q = F.etat === 'sol' ? F.sol : sonSocle;
      m.position.set(q.x, (F.etat === 'sol' ? 0 : 0.5) + solY(q.x, q.z), q.z); m.rotation.set(0, G.t * 0.4, 0); m.scale.setScalar(1);
    }
    const loin = F.etat === 'porte' || F.etat === 'sol';
    F.rayon.visible = loin; F.cercle.visible = F.etat === 'porte';
    if (loin) { F.rayon.position.x = m.position.x; F.rayon.position.z = m.position.z; F.cercle.position.x = m.position.x; F.cercle.position.z = m.position.z; F.cercle.position.y = 0.07 + solY(m.position.x, m.position.z); }
  }
  if (goulet.t <= 0) {
    const { bleu, rouge } = goulet.score;
    return finGoulet(bleu > rouge ? true : bleu < rouge ? false : goulet.dernierCap ? goulet.dernierCap === 'bleu' : null);
  }
  goulet.resJ = joueur.mort ? Math.max(1, Math.ceil(joueur.resT || 0)) : 0;
  UI.scoreGoulet(goulet);
  // flèches au bord de l'écran vers les porteurs hors champ
  const fl = [];
  for (const F of Object.values(goulet.drapeaux)) if ((F.etat === 'porte' && F.porteur !== joueur) || F.etat === 'sol') {
    const s = projeter(V(F.mesh.position.x, 1.5, F.mesh.position.z));
    if (s.visible && s.x > 30 && s.x < innerWidth - 30 && s.y > 30 && s.y < innerHeight - 30) continue;
    fl.push({ x: s.visible ? s.x : innerWidth - s.x, y: s.visible ? s.y : innerHeight - s.y, c: COUL_CAMP[F.camp], nom: F.etat === 'sol' ? 'à terre' : F.porteur.nom });
  }
  UI.flechesDrapeau(fl);
}
function ciblerPorteur(camp) {
  if (!goulet) return; const F = goulet.drapeaux[camp];
  if (F.etat === 'porte' && F.porteur && campDe(F.porteur) !== 'bleu') { joueur.cibleVerrou = F.porteur; UI.toast(`Cible : ${F.porteur.nom}`); son('click_001', 0.3); }
}
function finGoulet(victoire) {
  if (victoire) exploit('goulet_victoire');
  goulet.fini = true; UI.scoreGoulet(null); UI.flechesDrapeau([]);
  for (const x of [...membresGoulet('bleu'), ...membresGoulet('rouge')]) if (x) { finBuffs(x); x.drapeauPorte = null; fantome(x, false); }
  for (const F of Object.values(goulet.drapeaux)) { F.rayon.visible = false; F.cercle.visible = false; }
  const s = scoreDe(joueur);
  const bonus = victoire === true ? 200 : victoire === false ? 60 : 110;
  const renom = renomDe(s, bonus);
  J.renom = (J.renom || 0) + renom;
  const gainA = Math.round((victoire === true ? 90000 : 30000) * (1 + 0.3 * rangDe('arene').i)); J.argent += gainA;
  gagnerXP(Math.round(8 * 14 * (victoire ? 60 : 25)));
  if (victoire !== null) changerRang('arene', victoire ? 12 : -8, victoire ? 'Victoire au Goulet' : 'Défaite au Goulet');
  sauver();
  const lignes = [`Score final : 🔵 ${goulet.score.bleu} – ${goulet.score.rouge} 🔴`, `Coups fatals : ${s.kb} · victoires honorables : ${s.hk} · captures : ${s.caps} · drapeaux ramenés : ${s.ret} · morts : ${s.morts}`, `✦ +${renom} honneur (total ${fmtN(J.renom)})`, `+ ${fmtN(gainA)} d’argent`];
  const rows = lignesClassement(); const moiR = rows.find(r => r.moi); if (moiR) moiR.renom = renom;
  const titre = victoire === null ? 'Égalité' : (victoire ? 'L’ÉQUIPE BLEUE L’EMPORTE' : 'L’ÉQUIPE ROUGE L’EMPORTE');
  setTimeout(() => UI.classementGoulet({ rows, fin: true, titre, victoire, score: goulet.score }, () =>
    UI.resultatArene({ victoire: victoire === true, lignes, refaire: 'Goulet des Braises', titre: victoire === null ? 'Égalité' : null }, (refaire) => { goulet = null; if (refaire && etatPortailGoulet().ouvert) entrerGoulet(); else { if (refaire) UI.toast('Le portail du Goulet est refermé : reviens à sa prochaine ouverture'); fondu(() => lancerHub()); } })), 1400);
}
