// ---------------- Refaire ----------------
function memoriserMode(nom, fn) { G.dernier = { nom, fn }; UI.boutonRefaire(null); }
function proposerRefaire(duree = 0) {
  if (!G.dernier) return;
  const d = G.dernier;
  UI.boutonRefaire(d.nom, () => {
    if (transition) return;
    UI.boutonRefaire(null);
    if (modeActuel) bilanGroupe();
    d.fn();
  }, duree);
}
function bilanGroupe() {
  if (groupe && modeActuel && (modeActuel.mode !== undefined || MODES.includes(modeActuel))) {
    if (groupe.fort) { J.rushs = (J.rushs || 0) + 1; sauver(); }
    groupe.donjonsRestants = (groupe.donjonsRestants ?? 2) - 1;
    if (groupe.donjonsRestants <= 0) { const n = groupe.nom; groupe = null; setTimeout(() => UI.chat(n, hasard(['gg, je dois y aller', 'bon je déco, gg', 'merci pour les runs', 'bye'])), 1500); }
  }
}

// ======================= DONJON VIVANT : scènes de vie, rondes, morale, repaires des boss, crypte et reliques =======================
let scenes = [], crypteEtat = null;
const PAISIBLES = ['scene', 'alerte', 'fuite', 'terre', 'dormant', 'idle', 'eveil', 'peur'];
const _decks = {};
// réplique tirée au hasard sans jamais répéter la précédente
function replique(cat) {
  const src = REPLIQUES[cat]; if (!src || !src.length) return '';
  let d = _decks[cat];
  if (!d || !d.length) { d = _decks[cat] = [...src].sort(() => Math.random() - 0.5); if (d.length > 1 && d[d.length - 1] === _decks['_' + cat]) d.unshift(d.pop()); }
  const l = d.pop(); _decks['_' + cat] = l; return l;
}
function faceVers(e, p, dt, k = 8) { e.angle = tourner(e.angle, Math.atan2(p.x - e.pos.x, p.z - e.pos.z), dt * k); e.root.rotation.y = e.angle; }
function peuplerDonjon(types) {
  scenes = [];
  const tierM = modeActuel.mobTier;
  const S = (type, centre, extra = {}) => { const sc = { type, centre, membres: [], etat: 'calme', t: 0, bavardT: rnd(2, 7), ...extra }; scenes.push(sc); return sc; };
  const mob = (cle, p, sc, act, angle) => {
    const e = creerEnnemi(MOBS[cle], p, tierM, 500 + scenes.length);
    e.root.position.copy(p); e.scene = sc; e.activite = act; e.etat = 'scene'; sc.membres.push(e);
    if (angle !== undefined) { e.angle = angle; e.root.rotation.y = angle; }
    e.jouer(act === 'assis' ? 'Sit_Floor_Idle' : 'Idle', { vitesse: rnd(0.85, 1.1) });
    return e;
  };
  const autour = (sc, n, R, a0 = 0.4) => Array.from({ length: n }, (_, i) => { const a = a0 + i / n * 6.283; return V(sc.centre.x + Math.cos(a) * R, 0, sc.centre.z + Math.sin(a) * R); });
  for (const s of monde.noeuds) {
    const d0 = s.scene; if (!d0) continue;
    const sc = S(d0.type, d0.centre.clone(), { salle: s.id, orbe: d0.orbe });
    if (sc.type === 'tablee' || sc.type === 'feu') {
      const n = Math.random() < 0.5 ? 4 : 3;
      autour(sc, 4, sc.type === 'feu' ? 2.5 : 1.85).slice(0, n).forEach(p => mob(hasard(['cultiste', 'cultiste', 'brute', 'pretresse']), p, sc, 'assis', Math.atan2(sc.centre.x - p.x, sc.centre.z - p.z)));
    } else if (sc.type === 'rituel') autour(sc, 3, 3.2, 0).forEach(p => mob('mage', p, sc, 'rituel', Math.atan2(sc.centre.x - p.x, sc.centre.z - p.z)));
    else autour(sc, 3, 1.6, 0.3).forEach(p => mob(hasard(types), p, sc, 'debout', Math.atan2(sc.centre.x - p.x, sc.centre.z - p.z)));
    // deux gardes postés à une entrée, tournés vers le couloir
    if (s.entrees && s.entrees.length) {
      const en = hasard(s.entrees); const g = S('garde', en.p.clone(), { salle: s.id }); const perp = V(-en.dir.z, 0, en.dir.x);
      for (const k of [-1, 1]) mob(hasard(['guerrier', 'guerrier', 'minion']), en.p.clone().addScaledVector(perp, k * 3), g, 'garde', Math.atan2(en.dir.x, en.dir.z));
    }
    // un tireur posté sur la mezzanine
    if (s.mezz) { const g = S('garde', s.mezz.pos.clone(), { salle: s.id }); mob('archer', s.mezz.pos.clone(), g, 'garde', Math.PI * 0.8); }
  }
  // rondes de 1 à 3 sentinelles entre les salles
  for (const r of monde.rondes) {
    const sc = S('ronde', r.pts[0].clone(), { pts: r.pts, i: 1, sens: 1, pause: rnd(0, 2) });
    const n = 1 + Math.floor(Math.random() * 3);
    for (let k = 0; k < n; k++) mob(hasard(['guerrier', 'minion', 'minion', 'archer']), r.pts[0].clone().add(V(rnd(-1.2, 1.2), 0, rnd(-1.2, 1.2))), sc, 'ronde');
  }
}
function voitJoueur(e) {
  if (joueur.mort || joueur.furtifT > 0) return false;
  if (e.pv < e.pvMax) return true;
  for (const a of allies) if (!a.mort && !a.invoc && dist2D(a.pos, e.pos) < 7) return true;
  const d = dist2D(e.pos, joueur.pos);
  const portee = e.activite === 'assis' ? 10 : e.activite === 'garde' ? 15 : 13;
  if (d > portee) return false;
  if ((e.activite === 'ronde' || e.activite === 'garde') && d > 5.5) { let r = Math.atan2(joueur.pos.x - e.pos.x, joueur.pos.z - e.pos.z) - e.angle; r = Math.atan2(Math.sin(r), Math.cos(r)); if (Math.abs(r) > 1.25) return false; }
  return ligneLibre(e.pos, joueur.pos);
}
function declencherAlerte(sc, rapide = false) {
  if (sc.etat !== 'calme') return;
  const v = sc.membres.filter(e => !e.mort && (e.etat === 'scene')); if (!v.length) { sc.etat = 'combat'; return; }
  sc.etat = 'alerte'; sc.t = rapide ? 0.6 : 1.6;
  const parleur = v.reduce((b, e) => dist2D(e.pos, joueur.pos) < dist2D(b.pos, joueur.pos) ? e : b);
  const faible = J.dissimule && Math.random() < 0.6;
  if (!rapide || Math.random() < 0.5) UI.parole(parleur, replique(faible ? 'moquerie' : (REPLIQUES['intrus_' + sc.type] && Math.random() < 0.7 ? 'intrus_' + sc.type : 'intrus')), 'menace');
  son('metalLatch', 0.5, 0.7);
  for (const e of v) {
    e.etat = 'alerte'; e.regard = joueur.pos;
    e.jouer(e.activite === 'assis' ? 'Idle' : 'Idle_Combat', { fondu: 0.35 });
    UI.nombre(V(e.pos.x, e.hauteurPlaque + 0.4, e.pos.z), '!', 'crit');
  }
  // les scènes voisines entendent le vacarme
  for (const o of scenes) if (o !== sc && o.etat === 'calme' && o.type !== 'ronde' && dist2D(o.centre, sc.centre) < 15) declencherAlerte(o, true);
}
function moraleScene(sc) {
  const P = puissanceReelleJoueur();
  let fuiteDite = false, loyalDit = false;
  for (const e of sc.membres) {
    if (e.mort || e.etat !== 'alerte') continue;
    // ils n'ont peur que si ta puissance dépasse la leur de plus de 500
    const ecart = ipReel() - puissanceMob(e);
    let peur = ecart > 500 ? Math.min(0.85, 0.5 + (ecart - 500) / 1200) : 0;
    if (J.dissimule) peur = 0; // ta force est cachée : ils ne la sentent pas
    if (joueur.eveilT > 0) peur = Math.min(0.92, peur * 1.6 + 0.3);
    const loyal = Math.random() < (sc.type === 'garde' || sc.type === 'rituel' ? 0.5 : 0.3);
    if (!loyal && Math.random() < peur) { fuirEnnemi(e, !fuiteDite); fuiteDite = true; continue; }
    e.etat = 'chasse'; e.regard = null;
    if (loyal && peur > 0) { e.loyal = true; e.dmg *= 1.2; if (!loyalDit) { UI.parole(e, replique('loyal'), 'menace'); loyalDit = true; } emettre(V(e.pos.x, 1.2, e.pos.z), { n: 16, c1: '#ffd27a', c2: '#ff3a2a', vit: 2.5, vie: 0.6, taille: 0.35 }); }
  }
}
function lacherArme(e, fort = false) {
  const m = e.armeMesh; if (!m || !m.parent || !monde.groupe) return;
  if (fort) { son('impactMetal_medium_001', 0.55, 0.8); }
  m.updateWorldMatrix(true, false); const mw = m.matrixWorld.clone(); m.removeFromParent(); monde.groupe.add(m); mw.decompose(m.position, m.quaternion, m.scale);
  for (const n of ['Knife_Offhand', '1H_Axe_Offhand']) if (e.nodes[n] && e.nodes[n].visible && e.nodes[n] !== m) e.nodes[n].visible = false;
  const y0 = solY(m.position.x, m.position.z) + 0.12, q0 = m.quaternion.clone(), q1 = new THREE.Quaternion().setFromEuler(new THREE.Euler(Math.PI / 2, rnd(0, 6), 0)), x0 = m.position.y;
  G.anims.push((t, dt) => { if (m.userData.posee) return; m.userData.k = Math.min(1, (m.userData.k || 0) + dt / 0.55); const k = m.userData.k; m.position.y = x0 + (y0 - x0) * k * k + Math.sin(Math.min(1, k * 1.2) * Math.PI) * 0.35 * (1 - k) + (k > 0.85 ? Math.sin((k - 0.85) / 0.15 * Math.PI) * 0.12 : 0); m.quaternion.slerpQuaternions(q0, q1, k); if (k >= 1) { m.userData.posee = true; son('impactMetal_medium_001', 0.3, 1.3); emettre(V(m.position.x, 0.2, m.position.z), { n: 6, c1: '#d8c8a8', c2: '#6a5a4a', vit: 2, vie: 0.4, taille: 0.25 }); } });
}
// puissance d'un monstre, sur la même échelle que la tienne
function puissanceMob(e) { return e.combattant ? (e.ip || 300) : Math.round(100 + (e.tierMob || 1) * 140 * (e.boss ? 1.25 : 1)); }
let fuiteCineT = -99;
function fuirEnnemi(e, parle) {
  // la première fuite d'une scène est mise en scène : ralenti, caméra sur lui, il tremble, son arme tombe, il s'enfuit
  if (G.t - fuiteCineT > 20 && !sceneOmbre && !G.camCible && dist2D(e.pos, joueur.pos) < 22) {
    fuiteCineT = G.t; e.etat = 'peur'; e.peurT = 1.5; e.regard = joueur.pos; e.fuiteParle = parle;
    e.angle = Math.atan2(joueur.pos.x - e.pos.x, joueur.pos.z - e.pos.z); e.root.rotation.y = e.angle;
    e.jouer('Hit_A', { boucle: false, forcer: true, vitesse: 0.7 });
    ralenti(1.1, 0.4); G.camCible = V(e.pos.x * 0.6 + joueur.pos.x * 0.4, 0, e.pos.z * 0.6 + joueur.pos.z * 0.4); e._camAvant = G.camDist; G.camDist = Math.max(14, G.camDist * 0.7);
    UI.parole(e, replique('fuite'), 'peur'); UI.nombre(V(e.pos.x, e.hauteurPlaque + 0.5, e.pos.z), '!!', 'crit');
    emettre(V(e.pos.x, 1.6, e.pos.z), { n: 14, c1: '#ffffff', c2: '#9ad8ff', vit: 1.6, vie: 0.8, taille: 0.3, grav: 2 }); // sueur froide
    programmer(0.55, () => { if (!e.mort) lacherArme(e, true); });
    return;
  }
  e.etat = 'fuite'; e.regard = null; e.fuiteT = 7;
  if (parle) UI.parole(e, replique('fuite'), 'peur');
  lacherArme(e);
  const d = V(e.pos.x - joueur.pos.x, 0, e.pos.z - joueur.pos.z).normalize();
  e.fuiteBut = pointLibrePres(V(e.pos.x + d.x * 18, 0, e.pos.z + d.z * 18), 0, 5);
  UI.retirerPlaque(e); UI.plaque(e, { nom: e.def.nom, guilde: 'EN FUITE', classe: 'ennemi fuyard', vie: true, lettre: false });
}
function majRonde(sc, v, dt) {
  const chef = v[0];
  if (sc.pause > 0) { sc.pause -= dt; for (const e of v) e.jouer('Idle'); return; }
  const but = sc.pts[sc.i];
  if (dist2D(chef.pos, but) < 1.6) { sc.i += sc.sens; if (sc.i >= sc.pts.length || sc.i < 0) { sc.sens *= -1; sc.i += 2 * sc.sens; } sc.pause = rnd(1.5, 3.5); return; }
  allerVers(chef, but, dt, 1.75); chef.jouer('Walking_A');
  const fx = Math.sin(chef.angle), fz = Math.cos(chef.angle);
  for (let k = 1; k < v.length; k++) {
    const e = v[k], lat = k % 2 ? -0.9 : 0.9;
    const c = V(chef.pos.x - fx * 1.9 * k + fz * lat, 0, chef.pos.z - fz * 1.9 * k - fx * lat);
    if (dist2D(e.pos, c) > 0.6) { allerVers(e, c, dt, 2.0); e.jouer('Walking_A'); } else { e.jouer('Idle'); faceVers(e, but, dt, 4); }
  }
}
function majScenes(dt) {
  if (!scenes.length || !joueur) return;
  for (const sc of scenes) {
    if (sc.etat === 'combat' || sc.etat === 'fini') continue;
    let v = null; for (const e of sc.membres) if (!e.mort) { (v || (v = [])).push(e); }
    if (!v) { sc.etat = 'fini'; continue; }
    const ref = sc.type === 'ronde' ? v[0].pos : sc.centre, dC = dist2D(joueur.pos, ref);
    if (sc.etat === 'calme') {
      if (dC > 55) continue;
      if (sc.type === 'ronde') majRonde(sc, v, dt);
      else if (sc.type === 'rituel') { sc.castT = (sc.castT ?? rnd(1, 3)) - dt; if (sc.castT <= 0) { sc.castT = rnd(2.5, 4); const e = hasard(v); e.jouer('Spellcast_Shoot', { boucle: false, forcer: true, vitesse: 0.7, fin: () => e.etat === 'scene' && e.jouer('Idle') }); if (sc.orbe) emettre(V(sc.orbe.position.x, 1.6, sc.orbe.position.z), { n: 14, c1: '#ffffff', c2: monde.theme.cristal, vit: 2, vie: 0.7, taille: 0.3 }); } }
      // ils bavardent si tu es assez près pour les entendre (sans te voir)
      if (dC < 24) {
        sc.bavardT -= dt;
        if (sc.bavardT <= 0) {
          sc.bavardT = rnd(4.5, 8.5); const e = hasard(v);
          UI.parole(e, replique('bav_' + (sc.type === 'debout' ? 'cercle' : sc.type)));
          for (const o of v) o.regard = o === e ? (v.find(x => x !== e) || {}).pos || null : e.pos;
          if (e.activite === 'debout' && Math.random() < 0.4) e.jouer('Cheer', { boucle: false, forcer: true, fin: () => e.etat === 'scene' && e.jouer('Idle') });
        }
      }
      for (const e of v) if (voitJoueur(e)) { declencherAlerte(sc); break; }
    } else if (sc.etat === 'alerte') {
      sc.t -= dt;
      for (const e of v) if (e.etat === 'alerte') faceVers(e, joueur.pos, dt, 6);
      if (sc.t <= 0) { sc.etat = 'combat'; moraleScene(sc); }
    }
  }
}
// états propres au donjon vivant ; renvoie true si l'ennemi est géré ici
function majEnnemiVivant(e, d, dt) {
  const s = e.etat;
  if (s === 'scene' || s === 'alerte') { e.maj(dt); return true; }
  if (s === 'peur') {
    e.peurT -= dt; faceVers(e, joueur.pos, dt, 6);
    e.model.position.x = Math.sin(G.t * 70) * 0.035; // il tremble
    if (e.peurT <= 0) {
      e.model.position.x = 0; G.camCible = null; if (e._camAvant) G.camDist = e._camAvant;
      e.etat = 'fuite'; e.regard = null; e.fuiteT = 7;
      const d = V(e.pos.x - joueur.pos.x, 0, e.pos.z - joueur.pos.z).normalize();
      e.fuiteBut = pointLibrePres(V(e.pos.x + d.x * 18, 0, e.pos.z + d.z * 18), 0, 5);
      UI.retirerPlaque(e); UI.plaque(e, { nom: e.def.nom, guilde: 'EN FUITE', classe: 'ennemi fuyard', vie: true, lettre: false });
      emettre(V(e.pos.x, 0.3, e.pos.z), { n: 12, c1: '#d8c8a8', c2: '#6a5a4a', vit: 2.5, vie: 0.5, taille: 0.35 });
    }
    e.maj(dt); return true;
  }
  if (s === 'fuite') {
    e.fuiteT -= dt;
    if (e.fuiteBut && dist2D(e.pos, e.fuiteBut) > 1.4 && e.fuiteT > 0) { allerVers(e, e.fuiteBut, dt, e.def.vitesse * 1.2); e.jouer('Running_A'); }
    else { e.etat = 'terre'; e.jouer('Idle'); }
    e.maj(dt); return true;
  }
  if (s === 'terre') {
    faceVers(e, joueur.pos, dt, 3); e.regard = d < 14 ? joueur.pos : null;
    e.supplieT = Math.max(0, (e.supplieT || 0) - dt);
    if (d < 4.5 && e.supplieT <= 0) { e.supplieT = 9; UI.parole(e, replique('terre'), 'peur'); }
    e.maj(dt); return true;
  }
  if (s === 'eveil') { e.eveilT -= dt; faceJoueur(e, dt, 3); if (e.eveilT <= 0) { e.etat = 'chasse'; e.teteBas = false; e.regard = null; } e.maj(dt); return true; }
  if (s === 'dormant' && e.repaire) { majRepaire(e, d, dt); e.maj(dt); return true; }
  return false;
}
// un ennemi paisible est frappé : sa scène s'alerte aussitôt, un fuyard se défend
function frappeVivant(e) {
  if (e.etat === 'fuite' || e.etat === 'terre' || e.etat === 'peur') { if (e.etat === 'peur') { e.model.position.x = 0; G.camCible = null; if (e._camAvant) G.camDist = e._camAvant; } e.etat = 'chasse'; e.regard = null; UI.parole(e, replique('desespoir'), 'menace'); return; }
  if ((e.etat === 'scene' || e.etat === 'alerte') && e.scene) { if (e.scene.etat === 'calme') declencherAlerte(e.scene, true); e.etat = 'chasse'; e.regard = null; e.jouer('Idle_Combat'); }
}
// ---- boss : un vrai lieu de vie (il dort, fait sa ronde, étudie) puis une réplique à l'arrivée ----
function majRepaire(e, d, dt) {
  const R = e.repaire;
  const zone = monde.zoneDe(joueur.pos.x, joueur.pos.z);
  if (zone === e.salle.id) e.dansSalleT = (e.dansSalleT || 0) + dt; else e.dansSalleT = 0;
  const seuil = R.activite === 'dort' ? 14 : R.activite === 'recherche' ? 13 : 17;
  if (!joueur.mort && (d < seuil || e.pv < e.pvMax || e.dansSalleT > 8)) { eveilBoss(e); return; }
  if (R.activite === 'dort') {
    e.zT = (e.zT ?? 1) - dt;
    if (e.zT <= 0 && d < 45) { e.zT = 3.4; UI.parole(e, e.def.model === 'Dragon_Evolved' ? hasard(['Rrrh… zzz…', 'Zzz… mon or… zzz…']) : hasard(['Zzz…', 'Zzz… hm… zzz…']), 'dodo'); }
    if (e.def.model === 'Dragon_Evolved' && Math.random() < dt * 1.5) emettre(V(e.pos.x + Math.sin(e.angle) * 2.6, 2 + solY(e.pos.x, e.pos.z), e.pos.z + Math.cos(e.angle) * 2.6), { n: 2, c1: '#8a8a8a', c2: '#3a3a3a', vit: 0.6, vie: 1.4, taille: 0.6, grav: -0.6 });
  } else if (R.activite === 'recherche') {
    e.rT = (e.rT ?? 2) - dt;
    if (e.rT <= 0) {
      e.rT = rnd(3, 5); e.jouer('Spellcast_Shoot', { boucle: false, forcer: true, vitesse: 0.55, fin: () => e.etat === 'dormant' && e.jouer('Idle') });
      emettre(V(e.pos.x + Math.sin(e.angle) * 2.2, 2.7 + solY(e.pos.x, e.pos.z), e.pos.z + Math.cos(e.angle) * 2.2), { n: 18, c1: '#ffffff', c2: monde.theme.runes, vit: 2, vie: 0.8, taille: 0.3 });
      if (Math.random() < 0.4 && d < 32) UI.parole(e, replique('rech_necro'));
    }
  } else if (R.activite === 'ronde') {
    R.i = R.i ?? 1; R.pause = R.pause || 0;
    if (R.pause > 0) { R.pause -= dt; return; }
    const but = R.ronde[R.i];
    if (dist2D(e.pos, but) < 1.3) {
      if (R.i === 0) { // tir d'entraînement sur les cibles
        faceVers(e, R.cible, 1, 99); e.jouer('2H_Ranged_Shoot', { boucle: false, forcer: true, fin: () => e.etat === 'dormant' && e.jouer('Idle') });
        programmer(0.45, () => { if (e.etat === 'dormant') { son('drawKnife2', 0.3, 1.1); emettre(V(R.cible.x, 2.9, R.cible.z), { n: 8, c1: '#e8d8a8', c2: '#8a6a3a', vit: 2, vie: 0.4, taille: 0.25 }); } });
        R.pause = 2.6;
      } else R.pause = rnd(1, 2.4);
      R.i = (R.i + 1) % R.ronde.length; e.jouer('Idle'); return;
    }
    allerVers(e, but, dt, 1.6); e.jouer('Walking_A');
  }
}
function eveilBoss(e) {
  if (e.etat !== 'dormant') return;
  const dragon = e.def.model === 'Dragon_Evolved';
  e.etat = 'eveil'; e.eveilT = 1.9; e.teteBas = false; e.regard = joueur.pos; e.repaire = null;
  e.vitesseAnim = 1; e.jouer(dragon ? 'Flying_Idle' : 'Cheer', { boucle: false, forcer: true, fin: () => e.jouer(dragon ? 'Flying_Idle' : 'Idle_Combat') });
  UI.parole(e, replique('boss_' + e.boss.id), 'menace');
  UI.titreManga(e.boss.nom, modeActuel.lieu); UI.intention(e.boss.couleur || '#ff2a2a');
  son('lowFrequency_explosion_000', 0.6, 0.7); G.shake = 0.5;
}
function installerRepaire(b, s) {
  const R = s.repaire; if (!R) return;
  b.root.position.copy(R.pos); b.angle = R.angle; b.root.rotation.y = R.angle; b.repaire = R;
  if (R.activite === 'dort') { b.teteBas = true; b.jouer(b.def.model === 'Dragon_Evolved' ? 'Flying_Idle' : 'Idle', { vitesse: 0.3, forcer: true }); }
  else b.jouer('Idle', { forcer: true });
}
// ---- la crypte cachée et sa relique ----
function preparerCrypte() {
  const C = monde.crypte; if (!C) return;
  const rar = couleurSelonRang(tirerCouleurCoffre());
  const def = hasard(ARTEFACTS), R = RARETES_RELIQUE[rar] || RARETES_RELIQUE.vert;
  const g = new THREE.Group(); g.position.set(C.socle.x, 2.3, C.socle.z);
  const mat = new THREE.MeshStandardMaterial({ color: R.color, emissive: R.color, emissiveIntensity: 1.4, metalness: 0.5, roughness: 0.2, flatShading: true });
  const or = new THREE.MeshStandardMaterial({ color: '#e8c070', metalness: 0.9, roughness: 0.25, emissive: '#5a3a10', emissiveIntensity: 0.4 });
  const gemme = new THREE.Mesh(new THREE.OctahedronGeometry(0.42, 0), mat); gemme.scale.y = 1.5; g.add(gemme);
  const anneau = new THREE.Mesh(new THREE.TorusGeometry(0.72, 0.07, 8, 32), or); g.add(anneau);
  const anneau2 = new THREE.Mesh(new THREE.TorusGeometry(0.9, 0.04, 6, 32), or); anneau2.rotation.x = Math.PI / 2; g.add(anneau2);
  const eclats = []; for (let i = 0; i < 4; i++) { const m = new THREE.Mesh(new THREE.OctahedronGeometry(0.12, 0), mat); g.add(m); eclats.push(m); }
  monde.groupe.add(g);
  const aura = faisceau(V(C.socle.x, 0, C.socle.z), R.color, 12, 0.7); monde.groupe.add(aura);
  const solA = new THREE.Mesh(new THREE.CircleGeometry(2.8, 40), new THREE.MeshBasicMaterial({ color: R.color, map: texRond(), transparent: true, opacity: 0.6, blending: THREE.AdditiveBlending, depthWrite: false })); solA.rotation.x = -Math.PI / 2; solA.position.set(C.socle.x, 0.12, C.socle.z); monde.groupe.add(solA);
  const voile = new THREE.Mesh(new THREE.CylinderGeometry(1.7, 1.7, 3.6, 32, 1, true), new THREE.MeshBasicMaterial({ color: '#c08aff', transparent: true, opacity: 0.22, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide })); voile.position.set(C.socle.x, 1.8, C.socle.z); monde.groupe.add(voile);
  G.torches.push({ pos: V(C.socle.x, 2.6, C.socle.z), color: R.color, int: 34, dist: 14 });
  G.anims.push((t) => { g.rotation.y = t * 0.9; g.position.y = 2.3 + Math.sin(t * 1.6) * 0.18; anneau.rotation.x = Math.sin(t) * 0.6; eclats.forEach((m, i) => { const a = t * 1.8 + i * 1.57; m.position.set(Math.cos(a) * 1.1, Math.sin(t * 2 + i) * 0.3, Math.sin(a) * 1.1); }); if (voile.parent) voile.material.opacity = 0.16 + 0.08 * Math.sin(t * 3); if (Math.random() < 0.25) emettre(V(C.socle.x + rnd(-1, 1), 1.4, C.socle.z + rnd(-1, 1)), { n: 1, c1: '#ffffff', c2: R.color, dir: V(0, 1, 0), vit: 1.2, vie: 1, taille: 0.25 }); });
  crypteEtat = { relique: { id: def.id, rarete: rar }, def, R, objet: g, aura, solA, voile, ouverte: false, gardiens: null, prise: false, indice: false };
  try { sentierCrypte(); } catch (e) { console.warn('sentier crypte', e); }
}
// un fin sentier de lumière dessiné au sol, de l'entrée jusqu'au mur fissuré (puis jusqu'à la relique une fois le mur brisé).
// Des vagues de lueur le parcourent vers la crypte, et un feu follet t'attend un peu plus loin quand tu t'en approches.
function sentierCrypte() {
  const C = monde.crypte, E = crypteEtat; if (!C || !C.murObj || !monde.spawn) return;
  const a = cheminGrille(monde.spawn, C.murObj.pos), b = cheminGrille(C.murObj.pos, C.socle);
  if (!a || a.length < 2) return;
  // lissage (Chaikin) puis rééchantillonnage régulier tous les 1,05 m
  let pts = [monde.spawn.clone(), ...a, C.murObj.pos.clone()];
  const apresMur = b ? b : []; pts = pts.concat(apresMur, [C.socle.clone()]);
  for (let it = 0; it < 2; it++) { const q = [pts[0]]; for (let i = 0; i < pts.length - 1; i++) { const p0 = pts[i], p1 = pts[i + 1]; q.push(p0.clone().lerp(p1, 0.25), p0.clone().lerp(p1, 0.75)); } q.push(pts[pts.length - 1]); pts = q; }
  const Mu = C.mur, ech = []; let acc = 0, dist = 0;
  for (let i = 0; i < pts.length - 1; i++) {
    const p0 = pts[i], p1 = pts[i + 1], l = dist2D(p0, p1);
    while (acc <= l) { const p = p0.clone().lerp(p1, l ? acc / l : 0); ech.push({ p, d: dist + acc, apres: (Mu.axe === 'x' ? p.z < Mu.z - 0.3 : p.x < Mu.x - 0.3) ? 1 : 0 }); acc += 0.8; }
    acc -= l; dist += l;
  }
  // on ne commence pas collé à l'entrée : le sentier apparaît quelques mètres plus loin
  const liste = ech.filter(e => e.d > 5);
  const n = liste.length; if (!n) return;
  const geo = new THREE.PlaneGeometry(0.7, 0.7).rotateX(-Math.PI / 2);
  const aD = new Float32Array(n), aA = new Float32Array(n);
  const mat = new THREE.ShaderMaterial({ transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
    uniforms: { uT: { value: 0 }, uOuv: { value: 0 }, uFin: { value: 1 }, uC: { value: new THREE.Color('#b8a4ff') } },
    vertexShader: 'attribute float aD; attribute float aA; varying vec2 vU; varying float vD; varying float vA; void main(){ vU=uv; vD=aD; vA=aA; gl_Position=projectionMatrix*modelViewMatrix*instanceMatrix*vec4(position,1.0); }',
    fragmentShader: 'uniform float uT; uniform float uOuv; uniform float uFin; uniform vec3 uC; varying vec2 vU; varying float vD; varying float vA; void main(){ float r=length(vU-0.5)*2.0; float f=smoothstep(1.0,0.0,r); f*=f; float vague=pow(max(0.0,sin(vD*0.32-uT*2.6)),14.0); float base=0.26+0.08*sin(vD*1.7+uT*1.3); float vis=mix(1.0,uOuv,vA)*uFin; gl_FragColor=vec4(uC*(base+vague*1.1), (base+vague*0.9)*f*vis); }' });
  const im = new THREE.InstancedMesh(geo, mat, n); const m4 = new THREE.Matrix4(), q4 = new THREE.Quaternion(), sc = new THREE.Vector3();
  liste.forEach((e, i) => { const y = solY(e.p.x, e.p.z) + 0.11; sc.setScalar(0.75 + Math.sin(i * 2.3) * 0.2); q4.setFromAxisAngle(V(0, 1, 0), i * 1.7); m4.compose(V(e.p.x + Math.sin(i * 3.1) * 0.12, y, e.p.z + Math.cos(i * 2.7) * 0.12), q4, sc); im.setMatrixAt(i, m4); aD[i] = e.d; aA[i] = e.apres; });
  geo.setAttribute('aD', new THREE.InstancedBufferAttribute(aD, 1)); geo.setAttribute('aA', new THREE.InstancedBufferAttribute(aA, 1));
  im.frustumCulled = false; im.renderOrder = 2; monde.groupe.add(im);
  // feu follet
  const follet = new THREE.Sprite(new THREE.SpriteMaterial({ map: texRond(), color: '#d8ccff', blending: THREE.AdditiveBlending, transparent: true, depthWrite: false, opacity: 0 }));
  follet.scale.setScalar(0.7); monde.groupe.add(follet);
  E.sentier = { im, mat, liste, follet, i: 0, fp: liste[0].p.clone(), t: 0 };
  G.anims.push((t, dt) => {
    const S = E.sentier; if (!S || !S.im.parent) return;
    mat.uniforms.uT.value = t;
    mat.uniforms.uOuv.value += ((E.ouverte ? 1 : 0) - mat.uniforms.uOuv.value) * Math.min(1, dt * 2);
    if (E.prise) mat.uniforms.uFin.value = Math.max(0, mat.uniforms.uFin.value - dt * 0.4);
    if (!joueur) return;
    S.t -= dt; if (S.t <= 0) { S.t = 0.2; let bi = 0, bd = Infinity; for (let i = 0; i < S.liste.length; i++) { const d = dist2D(S.liste[i].p, joueur.pos); if (d < bd) { bd = d; bi = i; } } S.i = bi; S.pres = bd; }
    // le feu follet flotte ~7 m devant toi sur le sentier (il ne dépasse pas le mur tant qu'il est fermé)
    let k = Math.min(S.liste.length - 1, S.i + 7); if (!E.ouverte) while (k > 0 && S.liste[k].apres) k--;
    const cible = S.liste[k].p; S.fp.lerp(cible, Math.min(1, dt * 1.2));
    const proche = S.pres < 9 && !E.prise ? 1 : 0;
    follet.material.opacity += (proche * (0.75 + 0.2 * Math.sin(t * 5)) - follet.material.opacity) * Math.min(1, dt * 2);
    follet.position.set(S.fp.x + Math.sin(t * 1.3) * 0.3, solY(S.fp.x, S.fp.z) + 1.3 + Math.sin(t * 2.1) * 0.25, S.fp.z + Math.cos(t * 1.1) * 0.3);
    if (proche && Math.random() < 0.3) emettre(V(follet.position.x, follet.position.y, follet.position.z), { n: 1, c1: '#ffffff', c2: '#a890ff', vit: 0.4, vie: 0.9, taille: 0.18, grav: -0.6 });
    if (S.pres < 14 && Math.random() < 0.12) { const e = S.liste[Math.min(S.liste.length - 1, S.i + Math.floor(Math.random() * 10))]; if (!e.apres || E.ouverte) emettre(V(e.p.x, solY(e.p.x, e.p.z) + 0.15, e.p.z), { n: 1, c1: '#e8e0ff', c2: '#8a70ff', dir: V(0, 1, 0), vit: 0.6, vie: 1.2, taille: 0.14 }); }
  });
}
function majCrypte(dt) {
  const C = monde.crypte, E = crypteEtat; if (!C || !E || joueur.mort) return;
  const m = C.murObj;
  if (!E.annonce && E.sentier && E.sentier.pres < 5) { E.annonce = true; UI.toast('Une traînée de lumière pâle serpente sur les dalles… un feu follet semble t’inviter à la suivre.'); }
  if (!E.ouverte && !E.indice && dist2D(joueur.pos, m.pos) < 7) { E.indice = true; UI.toast('Un courant d’air froid passe à travers ce mur fissuré…'); }
  if (E.ouverte && !E.gardiens && monde.zoneDe(joueur.pos.x, joueur.pos.z) === C.id) reveilGardiensCrypte();
  if (E.gardiens && !E.libre && E.gardiens.every(g => g.mort)) {
    E.libre = true; if (E.voile.parent) E.voile.removeFromParent();
    UI.toast('La relique est libérée', true); son('jingle_legend', 0.5, 1.1); onde(C.socle, E.R.color, 7, 0.9);
  }
}
function briserMurCrypte() {
  const C = monde.crypte, E = crypteEtat; if (!C || !E || E.ouverte) return;
  E.ouverte = true; const m = C.murObj;
  m.mesh.removeFromParent(); m.fissures.removeFromParent();
  for (const c of m.cols) { const i = monde.collisions.indexOf(c); if (i >= 0) monde.collisions.splice(i, 1); }
  G.shake = 0.7; son('impactPlate_heavy_000', 0.8, 0.5); son('explosionCrunch_000', 0.5, 0.7);
  emettre(V(m.pos.x, 1.6, m.pos.z), { n: 90, c1: '#d8c8a8', c2: '#5a4a3a', vit: 8, vie: 1.1, taille: 0.7, grav: 7, hemi: true });
  monde.crypteVue = true; monde._fond = null;
  UI.toast('PASSAGE SECRET', true); UI.toast('Une crypte oubliée… quelque chose brille au fond.');
}
function reveilGardiensCrypte() {
  const C = monde.crypte, E = crypteEtat;
  const ipJ = Math.round(puissanceReelleJoueur().ip || statsHeros(J.equip).ip);
  E.gardiens = C.gardiens.map((p, i) => {
    const data = { nom: i ? 'Gardienne de la relique' : 'Gardien de la relique', guilde: 'CRYPTE OUBLIÉE', equip: genererEquipRival(ipJ, i ? 'baton' : 'epee'), niv: niveauHeros(J.equip), ip: ipJ, modele: i ? 'Mage' : 'Knight', kPv: 1.11, kDg: 1.11, skill: 0.9 };
    const g = creerCombattant(p.clone(), data, 'ennemi');
    g.root.scale.setScalar(1.22); g.hauteurPlaque = 3.0; g.rayon = 0.7; g.gardienCrypte = true;
    g.tenueCouleur && g.tenueCouleur('#5a2a8a'); auraMeurtriere(g, '#b05aff', 1.5);
    emettre(V(p.x, 0.4, p.z), { n: 60, c1: '#e8d0ff', c2: '#5a1a9a', vit: 6, vie: 1, taille: 0.6, hemi: true, monte: 3 }); onde(p, '#b05aff', 5, 0.8);
    return g;
  });
  UI.parole(E.gardiens[0], replique('crypte'), 'menace');
  UI.titreManga('Gardiens de la relique', `Puissance : 111 % de la tienne`); UI.intention('#b05aff');
  son('lowFrequency_explosion_000', 0.7, 0.6); G.shake = 0.6;
}
function prendreRelique() {
  const E = crypteEtat; if (!E || E.prise || !E.libre) return;
  E.prise = true; UI.action(null);
  E.objet.removeFromParent(); E.aura.removeFromParent(); E.solA.removeFromParent();
  son('jingle_legend', 0.6); onde(monde.crypte.socle, E.R.color, 8, 1); G.shake = 0.4;
  emettre(V(joueur.pos.x, 1.4, joueur.pos.z), { n: 120, c1: '#ffffff', c2: E.R.color, vit: 7, vie: 1.2, taille: 0.45, monte: 4 });
  J.reliques = J.reliques || []; J.reliques.push(E.relique); exploit('relique'); if (E.relique.rarete === 'legendaire') exploit('relique_legende');
  const avant = J.relique;
  UI.relique({ ...E.def, rarete: E.R, rareteId: E.relique.rarete }, avant ? { ...ARTEFACTS.find(a => a.id === avant.id), rarete: RARETES_RELIQUE[avant.rarete] } : null, (lier) => {
    if (lier || !avant) { J.relique = E.relique; construireJoueur(); UI.toast(`${E.def.pouvoir} lié à ton âme · bouton ✦`, true); }
    sauver();
  });
}
// ---- pouvoirs des reliques ----
function sortRelique(r) {
  const d = ARTEFACTS.find(a => a.id === r.id); if (!d) return null;
  const R = RARETES_RELIQUE[r.rarete] || RARETES_RELIQUE.vert;
  return { id: 'art_' + d.id, nom: d.pouvoir + ' (' + R.nom.toLowerCase() + ')', desc: d.desc, cd: d.cd, energie: 0, mult: 0, portee: 14, type: 'relique', couleur: [R.color, d.couleur[1]], glyphe: d.glyphe, k: R.k, relique: true };
}
function pouvoirRelique(s) {
  const k = s.k || 1, st = joueur.st;
  const fin = () => joueur.jouer(joueur.def.idle);
  joueur.jouer('Spellcast_Raise' in joueur.actions ? 'Spellcast_Raise' : 'Cheer', { boucle: false, forcer: true, vitesse: 1.3, fin });
  UI.titreManga(s.nom.split(' (')[0], 'Relique'); son('forceField_000', 0.7, 0.7);
  emettre(V(joueur.pos.x, 1.4, joueur.pos.z), { n: 50, c1: '#ffffff', c2: s.couleur[0], vit: 5, vie: 0.8, taille: 0.4, monte: 3 });
  if (s.id === 'art_meteore') {
    const { point } = directionVisee(14); const c = point.clone();
    telegraphe(c, 7, 1.2, '#ffb030', () => {
      G.shake = 1.3; son('lowFrequency_explosion_000', 0.9); son('explosionCrunch_000', 0.7, 0.5);
      onde(c, '#ffd27a', 11, 0.8); onde(c, '#ff5a1a', 8, 1);
      emettre(V(c.x, 0.5, c.z), { n: 220, c1: '#fff0b0', c2: '#ff2a00', vit: 16, vie: 1.1, taille: 1, grav: 4, hemi: true });
      zoneDegats(c, 7, 9 * k, { stun: 1.6, c1: '#ffe08a', c2: '#ff3a00' });
      lueurSol(c, '#ff4a10', 6.5, 4, 0.9);
      let tick = 0; ajouterVfx(new THREE.Group(), (t, dt) => { tick += dt; if (tick > 0.5) { tick = 0; zoneDegats(c, 6.5, 0.45 * k, { silence: true }); } if (t > 4) return false; });
    });
  } else if (s.id === 'art_avatar') {
    const pos = pointLibrePres(V(joueur.pos.x - Math.sin(joueur.angle) * 2.5, 0, joueur.pos.z - Math.cos(joueur.angle) * 2.5), 0, 1.5);
    const a = creerCombattant(pos, { nom: 'Roi oublié', guilde: J.nom.toUpperCase(), equip: { ...J.equip, arme: creerArme('epee', Math.max(1, (J.equip.arme || {}).tier || 1)) }, modele: 'Knight', sansRecalage: true }, 'allie');
    UI.retirerPlaque(a);
    Object.assign(a, { invoc: 'avatar', vieT: 20, potions: 0, cdRempart: 1e9 });
    a.pvMax = a.pv = Math.round(st.pvMax * 1.6 * k); a.dmg = st.degats * 1.1 * k; a.reduction = Math.max(0.3, st.reduction);
    a.root.scale.setScalar(1.55); a.hauteurPlaque = 3.6; a.rayon = 0.9;
    teinteSpectrale(a, '#c8b0ff', 0.55);
    UI.plaque(a, { nom: 'Roi oublié', guilde: '20 s', classe: 'allie', vie: true, lettre: false });
    onde(pos, '#c9a0ff', 6, 0.9); emettre(V(pos.x, 1, pos.z), { n: 90, c1: '#ffffff', c2: '#8a5aff', vit: 6, vie: 1, taille: 0.6, monte: 4 });
  } else if (s.id === 'art_temps') {
    onde(joueur.pos, '#bfe8ff', 14, 1.1); onde(joueur.pos, '#ffffff', 10, 0.8);
    let n = 0;
    for (const e of vivants()) { if (dist2D(e.pos, joueur.pos) > 14) continue; const t = (e.boss ? 1.3 : 4) * Math.sqrt(k); e.stunT = Math.max(e.stunT, e.combattant ? t * 0.5 : t); n++; emettre(V(e.pos.x, 1.2, e.pos.z), { n: 14, c1: '#ffffff', c2: '#7ac8ff', vit: 2, vie: 0.8, taille: 0.35 }); }
    if (n) UI.toast(`${n} ennemi${n > 1 ? 's' : ''} figé${n > 1 ? 's' : ''}`);
  } else if (s.id === 'art_nova') {
    joueur.pv = Math.min(st.pvMax, joueur.pv + st.pvMax * 0.5 * Math.min(1.6, k));
    joueur.bouclier = Math.max(joueur.bouclier || 0, st.pvMax * 0.3 * k); joueur.bouclierT = 6;
    onde(joueur.pos, '#fff2a0', 9, 0.9); lueurSol(joueur.pos, '#ffe27a', 5, 1.2, 0.8);
    for (const e of vivants()) if (dist2D(e.pos, joueur.pos) < 7) { blesser(e, 2 * k, { air: true, c1: '#fff2a0' }); }
  } else if (s.id === 'art_ailes') {
    joueur.sprintT = Math.max(joueur.sprintT || 0, 6); joueur.invuln = Math.max(joueur.invuln || 0, 2); joueur.ailesT = 6; joueur.ailesK = k;
    onde(joueur.pos, '#ffb07a', 6, 0.7);
    ajouterVfx(new THREE.Group(), (t) => { if (Math.random() < 0.8) emettre(V(joueur.pos.x + rnd(-0.6, 0.6), 1.4, joueur.pos.z + rnd(-0.6, 0.6)), { n: 2, c1: '#ffe0a0', c2: '#ff4a00', vit: 1.5, vie: 0.6, taille: 0.35, grav: -1 }); if (t > 6 || joueur.mort) return false; });
  }
}
function mortGardienCrypte(e) {
  G.shake = 0.7; son('lowFrequency_explosion_000', 0.5, 0.9);
  onde(e.pos, '#b05aff', 7, 0.9); emettre(V(e.pos.x, 1.5, e.pos.z), { n: 80, c1: '#f0e0ff', c2: '#6a1aaa', vit: 7, vie: 1.1, taille: 0.5, grav: -1 });
  UI.toast(`${e.nom} retourne à la poussière`, true);
  gagnerXPRelatif(0.08);
  const reste = ennemis.filter(x => x.gardienCrypte && !x.mort).length;
  if (!reste) UI.boss(null);
  setTimeout(() => { e.descendre = true; }, 2500);
}
function majAurasDonjon(dt) {
  for (const e of ennemis) if (e.auraM && e.gardienCrypte) {
    const A = e.auraM; if (e.mort) { if (A.ring.parent) G.scene.remove(A.ring); continue; }
    A.ring.position.set(e.pos.x, 0.12 + solY(e.pos.x, e.pos.z), e.pos.z); const s = (0.9 + Math.sin(G.t * 5) * 0.12) * A.k * e.root.scale.x; A.ring.scale.set(s, s, s);
    if (Math.random() < dt * 14 * A.k) emettre(V(e.pos.x + rnd(-0.5, 0.5), 0.3, e.pos.z + rnd(-0.5, 0.5)), { n: 1, c1: A.couleur, c2: '#0a0000', dir: V(0, 1, 0), vit: 3 * A.k, disp: 0.5, vie: 0.8, taille: 0.45 * A.k, frein: 0.6 });
  }
}

// les têtes suivent ce qui compte : ta cible pour toi, toi pour les personnages qui te voient passer
function majRegards() {
  const c = joueur.cibleVerrou && !joueur.cibleVerrou.mort ? joueur.cibleVerrou : (joueur.combatT > 0 && joueur.cible && !joueur.cible.mort ? joueur.cible : null);
  joueur.regard = c && dist2D(c.pos, joueur.pos) < 16 ? c.pos : null;
  for (const p of [marchand, graveuse, passeur, intendant]) if (p) p.regard = dist2D(p.pos, joueur.pos) < 9 ? joueur.pos : null;
  if (!modeActuel) for (const b of bots) b.regard = b.etat === 'idle' && dist2D(b.pos, joueur.pos) < 7 ? joueur.pos : null;
  if (taverne) for (const cl of taverne.clients) cl.regard = dist2D(cl.pos, joueur.pos) < 6 ? joueur.pos : null;
}

