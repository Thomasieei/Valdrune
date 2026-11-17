// ---------------- IA des ennemis ----------------
function majEnnemis(dt) {
  for (let i = ennemis.length - 1; i >= 0; i--) {
    const e = ennemis[i];
    const d = dist2D(e.pos, joueur.pos);
    if (e.mort) {
      if (e.descendre) { e.root.position.y -= dt * 0.8; if (e.root.position.y < -2.5) { G.scene.remove(e.root); UI.retirerPlaque(e); ennemis.splice(i, 1); continue; } }
      if (d < 40) e.maj(dt);
      continue;
    }
    const proche = d < 42 || e.combattant;
    e.root.visible = d < (G.camVue && G.camVue !== 'iso' ? 58 : 36);
    if (!proche) continue;
    // effets
    for (let k = e.dots.length - 1; k >= 0; k--) {
      const o = e.dots[k]; o.t -= dt; o.acc = (o.acc || 0) + dt;
      if (o.acc >= 0.5) { o.acc = 0; e.pv -= o.dps * 0.5; if (compteur) noterDegats(joueur, o.dps * 0.5); UI.nombre(V(e.pos.x, e.hauteurPlaque * 0.7, e.pos.z), Math.round(o.dps * 0.5), 'info'); emettre(V(e.pos.x, 1, e.pos.z), { n: 3, c1: o.c, c2: '#ffffff', vit: 1.5, vie: 0.4, taille: 0.25 }); if (e.pv <= 0) { tuer(e); break; } }
      if (o.t <= 0) e.dots.splice(k, 1);
    }
    if (e.mort) continue;
    if (e.tk) { e.maj(dt); continue; }
    if (e.pousse) { const P = e.pousse; P.t -= dt; deplacer(e, P.vx * dt, P.vz * dt, Math.min(e.rayon * 0.8, 1.1)); if (P.t <= 0) e.pousse = null; }
    if (e.stunT > 0) { e.stunT -= dt; if (Math.random() < dt * 8) emettre(V(e.pos.x, e.hauteurPlaque, e.pos.z), { n: 1, c1: '#fff7a0', c2: '#ffd040', vit: 0.6, vie: 0.5, taille: 0.25, rayon: 0.4 }); e.maj(dt * 0.15); continue; }
    if (sautEnCours(e, dt)) continue;
    if (e.airT > 0) { e.airT -= dt; e.root.position.y = Math.sin((0.6 - e.airT) / 0.6 * Math.PI) * 1.6; e.maj(dt); continue; } else if (!e.boss && !e.sautT) e.root.position.y = e.hover;
    if (e.slowT > 0) e.slowT -= dt;
    if (e.racineT > 0) e.racineT -= dt;
    e.atkT -= dt * (modeActuel && modeActuel.abime ? 2 : modeHard ? 1.35 : 1);
    if (majEnnemiVivant(e, d, dt)) continue;
    if (e.etat === 'idle') { if (d < 11 || allies.some(a => !a.mort && dist2D(a.pos, e.pos) < 8)) reveiller(e); e.maj(dt); continue; }
    if (e.etat === 'dormant') {
      const zone = monde.zoneDe ? monde.zoneDe(joueur.pos.x, joueur.pos.z) : null;
      if ((e.salle && zone === e.salle.id) || d < 13) reveiller(e);
      e.maj(dt); continue;
    }
    if (e.equipeId && d > 26 && terres) { escarmouche(e, dt); e.maj(dt); continue; }
    if (e.combattant) { majCombattant(e, dt); e.maj(dt); continue; }
    if (e.raidV && majPillardVille(e, d, dt)) { e.maj(dt); continue; }
    e.tc = cibleIA(e);
    if (!e.tc) { e.jouer(e.def.model === 'Dragon_Evolved' ? 'Flying_Idle' : 'Idle_Combat'); e.maj(dt); continue; }
    const dc = dist2D(e.pos, e.tc.pos);
    if (e.boss) { majBoss(e, dc, dt); e.maj(dt); continue; }
    majMob(e, dc, dt);
    e.maj(dt);
  }
}
const _dirAV = new THREE.Vector3();
function avancerVers(e, cible, dt, vitesse) {
  if (e.racineT > 0 && e !== joueur) return; // entravé : ne peut plus bouger
  const dir = _dirAV.set(cible.x - e.pos.x, 0, cible.z - e.pos.z); const l = dir.length(); if (l < 0.01) return;
  dir.divideScalar(l);
  // séparation
  for (let li = 0; li < (e.bg ? 2 : 1); li++) for (const o of (li ? allies : ennemis)) { if (o === e || o.mort || o.loup) continue; const dx = e.pos.x - o.pos.x, dz = e.pos.z - o.pos.z, dd = Math.hypot(dx, dz); const r = e.rayon + o.rayon + 0.3; if (dd < r && dd > 0.01) { dir.x += dx / dd * (r - dd) * 1.5; dir.z += dz / dd * (r - dd) * 1.5; } }
  dir.normalize();
  const v = vitesse * (e.slowT > 0 ? 0.6 : 1) * dt;
  const ax = e.pos.x, az = e.pos.z;
  deplacer(e, dir.x * v, dir.z * v, e === joueur ? 0.5 : Math.min(e.rayon * 0.8, 1.1));
  // détection de blocage dans le décor : après 0,8 s coincé, il bondit près de sa cible
  const bouge = Math.hypot(e.pos.x - ax, e.pos.z - az);
  e.bloqueT = bouge < v * 0.3 ? (e.bloqueT || 0) + dt : Math.max(0, (e.bloqueT || 0) - dt * 2);
  if (e.bloqueT > 0.8) { e.bloqueT = 0; if (e === joueur) { e.chemin = null; e.contour = -(e.contour || 1); } else if (l < 18) bondir(e, cible); }
  e.angle = tourner(e.angle, Math.atan2(dir.x, dir.z), dt * 10); e.root.rotation.y = e.angle;
}
function faceJoueur(e, dt, k = 10) { const c = e.tc || joueur; e.angle = tourner(e.angle, Math.atan2(c.pos.x - e.pos.x, c.pos.z - e.pos.z), dt * k); e.root.rotation.y = e.angle; }
function majMob(e, d, dt) {
  const def = e.def;
  const c = e.tc;
  if (e.attaqueT > 0) { e.attaqueT -= dt * (modeActuel && modeActuel.abime ? 1.8 : 1); faceJoueur(e, dt, 6); return; }
  const portee = def.portee;
  if (d > portee + e.rayon) { allerVers(e, c.pos, dt, def.vitesse); e.jouer('Running_A'); return; }
  faceJoueur(e, dt);
  if (e.atkT > 0) { e.jouer('Idle_Combat'); return; }
  e.atkT = def.type === 'melee' ? rnd(1.3, 1.7) : rnd(1.9, 2.4);
  e.attaqueT = 0.7;
  e.jouer(def.atk, { boucle: false, forcer: true, vitesse: 1.1, fin: () => e.jouer('Idle_Combat') });
  if (def.type === 'melee') programmer(0.45, () => { if (!e.mort && e.stunT <= 0 && !c.mort && dist2D(e.pos, c.pos) < portee + e.rayon + 0.9) { infliger(e, c, e.dmg); son('impactGeneric_light_000', 0.3); } });
  else programmer(0.4, () => { if (!e.mort && e.stunT <= 0) tirEnnemi(e, def.type === 'caster' ? 'feu' : 'carreau', e.dmg); });
}
function tirEnnemi(e, type, dmg, dirForcee = null, vitesse = null) {
  const depart = V(e.pos.x, 1.3 * (e.boss ? Math.min(2.2, e.boss.scale) * 0.7 : 1) + (e.hover || 0) + solY(e.pos.x, e.pos.z), e.pos.z);
  const vise = e.tc || joueur;
  const dest = V(vise.pos.x, 1.1 + (vise.hover || 0) + solY(vise.pos.x, vise.pos.z), vise.pos.z);
  if (e.skill !== undefined && vise.vel && !dirForcee) { const t = dest.distanceTo(V(e.pos.x, 1.3, e.pos.z)) / (vitesse || (type === 'feu' ? 11 : 16)); dest.addScaledVector(vise.vel, t * e.skill * 0.9); }
  if (e.skill !== undefined && !dirForcee) { const err = (1 - e.skill) * 1.6; dest.x += rnd(-err, err); dest.z += rnd(-err, err); }
  const dir = dirForcee ? dirForcee.clone() : dest.sub(depart).normalize();
  const coul = type === 'feu' ? '#ff4a2a' : '#c8ff9a';
  const mesh = type === 'feu' ? meshBoule(coul, e.boss ? 0.7 : 0.45) : meshCarreau(coul);
  mesh.position.copy(depart); mesh.lookAt(depart.clone().add(dir)); G.scene.add(mesh);
  const v = vitesse || (type === 'feu' ? 11 : 16);
  projectiles.push({ mesh, pos: mesh.position, vel: dir.multiplyScalar(v), vie: 16 / v * 1.4, camp: e.camp === 'allie' ? 'allie' : 'ennemi', src: e, type, dmg, couleur: coul, touches: new Set(), largeur: 0.75 });
  son(type === 'feu' ? 'thrusterFire_000' : 'drawKnife2', 0.15, type === 'feu' ? 1.2 : 1.5);
}

// ---------------- Boss ----------------
function majBoss(e, d, dt) {
  const b = e.boss; const enrage = e.pv < e.pvMax * 0.3;
  const tc = e.tc;
  if (e.chargeT > 0) { e.chargeT -= dt; deplacer(e, e.chargeV.x * dt, e.chargeV.z * dt, 1.2); emettre(V(e.pos.x, 1.5, e.pos.z), { n: 3, c1: '#ffb84a', c2: '#ff2a00', vit: 2, vie: 0.5, taille: 0.8, rayon: 1.5 }); for (const c of adversaires(e)) if (dist2D(e.pos, c.pos) < 2.8 && !e.chargeTouches.has(c)) { e.chargeTouches.add(c); infliger(e, c, e.dmg * 3.0); } if (e.chargeT <= 0) e.jouer('Flying_Idle'); return; }
  if (e.attaqueT > 0) { e.attaqueT -= dt; return; }
  e.specT -= dt * (enrage ? 1.4 : 1);
  if (e.specT <= 0) { capaciteBoss(e); e.specT = rnd(4.2, 5.6) * (BOSS_SYLVE.includes(b) ? 1.15 : 1); return; }
  const dragon = e.def.model === 'Dragon_Evolved';
  const ranged = b.id === 'archere' || b.id === 'necro' || b.id === 'sylphe' || b.id === 'chasseur';
  if (b.id === 'sylphe') e.root.position.y = e.hover + Math.sin(G.t * 2) * 0.25;
  const portee = ranged ? 10 : e.def.portee + e.rayon;
  if (e.figeT > 0) { e.figeT -= dt; return; }
  if (d > portee) { allerVers(e, tc.pos, dt, e.def.vitesse * (enrage ? 1.25 : 1)); e.jouer(dragon ? 'Fast_Flying' : 'Running_A'); return; }
  faceJoueur(e, dt, 6);
  if (e.atkT > 0) { e.jouer(dragon ? 'Flying_Idle' : 'Idle_Combat'); return; }
  e.atkT = ranged ? 1.4 : 1.7; e.attaqueT = 0.8;
  if (dragon) { e.jouer(Math.random() < 0.5 ? 'Punch' : 'Headbutt', { boucle: false, forcer: true, fin: () => e.jouer('Flying_Idle') }); programmer(0.5, () => { if (!e.mort && !tc.mort && dist2D(e.pos, tc.pos) < portee + 1.2) infliger(e, tc, e.dmg); }); }
  else if (ranged) { e.jouer(e.def.atk, { boucle: false, forcer: true, fin: () => e.jouer('Idle_Combat') }); programmer(0.4, () => { if (!e.mort) tirEnnemi(e, b.id === 'necro' || b.id === 'sylphe' ? 'feu' : 'carreau', e.dmg * 0.75); }); }
  else { e.jouer('2H_Melee_Attack_Chop', { boucle: false, forcer: true, vitesse: 0.9, fin: () => e.jouer('Idle_Combat') }); programmer(0.55, () => { if (!e.mort && !tc.mort && dist2D(e.pos, tc.pos) < portee + 1.2) { infliger(e, tc, e.dmg); if (tc === joueur) G.shake = 0.4; } }); }
}
function invoquer(e, n) {
  for (let i = 0; i < n; i++) {
    const a = Math.random() * 6.28; const p = V(e.pos.x + Math.cos(a) * 4, 0, e.pos.z + Math.sin(a) * 4);
    if (!libre(p.x, p.z, 0.5)) continue;
    const m = creerEnnemi(MOBS.minion, p, modeActuel.mobTier, -2);
    m.invoque = true; m.maitre = e; m.etat = 'chasse';
    m.jouer('Spawn_Ground_Skeletons', { boucle: false, fin: () => m.jouer('Idle_Combat') }); m.attaqueT = 1.2;
    emettre(V(p.x, 0.3, p.z), { n: 20, c1: '#7a5a9a', c2: '#2a1a3a', vit: 3, vie: 0.8, taille: 0.5, hemi: true });
  }
}
function capaciteBoss(e) {
  const b = e.boss; e.cycle++;
  if (BOSS_SYLVE.includes(b)) return capaciteSylve(e);
  const pj = (e.tc || joueur).pos.clone();
  if (b.id === 'gardien') {
    if (e.cycle % 2) {
      // bond et fracas
      e.jouer('1H_Melee_Attack_Jump_Chop', { boucle: false, forcer: true, vitesse: 0.8, fin: () => e.jouer('Idle_Combat') });
      e.sautA = e.pos.clone(); e.sautB = pointLibrePres(pj, 0, 1.2, 1.0); e.sautD = e.sautT = 1.2; e.sautH = 4; e.attaqueT = 1.6;
      tele(pj, 3.8, 1.2, '#ff2a2a', () => { G.shake = 1; onde(pj, '#ff8a3a', 6, 0.6); emettre(V(pj.x, 0.3, pj.z), { n: 50, c1: '#d8c8a8', c2: '#6a5a4a', vit: 8, vie: 0.8, taille: 0.6, hemi: true, grav: 6 }); son('impactPlate_heavy_000', 0.8, 0.6); toucherZone(e, pj, 3.8, e.dmg * 3.4, { slow: 2.5 }); });
    } else {
      e.jouer('2H_Melee_Attack_Spinning', { vitesse: 1.2, forcer: true }); e.attaqueT = 1.6;
      const c = e.pos.clone();
      tele(c, 5.5, 1.4, '#ff2a2a', () => { onde(c, '#ffd0a0', 6, 0.5); son('knifeSlice', 0.7, 0.6); toucherZone(e, e.pos, 5.9, e.dmg * 2.9); e.jouer('Idle_Combat'); });
    }
  } else if (b.id === 'archere') {
    if (e.cycle % 3 === 0) { e.jouer('Spellcast_Summon', { boucle: false, forcer: true, fin: () => e.jouer('Idle_Combat') }); e.attaqueT = 1.2; invoquer(e, 2); UI.toast('L’Archère appelle ses morts !'); }
    else {
      const base = Math.atan2(pj.x - e.pos.x, pj.z - e.pos.z); e.attaqueT = 1.5;
      e.jouer('2H_Ranged_Aiming' in e.actions ? '2H_Ranged_Shoot' : e.def.atk, { boucle: false, forcer: true, vitesse: 0.6, fin: () => e.jouer('Idle_Combat') });
      tele(e.pos, 14, 1.0, '#ff2a2a', () => { for (let i = -3; i <= 3; i++) { const a = base + i * 0.17; tirEnnemi(e, 'carreau', e.dmg * 1.5, V(Math.sin(a), 0, Math.cos(a)), 19); } }, { cone: 1.2, angle: base - Math.PI / 2 });
    }
  } else if (b.id === 'necro') {
    if (e.cycle % 3 === 0) { e.jouer('Spellcast_Summon', { boucle: false, forcer: true, fin: () => e.jouer('Idle_Combat') }); e.attaqueT = 1.4; invoquer(e, 3); UI.toast('Le Nécromancien relève les morts !'); }
    else {
      e.jouer('Spellcast_Shoot', { boucle: false, forcer: true, fin: () => e.jouer('Idle_Combat') }); e.attaqueT = 1.0;
      for (let i = 0; i < 5; i++) {
        const p = i === 0 ? pj.clone() : pj.clone().add(V(rnd(-5, 5), 0, rnd(-5, 5)));
        tele(p, 2.6, 1.3 + i * 0.12, '#ff2a2a', () => { emettre(V(p.x, 0.4, p.z), { n: 30, c1: '#ff8aff', c2: '#ff1a4a', vit: 6, vie: 0.6, taille: 0.6, hemi: true }); onde(p, '#ff3a6a', 3, 0.4); son('explosionCrunch_000', 0.3, 1.2); toucherZone(e, p, 2.6, e.dmg * 2.4); });
      }
    }
  } else if (b.id === 'horreur' || b.id === 'devoreur') {
    const r = e.cycle % 3;
    const base = Math.atan2(pj.x - e.pos.x, pj.z - e.pos.z);
    if (r === 1) {
      e.attaqueT = 1.9; e.jouer('Headbutt', { boucle: false, forcer: true, vitesse: 0.6, fin: () => e.jouer('Flying_Idle') });
      e.angle = base; e.root.rotation.y = base;
      const c = e.pos.clone();
      tele(c, 11, 1.3, '#ff2a2a', () => {
        son('thrusterFire_000', 0.9, 0.6); G.shake = 0.6;
        for (let i = 0; i < 70; i++) { const a = base + rnd(-0.6, 0.6); emettre(V(c.x, 2.4, c.z), { n: 1, c1: '#ffe08a', c2: '#ff2a00', dir: V(Math.sin(a), -0.05, Math.cos(a)), vit: 16, disp: 1, vie: 0.7, taille: 1.0, frein: 1 }); }
        toucherZone(e, c, 11, e.dmg * 3.6, { cone: { dir: V(Math.sin(base), 0, Math.cos(base)), cos: Math.cos(0.65) } });
      }, { cone: 1.3, angle: base - Math.PI / 2 });
    } else if (r === 2) {
      e.attaqueT = 1.2; const dir = V(Math.sin(base), 0, Math.cos(base));
      tele(e.pos, 18, 1.1, '#ff2a2a', () => { e.chargeT = 0.6; e.chargeV = dir.clone().multiplyScalar(30); e.chargeTouches = new Set(); e.jouer('Fast_Flying', { vitesse: 2 }); son('lowFrequency_explosion_000', 0.5, 1.2); }, { ligne: true, largeur: 3.4, angle: base + Math.PI });
      e.angle = base; e.root.rotation.y = base;
    } else {
      e.attaqueT = 1; e.jouer('Punch', { boucle: false, forcer: true, fin: () => e.jouer('Flying_Idle') });
      for (let i = 0; i < 6; i++) {
        const p = i === 0 ? pj.clone() : pj.clone().add(V(rnd(-6, 6), 0, rnd(-6, 6)));
        tele(p, 3, 1.6 + i * 0.1, '#ff2a2a', () => { G.shake = 0.5; emettre(V(p.x, 0.5, p.z), { n: 40, c1: '#fff0b0', c2: '#ff3a00', vit: 8, vie: 0.7, taille: 0.7, hemi: true }); onde(p, '#ff8a2a', 4, 0.5); son('explosionCrunch_000', 0.4, 0.8); toucherZone(e, p, 3, e.dmg * 2.6); });
        const m = meshBoule('#ff5a1a', 0.9); m.position.set(p.x + 6, 18, p.z - 6); G.scene.add(m);
        const dur = 1.6 + i * 0.1;
        ajouterVfx(m, (t) => { const k = t / dur; if (k >= 1) return false; m.position.set(p.x + 6 * (1 - k), 18 * (1 - k), p.z - 6 * (1 - k)); emettre(m.position, { n: 2, c1: '#ffe08a', c2: '#ff3a00', vit: 0.5, vie: 0.4, taille: 0.6 }); });
      }
    }
  }
}

// ---------------- Projectiles ----------------
function majProjectiles(dt) {
  for (let i = projectiles.length - 1; i >= 0; i--) {
    const p = projectiles[i];
    p.vie -= dt; p.pos.addScaledVector(p.vel, dt);
    if (p.type === 'feu') emettre(p.pos, { n: 2, c1: '#ffe08a', c2: p.couleur, vit: 0.6, vie: 0.35, taille: p.camp === 'joueur' ? 0.55 : 0.6 });
    else if (Math.random() < 0.6) emettre(p.pos, { n: 1, c1: p.couleur, c2: '#ffffff', vit: 0.2, vie: 0.25, taille: 0.2 });
    let fini = p.vie <= 0 || !monde.marche(p.pos.x, p.pos.z);
    if (!fini && p.camp === 'joueur' && p.cible && G.agression && estPassant(p.cible) && dist2D(p.cible.pos, p.pos) < 1.1) { blesserPassant(p.cible, degatsJoueur(p.mult || 1).d); fini = true; }
    if (!fini && p.camp === 'joueur') {
      for (const e of vivants()) {
        if (p.touches.has(e)) continue;
        if (dist2D(e.pos, p.pos) < e.rayon + p.largeur * 0.6) {
          p.touches.add(e);
          if (p.onHit) { p.onHit(p.pos.clone()); fini = true; break; }
          blesser(e, p.mult || 1, { c1: p.couleur });
          if (!p.perce) { fini = true; break; }
        }
      }
    } else if (!fini && p.camp === 'allie') {
      for (const e of vivants()) if (dist2D(e.pos, p.pos) < e.rayon + 0.5 && p.pos.y < 2.6 + (e.hover || 0) * 2) { infliger(p.src, e, p.dmg); fini = true; break; }
    } else if (!fini && p.camp === 'ennemi') {
      for (const c of equipeJoueur()) if (dist2D(c.pos, p.pos) < 0.85 && p.pos.y < 2.6) { infliger(p.src, c, p.dmg); fini = true; emettre(p.pos, { n: 12, c1: '#ffd0a0', c2: p.couleur, vit: 3, vie: 0.4, taille: 0.4 }); break; }
    }
    if (fini) {
      if (p.onHit && !p.touches.size) p.onHit(p.pos.clone());
      else if (p.type === 'feu' && p.camp === 'ennemi') emettre(p.pos, { n: 10, c1: '#ffb84a', c2: '#ff2a00', vit: 3, vie: 0.4, taille: 0.4 });
      G.scene.remove(p.mesh); projectiles.splice(i, 1);
    }
  }
}

