// ---- vie du monde : les joueurs de la Place ----
const PHRASES_RETOUR = ['coffre violet !!', 'le dragon m’a eu…', 'facile ce donjon', 'gg l’arène', '+100 trophées', 'mon île a bien produit', 'qui vend du T3 ?', 'enfin un légendaire'];
function destinationBot(b) {
  const r = Math.random();
  const devant = (p, d = 4.5) => { const v = p.clone().setY(0); return v.addScaledVector(v.clone().negate().normalize(), d); };
  const autour = (p, r0, r1) => { const a = rnd(0, 6.283), d = rnd(r0, r1); return p.clone().add(V(Math.cos(a) * d, 0, Math.sin(a) * d)); };
  const ecart = (p) => { const q = p.clone(); q.x += rnd(-2.6, 2.6); q.z += rnd(-2.6, 2.6); return q; };
  const occupe = (p) => bots.some(o => o !== b && o.but && dist2D(o.but.p, p) < 1.4);
  if (r < 0.12 && marchand) { let p, n = 0; do { p = autour(marchand.pos, 2.2, 4.2); } while ((occupe(p) || !libre(p.x, p.z, 0.6)) && ++n < 12); if (n < 12) return { type: 'marchand', p }; return null; }
  if (r < 0.26) return { type: 'portail', p: ecart(devant(monde.portail.pos)), porte: monde.portail.pos };
  if (r < 0.36 && monde.portailArene) return { type: 'portail', p: ecart(devant(monde.portailArene.pos)), porte: monde.portailArene.pos };
  if (r < 0.44 && monde.portailIle) return { type: 'portail', p: ecart(devant(monde.portailIle.pos, 2.5)), porte: monde.portailIle.pos };
  if (r < 0.5) { const a = rnd(0, 6.283); const p = V(Math.cos(a) * 3.6, 0, Math.sin(a) * 3.6); if (!occupe(p)) return { type: 'fontaine', p }; }
  return null;
}
function majVieBot(b, dt) {
  if (b.absentT > 0) { // dans un donjon, l'arène ou sur son île
    b.absentT -= dt;
    if (b.absentT <= 0) {
      b.mort = false; b.root.visible = true; b.pos.copy(pointLibrePres(b.retour, 2, 4)); effetPortail(b.pos, b.couleurPortail);
      b.jouer('Cheer', { boucle: false, fin: () => b.jouer('Idle') }); b.etat = 'idle'; b.timer = rnd(3, 6);
      if (Math.random() < 0.6) setTimeout(() => UI.chat(b.nom, hasard(PHRASES_RETOUR)), 1200);
    }
    return true;
  }
  if (b.etat === 'commerce') {
    b.timer -= dt; if (b.timer <= 0) { b.etat = 'idle'; b.timer = rnd(1, 3); b.jouer('Idle'); if (marchand) marchand.jouer('Idle'); }
    return false;
  }
  if (b.etat !== 'but') return false;
  const d = dist2D(b.pos, b.but.p);
  if (d < 1.0) {
    if (b.but.type === 'marchand') {
      b.etat = 'commerce'; b.timer = rnd(4, 8); b.jouer('Interact'); b.angle = Math.atan2(marchand.pos.x - b.pos.x, marchand.pos.z - b.pos.z); b.root.rotation.y = b.angle;
      marchand.jouer('Interact'); son('handleCoins', 0.15);
      if (Math.random() < 0.4) setTimeout(() => UI.chat(b.nom, hasard(['je revends mon butin', 'Borin t’as du bronze ?', 'combien la potion ?', 'vendu !'])), 800);
    } else if (b.but.type === 'portail') {
      b.mort = true; b.root.visible = false; b.absentT = rnd(45, 160); b.retour = b.but.porte;
      b.couleurPortail = b.but.porte === monde.portail.pos ? '#ff3a2a' : b.but.porte === monde.portailArene?.pos ? '#b05aff' : '#ffc84a';
      effetPortail(b.pos, b.couleurPortail);
    } else { b.etat = 'idle'; b.timer = rnd(6, 14); b.jouer('Sit_Floor_Idle'); }
    return true;
  }
  if (!coinceBot(b, d, dt)) { b.etat = 'idle'; b.timer = 1; b.but = null; b.jouer('Idle'); return true; }
  const dir = V(b.but.p.x - b.pos.x, 0, b.but.p.z - b.pos.z).normalize();
  const v = 4.6 * dt;
  if (!deplacer(b, dir.x * v, dir.z * v, 0.5)) { b.bloque = (b.bloque || 0) + dt; if (b.bloque > 2) { b.etat = 'idle'; b.timer = 1; b.bloque = 0; b.jouer('Idle'); } }
  b.angle = tourner(b.angle, Math.atan2(dir.x, dir.z), dt * 8); b.root.rotation.y = b.angle; b.jouer('Running_A');
  return true;
}
function effetPortail(p, c) { onde(p, c, 3, 0.6); emettre(V(p.x, 1, p.z), { n: 30, c1: '#ffffff', c2: c, dir: V(0, 1, 0), vit: 5, disp: 1.5, rayon: 0.8, vie: 0.8, taille: 0.35 }); }
function creerPasseur() {
  const a = new Acteur('Knight', { hauteur: 2.05 });
  const tous = Object.keys(a.nodes).filter(n => /Sword|Axe|Shield|Crossbow|Staff|Wand|Knife|Throwable|Mug|Spellbook|Offhand/.test(n));
  a.montrerSeul([], tous); a.attacher('tool_lantern', 'handslot.l', { echelle: 0.6 });
  const cape = Object.keys(a.nodes).find(n => n.endsWith('_Cape')); if (cape) a.teinter(cape, '#ffc84a', 0.7, 0.2);
  a.root.position.copy(monde.passeur.pos); a.root.rotation.y = monde.passeur.rot; a.pos = a.root.position; a.hauteurPlaque = 2.65;
  a.jouer('Idle'); G.scene.add(a.root);
  UI.plaque(a, { nom: 'Aldric', guilde: 'MAÎTRE DES ÎLES', classe: 'pnj', vie: false });
  monde.collisions.push({ x: a.pos.x, z: a.pos.z, r: 0.7 });
  passeur = a;
}



// ---------------- Émoticônes ----------------
let emoteHubT = 6, emoteJoueurT = 0;
const REPONSES = { salut: ['salut', 'merci'], gg: ['gg', 'merci'], mdr: ['mdr', 'clown'], ez: ['rage', 'toi', 'clown', 'mdr'], clown: ['clown', 'rage', 'mdr'], rip: ['mdr', 'ouin'],
  rage: ['mdr', 'clown', 'bof'], ouin: ['mdr', 'rip'], toi: ['diable', 'toi', 'malin'], bof: ['bof', 'malin'], feu: ['feu', 'mdr'], merci: ['merci', 'salut'],
  diable: ['diable', 'fuite', 'ez'], fuite: ['mdr', 'clown'], malin: ['malin', 'toi'], oups: ['mdr', 'oups'] };
function emoteBot(e, ids, chance = 1, delai = 0) {
  if (!e || Math.random() > chance) return;
  const go = () => { if (!e.mort || ids.includes('rip') || ids.includes('ouin') || ids.includes('rage')) UI.emote(e, hasard(ids), e.nom); };
  if (delai > 0) setTimeout(go, delai * 1000); else go();
}
function emoteJoueur(id) {
  if (!joueur || performance.now() < emoteJoueurT) return;
  emoteJoueurT = performance.now() + 1500;
  UI.emote(joueur, id, J.nom); son('select_001', 0.3, 1.3);
  const rep = REPONSES[id] || ['mdr'];
  // les autres « joueurs » réagissent
  const cands = !modeActuel ? bots.filter(b => !(b.absentT > 0) && dist2D(b.pos, joueur.pos) < 14) : [...ennemis.filter(e => e.combattant && !e.mort), ...allies.filter(a => !a.mort && !a.invoc && a.combattant)];
  cands.sort((a, b) => dist2D(a.pos, joueur.pos) - dist2D(b.pos, joueur.pos));
  cands.slice(0, 2).forEach((c, i) => emoteBot(c, rep, i ? 0.25 : (modeActuel ? 0.45 : 0.6), rnd(0.8, 1.9) + i));
}





// ---------------- Réflexes humains : on esquive… pas toujours ----------------
function reagit(e, z, dt) {
  if (e.invoc) return true;
  if (e.dangerVu !== z) { e.dangerVu = z; e.reflexeOK = Math.random() < (e.reflexe || (e.reflexe = rnd(0.55, 0.85))); e.reactionT = rnd(0.15, 0.55); }
  if (!e.reflexeOK) return false;
  e.reactionT -= dt; return e.reactionT <= 0;
}
// ---------------- Au Sanctuaire, chaque joueur du groupe joue sa partie ----------------
let objectifSylve = null, objectifSylveT = 0;
function majObjectifSylve(dt) {
  objectifSylveT -= dt; if (objectifSylveT > 0) return objectifSylve; objectifSylveT = 0.8;
  let best = null, bs = Infinity;
  for (const x of ennemis) { if (x.mort || x.invoque) continue; const s = monde.abscisse(x.pos.x, x.pos.z); if (s < bs) { bs = s; best = x; } }
  objectifSylve = best ? { e: best, s: bs, boss: !!best.boss } : null;
  return objectifSylve;
}
function esquiveExperte(e, dt, melee) {
  if (e.esquiveT > 0 || e.dashT > 0 || e.stunT > 0) return false;
  for (const p of projectiles) {
    if (p.camp === 'ennemi') continue;
    const rx = e.pos.x - p.pos.x, rz = e.pos.z - p.pos.z; const v = Math.hypot(p.vel.x, p.vel.z) || 1; const vx = p.vel.x / v, vz = p.vel.z / v;
    const along = rx * vx + rz * vz; if (along < 0 || along > 8) continue;
    const perp = rx * vz - rz * vx; if (Math.abs(perp) > 1.6) continue;
    if (!p.vus) p.vus = new Set(); if (p.vus.has(e)) continue; p.vus.add(e);
    if (Math.random() > e.skill * (e.rival && arene ? 0.97 : 0.8)) continue; // en arène, les cracks esquivent presque tout
    const s = perp >= 0 ? 1 : -1; return pasDeCote(e, vz * s, -vx * s, false);
  }
  if (joueur.debutAtk && G.t - joueur.debutAtk < 0.18 && dist2D(joueur.pos, e.pos) < 3.8 && e.dernierAtkVu !== joueur.debutAtk) {
    e.dernierAtkVu = joueur.debutAtk;
    if (Math.random() < e.skill * (e.rival && arene ? 0.8 : 0.45)) { const ar = V(e.pos.x - joueur.pos.x, 0, e.pos.z - joueur.pos.z).normalize(); return pasDeCote(e, ar.x, ar.z, true); }
  }
  return false;
}
function pasDeCote(e, dx, dz, arriere) {
  e.dashT = 0.26; e.dashV = V(dx, 0, dz).multiplyScalar(16); e.esquiveT = rnd(1.6, 3) * (1.7 - e.skill);
  e.jouer(arriere ? 'Dodge_Backward' : 'Dodge_Forward', { boucle: false, forcer: true, vitesse: 1.6, fin: () => e.jouer(e.armeDef.idle) });
  if (!arriere) { e.angle = Math.atan2(dx, dz); e.root.rotation.y = e.angle; }
  emettre(V(e.pos.x, 0.3, e.pos.z), { n: 10, c1: '#d0f0ff', c2: '#6aa0c0', vit: 3, vie: 0.4, taille: 0.35 });
  if (Math.random() < 0.15) emoteBot(e, ['malin', 'bof', 'mdr'], 1, 0.3);
  return true;
}
function choisirProie(e, filtre) {
  // un vrai joueur ne va pas taper le même monstre que toi : il part de son côté
  let best = null, bs = Infinity;
  for (const x of ennemis) {
    if (x.mort || x.etat === 'dormant' || x.rival || !filtre(x)) continue;
    let s = dist2D(x.pos, e.pos);
    if (dist2D(x.pos, joueur.pos) < 9) s += 14;
    s += 8 * allies.filter(a => a !== e && a.proie === x).length;
    if (s < bs) { bs = s; best = x; }
  }
  return best;
}
const PAROLES = {
  bavard: ['vous avez vu le patch ?', 'qqn a drop un truc ?', 'j’ai faim', 'ce donjon est trop beau', 'mon chat marche sur le clavier', 'on fait l’arène après ?', 'gg les gars', 'quelqu’un a un T5 à vendre ?'],
  toxique: ['ez', 'vous êtes nuls', 'je carry', 'même pas mal', 'lol', 'vous suivez ou quoi', 'trop lent'],
  tranquille: ['brb 2 min', 'je reviens', 'attendez-moi', 'doucement'],
  protecteur: ['je te couvre', 'reste derrière moi', 'je prends le gros'],
  prudent: ['attention aux zones', 'on y va doucement', 'je reste derrière'],
  fonceur: ['go go go', 'on pull', 'plus vite'],
};
function appliquerTrait(a, t) { const T = TRAITS[t] || TRAITS.bavard; a.trait = t; a.reflexe = T.reflexe; a.vitTrait = T.vit; a.parlerT = rnd(8, 20); a.chaosT = rnd(3, 6); a.afkT = rnd(40, 80); }
function traitVivant(e, dt) {
  // ce qui donne sa personnalité au joueur, quel que soit le donjon
  e.parlerT -= dt;
  if (e.parlerT <= 0) { const t = e.trait; e.parlerT = t === 'bavard' ? rnd(10, 20) : t === 'toxique' ? rnd(12, 22) : rnd(35, 70); if (PAROLES[t] && Math.random() < 0.7) UI.chat(e.nom, hasard(PAROLES[t])); else emoteBot(e, t === 'toxique' ? ['clown', 'ez', 'mdr', 'toi'] : ['feu', 'salut', 'malin', 'bof'], 1); }
  if (e.trait === 'toxique') {
    e.chaosT -= dt;
    if (e.chaosT <= 0) { e.chaosT = rnd(3, 7); const a = rnd(0, 6.28); e.dashT = 0.3; e.dashV = V(Math.sin(a), 0, Math.cos(a)).multiplyScalar(15); e.jouer('Dodge_Forward', { boucle: false, forcer: true, vitesse: 1.5, fin: () => e.jouer(e.armeDef.idle) }); if (Math.random() < 0.4) emoteBot(e, ['clown', 'mdr', 'ez'], 1); return true; }
    if (Math.random() < dt * 0.25) { e.tourneT = rnd(1.5, 3); }
    if (e.tourneT > 0) { e.tourneT -= dt; const a = G.t * 3; allerVers(e, V(e.pos.x + Math.sin(a) * 3, 0, e.pos.z + Math.cos(a) * 3), dt, e.st.vitesse); e.jouer(e.armeDef.run); return true; }
  }
  if (e.trait === 'tranquille') {
    e.afkT -= dt;
    if (e.afkT <= 0 && !e.afk) { e.afk = rnd(6, 11); UI.chat(e.nom, hasard(['brb', 'afk 1 min', 'je reviens'])); }
    if (e.afk > 0) { e.afk -= dt; e.jouer('Sit_Floor_Idle' in e.actions ? 'Sit_Floor_Idle' : e.armeDef.idle); if (e.afk <= 0) { e.afk = 0; e.afkT = rnd(50, 90); UI.chat(e.nom, hasard(['re', 'je suis là', 'dsl'])); } return true; }
  }
  return false;
}
function allerLooter(e, dt) {
  const c = e.lootCible; if (!c) return false;
  if (c.lootePar && c.lootePar.has(e)) { e.lootCible = null; return false; }
  if (dist2D(e.pos, c.pos) > 2.4) { allerVers(e, c.pos, dt, e.st.vitesse); e.jouer(e.armeDef.run); return true; }
  if (!e.fouilleT) { e.fouilleT = 1.6; e.jouer('Interact' in e.actions ? 'Interact' : 'PickUp', { boucle: false, forcer: true }); son('creak1', 0.35, 1.2); }
  e.fouilleT -= dt;
  if (e.fouilleT <= 0) {
    e.fouilleT = 0; (c.lootePar = c.lootePar || new Set()).add(e); e.lootCible = null;
    emettre(V(c.pos.x, 1.2, c.pos.z), { n: 30, c1: '#fff2c0', c2: c.def.color, vit: 4, vie: 0.8, taille: 0.35, monte: 3 });
    UI.toast(`${e.nom} a récupéré sa part du ${c.def.nom.toLowerCase()}`);
    if (Math.random() < 0.5) UI.chat(e.nom, hasard(['loot !', 'merci le boss', 'pas ouf', 'ENFIN un drop', 'encore des os…', 'bof']));
    else emoteBot(e, ['feu', 'malin', 'merci', 'bof'], 1);
    e.jouer(e.armeDef.idle);
  }
  return true;
}
function autonomieSylve(e, dt) {
  if (allerLooter(e, dt)) return;
  if (e.decal === undefined) Object.assign(e, { decal: rnd(-3.2, 3.2), attenteT: 0, proieT: 0 });
  if (traitVivant(e, dt)) return;
  const T = TRAITS[e.trait] || TRAITS.bavard;
  const se = monde.abscisse(e.pos.x, e.pos.z);
  const k = monde.salles.findIndex((s, i) => ennemis.some(b => b.boss && b.idxSylve === i && !b.mort && b.etat === 'dormant'));
  const limite = k >= 0 ? monde.salleS[k] - monde.salles[k].r - 3 : monde.longueur;
  e.proieT -= dt;
  if (e.proieT <= 0 || !e.proie || e.proie.mort) {
    e.proieT = rnd(1.5, 3);
    if (e.trait === 'protecteur') { const l = ennemis.filter(x => !x.mort && x.etat === 'chasse' && x.tc === joueur); e.proie = l.length ? l[0] : choisirProie(e, x => dist2D(x.pos, joueur.pos) < 18 && (!x.boss || x.etat === 'chasse')); }
    else e.proie = choisirProie(e, x => { const s = monde.abscisse(x.pos.x, x.pos.z); return s > se - 12 && s < Math.min(limite + 6, se + (e.trait === 'tranquille' ? 30 : 70)) && (!x.boss || x.etat === 'chasse'); });
  }
  const vit = e.st.vitesse * (e.vitTrait || 1);
  if (e.proie) { allerVers(e, e.proie.pos, dt, vit); e.jouer(e.armeDef.run); e.attenteT = 0; return; }
  const sj = monde.abscisse(joueur.pos.x, joueur.pos.z);
  let s = e.trait === 'protecteur' ? sj - 3 : Math.min(limite + (e.trait === 'fonceur' ? 1 : -2), Math.max(se, sj) + 10 + T.avance);
  if (e.trait === 'tranquille') s = Math.min(s, se + 6);
  const c = monde.pointA(s); const dest = V(c.p.x - c.dir.z * e.decal, 0, c.p.z + c.dir.x * e.decal);
  if (dist2D(e.pos, dest) > 1.8) { allerVers(e, dest, dt, vit * 0.9); e.jouer(e.armeDef.run); return; }
  e.jouer(e.armeDef.idle);
  if (k >= 0 && s >= limite - 3) {
    e.attenteT += dt;
    if (e.trait === 'fonceur' && e.attenteT > 20) {
      if (!e.annonce) { e.annonce = true; UI.chat(e.nom, hasard(['on pull ?', 'je lance le boss', 'go go go', 'bon j’y vais'])); emoteBot(e, ['diable', 'feu'], 0.6); }
      const b = ennemis.find(x => x.boss && x.idxSylve === k && !x.mort); if (b && e.attenteT > 24) { allerVers(e, b.pos, dt, vit); e.jouer(e.armeDef.run); }
    } else if (e.attenteT > 12 && !e.relance && dist2D(joueur.pos, e.pos) > 25) { e.relance = true; UI.chat(e.nom, hasard([`${J.nom} tu viens ?`, 'on attend qui là', 'afk ?'])); }
  } else { e.attenteT = 0; e.annonce = false; e.relance = false; }
}

// ---------------- Visée des sorts (doigt appuyé) ----------------
let visee = null, viseeForcee = null, viseeObj = null;
function cibleDansDirection(dir, portee) {
  let best = null, bs = Infinity;
  for (const e of vivants()) {
    const dx = e.pos.x - joueur.pos.x, dz = e.pos.z - joueur.pos.z, d = Math.hypot(dx, dz);
    if (d > portee + 2 + (e.rayon || 0) || d < 0.3) continue;
    const cos = (dx * dir.x + dz * dir.z) / d; if (cos < 0.8) continue;
    const score = (1 - cos) * 30 + d * 0.15; if (score < bs) { bs = score; best = e; }
  }
  return best;
}
function majVisee() {
  if (!visee) return;
  if (!viseeObj) {
    const g = new THREE.Group();
    const mat = new THREE.MeshBasicMaterial({ color: '#ffffff', transparent: true, opacity: 0.22, blending: THREE.AdditiveBlending, depthWrite: false });
    const cercle = new THREE.Mesh(new THREE.RingGeometry(0.965, 1, 96), mat); cercle.rotation.x = -Math.PI / 2;
    const fond = new THREE.Mesh(new THREE.CircleGeometry(1, 64), new THREE.MeshBasicMaterial({ color: '#bfe0ff', transparent: true, opacity: 0.05, blending: THREE.AdditiveBlending, depthWrite: false })); fond.rotation.x = -Math.PI / 2;
    const fleche = new THREE.Mesh(new THREE.PlaneGeometry(0.5, 1).translate(0, 0.5, 0), new THREE.MeshBasicMaterial({ color: '#ffffff', transparent: true, opacity: 0.35, blending: THREE.AdditiveBlending, depthWrite: false })); fleche.rotation.x = -Math.PI / 2;
    const marque = new THREE.Mesh(new THREE.RingGeometry(0.8, 1.05, 40), new THREE.MeshBasicMaterial({ color: '#ffd27a', transparent: true, opacity: 0.85, blending: THREE.AdditiveBlending, depthWrite: false })); marque.rotation.x = -Math.PI / 2;
    g.add(fond, cercle); G.scene.add(g, fleche, marque);
    viseeObj = { g, fleche, marque };
  }
  const { g, fleche, marque } = viseeObj; const p = visee.s.portee;
  g.visible = true; g.position.set(joueur.pos.x, 0.1, joueur.pos.z); g.scale.set(p, 1, p);
  fleche.visible = !!visee.dir;
  if (visee.dir) {
    const cible = visee.cible; const l = cible ? Math.min(p, dist2D(cible.pos, joueur.pos)) : p;
    const ang = cible ? Math.atan2(cible.pos.x - joueur.pos.x, cible.pos.z - joueur.pos.z) : Math.atan2(visee.dir.x, visee.dir.z);
    fleche.position.set(joueur.pos.x, 0.12, joueur.pos.z); fleche.scale.set(1, l, 1); fleche.rotation.z = ang + Math.PI;
  }
  marque.visible = !!visee.cible;
  if (visee.cible) { const c = visee.cible; const r = (c.rayon || 0.5) + 0.6; marque.position.set(c.pos.x, 0.13, c.pos.z); marque.scale.set(r, r, 1); marque.rotation.z = G.t * 2; }
}
function cacherVisee() { if (viseeObj) { viseeObj.g.visible = false; viseeObj.fleche.visible = false; viseeObj.marque.visible = false; } }

// ---------------- Chemins dans le donjon (grille) ----------------
function cheminGrille(a, b) {
  const W = monde.grilleW, H = monde.grilleH, g = monde.grille, C = monde.grilleC || 4, OX = monde.grilleX0 || 0, OZ = monde.grilleZ0 || 0;
  const ax = Math.floor((a.x - OX) / C), az = Math.floor((a.z - OZ) / C), bx = Math.floor((b.x - OX) / C), bz = Math.floor((b.z - OZ) / C);
  if (bx < 0 || bz < 0 || bx >= W || bz >= H || !g[bz * W + bx]) return null;
  if (!cheminGrille.prec || cheminGrille.prec.length !== W * H) { cheminGrille.prec = new Int32Array(W * H); cheminGrille.file = new Int32Array(W * H); }
  if (ax < 0 || az < 0 || ax >= W || az >= H) return null;
  const prec = cheminGrille.prec, file = cheminGrille.file; prec.fill(-1);
  let n = 0; file[n++] = az * W + ax; prec[az * W + ax] = az * W + ax;
  const but = bz * W + bx; let i = 0;
  while (i < n) {
    const c = file[i++]; if (c === but) break;
    const cx = c % W, cz = (c / W) | 0;
    for (const [dx, dz] of [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]) {
      const nx = cx + dx, nz = cz + dz; if (nx < 0 || nz < 0 || nx >= W || nz >= H) continue;
      const k = nz * W + nx; if (prec[k] >= 0 || !g[k]) continue;
      if (dx && dz && (!g[cz * W + nx] || !g[nz * W + cx])) continue;
      prec[k] = c; file[n++] = k;
    }
  }
  if (prec[but] < 0) return null;
  const pts = []; for (let c = but; c !== prec[c]; c = prec[c]) pts.push(V(OX + (c % W) * C + C / 2, 0, OZ + ((c / W) | 0) * C + C / 2));
  return pts.reverse();
}
// va vers une destination en contournant les murs du donjon
function ligneLibre(a, b) {
  const d = dist2D(a, b), n = Math.ceil(d / 1.5);
  for (let i = 1; i < n; i++) { const t = i / n; if (!libre(a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t, 0.45)) return false; }
  return true;
}
function allerVers(e, dest, dt, vitesse) {
  if (monde.type === 'sylve') {
    e._lv = e._lv || { t: 0, ok: true };
    e._lv.t -= dt; if (e._lv.t <= 0) { e._lv.t = 0.4; e._lv.ok = dist2D(e.pos, dest) < 3 || ligneLibre(e.pos, dest); }
    if (e._lv.ok) { avancerVers(e, dest, dt, vitesse); return; }
    const se = monde.abscisse(e.pos.x, e.pos.z), sd = monde.abscisse(dest.x, dest.z);
    const w = monde.pointA(se + Math.sign(sd - se) * Math.min(5, Math.abs(sd - se)));
    avancerVers(e, w.p, dt, vitesse); return;
  }
  if (!monde.grille || dist2D(e.pos, dest) < 7 && ((e !== joueur && monde.type !== 'goulet') || ligneLibre(e.pos, dest))) { avancerVers(e, dest, dt, vitesse); return; }
  const ch = e.chemin;
  if (!ch || ch.t <= 0 || dist2D(ch.dest, dest) > 4) { e.chemin = { pts: cheminGrille(e.pos, dest) || [], i: 0, dest: dest.clone(), t: 1.5 }; }
  e.chemin.t -= dt;
  const pts = e.chemin.pts; while (e.chemin.i < pts.length && dist2D(pts[e.chemin.i], e.pos) < 1.6) e.chemin.i++;
  avancerVers(e, e.chemin.i < pts.length ? pts[e.chemin.i] : dest, dt, vitesse);
}
// ---------------- Le coéquipier fait sa vie ----------------
const PHRASES_EXPLO = ['je vais clean à côté', 'je prends la salle là-bas', 'rejoins-moi', 'je check à gauche', 'y a du monde par ici', 'suis-moi'];
function autonomieAllie(e, dt, dj) {
  if (allerLooter(e, dt)) return true;
  if (traitVivant(e, dt)) return true;
  // il vient t'aider s'il te voit en difficulté ou en plein combat pas trop loin
  const c = joueur.cible && !joueur.cible.mort ? joueur.cible : null;
  if (c && dj < 32 && (joueur.pv < joueur.st.pvMax * 0.5 || (G.enCombat && (c.boss || dj < 20)))) {
    if (e.modeA !== 'aider') { e.modeA = 'aider'; if (Math.random() < 0.5) UI.chat(e.nom, hasard(['j’arrive !', 'tiens bon', 'je t’aide', 'focus le gros', 'heal toi je tank'])); }
    allerVers(e, c.pos, dt, e.st.vitesse * 1.05 * (e.vitTrait || 1)); e.jouer(e.armeDef.run); return true;
  }
  if (e.modeA === 'aider') e.modeA = 'explorer';
  // il chasse ses propres monstres (pas ceux que tu tapes)
  if (!e.objectif || e.objectif.mort || (e.objectif.etat === 'chasse' && dist2D(e.objectif.pos, e.pos) > 30)) {
    e.objectif = choisirProie(e, x => !x.boss || dist2D(x.pos, joueur.pos) < 20);
    if (e.objectif && Math.random() < 0.15) UI.chat(e.nom, hasard(PHRASES_EXPLO));
  }
  if (e.objectif) { allerVers(e, e.objectif.pos, dt, e.st.vitesse * 0.95 * (e.vitTrait || 1)); e.jouer(e.armeDef.run); return true; }
  // plus rien à chasser : il se balade, fouille les coins, s'arrête de temps en temps
  e.baladeT = (e.baladeT || 0) - dt;
  if (!e.balade || e.baladeT <= 0 || dist2D(e.pos, e.balade) < 1.2) {
    if (e.balade && dist2D(e.pos, e.balade) < 1.2 && !e.pause) { e.pause = rnd(1.5, 5); }
    if (e.pause > 0) { e.pause -= dt; e.jouer(e.armeDef.idle); if (e.pause > 0) return true; }
    e.pause = 0; e.baladeT = rnd(8, 16);
    let p = null; for (let n = 0; n < 10 && !p; n++) { const q = pointLibrePres(Math.random() < 0.3 ? joueur.pos : e.pos, 6, 22); if (!monde.marche || monde.marche(q.x, q.z)) p = q; }
    e.balade = p || pointLibrePres(e.pos, 2, 6);
  }
  allerVers(e, e.balade, dt, e.st.vitesse * 0.8); e.jouer(e.armeDef.run);
  return true;
}
function reactionApresBoss(a) {
  if (a.perso === 'solo' && !a.parti && Math.random() < 0.7) { a.parti = true; setTimeout(() => partirAllie(a), rnd(2500, 5000)); return; }
  if (a.perso === 'traitre' && !a.trahi && bossVaincus >= 1 && Math.random() < 0.65) { a.trahi = true; setTimeout(() => trahir(a), rnd(4000, 9000)); return; }
  emoteBot(a, ['gg', 'feu', 'merci', 'ez'], 0.6, 1);
}
function partirAllie(a) {
  if (a.mort || !allies.includes(a)) return;
  emoteBot(a, ['gg', 'merci', 'salut'], 1);
  UI.chat(a.nom, hasard(['bon je dois y aller, gg', 'gg je déco', 'je rentre, bonne chance', 'j’ai ce qu’il me faut, bye', 'ma mère m’appelle dsl']));
  setTimeout(() => {
    if (!allies.includes(a)) return;
    effetArrivee(a.pos.clone()); fumeeOmbre(a.pos);
    allies.splice(allies.indexOf(a), 1); UI.retirerPlaque(a); G.scene.remove(a.root);
    if (groupe && groupe.nom === a.nom) groupe = null;
    UI.toast(`${a.nom} a quitté le donjon et ton groupe`);
  }, 2200);
}
function trahir(a) {
  if (a.mort || !allies.includes(a) || joueur.mort || !modeActuel || modeActuel.sylve) return;
  UI.chat(a.nom, hasard(['dsl, rien de perso', 'ton stuff me plaît trop', 'gg… pour moi', 'merci pour le carry 😈', 'surprise']));
  emoteBot(a, ['diable', 'toi', 'malin'], 1);
  setTimeout(() => {
    if (a.mort || !allies.includes(a)) return;
    allies.splice(allies.indexOf(a), 1); ennemis.push(a);
    Object.assign(a, { camp: 'ennemi', rival: true, autonome: false, potions: 2, tc: joueur, specT: 1, chasseur: true });
    UI.retirerPlaque(a); UI.plaque(a, { nom: a.nom, guilde: a.guilde, classe: 'rival joueur', ip: a.ip, niv: a.data && a.data.niv, vie: true });
    if (groupe && groupe.nom === a.nom) groupe = null;
    invasion = invasion && !invasion.fini ? invasion : { mode: 'subie', t: 0, rival: null, rivaux: [] };
    invasion.rivaux = [...(invasion.rivaux || []), a]; invasion.rival = invasion.rival && !invasion.rival.mort ? invasion.rival : a; invasion.revealT = 10; invasion.revele = 0;
    UI.flashInvasion(); son('lowFrequency_explosion_000', 0.8, 0.7); G.shake = 0.6;
    UI.toast('TRAHISON !', true); UI.toast(`${a.nom} se retourne contre toi : s’il te tue, il prend tout ton équipement`);
    UI.journal('Trahison !', `${a.nom} veut ton équipement. Tue-le ou perds tout.`, null);
  }, 1600);
}
function rivauxVivants() { return invasion && invasion.rivaux ? invasion.rivaux.filter(r => !r.mort) : invasion && invasion.rival && !invasion.rival.mort ? [invasion.rival] : []; }
function alerteInvasion(n, subie) {
  UI.alerteInvasion(n, subie);
  son('lowFrequency_explosion_000', 0.9, 0.55); G.shake = 0.7;
  // la lumière du donjon vire au rouge quelques secondes
  const h0 = G.hemi.color.clone(), s0 = G.sun.color.clone();
  ajouterVfx(new THREE.Group(), (t) => { const k = Math.max(0, Math.sin(Math.min(1, t / 3) * Math.PI)); G.hemi.color.copy(h0).lerp(new THREE.Color('#ff1a1a'), k * 0.85); G.sun.color.copy(s0).lerp(new THREE.Color('#ff3a2a'), k * 0.8); if (t > 3) { G.hemi.color.copy(h0); G.sun.color.copy(s0); return false; } });
}

