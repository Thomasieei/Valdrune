// ======================= ESPRIT : TÉLÉKINÉSIE ET TROIS LAMES =======================
let TKS = [], lames = [], lamesMode = 'garde', possedes = [];
function ciblesTK() { return [...ennemis.filter(e => !e.mort && !e.descendre && !e.tk), ...(modeActuel ? [] : bots.filter(b => !b.tk && !b.mort)), ...allies.filter(a => !a.mort && a !== joueur && !a.tk), ...serviteurs.filter(a => !a.tk)]; }
function hostileTK(c) { return ennemis.includes(c); }
// Emprise : soulève ta cible ET la personne la plus proche d'elle (2 à la fois), boss compris
function lancerEmprise(s) {
  if (TKS.length) return;
  const portee = s.portee || 15, f = V(Math.sin(joueur.angle), 0, Math.cos(joueur.angle));
  let c = joueur.cible && !joueur.cible.mort && dist2D(joueur.cible.pos, joueur.pos) < portee ? joueur.cible : null;
  if (!c) { let bd = portee; for (const e of ciblesTK()) { const d = dist2D(e.pos, joueur.pos); const v = V(e.pos.x - joueur.pos.x, 0, e.pos.z - joueur.pos.z).normalize(); const sc = d - v.dot(f) * 4; if (d < portee && sc < bd) { bd = sc; c = e; } } }
  if (!c) { UI.toast('Personne à saisir à portée'); joueur.cds.Q = 0.5; return; }
  let c2 = null, b2 = 6; for (const e of ciblesTK()) { if (e === c) continue; const d = dist2D(e.pos, c.pos); if (d < b2) { b2 = d; c2 = e; } }
  for (const x of [c, c2].filter(Boolean)) {
    x.tk = true; x.stunT = 0;
    const T = { c: x, t: 0, phase: 'monte', y0: x.root.position.y, mult: s.mult * (x.boss ? 0.6 : 1), hostile: hostileTK(x), haut: x.boss ? 3.4 : 2.6 };
    if (T.hostile && (x.etat === 'idle' || x.etat === 'dormant')) { if (x.boss && x.repaire) x.etat = 'chasse'; else reveiller(x); }
    x.jouer('Hit_A', { boucle: true, vitesse: 0.4, forcer: true });
    onde(x.pos, '#b07aff', 3, 0.6);
    if (!T.hostile) UI.parole && UI.parole(x, hasard(['Hé ! Lâche-moi !', 'Mais… je vole ?!', 'Repose-moi tout de suite !', 'AAAAH !']));
    if (x.boss) UI.parole && UI.parole(x, hasard(['QUOI ?! Personne ne me soulève !', 'Lâche-moi, insecte !', 'Impossible…']), 'menace');
    TKS.push(T);
  }
  faireFace(V(c.pos.x - joueur.pos.x, 0, c.pos.z - joueur.pos.z).normalize());
  joueur.jouer('Spellcast_Raise', { boucle: false, forcer: true, vitesse: 0.8, fin: () => TKS.length && joueur.jouer('Spellcast_Long', { boucle: true }) });
  son('forceField_000', 0.5, 0.7); if (c2) son('forceField_000', 0.4, 0.9);
  UI.choixTK((ch) => finEmprise(ch));
}
function finEmprise(choix) {
  const tenus = TKS.filter(T => T.phase === 'tenu' || T.phase === 'monte'); if (!tenus.length) return;
  UI.choixTK(null);
  const f = V(Math.sin(joueur.angle), 0, Math.cos(joueur.angle)); let dir = f;
  if (Math.hypot(entree.jx, entree.jy) > 0.3) dir = DIR_DROITE.clone().multiplyScalar(entree.jx).addScaledVector(DIR_HAUT, entree.jy).normalize();
  const visees = new Set();
  for (const T of tenus) {
    const c = T.c;
    if (choix === 'projeter') {
      let best = null, bs = 1e9; for (const e of vivants()) { if (TKS.some(x => x.c === e) || visees.has(e)) continue; const v = V(e.pos.x - c.pos.x, 0, e.pos.z - c.pos.z), d = v.length(); if (d > 18 || d < 1) continue; v.normalize(); const al = v.dot(dir); if (al < 0.5) continue; const sc = d * (2 - al); if (sc < bs) { bs = sc; best = e; } }
      if (best) visees.add(best);
      const dest = best ? best.pos.clone() : c.pos.clone().addScaledVector(dir, 11);
      T.phase = 'vol'; T.t = 0; T.dep = c.pos.clone(); T.dest = pointLibreProche(dest, 0.6) || dest; T.duree = Math.max(0.35, dist2D(T.dep, T.dest) / 24); T.touches = new Set();
    } else if (choix === 'ecraser') { T.phase = 'ecrase'; T.t = 0; }
    else { T.phase = 'depose'; T.t = 0; }
  }
  if (choix === 'deposer') joueur.jouer(joueur.def.idle); else { joueur.jouer('Spellcast_Shoot', { boucle: false, forcer: true, fin: () => joueur.jouer(joueur.def.idle) }); son(choix === 'projeter' ? 'thrusterFire_000' : 'forceField_000', 0.4, 0.6); }
}
function impactTK(p, force) {
  G.shake = Math.max(G.shake || 0, 0.25 + force * 0.3); son('explosionCrunch_000', 0.5, 0.8); son('impactPlate_heavy_000', 0.5, 0.6);
  onde(p, '#b07aff', 4 + force * 3, 0.7);
  emettre(V(p.x, 0.3, p.z), { n: 50, c1: '#d8c8b0', c2: '#5a4a3a', vit: 7, vie: 0.9, taille: 0.45, grav: 10, hemi: true });
  const f = new THREE.Mesh(new THREE.PlaneGeometry(4 + force * 2, 4 + force * 2), new THREE.MeshBasicMaterial({ map: texFissures(), color: '#2a1a12', transparent: true, opacity: 0.85, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -4 }));
  f.rotation.x = -Math.PI / 2; f.rotation.z = Math.random() * 6; f.position.set(p.x, 0.06 + solY(p.x, p.z), p.z);
  ajouterVfx(f, (t) => { if (t > 6) { f.material.opacity -= 0.02; if (f.material.opacity <= 0) return false; } });
  if (G.assets.rubble_half) for (let k = 0; k < 5; k++) {
    const m = cloner('rubble_half', p.x, 0.5, p.z, Math.random() * 6, 0.12 + Math.random() * 0.1); m.traverse(o => { if (o.geometry) o.geometry.userData.partage = true; }); const a = Math.random() * 6.28, v = 3 + Math.random() * 4; let vy = 5 + Math.random() * 4;
    ajouterVfx(m, (t, dt) => { dt = Math.min(dt || 0.016, 0.05); vy -= 20 * dt; m.position.x += Math.cos(a) * v * dt; m.position.z += Math.sin(a) * v * dt; m.position.y = Math.max(0.05, m.position.y + vy * dt); m.rotation.x += dt * 6; if (t > 3) { m.scale.multiplyScalar(0.92); if (m.scale.x < 0.01) return false; } });
  }
}
function lacherTK(c, assomme) {
  c.tk = false; c.root.position.y = c.hover || 0; c.root.rotation.x = 0; c.root.rotation.z = 0;
  if (assomme && ennemis.includes(c) && !c.mort) c.stunT = Math.max(c.stunT || 0, c.boss ? 0.6 : 1.2);
  if (!c.mort) c.jouer('Idle', { forcer: true });
}
function frapperNonHostile(c) {
  if (G.agression && estPassant(c)) { blesserPassant(c, joueur.st.degats * 4); if (c.mort) return; } c.jouer('Death_A', { boucle: false, forcer: true }); const cc = c; programmer(2.2, () => { if (!cc.mort) { cc.jouer('Idle', { forcer: true }); UI.parole && UI.parole(cc, hasard(['Aïe… ça va pas la tête ?!', 'J’ai vu des étoiles…', 'Plus jamais ça.'])); } }); }
function majTK(dt) {
  for (let i = TKS.length - 1; i >= 0; i--) {
    const T = TKS[i], c = T.c; T.t += dt;
    const fin = () => { TKS.splice(i, 1); if (!TKS.length) UI.choixTK(null); };
    if (c.mort || !c.root.parent) { c.tk = false; fin(); continue; }
    if (T.phase === 'monte' || T.phase === 'tenu') {
      const h = Math.min(1, T.t / 0.6); if (h >= 1) T.phase = 'tenu';
      c.root.position.y = T.y0 + (1 - Math.pow(1 - h, 3)) * T.haut + Math.sin(T.t * 2.4 + i) * 0.15;
      c.root.rotation.z = Math.sin(T.t * 1.7 + i) * 0.25; c.angle += dt * 0.8; c.root.rotation.y = c.angle;
      if (Math.random() < 0.4) { const m = pointArme(); emettre(V(m.x + (c.pos.x - m.x) * Math.random(), m.y + (c.root.position.y + 1 - m.y) * Math.random(), m.z + (c.pos.z - m.z) * Math.random()), { n: 1, c1: '#f0e0ff', c2: '#7a3aff', vit: 0.5, vie: 0.4, taille: 0.25 }); }
      if (T.t > 7 || dist2D(c.pos, joueur.pos) > 24) finEmprise('deposer');
    } else if (T.phase === 'depose') {
      const k = Math.min(1, T.t / 0.9); c.root.position.y = T.y0 + T.haut * (1 - k); c.root.rotation.z *= 0.9;
      if (k >= 1) { emettre(V(c.pos.x, 0.2, c.pos.z), { n: 12, c1: '#ffffff', c2: '#b07aff', vit: 1.5, vie: 0.6, taille: 0.3 }); lacherTK(c, false); fin(); }
    } else if (T.phase === 'ecrase') {
      if (T.t < 0.25) c.root.position.y += dt * 8;
      else { const y = c.root.position.y - dt * 40; c.root.position.y = y; c.root.rotation.x += dt * 8;
        if (y <= T.y0) { impactTK(c.pos, c.boss ? 1.6 : 1);
          if (T.hostile) { blesser(c, T.mult, { stun: 1.4 }); zoneDegats(c.pos, 3.2, T.mult * 0.35, { c1: '#d8c8ff' }); }
          lacherTK(c, true); if (!T.hostile) frapperNonHostile(c); fin(); } }
    } else if (T.phase === 'vol') {
      const k = Math.min(1, T.t / T.duree);
      c.pos.x = T.dep.x + (T.dest.x - T.dep.x) * k; c.pos.z = T.dep.z + (T.dest.z - T.dep.z) * k;
      c.root.position.y = T.y0 + T.haut * (1 - k) + Math.sin(k * Math.PI) * 2; c.root.rotation.x += dt * 14;
      if (Math.random() < 0.7) emettre(V(c.pos.x, c.root.position.y + 1, c.pos.z), { n: 1, c1: '#ffffff', c2: '#9a5aff', vit: 0.3, vie: 0.4, taille: 0.35 });
      for (const e of vivants()) if (e !== c && !e.tk && !T.touches.has(e) && dist2D(e.pos, c.pos) < 1.6) { T.touches.add(e); blesser(e, T.mult * 0.6, { stun: 0.8, air: true }); if (!e.boss) { const v = V(e.pos.x - c.pos.x, 0, e.pos.z - c.pos.z).normalize(); e.pousse = { vx: v.x * 9, vz: v.z * 9, t: 0.3 }; } }
      if (k >= 1) { impactTK(c.pos, 1.3); if (T.hostile) blesser(c, T.mult * 0.9, { stun: 1.2 }); zoneDegats(c.pos, 3.6, T.mult * 0.45, { c1: '#d8c8ff' }); lacherTK(c, true); if (!T.hostile && !c.mort) frapperNonHostile(c); fin(); }
    }
  }
}
// ---- Possession (E) : tu envoûtes ta cible et tout son groupe ; un boss envoûté compte comme vaincu et se bat pour toi ----
function lancerPossession(s) {
  const c = joueur.cible && !joueur.cible.mort && ennemis.includes(joueur.cible) && !joueur.cible.rival && dist2D(joueur.cible.pos, joueur.pos) < s.portee ? joueur.cible : (() => { let b = null, bd = s.portee; for (const e of vivants()) { if (e.rival) continue; const d = dist2D(e.pos, joueur.pos); if (d < bd) { bd = d; b = e; } } return b; })();
  if (!c) { UI.toast('Aucun esprit à envoûter à portée'); joueur.cds.E = 0.5; return; }
  const groupe = c.boss ? [c] : [c, ...vivants().filter(e => e !== c && !e.boss && !e.rival && dist2D(e.pos, c.pos) < 6)].slice(0, 6);
  joueur.jouer('Spellcast_Long', { boucle: false, forcer: true, vitesse: 1.2, fin: () => joueur.jouer(joueur.def.idle) }); joueur.verrouT = 0.5;
  son('forceField_000', 0.6, 0.45); son('lowFrequency_explosion_000', 0.4, 1.4); UI.intention && UI.intention('#9a5aff');
  for (const e of groupe) {
    emettre(V(e.pos.x, 1.4, e.pos.z), { n: 40, c1: '#ffffff', c2: '#7a2aff', vit: 3, vie: 0.9, taille: 0.4, monte: 2 }); onde(e.pos, '#9a5aff', 3, 0.7);
    programmer(0.5, () => envouter(e));
  }
  UI.toast(c.boss ? `${c.boss.nom} est sous ton emprise !` : `${groupe.length} esprit${groupe.length > 1 ? 's' : ''} envoûté${groupe.length > 1 ? 's' : ''}`, true);
}
function envouter(e) {
  if (e.mort || !ennemis.includes(e)) return;
  if (e.tk) { const i = TKS.findIndex(T => T.c === e); if (i >= 0) TKS.splice(i, 1); lacherTK(e, false); }
  const nom = e.boss ? e.boss.nom : (e.def && e.def.nom) || 'Envoûté';
  // il compte comme vaincu (butin, progression, coffre du gardien)…
  sansChoc(() => { e.pv = 0; tuer(e); });
  // …puis se relève à ton service
  const i = ennemis.indexOf(e); if (i >= 0) ennemis.splice(i, 1);
  e.mort = false; e.descendre = false; e.etat = 'possede'; e.stunT = 0; e.tk = false; e.root.position.y = e.hover || 0;
  e.pvMax = Math.max(e.pvMax || 1000, joueur.st.pvMax * (e.boss ? 3 : 0.8)); e.pv = e.pvMax; e.vieT = e.boss ? 120 : 60;
  e.degPet = Math.max(joueur.st.degats * (e.boss ? 2.2 : 0.9), (e.dmg || 0) * 2);
  for (const m of e.mats || []) if (m.emissive) { m.emissive.set('#5a1aaa'); m.emissiveIntensity = 0.45; }
  e.jouer('Idle', { forcer: true });
  UI.retirerPlaque(e); UI.plaque(e, { nom: '✦ ' + nom, guilde: 'ENVOÛTÉ', classe: 'allie', vie: true, lettre: false });
  possedes.push(e);
}
function majPossedes(dt) {
  for (let i = possedes.length - 1; i >= 0; i--) {
    const p = possedes[i];
    if (!p.root.parent) { possedes.splice(i, 1); continue; }
    p.vieT -= dt;
    // il s'use en combattant : chaque ennemi au contact l'abîme
    let cible = null, bd = 20;
    for (const e of vivants()) { const d = dist2D(e.pos, p.pos); if (d < 2.5) p.pv -= (e.dmg || joueur.st.degats * 0.3) * dt * 0.6; const dj = dist2D(e.pos, joueur.pos); if (dj < bd) { bd = dj; cible = e; } }
    if (p.pv <= 0 || p.vieT <= 0) {
      possedes.splice(i, 1); p.etat = 'mort'; p.mort = true; p.jouer(p.def && p.def.model === 'Dragon_Evolved' ? 'Death' : 'Death_A', { boucle: false, forcer: true });
      emettre(V(p.pos.x, 1.2, p.pos.z), { n: 50, c1: '#e8d0ff', c2: '#3a0a6a', vit: 4, vie: 1, taille: 0.45, monte: 2 }); UI.retirerPlaque(p);
      const pp = p; programmer(2.5, () => { G.scene.remove(pp.root); }); continue;
    }
    if (Math.random() < dt * 3) emettre(V(p.pos.x, 0.4, p.pos.z), { n: 1, c1: '#c9a0ff', c2: '#2a0a4a', dir: V(0, 1, 0), vit: 1, vie: 0.6, taille: 0.3 });
    if (cible) {
      const d = dist2D(p.pos, cible.pos);
      if (d > (cible.rayon || 0.6) + (p.rayon || 0.6) + 1) { avancerVers(p, cible.pos, dt, Math.max(4, vitesseJoueur())); p.jouer('Running_A'); }
      else {
        p.angle = tourner(p.angle, Math.atan2(cible.pos.x - p.pos.x, cible.pos.z - p.pos.z), dt * 10); p.root.rotation.y = p.angle;
        p.coupT = (p.coupT || 0) - dt;
        if (p.coupT <= 0) { p.coupT = p.boss ? 1.3 : 1;
          p.jouer(hasard(['1H_Melee_Attack_Chop', '2H_Melee_Attack_Chop', '1H_Melee_Attack_Slice_Diagonal']), { boucle: false, forcer: true, fin: () => p.jouer('Idle') });
          const c = cible; programmer(0.3, () => { if (c.mort) return; blesser(c, 0, { fixe: p.degPet, c1: '#c9a0ff' }); if (p.boss) { onde(c.pos, '#9a5aff', 3, 0.5); zoneDegats(c.pos, 2.5, 0, { fixe: p.degPet * 0.4 }); } son('impactPlate_heavy_000', 0.3, 0.9); }); }
      }
    } else { const d = dist2D(p.pos, joueur.pos); if (d > 4) { avancerVers(p, joueur.pos, dt, Math.max(4, vitesseJoueur() * 1.1)); p.jouer('Running_A'); } else p.jouer('Idle'); }
    p.maj(dt);
  }
}
// ---- trois lames spectrales ----
function statsLame() { const T = joueur.st.tal || {}; return { deg: joueur.st.degats * 0.45 * (1 + (T.lameDeg || 0)) * (1 + (T.s_lames || 0)), pv: joueur.st.pvMax * 0.25 * (1 + (T.lamePv || 0)), vit: 1 + (T.lameVit || 0) }; }
function creerLame(i) {
  const g = new THREE.Group();
  const m = G.assets.Skeleton_Blade ? cloner('Skeleton_Blade', 0, 0, 0, 0, 1.3) : new THREE.Mesh(new THREE.BoxGeometry(0.08, 1.2, 0.2), new THREE.MeshStandardMaterial());
  m.traverse(o => { if (o.isMesh) { o.material = o.material.clone(); o.material.color = new THREE.Color('#d8d0ff'); o.material.emissive = new THREE.Color('#7a4aff'); o.material.emissiveIntensity = 0.9; } });
  m.rotation.x = Math.PI / 2; g.add(m);
  const halo = new THREE.Sprite(new THREE.SpriteMaterial({ map: texRond(), color: '#a07aff', blending: THREE.AdditiveBlending, transparent: true, depthWrite: false, opacity: 0.6 })); halo.scale.setScalar(1.4); g.add(halo);
  G.scene.add(g); const S = statsLame();
  g.position.set(joueur.pos.x, 0.2, joueur.pos.z);
  return { g, i, pv: S.pv, pvMax: S.pv, cible: null, coupT: 0, mort: false, respawnT: 0, a: i / 3 * Math.PI * 2 };
}
function invoquerLames() {
  for (const L of lames) G.scene.remove(L.g);
  lames = [0, 1, 2].map(creerLame); lamesMode = 'garde';
  son('drawKnife2', 0.5, 0.8); son('forceField_000', 0.4, 1.2); onde(joueur.pos, '#a07aff', 4, 0.6);
  UI.toast('Trois lames se lèvent autour de toi');
}
function ordreLames() {
  if (!lames.length) return invoquerLames();
  const modes = ['garde', 'assaut', ...(monde && (monde.type === 'donjon' || monde.type === 'sylve') ? ['exploration'] : [])];
  lamesMode = modes[(modes.indexOf(lamesMode) + 1) % modes.length];
  for (const L of lames) { L.cible = null; L.route = null; }
  if (lamesMode === 'exploration') {
    const salles = (monde.salles || []).map(x => (x.centre || x.c || x).clone ? (x.centre || x.c || x).clone() : null).filter(Boolean);
    salles.sort((a, b) => dist2D(a, joueur.pos) - dist2D(b, joueur.pos));
    lames.forEach((L, k) => { L.route = salles.filter((_, j) => j % 3 === k).slice(0, 6); L.tues = 0; });
  }
  UI.toast({ garde: 'Lames : garde rapprochée', assaut: 'Lames : à l’assaut des ennemis proches', exploration: 'Lames : exploration du donjon (10 % plus vite que toi)' }[lamesMode]);
  son('select_001', 0.4);
}
function majLames(dt) {
  if (!lames.length) return;
  if (!joueur || joueur.armeType !== 'esprit') { for (const L of lames) G.scene.remove(L.g); lames = []; return; }
  const S = statsLame(), T = G.t;
  for (const L of lames) {
    if (L.mort) { L.respawnT -= dt; L.g.visible = false; if (L.respawnT <= 0) { L.mort = false; L.pv = L.pvMax = S.pv; L.g.visible = true; L.g.position.set(joueur.pos.x, 0.2, joueur.pos.z); } continue; }
    let but = null;
    const vit = (lamesMode === 'exploration' ? vitesseJoueur() * 1.1 : 18) * S.vit;
    if (lamesMode === 'exploration' && L.route) {
      while (L.route.length && dist2D(L.g.position, L.route[0]) < 1.5) L.route.shift();
      const proche = vivants().find(e => dist2D(e.pos, L.g.position) < 4);
      if (proche) L.cible = proche;
      if (!L.cible || L.cible.mort) but = L.route.length ? V(L.route[0].x, 1.4, L.route[0].z) : null;
      if (!L.route.length && !L.cible) { if (!L.fini) { L.fini = true; if (lames.every(x => x.fini || x.mort)) { UI.toast(`Tes lames ont fini d’explorer : ${lames.reduce((a, x) => a + (x.tues || 0), 0)} ennemis abattus`); lamesMode = 'garde'; lames.forEach(x => { x.fini = false; x.route = null; }); } } }
    } else if (lamesMode === 'assaut') {
      if (!L.cible || L.cible.mort || dist2D(L.cible.pos, joueur.pos) > 18) { const pris = new Set(lames.map(x => x.cible)); let bd = 16; L.cible = null; for (const e of vivants()) { const d = dist2D(e.pos, joueur.pos); if (d < bd && !pris.has(e)) { bd = d; L.cible = e; } } if (!L.cible) { let bd2 = 16; for (const e of vivants()) { const d = dist2D(e.pos, joueur.pos); if (d < bd2) { bd2 = d; L.cible = e; } } } }
    } else { // garde : elles tournent, et frappent ce qui approche à moins de 5 m
      if (!L.cible || L.cible.mort || dist2D(L.cible.pos, joueur.pos) > 6) { L.cible = null; for (const e of vivants()) if (dist2D(e.pos, joueur.pos) < 5) { L.cible = e; break; } }
      if (L.cible && L.coupT > 0.4) L.cible = null;
    }
    if (L.cible && !L.cible.mort) {
      const c = L.cible, p = V(c.pos.x + Math.cos(T * 5 + L.i * 2) * 1.2, 1.3, c.pos.z + Math.sin(T * 5 + L.i * 2) * 1.2); but = p;
      L.coupT -= dt;
      if (L.coupT <= 0 && dist2D(L.g.position, c.pos) < 2.2) { L.coupT = 0.55; blesser(c, 0, { fixe: S.deg, c1: '#c8b0ff', silence: true }); arcTaille(c.pos, T * 3, 1.8, '#b07aff', Math.PI * 0.6, 0.15); son('knifeSlice', 0.18, 1.4 + Math.random() * 0.3); if (c.mort && lamesMode === 'exploration') L.tues = (L.tues || 0) + 1; }
    } else if (!but) { L.a += dt * 1.6; but = V(joueur.pos.x + Math.cos(L.a) * 1.7, 1.5 + Math.sin(T * 2 + L.i) * 0.2, joueur.pos.z + Math.sin(L.a) * 1.7); }
    const d = L.g.position.distanceTo(but), k = Math.min(1, vit * dt / Math.max(d, 1e-3));
    const av = L.g.position.clone(); L.g.position.lerp(but, lamesMode === 'exploration' && !L.cible ? k : Math.min(1, dt * 9));
    if (L.g.position.distanceToSquared(av) > 1e-5) L.g.lookAt(L.g.position.clone().add(L.g.position.clone().sub(av)));
    if (Math.random() < 0.3) emettre(L.g.position, { n: 1, c1: '#ffffff', c2: '#8a5aff', vit: 0.2, vie: 0.3, taille: 0.2 });
  }
}
// une lame en garde pare une partie des coups reçus, jusqu'à se briser (elle se reforme 25 s plus tard)
function pareLame(d) {
  if (lamesMode !== 'garde') return d;
  const L = lames.find(x => !x.mort); if (!L) return d;
  const a = d * 0.5; L.pv -= a; emettre(L.g.position, { n: 8, c1: '#ffffff', c2: '#b07aff', vit: 3, vie: 0.3, taille: 0.25 }); son('impactMetal_medium_001', 0.25, 1.3);
  if (L.pv <= 0) { L.mort = true; L.respawnT = 25; emettre(L.g.position, { n: 40, c1: '#ffffff', c2: '#7a4aff', vit: 6, vie: 0.7, taille: 0.35 }); son('explosionCrunch_000', 0.3, 1.6); UI.toast('Une lame s’est brisée'); }
  return d - a;
}
function ondeForce(s) {
  joueur.jouer('Spellcast_Raise', { boucle: false, forcer: true, vitesse: 1.4, fin: () => joueur.jouer(joueur.def.idle) }); joueur.verrouT = 0.35;
  programmer(0.2, () => {
    onde(joueur.pos, '#c0a0ff', s.portee + 1, 0.8); onde(joueur.pos, '#ffffff', s.portee * 0.6, 0.5); G.shake = 0.35; son('lowFrequency_explosion_000', 0.45, 1.3);
    for (const e of vivants()) { const d = dist2D(e.pos, joueur.pos); if (d > s.portee + e.rayon) continue; const v = V(e.pos.x - joueur.pos.x, 0, e.pos.z - joueur.pos.z).normalize(); blesser(e, s.mult, { stun: 0.6, air: true }); if (!e.boss) e.pousse = { vx: v.x * 14, vz: v.z * 14, t: 0.35 }; }
  });
}
// ======================= TERRES ÉCARLATES : monde ouvert, zone rouge =======================
// Règle d'or : tout ce que tu gagnes ici n'est à toi qu'une fois sorti par un portail. Si tu meurs, tu perds ton équipement porté,
// tout ce que tu as ramassé pendant l'expédition et 10 % de ta bourse. Des chasseurs (vrais « joueurs ») rôdent et te traquent.
let terres = null;
async function entrerTerres() {
  if (!assetsSylvePrets) { UI.toast('Le voile des Terres Écarlates se déchire…'); try { await chargerAssets(ASSETS_SYLVE.map(k => [k, `assets/sylve/${k}.json`]), () => {}); assetsSylvePrets = true; } catch (e) {} }
  memoriserMode('Terres Écarlates', () => entrerTerres());
  fondu(() => {
    viderMonde(); invasion = null; arene = null; selection = null;
    const ipJ = statsHeros(J.equip).ip, t = Math.max(1, Math.min(7, Math.round((ipJ - 300) / 110) + 1));
    modeActuel = { id: 'terres', nom: 'Terres Écarlates', lieu: 'Terres Écarlates', argent: 1.6, xp: 8, tiers: [t, Math.min(8, t + 1)], mobTier: t, bossTier: [t + 1, t + 1, t + 1, t + 1] };
    monde = construireTerres(); G.solH = null;
    construireJoueur(monde.spawn.clone()); joueur.pv = joueur.st.pvMax; joueur.energie = joueur.st.energieMax;
    G.camTarget.copy(joueur.pos);
    G.scene.background.set('#3a2228'); G.scene.fog.color.set('#4a2a2e'); G.scene.fog.density = 0.011; G.hemi.color.set('#ffd8c0'); G.hemi.groundColor.set('#3a2a22'); G.hemi.intensity = 1.45; G.sun.intensity = 1.9; G.sun.color.set('#ffc8a0');
    terres = { argent0: J.argent, sac0: new Set(J.sac.map(i => i.id)), chasseT: rnd(45, 70), kills: 0, chasseursTues: 0, debut: G.t, avertiT: 0 };
    // camps de monstres : plus on s'éloigne du camp de départ, plus ils sont nombreux et durs
    monde.camps.forEach((cp, k) => {
      const tier = Math.min(8, t + cp.danger), n = 3 + cp.danger * 2, liste = [];
      const types = cp.biome === 'ruines' ? ['cultiste', 'brute', 'pretresse'] : cp.biome === 'foret' ? ['minion', 'archer', 'guerrier'] : ['guerrier', 'mage', 'brute'];
      for (let i = 0; i < n; i++) { const p = pointLibrePres(V(cp.pos.x + rnd(-5, 5), 0, cp.pos.z + rnd(-5, 5)), 0, 3); const def = MOBS[hasard(types)] || MOBS.guerrier; liste.push(creerEnnemi(def, p, tier, 100 + k)); }
      const chef = liste[0]; chef.pvMax *= 2.5; chef.pv = chef.pvMax; chef.root.scale.multiplyScalar(1.25);
      const couleur = cp.danger >= 3 ? (Math.random() < 0.35 ? 'legendaire' : 'violet') : cp.danger === 2 ? (Math.random() < 0.5 ? 'violet' : 'bleu') : cp.danger === 1 ? 'bleu' : 'vert';
      creerCoffre(pointLibrePres(V(cp.pos.x, 0, cp.pos.z + 3), 0.5, 2), couleur, { get mort() { return liste.every(e => e.mort || e.etat === 'possede'); }, boss: { nom: 'tous les gardiens du camp' }, idx: Math.min(3, cp.danger) });
    });
    const dr = creerBoss(BOSS[3], monde.dragon.clone(), Math.min(8, t + 2), null); dr.pvMax *= 1.6; dr.pv = dr.pvMax; terres.dragon = dr;
    creerCoffre(pointLibrePres(V(monde.dragon.x - 6, 0, monde.dragon.z + 6), 0.5, 2), 'legendaire', dr);
    UI.journal('Terres Écarlates', 'Zone rouge : meurs et tu perds ton équipement porté et tout ce que tu as ramassé. Ressors par un portail violet pour tout garder.', null);
    UI.zone('Terres Écarlates', 'Zone rouge · PvP sans pitié');
    $('#btnQuitter').hidden = true;
    setTimeout(() => UI.manga([{ nom: 'Kael', titre: 'Ombre de ' + J.nom, modele: 'Rogue_Hooded', texte: 'Maître… ici, personne ne t’épargnera. Les chasseurs dépouillent les morts. Ce que tu ramasses n’est à toi qu’une fois sorti par un portail.', couleur: '#ff4a3a', choc: true }]), 900);
    son('lowFrequency_explosion_000', 0.6, 0.6);
  });
}
// ---- Terres Ancestrales : archipel, solo ou équipe de 5, camps qui s'éveillent à ton approche ----
// Les Terres Ancestrales, en étapes : 5 îles de départ (une par équipe) → 2 îles à dragon → l'île finale du Dragon Ancestral.
// Sur chaque île : tue 20 monstres pour ouvrir le coffre, prends la pierre de téléportation, active le portail. Pas de retour.
// À la fin, les équipes survivantes se retrouvent : le Dragon Ancestral, puis la dernière équipe en vie emporte le coffre.
const ETAPES_ANC = [
  { nom: 'Île de départ', r: 58, monstres: 16, boss: 'squelette', biomes: ['foret', 'marais', 'ruines', 'givre', 'plaine'] },
  { nom: 'Île du Dragon', r: 64, monstres: 20, boss: 'dragon', biomes: ['cendres', 'givre'] },
  { nom: 'Île du Dragon Ancestral', r: 72, monstres: 8, boss: 'ancestral', biomes: ['cristaux'] },
];
async function entrerAncestrales(equipe) {
  if (!assetsSylvePrets) { UI.toast('Les brumes ancestrales se lèvent…'); try { await chargerAssets(ASSETS_SYLVE.map(k => [k, `assets/sylve/${k}.json`]), () => {}); assetsSylvePrets = true; } catch (e) {} }
  memoriserMode('Terres Ancestrales' + (equipe ? ' · équipe' : ''), () => entrerAncestrales(equipe));
  const ipJ = statsHeros(J.equip).ip, t = Math.max(1, Math.min(7, Math.round((ipJ - 300) / 110) + 1));
  // 4 équipes rivales (1 à 5 joueurs) partent en même temps sur les autres îles de départ
  const rivales = [0, 1, 2, 3].map(q => ({ guilde: GUILDES_CHASSE[q], taille: hasard([1, 2, 3, 4, 5, 5]), vivante: true }));
  const T = { argent0: J.argent, sac0: new Set(J.sac.map(i => i.id)), chasseT: 1e9, kills: 0, chasseursTues: 0, debut: 0, avertiT: 0, equipe: !!equipe, tier: t, anc: { etape: 0, kills: 0, pierre: false, rivales, coequipiers: equipe ? 4 : 0 } };
  chargerEtapeAnc(T, 0);
}
function chargerEtapeAnc(T, n) {
  const E = ETAPES_ANC[n], t = T.tier + n;
  fondu(() => {
    viderMonde(); document.body.classList.add('brumeAnc'); terres = T; invasion = null; arene = null; selection = null;
    T.anc.etape = n; T.anc.kills = 0; T.anc.pierre = false; T.anc.final = n === 2; T.anc.coffre = null;
    modeActuel = { id: 'terres', ancestrales: true, nom: 'Terres Ancestrales', lieu: `Terres Ancestrales · ${E.nom}`, argent: 2 + n, xp: 10 + n * 4, tiers: [Math.min(8, t), Math.min(8, t + 1)], mobTier: Math.min(8, t), bossTier: [t + 1, t + 1, t + 2, t + 2] };
    monde = construireIleAnc({ r: E.r, biome: hasard(E.biomes), etape: n, graine: Math.floor(Math.random() * 1e5) }); G.solH = monde.solH;
    construireJoueur(monde.spawn.clone()); joueur.pv = joueur.st.pvMax; joueur.energie = joueur.st.energieMax; G.camTarget.copy(joueur.pos);
    G.scene.background.set(n === 2 ? '#1a1a28' : '#0f2c34'); G.scene.fog.color.set(n === 2 ? '#2a2236' : '#1c4c54'); G.scene.fog.density = 0.011; G.hemi.color.set('#d8f0ff'); G.hemi.groundColor.set('#1a3a3a'); G.hemi.intensity = 1.5; G.sun.intensity = 1.7; G.sun.color.set('#fff4e0');
    // ton équipe (ceux qui ont survécu)
    for (let i = 0; i < T.anc.coequipiers; i++) { const d = calerSurJoueur(donneesBot(statsHeros(J.equip).ip * rnd(0.9, 1.05), []), 3, 0); d.guilde = 'CROW ZERO'; creerCombattant(pointLibrePres(V(rnd(-4, 4), 0, monde.spawn.z - 2), 0, 3), d, 'allie').membreAncestral = true; { const m = allies[allies.length - 1]; if (m) Object.assign(m, { autonome: true, perso: 'loyal', modeA: 'explorer', modeT: 20 }); } }
    // l'île grouille de monstres
    const types = ['minion', 'archer', 'guerrier', 'mage', 'cultiste', 'brute'];
    // packs de 2 à 3 monstres, bien espacés (E.monstres = nombre de packs)
    monde.packs.slice(0, E.monstres).forEach((P, k) => { const nb = 2 + (Math.random() < 0.45 ? 1 : 0), type = hasard(types);
      for (let i = 0; i < nb; i++) { const p = pointLibrePres(V(P.x + rnd(-1.8, 1.8), 0, P.z + rnd(-1.8, 1.8)), 0, 2); creerEnnemi(MOBS[i === 0 ? type : hasard(types)] || MOBS.guerrier, p, Math.min(8, t), 300 + k).campA = { ile: n }; } });
    // le gardien de l'île
    let boss;
    if (E.boss === 'ancestral') boss = creerBoss({ ...BOSS[3], nom: 'Dragon Ancestral', hauteur: 9.5, teinte: '#3a0a0a' }, monde.bossPos.clone(), 8, null);
    else if (E.boss === 'dragon') boss = creerBoss({ ...BOSS[3], nom: 'Dragon de ' + (monde.biome() === 'givre' ? 'Givre' : 'la Fournaise'), teinte: monde.biome() === 'givre' ? '#8ad0ff' : '#ff5a1a' }, monde.bossPos.clone(), Math.min(8, t + 1), null);
    else boss = creerBoss(hasard(BOSS.slice(0, 3)), monde.bossPos.clone(), Math.min(8, t + 1), null);
    boss.pvMax *= E.boss === 'ancestral' ? 5 : 1.5; boss.pv = boss.pvMax; T.anc.boss = boss;
    auraMeurtriere(boss, E.boss === 'ancestral' ? '#ff2a1a' : E.boss === 'dragon' ? '#ff8a2a' : '#b05aff', E.boss === 'ancestral' ? 2.4 : 1.6); boss.contour = true;
    // le coffre : il s'ouvre après 20 monstres (sur l'île finale : quand le dragon ET toutes les équipes rivales sont tombés)
    const A = T.anc;
    creerCoffre(monde.coffrePos.clone(), n === 2 ? 'legendaire' : n === 1 ? 'violet' : 'bleu', { get mort() { return A.final ? (A.boss.mort || A.boss.etat === 'possede') && !ennemis.some(e => e.equipeId && !e.mort) : A.kills >= 20; }, boss: { nom: A.final ? 'le Dragon Ancestral et toutes les équipes rivales' : '20 monstres de l’île' }, idx: Math.min(3, n + 1) });
    A.coffre = coffres[coffres.length - 1]; A.coffre.anc = true;
    // les équipes rivales qui ont survécu arrivent sur l'île finale (et une sur l'île du dragon)
    const ipJ = statsHeros(J.equip).ip;
    const venir = n === 2 ? A.rivales.filter(r => r.vivante) : n === 1 ? A.rivales.filter(r => r.vivante).slice(0, 1) : [];
    venir.forEach((R, q) => { const a = q / Math.max(1, venir.length) * 6.283 + 1, base = V(Math.cos(a) * (E.r - 8), 0, Math.sin(a) * (E.r - 8));
      for (let i = 0; i < R.taille; i++) { const d = calerSurJoueur(donneesBot(ipJ * rnd(0.85, 1.15), []), 3, 0); d.guilde = R.guilde; const e = creerCombattant(pointLibrePres(V(base.x + rnd(-3, 3), 0, base.z + rnd(-3, 3)), 0, 4), d, 'ennemi'); e.chasseur = true; e.equipeId = R.guilde; e.potions = 1; e.skill = 0.6 + Math.random() * 0.3; e.etat = 'chasse'; e.rivale = R; } });
    UI.zone('Terres Ancestrales', `${E.nom} · étape ${n + 1}/3`);
    UI.journal('Terres Ancestrales', A.final ? 'Abats le Dragon Ancestral et sois la dernière équipe debout : le coffre est au vainqueur.' : 'Tue 20 monstres pour ouvrir le coffre, prends la pierre de téléportation, puis active le portail.', 0);
    $('#btnQuitter').hidden = true;
    if (n === 0) setTimeout(() => UI.manga([{ nom: 'Kael', titre: 'Ombre de ' + J.nom, modele: 'Rogue_Hooded', texte: `Maître… quatre autres équipes ont débarqué sur les îles voisines. Pas de retour possible : tue, prends la pierre, avance. À la fin, une seule équipe repartira avec le trésor.`, couleur: '#7ab8ff', choc: true }]), 900);
    if (n === 2) setTimeout(() => UI.titreManga('DRAGON ANCESTRAL', `${venir.length} équipe${venir.length > 1 ? 's' : ''} rivale${venir.length > 1 ? 's' : ''} sur l’île`), 800);
    son('lowFrequency_explosion_000', 0.6, 0.6);
  });
}
// progression : 20 monstres, la pierre, le portail ; les équipes rivales vivent leur vie entre deux étapes
function majAnc() {
  const A = terres.anc; if (!A) return;
  { const b = A.boss; if (b && b.auraM) { const R = b.auraM; if (b.mort || b.etat === 'possede') { if (R.ring.parent) G.scene.remove(R.ring); } else { R.ring.position.set(b.pos.x, 0.08 + solY(b.pos.x, b.pos.z), b.pos.z); const k = (2.2 + Math.sin(G.t * 4) * 0.2) * R.k; R.ring.scale.set(k, k, k); if (Math.random() < 0.5) emettre(V(b.pos.x + rnd(-1.5, 1.5), 0.4, b.pos.z + rnd(-1.5, 1.5)), { n: 1, c1: R.couleur, c2: '#0a0000', dir: V(0, 1, 0), vit: 3 * R.k, vie: 0.9, taille: 0.45 }); } } }
  const txt = A.final ? `Dragon Ancestral ${(A.boss.mort || A.boss.etat === 'possede') ? '✔' : '…'} · équipes rivales restantes : ${new Set(ennemis.filter(e => e.equipeId && !e.mort).map(e => e.equipeId)).size}` : A.pierre ? 'Pierre de téléportation en main : active le portail !' : `Tue 20 monstres pour ouvrir le coffre (${Math.min(20, A.kills)}/20)`;
  if (terres._qtxt !== txt) { terres._qtxt = txt; UI.journal('Terres Ancestrales', txt, A.final ? ((A.boss.mort || A.boss.etat === 'possede') ? 0.5 : 0) : Math.min(1, A.kills / 20)); }
  if (A.coffre && A.coffre.ouvert && !A.pierre && !A.final) { A.pierre = true; monde.groupe.userData.portailActif = true; son('jingle_legend', 0.5, 1.2); UI.toast('Pierre de téléportation obtenue ! Active le portail au nord de l’île.', true); }
  if (A.final && A.coffre && A.coffre.ouvert && !A.gagne) { A.gagne = true; monde.groupe.userData.portailActif = true; exploit && exploit('gardien_ancestral'); UI.titreManga('VICTOIRE', 'Dernière équipe debout'); UI.toast('Tu as conquis les Terres Ancestrales ! Le portail te ramène avec tout ton butin.', true); }
  for (const e of ennemis) if (e.rivale && e.mort && !e._compte) { e._compte = true; if (!ennemis.some(x => x.rivale === e.rivale && !x.mort)) { e.rivale.vivante = false; UI.toast(`L’équipe ${e.rivale.guilde} est éliminée`, true); } }
}
function interactionsAnc() {
  const A = terres.anc; if (!A || dist2D(joueur.pos, monde.portail) > 4) return null;
  if (A.final && A.gagne) return UI.action('Rentrer avec ton butin', () => sortirTerres());
  if (!A.pierre) return UI.action('Portail éteint', () => UI.toast(A.final ? 'Gagne d’abord le combat final' : 'Il te faut la pierre de téléportation (coffre de l’île)'));
  return UI.action('Activer le portail', () => {
    // pendant ce temps, les autres équipes ont vécu : certaines tombent sur leur île
    for (const R of A.rivales) if (R.vivante && Math.random() < 0.3) R.vivante = false;
    A.coequipiers = allies.filter(a => a.membreAncestral && !a.mort).length;
    son('forceField_000', 0.6, 0.7); chargerEtapeAnc(terres, A.etape + 1);
  });
}
const GARDIEN_BIOME = { foret: 0, marais: 2, ruines: 0, givre: 1, cendres: 3, cristaux: 2 };
function majCampsAncestraux(dt) {
  terres.campT -= dt; if (terres.campT > 0) return; terres.campT = 0.5;
  const t = terres.tier, now = G.t;
  for (const cp of monde.camps) {
    const d = dist2D(cp.pos, joueur.pos);
    if (!cp.vivant && d < 62 && now >= cp.vide) { // le camp s'éveille
      cp.vivant = true; cp.mobs = [];
      const types = cp.biome === 'ruines' || cp.biome === 'cristaux' ? ['cultiste', 'brute', 'pretresse'] : cp.biome === 'foret' || cp.biome === 'plaine' ? ['minion', 'archer', 'guerrier'] : ['guerrier', 'mage', 'brute', 'archer'];
      const n = 5 + cp.danger * 2;
      for (let i = 0; i < n; i++) { const p = pointLibrePres(V(cp.pos.x + rnd(-6, 6), 0, cp.pos.z + rnd(-6, 6)), 0, 3); const e = creerEnnemi(MOBS[hasard(types)] || MOBS.guerrier, p, Math.min(8, t + cp.danger), 200 + monde.camps.indexOf(cp)); e.campA = cp; cp.mobs.push(e); }
      if (cp.danger >= 1 && !cp.pille) { const couleur = cp.danger >= 3 ? (Math.random() < 0.3 ? 'legendaire' : 'violet') : cp.danger === 2 ? (Math.random() < 0.45 ? 'violet' : 'bleu') : 'bleu';
        const mobs = cp.mobs; creerCoffre(pointLibrePres(V(cp.pos.x, 0, cp.pos.z + 3), 0.5, 2), couleur, { get mort() { return mobs.every(e => e.mort || e.etat === 'possede'); }, boss: { nom: 'tous les gardiens du camp' }, idx: Math.min(3, cp.danger) }); cp.coffre = coffres[coffres.length - 1]; }
    } else if (cp.vivant) {
      const tous = cp.mobs.every(e => e.mort || e.etat === 'possede');
      if (tous && !cp.nettoye) { cp.nettoye = true; terres.kills += cp.mobs.length; cp.vide = now + 300; }
      if (d > 120) { // trop loin : le camp se rendort (les morts restent morts 5 minutes)
        for (const e of cp.mobs) if (ennemis.includes(e)) { G.scene.remove(e.root); UI.retirerPlaque(e); ennemis.splice(ennemis.indexOf(e), 1); }
        if (cp.coffre) { if (cp.coffre.ouvert) cp.pille = true; const i = coffres.indexOf(cp.coffre); if (i >= 0) { G.scene.remove(cp.coffre.obj); G.scene.remove(cp.coffre.beam); coffres.splice(i, 1); } cp.coffre = null; }
        cp.vivant = false; cp.nettoye = false; cp.mobs = [];
      }
    }
  }
  for (const g of monde.gardiens) {
    if (g.vivant || g.vaincu || dist2D(g.pos, joueur.pos) > 70) continue;
    g.vivant = true; const I = monde.iles[g.ile];
    const dragon = ['givre', 'cendres', 'marais', 'cristaux'].includes(I.b);
    const bd = dragon ? { ...BOSS[3], nom: { givre: 'Dragon de Givre', cendres: 'Dragon de la Fournaise', marais: 'Dragon des Marais', cristaux: 'Dragon de Cristal' }[I.b], teinte: { givre: '#8ad0ff', cendres: '#ff5a1a', marais: '#8a3aaa', cristaux: '#b0a0ff' }[I.b] } : { ...BOSS[GARDIEN_BIOME[I.b] ?? 0] };
    if (!dragon) bd.nom = `${bd.nom} de ${I.nom.split(' ').slice(-1)[0]}`;
    const b = creerBoss(bd, g.pos.clone(), Math.min(8, t + g.danger), null); b.pvMax *= 1 + g.danger * 0.4; b.pv = b.pvMax; g.boss = b; g.dragon = dragon;
    creerCoffre(pointLibrePres(V(g.pos.x - 6, 0, g.pos.z + 5), 0.5, 2), g.danger >= 3 ? 'legendaire' : 'violet', b);
    UI.toast(`Le gardien de ${I.nom} se dresse devant toi !`, true); son('lowFrequency_explosion_000', 0.5, 0.8);
  }
  for (const g of monde.gardiens) if (g.boss && g.boss.mort && !g.vaincu) {
    g.vaincu = true; exploit && exploit('gardien_ancestral'); poserOrbe(g.boss.pos.clone(), g.dragon);
    if (g.dragon) { terres.dragons = (terres.dragons || 0) + 1; UI.toast(`Dragon abattu : ${terres.dragons} / 4`, true);
      if (terres.dragons >= 4 && !terres.ancestral) { terres.ancestral = true; programmer(4, invoquerDragonAncestral); } }
  }
  majEquipesIle(dt);
  majQuetesAnc();
}
// ---- orbes de pouvoir lâchés par les gardiens ----
function poserOrbe(p, dragon) {
  const g = new THREE.Group(); g.position.set(p.x, 1.4, p.z);
  const col = dragon ? '#ffcf4a' : '#7ab8ff';
  const o = new THREE.Mesh(new THREE.SphereGeometry(0.55, 20, 14), new THREE.MeshStandardMaterial({ color: col, emissive: col, emissiveIntensity: 2.2, transparent: true, opacity: 0.9 })); g.add(o);
  G.scene.add(g); const beam = faisceau(V(p.x, 0, p.z), col, 14, 0.8); G.scene.add(beam);
  const O = { g, beam, pos: p, dragon, pris: false }; (terres.orbes = terres.orbes || []).push(O);
  ajouterVfx(new THREE.Group(), (t) => { if (O.pris) { G.scene.remove(g); G.scene.remove(beam); return false; } g.position.y = 1.4 + Math.sin(t * 2) * 0.25; g.rotation.y = t; if (Math.random() < 0.3) emettre(V(p.x, 1.4, p.z), { n: 1, c1: '#ffffff', c2: col, vit: 1.5, vie: 0.8, taille: 0.25 }); });
  UI.toast(dragon ? 'Une ORBE DORÉE est tombée !' : 'Une orbe de pouvoir est tombée', true);
}
function prendreOrbe(O) {
  O.pris = true; son('jingle_legend', 0.55); onde(O.pos, O.dragon ? '#ffcf4a' : '#7ab8ff', 8, 1);
  const gain = Math.round(lootCoffre(O.dragon ? 'legendaire' : 'violet', modeActuel, 3).argent * (O.dragon ? 6 : 3)); J.argent += gain;
  J.orbeT = Date.now() + 5 * 60000; recalculer(); gagnerXPRelatif(O.dragon ? 0.08 : 0.04);
  UI.toast(`Orbe absorbée : +${fmtN(gain)} ¤ et +15 % de dégâts pendant 5 min — les chasseurs la sentent sur toi !`, true);
  terres.chasseT = Math.min(terres.chasseT, 15);
}
// ---- le Dragon Ancestral : quand les 4 dragons sont tombés ----
function invoquerDragonAncestral() {
  if (!terres || !monde.iles) return;
  const c = monde.iles[3], p = V(c.x, 0, c.z);
  const b = creerBoss({ ...BOSS[3], nom: 'Dragon Ancestral', hauteur: 9.5, teinte: '#3a0a0a', hpMult: 30, dmgMult: 3.2 }, p, 8, null); b.pvMax *= 4; b.pv = b.pvMax; b.etat = 'chasse';
  creerCoffre(pointLibrePres(V(p.x - 9, 0, p.z + 6), 0.5, 2), 'legendaire', b); creerCoffre(pointLibrePres(V(p.x + 9, 0, p.z + 6), 0.5, 2), 'legendaire', b);
  G.shake = 1; son('lowFrequency_explosion_000', 0.9, 0.4); UI.flashInvasion && UI.flashInvasion();
  UI.titreManga('DRAGON ANCESTRAL', 'Il s’éveille au cœur des Ruines');
  UI.chat('Système', 'Le Dragon Ancestral s’est éveillé au centre des Terres Ancestrales ! Toutes les équipes convergent…');
  terres.chasseT = 5;
}
// ---- quêtes d'île : 20, 35, 45, 60, 80 monstres ----
const PALIERS_QUETE = [20, 35, 45, 60, 80, 100];
function ileDe(p) { return monde.iles ? monde.iles.findIndex(I => Math.hypot(p.x - I.x, p.z - I.z) < I.r + 3) : -1; }
function compterQueteAnc(e) {
  if (!terres || !monde.iles) return; const k = e.campA ? e.campA.ile : ileDe(e.pos); if (k < 0) return;
  const Q = (terres.quetes = terres.quetes || {})[k] || (terres.quetes[k] = { etape: 0, kills: 0 });
  Q.kills++;
  const but = PALIERS_QUETE[Math.min(Q.etape, PALIERS_QUETE.length - 1)];
  if (Q.kills >= but) {
    Q.kills = 0; Q.etape++;
    const gain = Math.round(lootCoffre('bleu', modeActuel, 2).argent * (2 + Q.etape)); J.argent += gain; gagnerXPRelatif(0.02 * Q.etape);
    creerCoffre(pointLibrePres(V(joueur.pos.x + 3, 0, joueur.pos.z), 0.5, 3), Q.etape >= 4 ? 'legendaire' : Q.etape >= 2 ? 'violet' : 'bleu', { mort: true });
    UI.toast(`Quête de ${monde.iles[k].nom} accomplie (${but} monstres) ! +${fmtN(gain)} ¤ et un coffre`, true); son('jingle_win', 0.6);
  }
}
function majQuetesAnc() {
  const k = ileDe(joueur.pos); if (k < 0) return;
  const Q = (terres.quetes && terres.quetes[k]) || { etape: 0, kills: 0 }, but = PALIERS_QUETE[Math.min(Q.etape, PALIERS_QUETE.length - 1)];
  const txt = `${monde.iles[k].nom} — tue ${but} monstres (${Q.kills}/${but})${terres.dragons ? ` · dragons ${terres.dragons}/4` : ''}`;
  if (terres._qtxt !== txt) { terres._qtxt = txt; UI.journal('Terres Ancestrales', txt, Q.kills / but); }
}
// ---- équipes rivales : jusqu'à 6 par île (1 à 5 joueurs), elles se battent entre elles et contre les monstres ----
function majEquipesIle(dt) {
  const k = ileDe(joueur.pos); if (k <= 0) return; // pas sur le rivage de départ
  terres.equipesIle = terres.equipesIle || {};
  if (terres.equipesIle[k]) return; terres.equipesIle[k] = true;
  const I = monde.iles[k], ipJ = statsHeros(J.equip).ip, nb = 6;
  for (let q = 0; q < nb; q++) {
    const taille = hasard([1, 2, 3, 3, 4, 5]), guilde = GUILDES_CHASSE[q % GUILDES_CHASSE.length], id = 'eq' + k + '_' + q;
    const a = Math.random() * 6.283, r = I.r * (0.4 + Math.random() * 0.45), base = V(I.x + Math.cos(a) * r, 0, I.z + Math.sin(a) * r);
    if (dist2D(base, joueur.pos) < 30) continue;
    for (let i = 0; i < taille; i++) { const d = calerSurJoueur(donneesBot(ipJ * rnd(0.8, 1.15), []), 3, 0); d.guilde = guilde; const e = creerCombattant(pointLibrePres(V(base.x + rnd(-3, 3), 0, base.z + rnd(-3, 3)), 0, 4), d, 'ennemi'); e.chasseur = true; e.equipeId = id; e.potions = 1; e.skill = 0.6 + Math.random() * 0.3; e.etat = 'chasse'; }
  }
  UI.toast(`${nb} équipes rôdent sur ${I.nom}…`, true);
}
// combat « hors écran » entre équipes et contre les monstres (quand tu n'es pas tout près)
function mortSilencieuse(e) { e.mort = true; e.pv = 0; e.jouer(e.actions && e.actions.Death_C_Skeletons ? 'Death_C_Skeletons' : 'Death_A', { boucle: false, forcer: true }); UI.retirerPlaque && 0; setTimeout(() => { e.descendre = true; }, 3000); }
function escarmouche(e, dt) {
  e.escT = (e.escT || 0) - dt;
  if (!e.escCible || e.escCible.mort || e.escT < -6) { e.escT = 0; let best = null, bd = 45; for (const o of ennemis) { if (o === e || o.mort || o.tk || o.equipeId === e.equipeId || !o.equipeId && o.boss && !(terres && terres.anc && terres.anc.final)) continue; const d = dist2D(o.pos, e.pos); if (d < bd) { bd = d; best = o; } } e.escCible = best; }
  const c = e.escCible; if (!c) { e.jouer(e.armeDef.idle); return; }
  const d = dist2D(e.pos, c.pos);
  if (d > 2.4) { avancerVers(e, c.pos, dt, e.st.vitesse * 0.9); e.jouer(e.armeDef.run); return; }
  e.angle = tourner(e.angle, Math.atan2(c.pos.x - e.pos.x, c.pos.z - e.pos.z), dt * 10); e.root.rotation.y = e.angle;
  e.coupE = (e.coupE || 0) - dt;
  if (e.coupE <= 0) { e.coupE = 1.1; e.jouer(hasard(['1H_Melee_Attack_Chop', '2H_Melee_Attack_Slice', '1H_Melee_Attack_Slice_Diagonal']), { boucle: false, forcer: true, fin: () => e.jouer(e.armeDef.idle) });
    c.pv -= (e.dmg || e.st.degats || 60) * 0.8; c.frapper && c.frapper();
    if (c.pv <= 0 && !c.mort) mortSilencieuse(c); }
}
const GUILDES_CHASSE = ['LES CHACALS', 'CROCS NOIRS', 'SANG-FROID', 'LA MEUTE ROUGE', 'VAUTOURS', 'LAMES CREUSES'];
function majTerres(dt) {
  if (!terres || !modeActuel || modeActuel.id !== 'terres' || joueur.mort) return;
  if (terres.anc) { majAnc(); return; }
  const sur = dist2D(joueur.pos, monde.campSur) < monde.rayonSur;
  // les chasseurs : des groupes de 1 à 4 « joueurs » qui te traquent (jamais dans le camp)
  terres.chasseT -= dt;
  const actifs = ennemis.filter(e => e.chasseur && !e.mort);
  if (terres.chasseT <= 0 && !sur && actifs.length < (modeActuel.ancestrales ? 10 : 6)) {
    terres.chasseT = rnd(60, 110) * (1 - Math.min(0.5, terres.kills * 0.02));
    const ipJ = statsHeros(J.equip).ip, n = modeActuel.ancestrales ? hasard(terres.equipe ? [3, 4, 5, 5, 5] : [1, 2, 3, 3, 5]) : 1 + Math.floor(Math.random() * Math.min(4, 1 + terres.chasseursTues / 2 + Math.random() * 2)), guilde = hasard(GUILDES_CHASSE);
    const a = Math.random() * 6.283, base = V(joueur.pos.x + Math.cos(a) * 42, 0, joueur.pos.z + Math.sin(a) * 42);
    if (monde.marche(base.x, base.z) || !modeActuel.ancestrales && Math.hypot(base.x, base.z) < monde.rayonMonde - 10) for (let i = 0; i < n; i++) {
      const d = calerSurJoueur(donneesBot(ipJ * rnd(0.85, 1.2), []), 3, 0); d.guilde = guilde;
      const p = pointLibrePres(V(base.x + rnd(-3, 3), 0, base.z + rnd(-3, 3)), 0, 4);
      const e = creerCombattant(p, d, 'ennemi'); e.chasseur = true; e.potions = 1; e.skill = Math.min(0.95, 0.6 + Math.random() * 0.35); e.etat = 'chasse';
    }
  }
  for (const e of actifs) if (!e.annonce && dist2D(e.pos, joueur.pos) < 32) { e.annonce = true; if (!terres.avertiT || G.t - terres.avertiT > 20) { terres.avertiT = G.t; UI.toast(`☠ ${e.guilde || 'Des chasseurs'} t’ont repéré !`, true); son('lowFrequency_explosion_000', 0.4, 1.1); UI.chat(e.nom, hasard(['regardez qui se balade seul…', 'ton stuff est à moi', 'cours, petit', 'il est là ! sur lui !', 'pose ton sac et on te laisse partir… ou pas'])); } }
  // dans le camp, les chasseurs n'entrent pas
  if (sur) for (const e of actifs) if (dist2D(e.pos, monde.campSur) < monde.rayonSur + 4) { const v = V(e.pos.x - monde.campSur.x, 0, e.pos.z - monde.campSur.z).normalize(); e.pos.x += v.x * dt * 6; e.pos.z += v.z * dt * 6; }
}
function finChasseur(e) {
  terres && terres.chasseursTues++;
  victoireRival(e);
  UI.journal('Terres Écarlates', `Tu as abattu ${e.nom} (${e.guilde}). Fouille sa dépouille — puis rentre vivant pour tout garder.`, null);
}
function mortTerres() {
  const T = terres; terres = null;
  const perdus = ['arme', 'casque', 'plastron', 'bottes'].map(s => J.equip[s]).filter(Boolean);
  const type = J.equip.arme ? J.equip.arme.type : 'epee';
  J.equip = { arme: creerArme(type === 'ombre' ? 'epee' : type, 1, 0), casque: null, plastron: null, bottes: null };
  const avant = J.sac.length; J.sac = J.sac.filter(i => T.sac0.has(i.id)); const sacPerdu = avant - J.sac.length;
  const gain = Math.max(0, J.argent - T.argent0); J.argent = Math.max(0, Math.min(J.argent, T.argent0)); const perte = Math.round(J.argent * 0.1); J.argent -= perte;
  sauverMaintenant(); recalculer();
  const k = dernierAgresseur, par = k && k.chasseur ? `${k.nom} (${k.guilde})` : 'les Terres';
  if (k && k.chasseur && !k.mort) { emoteBot(k, ['ez', 'mdr', 'clown', 'rip'], 1, 0.6); UI.chat(k.nom, hasard(['merci pour le stuff', 'fallait rester au camp', 'ton arme est jolie, je la garde', 'gg ez'])); }
  son('lowFrequency_explosion_000', 0.8, 0.45);
  setTimeout(() => UI.mort(`Tué par ${par}. Ils t’ont tout pris : ${perdus.map(it => nomObjet(it)).join(', ') || 'rien sur le dos'}${sacPerdu ? `, ${sacPerdu} objet${sacPerdu > 1 ? 's' : ''} ramassé${sacPerdu > 1 ? 's' : ''}` : ''}, ${fmtN(gain)} ¤ gagnés pendant l’expédition et ${fmtN(perte)} ¤ de ta bourse. Tu repars avec une arme rouillée.`, () => fondu(() => lancerHub())), 1600);
}
function sortirTerres() {
  const T = terres; terres = null;
  const gain = Math.max(0, J.argent - T.argent0), objets = J.sac.filter(i => !T.sac0.has(i.id)).length;
  sauver(); son('jingle_win', 0.6);
  UI.toast(`Sorti vivant ! Tu gardes ${fmtN(gain)} ¤ et ${objets} objet${objets > 1 ? 's' : ''}`, true);
  if (T.chasseursTues >= 3) exploit && exploit('chasseur_de_chasseurs');
  fondu(() => lancerHub());
}
function interactionsTerres() {
  if (terres && terres.anc) { const r = interactionsAnc(); if (r !== null) return r; }
  for (const O of (terres && terres.orbes) || []) if (!O.pris && dist2D(joueur.pos, O.pos) < 3) return UI.action(O.dragon ? 'Absorber l’orbe dorée' : 'Absorber l’orbe', () => prendreOrbe(O));
  for (const p of monde.sorties) if (dist2D(joueur.pos, p) < 3.4) return UI.action('Sortir par le portail (tout garder)', () => sortirTerres());
  return null;
}
