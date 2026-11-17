// ---------------- Arbre de talents ----------------
function monterTalent(id) {
  const type = (J.equip.arme || {}).type || 'epee'; const arbre = arbreDe(type);
  const t = J.talents[type] = J.talents[type] || {};
  const dispo = pointsTotaux(niveauDe(type)) - pointsDepenses(t);
  for (const b of arbre.branches) { const n = b.noeuds.find(x => x.id === id); if (!n) continue;
    const r = t[id] || 0; if (r >= n.max || dispo <= 0) return false;
    let pb = 0; for (const x of b.noeuds) pb += t[x.id] || 0; if (pb < n.req) return false;
    if (n.dep && !(t[n.dep] > 0)) return false;
    t[id] = r + 1; sauver(); son('jingle_loot', 0.35, 1.4);
    if (n.competence && !t._annonce) UI.toast(`Compétence débloquée : ${SORTS[n.competence].nom} — place-la sur Q, W ou E`, true);
    const pv = joueur.pv, en = joueur.energie; construireJoueur(joueur.pos.clone()); joueur.pv = Math.min(pv, joueur.st.pvMax); joueur.energie = Math.min(en, joueur.st.energieMax);
    return true; }
  return false;
}
function resetTalents() {
  const type = (J.equip.arme || {}).type || 'epee'; J.talents[type] = {}; J.slotsTalent[type] = {}; sauver();
  construireJoueur(joueur.pos.clone()); UI.toast('Talents réinitialisés : tous tes points sont rendus');
}
function placerCompetence(id, k) {
  const type = (J.equip.arme || {}).type || 'epee';
  const s = J.slotsTalent[type] = J.slotsTalent[type] || {};
  for (const x of ['Q', 'W', 'E']) if (s[x] === id) delete s[x];
  if (k) s[k] = id;
  sauver(); construireJoueur(joueur.pos.clone());
  UI.toast(k ? `${SORTS[id].nom} placée sur ${k}` : `${SORTS[id].nom} retirée`);
}
// ---------------- Maître des bêtes : la meute de 3 loups démoniaques ----------------
const NOMS_LOUPS = ['Croc-Sang', 'Cendre', 'Fléau'];
const meuteVivante = () => meute.filter(l => l && !l.mort && allies.includes(l));
function statsLoups() {
  const st = joueur.st, T = st.tal || {};
  return { pv: Math.round(st.pvMax * 0.7 * (1 + (T.loupPv || 0))), dmg: st.degats * 0.42 * (1 + (T.loupDeg || 0)), vit: 1 + (T.loupVit || 0), red: Math.min(0.75, 0.42 + (T.loupArm || 0)), taunt: 10 + (T.loupTaunt || 0) };
}
function creerLoup(i, pos) {
  const l = new Loup(); G.scene.add(l.root); l.root.position.copy(pos);
  const S = statsLoups();
  Object.assign(l, { loup: true, invoc: 'loup', idx: i, camp: 'allie', pos: l.root.position, angle: joueur.angle, mort: false, stunT: 0, slowT: 0, dots: [], atkT: rnd(0, 1), rayon: 0.6, hauteurPlaque: 1.65,
    reduction: S.red, pvMax: S.pv, pv: S.pv, dmg: S.dmg, vitK: S.vit, taunt: S.taunt, energieMax: 100, energie: 100, nom: NOMS_LOUPS[i], armeDef: { idle: 'idle', run: 'course' }, sautCd: rnd(0, 2), actionT: 0 });
  if (modeActuel && modeActuel.goulet) l.bg = { camp: 'bleu', role: 'loup' };
  l.root.rotation.y = l.angle;
  allies.push(l); meute[i] = l; _equipes.t = -1;
  UI.plaque(l, { nom: l.nom, classe: 'allie loupP', vie: true, lettre: false });
  onde(pos, '#ff2a1a', 2.6, 0.5); emettre(V(pos.x, 0.8, pos.z), { n: 34, c1: '#ffb08a', c2: '#ff0a0a', vit: 4, vie: 0.6, taille: 0.4, grav: -1 });
  return l;
}
// les loups accompagnent le Maître des bêtes partout (Place, donjons, arène, Goulet)
function assurerMeute() {
  if (!joueur || joueur.armeType !== 'arc') {
    for (const l of meute) if (l && allies.includes(l)) dissiper(l);
    meute.length = 0; loupChoisi = null; UI.cadreMeute(null); return;
  }
  for (let i = 0; i < 3; i++) {
    const l = meute[i];
    if (l && allies.includes(l)) { const S = statsLoups(); const k = l.pv / l.pvMax; Object.assign(l, { pvMax: S.pv, pv: S.pv * k, dmg: S.dmg, vitK: S.vit, reduction: S.red, taunt: S.taunt }); continue; }
    creerLoup(i, pointLibrePres(joueur.pos, 1.5, 3.2));
  }
  joueur.comboMeute = joueur.comboMeute || 1; majSortMeute(); UI.cadreMeute(meute, API);
}
// le sort W : Appel de la meute s'il manque un loup, sinon l'enchaînement en 3 temps
function majSortMeute() {
  if (!joueur || joueur.armeType !== 'arc') return;
  const k = ['Q', 'W', 'E'].find(x => joueur.sorts[x] && (joueur.sorts[x].id === 'meute' || joueur.sorts[x].type === 'meute')); if (!k) return;
  const complet = meuteVivante().length === 3;
  const id = complet ? ['entrave', 'rugissement', 'bondMeurtrier'][(joueur.comboMeute || 1) - 1] : 'meute';
  if (joueur.sorts[k].id === id) return;
  joueur.sorts[k] = sortAvecTalents(id);
  joueur.cdMax[k] = +(joueur.sorts[k].cd * (1 - joueur.st.recharge / 100)).toFixed(2);
  if (id === 'meute' && (joueur.cds[k] || 0) < 0.1 && meuteVivante().length < 3 && joueur.loupsAppel) joueur.cds[k] = 0;
  UI.construireSorts(joueur);
}
function cibleLoup(a) {
  const ok = (e) => e && !e.mort && ennemis.includes(e) && e.camp !== 'allie';
  if (ok(joueur.cibleVerrou) && dist2D(joueur.cibleVerrou.pos, joueur.pos) < 22) return joueur.cibleVerrou;
  if (ok(joueur.cible) && joueur.combatT > 0 && dist2D(joueur.cible.pos, joueur.pos) < 20) return joueur.cible;
  let best = null, bd = Infinity;
  for (const e of vivants()) {
    if (PAISIBLES.includes(e.etat)) continue;
    const d = Math.min(dist2D(e.pos, a.pos), dist2D(e.pos, joueur.pos));
    if (d < 11 && d < bd) { bd = d; best = e; }
  }
  return best;
}
function bondLoup(a, c, mult, opts = {}) {
  if (a.mort || c.mort) return;
  const dep = a.pos.clone(); const dir = V(c.pos.x - dep.x, 0, c.pos.z - dep.z); if (dir.lengthSq() < 0.01) dir.set(0, 0, 1); dir.normalize();
  const r = (c.rayon || 0.5) + 0.75; const arr = V(c.pos.x - dir.x * r, 0, c.pos.z - dir.z * r);
  a.angle = Math.atan2(dir.x, dir.z); a.root.rotation.y = a.angle;
  const impact = () => {
    if (a.mort) return; a.root.position.y = 0; a.jouer('morsure', { forcer: true });
    emettre(V(c.pos.x, 1, c.pos.z), { n: 16, c1: '#ffd0c0', c2: '#ff0a0a', vit: 4, vie: 0.45, taille: 0.35 }); son('knifeSlice2', 0.4, 0.7);
    if (c.mort) return;
    auteurCoup = a;
    if (mult > 0) blesser(c, mult, { stun: opts.stun, dot: opts.dot, c1: '#ff4a2a' }); else infliger(a, c, a.dmg * 1.6);
    auteurCoup = null;
  };
  if (opts.teleport) {
    emettre(V(dep.x, 0.8, dep.z), { n: 24, c1: '#ffb08a', c2: '#3a0004', vit: 3, vie: 0.5, taille: 0.45 });
    a.pos.x = arr.x; a.pos.z = arr.z; a.actionT = 0.35; onde(arr, '#ff2a1a', 2.2, 0.35);
    programmer(0.06, impact); return;
  }
  a.actionT = 0.46; a.jouer('saut', { forcer: true });
  ajouterVfx(new THREE.Group(), (t) => { if (a.mort) return false; const k = Math.min(1, t / 0.42); a.pos.x = dep.x + (arr.x - dep.x) * k; a.pos.z = dep.z + (arr.z - dep.z) * k; a.root.position.y = Math.sin(k * Math.PI) * 1.5; if (k >= 1) { impact(); return false; } });
}
function combatLoup(a, c, dt) {
  const d = dist2D(a.pos, c.pos) - (c.rayon || 0.5);
  const vJ = vitesseJoueur() * a.vitK;
  if (d > 3.5 && d < 10 && a.sautCd <= 0 && ligneLibre(a.pos, c.pos)) { a.sautCd = rnd(4, 6.5); bondLoup(a, c, 0); return; } // bond naturel sur la proie
  if (d > 1.1) { allerVers(a, c.pos, dt, vJ * 1.1); a.jouer('course'); return; }
  a.angle = tourner(a.angle, Math.atan2(c.pos.x - a.pos.x, c.pos.z - a.pos.z), dt * 10); a.root.rotation.y = a.angle;
  if (a.atkT > 0) { if (a.etat !== 'morsure') a.jouer('idle'); return; }
  a.atkT = 1.05; a.jouer('morsure', { forcer: true });
  programmer(0.17, () => { if (a.mort || c.mort || dist2D(a.pos, c.pos) > (c.rayon || 0.5) + 1.9) return; infliger(a, c, a.dmg); son('knifeSlice', 0.25, 0.7); });
}
function majLoup(a, dt) {
  a.atkT -= dt * (a.frenesieT > 0 ? 1.8 : 1); a.sautCd -= dt; if (a.frenesieT > 0) a.frenesieT -= dt;
  a.coupT = (a.coupT || 0) - dt;
  a.energie = Math.min(a.energieMax, a.energie + dt * 8);
  if (a.actionT > 0) { a.actionT -= dt; return; }
  a.root.position.y = 0;
  if (joueur.mort && !goulet) { a.jouer('idle'); return; }
  const vJ = vitesseJoueur() * a.vitK;
  // ruée ordonnée : il fonce au point choisi, nettoie tout dans un rayon de 40 m, puis revient
  if (a.rush) {
    const R = a.rush;
    if (R.phase === 'aller') {
      if (dist2D(a.pos, R.point) > 1.6 && (R.t = (R.t || 0) + dt) < 25) { allerVers(a, R.point, dt, vitesseJoueur()); a.jouer('course'); return; }
      R.phase = 'zone'; for (const e of vivants()) if (dist2D(e.pos, R.point) < 40 && (e.etat === 'idle' || e.etat === 'dormant')) reveiller(e);
    }
    let cible = null, bd = Infinity;
    for (const e of vivants()) { const d = dist2D(e.pos, R.point); if (d < 40 && dist2D(e.pos, a.pos) < bd) { bd = dist2D(e.pos, a.pos); cible = e; } }
    if (cible) { combatLoup(a, cible, dt); return; }
    a.rush = null; UI.toast(`${a.nom} a nettoyé la zone et revient`);
  }
  const c = cibleLoup(a);
  if (c) { combatLoup(a, c, dt); return; }
  // suit son maître en formation
  const off = [[-1.7, -1.3], [1.7, -1.3], [0, -2.5]][a.idx] || [0, -2];
  const an = joueur.angle, ca = Math.cos(an), sa = Math.sin(an);
  const dest = V(joueur.pos.x + off[0] * ca + off[1] * sa, 0, joueur.pos.z - off[0] * sa + off[1] * ca);
  const dJ = dist2D(a.pos, joueur.pos);
  if (dJ > 30) { emettre(V(a.pos.x, 0.8, a.pos.z), { n: 16, c1: '#ffb08a', c2: '#3a0004', vit: 3, vie: 0.5, taille: 0.4 }); a.pos.copy(pointLibrePres(dest, 0, 1.5)); a.chemin = null; return; }
  const d = dist2D(a.pos, dest);
  if (d > 0.8) { allerVers(a, dest, dt, Math.max(vJ * 1.05, 4) * (d > 5 ? 1.35 : 1)); a.jouer('course'); }
  else { a.jouer('idle'); a.angle = tourner(a.angle, joueur.angle, dt * 4); a.root.rotation.y = a.angle; }
  if (a.coupT <= 0) a.pv = Math.min(a.pvMax, a.pv + a.pvMax * 0.05 * dt);
}
let meuteHudT = 0;
function majMeuteJoueur(dt) {
  if (!joueur) return;
  if (joueur.frenesieT > 0) joueur.frenesieT -= dt;
  if (joueur.comboT > 0) { joueur.comboT -= dt; if (joueur.comboT <= 0 && joueur.comboMeute !== 1) { joueur.comboMeute = 1; majSortMeute(); } }
  if (!meute.length) return;
  if ((meuteHudT -= dt) <= 0) { meuteHudT = 0.15; UI.majMeute(meute, loupChoisi); if (meuteVivante().length < 3 && joueur.sorts.W && joueur.sorts.W.type === 'meute') majSortMeute(); }
}
// cadre de la meute : on touche un loup, puis un point de la carte → il y fonce
function choisirLoup(i) {
  const l = meute[i];
  if (!l || l.mort || !allies.includes(l)) { UI.toast('Ce loup est tombé : relance l’Appel de la meute'); return; }
  loupChoisi = loupChoisi === l ? null : l;
  if (loupChoisi) { UI.toast(`${l.nom} : touche la carte là où il doit foncer`); son('select_001', 0.4); }
  UI.majMeute(meute, loupChoisi);
}
const _ray = new THREE.Raycaster(), _plan = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
function pointSol(x, y) {
  const v = new THREE.Vector2(x / innerWidth * 2 - 1, -(y / innerHeight) * 2 + 1);
  _ray.setFromCamera(v, G.camera); const p = new THREE.Vector3();
  return _ray.ray.intersectPlane(_plan, p) ? p.setY(0) : null;
}
function envoyerLoup(x, y) {
  const l = loupChoisi; loupChoisi = null; UI.majMeute(meute, null);
  if (!l || l.mort) return;
  const p = pointSol(x, y); if (!p) return;
  if (!monde.marche(p.x, p.z)) { UI.toast('Il ne peut pas aller là'); return; }
  l.rush = { point: p, phase: 'aller', t: 0 }; l.chemin = null;
  lueurSol(p, '#ff2a1a', 1.6, 1.2, 0.9); onde(p, '#ff3a1a', 2, 0.5);
  UI.toast(`${l.nom} fonce ! Il revient quand tout est mort à 40 m`); son('confirmation_001', 0.4, 0.8);
  l.jouer('hurle', { forcer: true }); l.actionT = 0.35;
}
function invoquerOmbres(n) {
  for (const a of allies.filter(x => x.invoc === 'ombre')) dissiper(a);
  const st = joueur.st;
  son('forceField_000', 0.5, 0.6); onde(joueur.pos, '#9a5aff', 5, 0.7);
  for (let i = 0; i < n; i++) {
    const ang = joueur.angle + Math.PI + (i - (n - 1) / 2) * (Math.PI * 1.6 / Math.max(1, n));
    const pos = pointLibrePres(V(joueur.pos.x + Math.sin(ang) * 2.4, 0, joueur.pos.z + Math.cos(ang) * 2.4), 0, 1.2);
    const a = creerCombattant(pos, { nom: 'Ombre', guilde: J.nom.toUpperCase(), equip: J.equip, modele: 'Rogue_Hooded' }, 'allie');
    UI.retirerPlaque(a);
    Object.assign(a, { invoc: 'ombre', vieT: 60, potions: 0, cdRempart: 1e9, specT: rnd(2, 5), ip: undefined });
    const fo = forceOmbre(); a.pvMax = a.pv = Math.round(st.pvMax * fo); a.dmg = st.degats * fo; a.reduction = st.reduction * 0.6; a.vieT = 60 + (J.equip.arme.ench || 0) * 5;
    a.root.scale.setScalar(0.9);
    teinteSpectrale(a, '#140c20', 0.8);
    UI.plaque(a, { nom: 'Ombre', guilde: '60 s', classe: 'allie', vie: true, lettre: false });
    fumeeOmbre(pos);
    a.jouer('Spellcast_Raise', { boucle: false, fin: () => a.jouer(a.armeDef.idle) });
  }
}
function invoquerReflet(cible) {
  for (const a of allies.filter(x => x.invoc === 'reflet')) dissiper(a);
  const pos = pointLibrePres(V((joueur.pos.x + cible.pos.x) / 2, 0, (joueur.pos.z + cible.pos.z) / 2), 0, 1.5);
  let a;
  const nom = 'Reflet de ' + (cible.nom || cible.def.nom);
  if (cible.combattant) {
    a = creerCombattant(pos, { ...cible.data, nom, guilde: 'OMBRE DE ' + J.nom.toUpperCase() }, 'allie');
    UI.retirerPlaque(a);
    Object.assign(a, { potions: 0, cdRempart: 1e9 });
  } else {
    const def = cible.def, dragon = def.model === 'Dragon_Evolved';
    a = new Acteur(def.model, { hauteur: dragon ? 3.2 : 2.0, echelle: cible.boss && !dragon ? Math.min(1.35, cible.boss.scale * 0.8) : 1 });
    if (def.arme) a.attacher(def.arme, 'handslot.r');
    a.root.position.copy(pos); G.scene.add(a.root);
    Object.assign(a, { def, refletMob: true, dragon, camp: 'allie', pos: a.root.position, angle: 0, mort: false, stunT: 0, slowT: 0, dots: [], atkT: 0.5, attaqueT: 0,
      rayon: Math.max(0.5, (cible.rayon || 0.6) * 0.8), hauteurPlaque: dragon ? 3.8 : (cible.hauteurPlaque || 2.5) * 0.85, hover: dragon ? 0.6 : 0, reduction: 0.25, nom,
      armeDef: { idle: dragon ? 'Flying_Idle' : 'Idle_Combat', run: dragon ? 'Fast_Flying' : 'Running_A' }, vitesse: (def.vitesse || 3.6) * 1.05, portee: def.type === 'ranged' || def.type === 'caster' ? 9 : (def.portee || 2.2) });
    a.root.position.y = a.hover;
    allies.push(a);
  }
  Object.assign(a, { invoc: 'reflet', vieT: 30 });
  const ar = J.equip.arme, pr = 0.15 + (ar.tier - 1) * 0.01 + (ar.ench || 0) * 0.02;
  a.pvMax = a.pv = Math.max(50, Math.round(cible.pvMax * pr));
  a.energieMax = a.energie = Math.round((cible.st ? cible.st.energieMax : 200) * pr);
  a.dmg = (cible.dmg || joueur.st.degats) * (0.45 + (ar.tier - 1) * 0.03 + (ar.ench || 0) * 0.04);
  a.vieT = 30 + (ar.ench || 0) * 2;
  teinteSpectrale(a, '#b48aff', 0.45);
  UI.plaque(a, { nom, guilde: '30 s', classe: 'allie', vie: true, lettre: false });
  fumeeOmbre(pos); onde(pos, '#c9a0ff', 4, 0.6); son('forceField_000', 0.6, 0.5);
  // le reflet sort du corps de la cible
  emettre(V(cible.pos.x, 1.2, cible.pos.z), { n: 40, c1: '#ffffff', c2: '#7a3aff', vit: 5, vie: 0.6, taille: 0.4 });
  UI.nombre(V(cible.pos.x, (cible.hauteurPlaque || 2.5) + 0.4, cible.pos.z), 'Reflet volé', 'crit');
  volerPouvoir(cible, a);
}
// tant que le double vit, le joueur dispose d'un pouvoir de la cible copiée (à la place de Reflet volé)
function pouvoirDe(c) {
  if (c.combattant && c.equip) { const ids = sortsArme(c.equip.arme).filter(id => id !== 'legion' && id !== 'reflet'); return ids[ids.length - 1] || 'fente'; }
  const d = c.def || {};
  if (d.model === 'Dragon_Evolved') return 'meteore';
  if (d.type === 'ranged') return c.boss ? 'pluie' : 'perforant';
  if (d.type === 'caster') return c.boss ? 'meteore' : 'bouleFeu';
  return c.boss ? 'tempete' : 'charge';
}
function volerPouvoir(cible, double) {
  const id = pouvoirDe(cible); const s = SORTS[id]; if (!s) return;
  joueur.pouvoirVole = { double, finReflet: G.t + (joueur.cdMax.W || 40), sortReflet: joueur.sorts.W, cdMaxReflet: joueur.cdMax.W };
  joueur.sorts.W = { ...s, id, vole: true, nom: s.nom + ' (volé)' };
  joueur.cdMax.W = +(s.cd * (1 - joueur.st.recharge / 100)).toFixed(2); joueur.cds.W = 0;
  UI.construireSorts(joueur);
  UI.toast(`Pouvoir volé : ${s.nom} — tant que le double vit`, true);
  son('forceField_000', 0.6, 1.6); emettre(V(joueur.pos.x, 1.4, joueur.pos.z), { n: 50, c1: '#f0d0ff', c2: '#7a2aff', vit: 4, vie: 0.9, taille: 0.45, monte: 3 });
}
function rendrePouvoir() {
  const pv = joueur && joueur.pouvoirVole; if (!pv) return;
  joueur.sorts.W = pv.sortReflet; joueur.cdMax.W = pv.cdMaxReflet; joueur.cds.W = Math.max(0, pv.finReflet - G.t);
  joueur.pouvoirVole = null; UI.construireSorts(joueur);
  UI.toast('Le double s’efface : pouvoir volé perdu');
}
function majRefletMob(a, dt) {
  a.tc = cibleIA(a); a.atkT -= dt;
  const c = a.tc;
  if (a.attaqueT > 0) { a.attaqueT -= dt; return; }
  if (!c) {
    const dj = dist2D(a.pos, joueur.pos);
    if (dj > 16) { fumeeOmbre(a.pos); a.pos.copy(pointLibrePres(joueur.pos, 1.5, 3)); fumeeOmbre(a.pos); }
    else if (dj > 3) { avancerVers(a, joueur.pos, dt, Math.max(a.vitesse, vitesseJoueur()) * (dj > 6 ? 1.3 : 1.05)); a.jouer(a.armeDef.run); }
    else a.jouer(a.armeDef.idle);
    return;
  }
  const d = dist2D(a.pos, c.pos);
  if (d > a.portee + (c.rayon || 0.5)) { avancerVers(a, c.pos, dt, Math.max(a.vitesse, vitesseJoueur())); a.jouer(a.armeDef.run); return; }
  faceJoueur(a, dt, 10);
  if (a.atkT > 0) { a.jouer(a.armeDef.idle); return; }
  a.atkT = 1.15; a.attaqueT = 0.35;
  const distance = a.portee > 5;
  const anim = a.dragon ? (Math.random() < 0.5 ? 'Punch' : 'Headbutt') : distance ? 'Spellcast_Shoot' : (Math.random() < 0.5 ? '1H_Melee_Attack_Chop' : '2H_Melee_Attack_Chop');
  a.jouer(anim, { boucle: false, forcer: true, vitesse: 1.3, fin: () => a.jouer(a.armeDef.idle) });
  programmer(0.3, () => {
    if (a.mort || c.mort) return;
    if (distance) { const p = V(c.pos.x, 1.1, c.pos.z); for (let k = 0; k < 6; k++) { const t = k / 6; emettre(V(a.pos.x + (p.x - a.pos.x) * t, 1.2, a.pos.z + (p.z - a.pos.z) * t), { n: 2, c1: '#e0c8ff', c2: '#5a1aaa', vit: 1, vie: 0.3, taille: 0.3 }); } }
    else arcTaille(a.pos, a.angle - Math.PI / 2, 2.6, '#b07aff', Math.PI * 0.7, 0.22);
    infliger(a, c, a.dmg); son('knifeSlice', 0.35, 0.8);
  });
}
// une ombre qui meurt explose et blesse tout autour
function mortInvocation(a) {
  if (a.loup) { // le loup s'effondre, puis se dissipe en braises
    const i = allies.indexOf(a); if (i >= 0) allies.splice(i, 1);
    a.mort = true; a.rush = null; a.jouer('Death_A'); UI.retirerPlaque(a); if (loupChoisi === a) loupChoisi = null;
    UI.toast(`${a.nom} est tombé · relance l’Appel de la meute`); majSortMeute();
    ajouterVfx(new THREE.Group(), (t, dt) => { a.maj(dt); if (t > 1.6) { emettre(V(a.pos.x, 0.6, a.pos.z), { n: 30, c1: '#ffb08a', c2: '#3a0004', vit: 3, vie: 0.8, taille: 0.4, grav: -2 }); G.scene.remove(a.root); return false; } });
    return;
  }
  if (a.invoc === 'ombre') {
    onde(a.pos, '#9a5aff', 3.4, 0.45); emettre(V(a.pos.x, 1, a.pos.z), { n: 40, c1: '#e0c8ff', c2: '#2a0050', vit: 7, vie: 0.6, taille: 0.5 });
    toucherZone(a, a.pos, 3.2, a.dmg * 1.6, { slow: 1.5 }); son('explosionCrunch_000', 0.35, 1.4);
  }
  dissiper(a);
}
function dissiper(a) {
  if (joueur && joueur.pouvoirVole && joueur.pouvoirVole.double === a) rendrePouvoir();
  const i = allies.indexOf(a); if (i < 0) return;
  allies.splice(i, 1); a.mort = true;
  fumeeOmbre(a.pos); UI.retirerPlaque(a); G.scene.remove(a.root);
  if (joueur && joueur.cible === a) joueur.cible = null;
}

// accès de débogage (console)
