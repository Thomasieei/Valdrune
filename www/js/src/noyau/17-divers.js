// ---------------- Musique ----------------
let pisteMusique = null, calmeT = 0;
function combatIntense() {
  if (arene && !arene.fini) return true;
  if (rivauxVivants().length) return true;
  if (assaut && !assaut.fini) return true;
  return ennemis.some(e => e.boss && !e.mort && e.etat === 'chasse' && dist2D(e.pos, joueur.pos) < 30);
}
function majMusique(dt) {
  if (!enJeu) return;
  if (combatIntense()) { calmeT = 5; if (pisteMusique !== 'theme') { pisteMusique = 'theme'; musique('theme'); } }
  else if (pisteMusique === 'theme') { calmeT -= dt; if (calmeT <= 0) { pisteMusique = 'fond'; musique('fond'); } }
}
// ---------------- Parchemins ----------------
function parchActifs() { return MODES.includes(modeActuel) && !(invasion && invasion.mode === 'menee') && !rivauxVivants().length; }
function bonusParch(effet) {
  if (!J.parchemins || !parchActifs()) return 0;
  for (const [c, p] of Object.entries(J.parchemins)) if (COULEURS_PARCH[c].effet === effet && p.reste > 0) return p.bonus;
  return 0;
}
let parchSauveT = 0;
function majParchemins(dt) {
  const P = J.parchemins; if (!P) return;
  const actif = parchActifs();
  const now = performance.now(); const reel = Math.min(5, (now - (majParchemins.t || now)) / 1000); majParchemins.t = now;
  if (actif) for (const [c, p] of Object.entries(P)) {
    p.reste -= reel;
    if (p.reste <= 0) { delete P[c]; UI.toast(`Parchemin de ${COULEURS_PARCH[c].nom} épuisé`); son('close_001', 0.4); }
  }
  parchSauveT -= 0.2; if (parchSauveT <= 0) { parchSauveT = 5; sauver(); }
  UI.majParchemins(etatParchemins());
}
function etatParchemins() {
  const P = J.parchemins || {}; const pause = !parchActifs();
  const raison = !MODES.includes(modeActuel) ? 'hors Brèche' : invasion && invasion.mode === 'menee' ? 'invasion' : rivauxVivants().length ? 'combat d’invasion' : '';
  return Object.entries(P).map(([c, p]) => ({ couleur: c, bonus: p.bonus, reste: p.reste, pause, raison }));
}
function utiliserParchemin(itemId) {
  const it = J.sac.find(i => i.id == itemId && i.cat === 'parchemin'); if (!it) return;
  const def = PARCHEMINS[it.type]; J.parchemins = J.parchemins || {};
  const cur = J.parchemins[def.couleur];
  if (cur) { cur.reste += DUREE_PARCH; cur.bonus = Math.max(cur.bonus, def.bonus); UI.toast(`${COULEURS_PARCH[def.couleur].nom} prolongé : ${Math.round(cur.reste / 60)} min restantes`); }
  else { J.parchemins[def.couleur] = { bonus: def.bonus, reste: DUREE_PARCH }; UI.toast(`Parchemin activé : +${Math.round(def.bonus * 100)} % ${COULEURS_PARCH[def.couleur].texte} pendant 30 min`, true); }
  it.n = (it.n || 1) - 1; if (it.n <= 0) J.sac = J.sac.filter(x => x !== it);
  son('bookOpen', 0.6); if (joueur) { onde(joueur.pos, COULEURS_PARCH[def.couleur].c2, 4, 0.6); emettre(V(joueur.pos.x, 1.2, joueur.pos.z), { n: 50, c1: COULEURS_PARCH[def.couleur].c1, c2: COULEURS_PARCH[def.couleur].c2, vit: 4, vie: 1, taille: 0.4, monte: 3 }); }
  if (!MODES.includes(modeActuel)) UI.toast('Il ne s’écoule que dans la Brèche Écarlate');
  sauver();
}

// ---------------- Rangs classés ----------------
// rang de la partie en cours : Argent, Or… rendent les ennemis plus forts et le butin meilleur
// les rivaux de haut rang encaissent et cognent plus (maîtrise, talents… comme de vrais joueurs)
function kpv(camp) { if (camp !== 'ennemi') return 1; const i = rangK(); return arene ? 1 + 0.16 * i + (i >= 5 ? 0.3 : 0) : 1 + 0.07 * i; }
function kdg(camp) { if (camp !== 'ennemi') return 1; const i = rangK(); return arene ? 1 + 0.09 * i : 1 + 0.07 * i; }
function couleurSelonRang(c) { const ordre = ['vert', 'bleu', 'violet', 'legendaire']; let i = ordre.indexOf(c); if (i >= 0 && i < 2 && Math.random() < 0.025 * rangK()) i++; return ordre[i] || c; } // le rang ne crée jamais de légendaire
function rangK() {
  if (arene) return rangDe('arene').i;
  if (MODES.includes(modeActuel) || modeActuel && modeActuel.sylve) return rangDe('donjon').i;
  return 0;
}
// progression lente sur la durée : chaque palier demande beaucoup plus que le précédent
// monter est une vraie galère : paliers énormes, gains qui fondent et défaites qui coûtent de plus en plus cher
const SEUILS_RANG = [0, 400, 1400, 4000, 10000, 25000];
const GAIN_K = [1, 0.7, 0.5, 0.35, 0.25, 0.18], PERTE_K = [0.8, 1, 1.3, 1.6, 2, 2.5];
function migrerRang() {
  if (!J.rang || J.rangV2) return; J.rangV2 = true;
  for (const m of ['arene', 'donjon']) { const p = J.rang[m] || 0, i = Math.min(RANGS.length - 1, Math.floor(p / 100)); const loc = i === RANGS.length - 1 ? p - i * 100 : p % 100;
    const larg = (SEUILS_RANG[i + 1] || SEUILS_RANG[i] + 1000) - SEUILS_RANG[i]; J.rang[m] = SEUILS_RANG[i] + Math.round(Math.min(0.99, loc / 100) * larg); }
}
function rangDe(mode) {
  migrerRang();
  const p = (J.rang && J.rang[mode]) || 0; let i = 0; while (i < RANGS.length - 1 && p >= SEUILS_RANG[i + 1]) i++;
  const max = i === RANGS.length - 1 ? null : SEUILS_RANG[i + 1] - SEUILS_RANG[i];
  return { i, pts: p, local: p - SEUILS_RANG[i], max, r: RANGS[i], mode };
}
function changerRang(mode, delta, raison) {
  if (!J.rang) { J.rang = { arene: 0, donjon: 0 }; J.rangV2 = true; }
  const avant = rangDe(mode); delta = delta >= 0 ? Math.max(1, Math.round(delta * GAIN_K[avant.i])) : Math.round(delta * PERTE_K[avant.i]); J.rang[mode] = Math.max(0, Math.round(J.rang[mode] + delta)); const apres = rangDe(mode); sauver();
  UI.changementRang(avant, apres, Math.round(delta), raison);
  if (apres.i > avant.i) son('jingle_legend', 0.6); else if (apres.i < avant.i) son('lowFrequency_explosion_000', 0.6, 0.6);
  if (apres.i > avant.i && apres.i > 0) exploit('rang_' + RANGS[apres.i].id);
}
// les autres joueurs du rang : leurs points bougent au fil de la journée
function classementRang(mode) {
  const rg = rangDe(mode); const t = Date.now() / 3.6e6;
  const liste = BOTS.slice(0, 24).map(([nom, tag], k) => {
    const s = (k + 1) * 9301 + rg.i * 49297 + (mode === 'arene' ? 7 : 3);
    const base = (s * 233280) % 97; const pts = Math.max(0, Math.min(rg.max || 3000, Math.round((base / 97) * (rg.max || 3000) * 0.95 + 10 * Math.sin(t * (0.6 + (s % 7) / 10) + k))));
    return { nom, tag, pts, moi: false };
  });
  liste.push({ nom: J.nom, tag: 'CZ', pts: rg.local, moi: true });
  liste.sort((a, b) => b.pts - a.pts);
  return { rang: rg, liste };
}
// ---------------- Boss errant ultra rare ----------------
let errant = null;
function apparitionErrant() {
  const salles = monde.salles.filter(s => s.type === 'normale').sort((a, b) => dist2D(b.centre, monde.spawn) - dist2D(a.centre, monde.spawn));
  const s = salles[Math.floor(Math.random() * Math.min(3, salles.length))]; if (!s) return;
  const b = creerBoss(BOSS_ERRANT, s.centre.clone(), modeActuel.bossTier[3], s);
  b.revealT = 6; b.revele = 0; errant = b;
  for (const mt of b.mats) if (mt.emissive) { mt.emissive.set('#8a2aff').multiplyScalar(0.25); mt.userData.baseEmissive = mt.emissive.clone(); }
  setTimeout(() => { UI.introBoss(BOSS_ERRANT.nom, BOSS_ERRANT.titre + ' est apparu dans le donjon', BOSS_ERRANT.couleur); son('lowFrequency_explosion_000', 0.8, 0.4); G.shake = 0.5; }, 2500);
}
function majErrant(dt) {
  const e = errant; if (!e || e.mort || !ennemis.includes(e)) { errant = null; return; }
  if (e.revele > 0) e.revele -= dt;
  if (e.etat === 'dormant') {
    e.revealT -= dt;
    if (e.revealT <= 0) { e.revealT = rnd(20, 30); e.revele = 3.2; UI.ping(); UI.toast(`${BOSS_ERRANT.nom} rôde dans le donjon…`); son('forceField_000', 0.4, 0.5); }
    if (Math.random() < dt * 3) emettre(V(e.pos.x + rnd(-2, 2), 2, e.pos.z + rnd(-2, 2)), { n: 1, c1: '#e0b0ff', c2: '#3a0a6a', dir: V(0, 1, 0), vit: 2, vie: 1.2, taille: 0.6 });
  }
}
function mortErrant(e) {
  UI.boss(null); G.shake = 1.4; son('jingle_legend', 0.8);
  onde(e.pos, '#c06aff', 14, 1.5); emettre(V(e.pos.x, 3, e.pos.z), { n: 200, c1: '#f4d8ff', c2: '#6a1aff', vit: 12, vie: 1.8, taille: 0.6, grav: 2 });
  UI.introBoss(`${BOSS_ERRANT.nom} est vaincu`, 'Un trésor légendaire t’attend', BOSS_ERRANT.couleur);
  creerCoffre(pointLibrePres(e.pos, 2, 4), 'legendaire', e); coffres[coffres.length - 1].mega = true;
  if (MODES.includes(modeActuel)) changerRang('donjon', 15, BOSS_ERRANT.nom + ' vaincu');
  gagnerXPRelatif(0.25); setTimeout(() => montrerXP(BOSS_ERRANT.nom), 1800);
  errant = null; sauver();
  setTimeout(() => { e.descendre = true; }, 6000);
}



// ---------------- Assassin ----------------
function distSegPt(a, b, p) { const vx = b.x - a.x, vz = b.z - a.z, l2 = vx * vx + vz * vz; let t = l2 ? ((p.x - a.x) * vx + (p.z - a.z) * vz) / l2 : 0; t = Math.max(0, Math.min(1, t)); return Math.hypot(p.x - (a.x + vx * t), p.z - (a.z + vz * t)); }
function gagnerCombo(n) { joueur.combo = Math.min(5, (joueur.combo || 0) + n); joueur.comboT = 8; }
function furtifBonus() { return joueur.furtifT > 0 ? 1.15 : 1; }
function traineeRouge(a, b, c1 = '#ff4a5a') { const n = Math.max(3, Math.round(a.distanceTo(b) * 2)); for (let i = 0; i <= n; i++) { const p = a.clone().lerp(b, i / n); emettre(V(p.x, 1, p.z), { n: 1, c1, c2: '#1a0004', vit: 0.6, vie: 0.35, taille: 0.45 }); } }
function teleportDerriere(c) {
  const ang = Math.atan2(c.pos.x - joueur.pos.x, c.pos.z - joueur.pos.z);
  const p = V(c.pos.x + Math.sin(ang) * (c.rayon + 1.0), 0, c.pos.z + Math.cos(ang) * (c.rayon + 1.0));
  const q = pointLibreProche(p, 0.5) || joueur.pos.clone();
  emettre(V(joueur.pos.x, 1, joueur.pos.z), { n: 20, c1: '#ff8a8a', c2: '#1a0004', vit: 3, vie: 0.5, taille: 0.45 });
  joueur.pos.set(q.x, 0, q.z); faireFace(V(c.pos.x - q.x, 0, c.pos.z - q.z).normalize());
  emettre(V(q.x, 1, q.z), { n: 20, c1: '#ff8a8a', c2: '#1a0004', vit: 3, vie: 0.5, taille: 0.45 }); son('cloth1', 0.5, 1.6);
}
function furtif(t) {
  joueur.furtifT = Math.max(joueur.furtifT || 0, t); joueur.invuln = Math.max(joueur.invuln, t);
  for (const e of ennemis) if (e.tc === joueur) e.tc = null;
  if (!joueur._furtifVfx) {
    joueur._furtifVfx = true;
    for (const m of joueur.mats) { m.transparent = true; m.opacity = 0.28; }
    const jF = joueur;
    ajouterVfx(new THREE.Group(), (tt, dt) => {
      if (joueur !== jF) return false;
      joueur.furtifT = (joueur.furtifT || 0) - dt;
      if (Math.random() < 0.4) emettre(V(joueur.pos.x + rnd(-0.4, 0.4), 0.3 + Math.random() * 1.5, joueur.pos.z + rnd(-0.4, 0.4)), { n: 1, c1: '#ff9a9a', c2: '#1a0004', vit: 0.6, vie: 0.5, taille: 0.3 });
      if (joueur.furtifT <= 0) { for (const m of joueur.mats) { m.opacity = 1; m.transparent = false; } joueur._furtifVfx = false; return false; }
    });
  }
}
// attaque de base : coup 1, coup 2, puis au 3e coup on se téléporte dans son dos et on disparaît 1 s
function attaqueAssassin(c, vit) {
  const st = joueur.st;
  joueur.comboPas = G.t - (joueur.dernierCoup || -9) < 1.5 ? ((joueur.comboPas || 0) + 1) % 3 : 0; joueur.dernierCoup = G.t;
  const pas = joueur.comboPas;
  if (pas === 2) teleportDerriere(c);
  const anim = ['1H_Melee_Attack_Slice_Diagonal', '1H_Melee_Attack_Chop', '2H_Melee_Attack_Stab'][pas];
  joueur.jouer(anim, { boucle: false, vitesse: Math.max(1.6, vit * 1.3), forcer: true, fondu: 0.05, fin: () => joueur.jouer(joueur.def.idle) });
  joueur.verrouT = pas === 2 ? 0.3 : 0.2;
  programmer(0.12, () => {
    if (c.mort) return;
    if (dist2D(c.pos, joueur.pos) - c.rayon > st.portee + 1.2) return;
    arcTaille(joueur.pos, joueur.angle - Math.PI / 2, 2.4, pas === 2 ? '#ff1a2a' : '#ffb0b0', Math.PI * 0.6, 0.18);
    blesser(c, (pas === 2 ? 1.45 : 0.85) * furtifBonus(), { c1: '#ff5a6a' }); gagnerCombo(1);
    son(pas === 2 ? 'knifeSlice2' : 'knifeSlice', 0.45, 1.1 + pas * 0.15);
    if (pas === 2 && G.t - (joueur.dernierFurtif || -9) > 4) { joueur.dernierFurtif = G.t; furtif(0.8); UI.nombre(V(joueur.pos.x, 2.8, joueur.pos.z), 'Furtif', 'info'); }
  });
}

// ---------------- Haches de l'Orage ----------------
function arcElectrique(a, b) {
  const n = Math.max(4, Math.round(a.distanceTo(b) * 2));
  for (let i = 0; i <= n; i++) { const t = i / n; const p = a.clone().lerp(b, t); p.x += rnd(-0.25, 0.25) * Math.sin(t * Math.PI); p.y += rnd(-0.25, 0.25) * Math.sin(t * Math.PI); emettre(p, { n: 1, c1: '#ffffff', c2: '#5a9aff', vit: 0.4, vie: 0.22, taille: 0.32 }); }
}
function chaineEclair(depart, n, mult) {
  const touches = new Set([depart]); let cur = depart;
  for (let k = 0; k < n; k++) {
    let best = null, bd = 6.5; for (const e of vivants()) { if (touches.has(e)) continue; const d = dist2D(e.pos, cur.pos); if (d < bd) { bd = d; best = e; } }
    if (!best) break; touches.add(best);
    arcElectrique(V(cur.pos.x, 1.2, cur.pos.z), V(best.pos.x, 1.2, best.pos.z));
    blesser(best, mult, { silence: true, c1: '#bfe0ff' }); cur = best;
  }
  if (touches.size > 1) son('impactGeneric_light_000', 0.35, 1.8);
}
function eclairCiel(e, mult) {
  const p = V(e.pos.x, 0, e.pos.z);
  arcElectrique(V(p.x + rnd(-1, 1), 14, p.z + rnd(-1, 1)), V(p.x, 0.4, p.z));
  lueurSol(p, '#8ab8ff', 2.4, 0.3, 1.5); onde(p, '#bfe0ff', 2.6, 0.3);
  blesser(e, mult, { stun: 0.25, c1: '#ffffff', c2: '#3a6aff' }); chaineEclair(e, 1, mult * 0.5);
  son('explosionCrunch_000', 0.25, 1.9); G.shake = Math.max(G.shake, 0.15);
}
function tirageOrage(t) {
  if (Math.random() >= (G.chanceOrage ?? CHANCE_ORAGE)) return false;
  const it = creerArme('orage', t, 2 + (Math.random() < 0.3 ? 1 : 0));
  J.maitrise.orage = J.maitrise.orage || { niv: 1, xp: 0 };
  setTimeout(() => { ajouterSac(it, true); sauver(); annonceRare(`${nomObjet(it)} · T${t}`, 'Classe légendaire : une chance sur cent'); UI.chat('Système', `${J.nom} vient d’obtenir ${nomObjet(it)} (T${t}) !`); }, 1400);
  return true;
}

// ---------------- Classe des Ombres ----------------
function utiliserCode(brut) {
  const c = String(brut || '').trim().toUpperCase().replace(/\s+/g, '');
  if (c.normalize('NFKD').replace(/[^A-Z0-9]/gi, '').toUpperCase() === 'THOMAS83') {
    if (V1) return { ok: true, texte: 'Tes ombres sont déjà à toi : bouton Ombres (ou touche O) pour les commander.' };
    J.escouade = !J.escouade;
    if (J.escouade) { J.escStats = { debut: Date.now(), argent0: J.argent, xp: 0, kills: 0, coffres: 0 }; annonceRare('Escouade d’ombres', '6 ombres te suivent partout · compteur de gains lancé'); }
    else { viderEscouade(); UI.escouadeHud(null); }
    sauverMaintenant();
    return { ok: true, texte: J.escouade ? 'Escouade d’ombres activée (retape le code pour la renvoyer).' : 'Escouade d’ombres renvoyée.' };
  }
  const def = CODES_BETA[c];
  if (!def) { son('error_001', 0.4); return { ok: false, texte: 'Code inconnu.' }; }
  J.codes = J.codes || [];
  if (def.tous) { // code réutilisable : toute la gamme pour tester
    J.maitrise[def.arme] = J.maitrise[def.arme] || { niv: 1, xp: 0 }; J.maitrise[def.arme].niv = Math.max(90, J.maitrise[def.arme].niv);
    J.debloques = [...new Set([...(J.debloques || []), def.arme])];
    for (let t = 1; t <= 8; t++) { const it = creerArme(def.arme, t, 2); it.beta = true; ajouterSac(it, true); }
    sauverMaintenant(); annonceRare(ARMES[def.arme].label, 'T1 à T8 ajoutées au sac · maîtrise niveau 90');
    return { ok: true, texte: def.texte };
  }
  if (J.codes.includes(c)) return { ok: false, texte: 'Ce code a déjà été utilisé sur ce profil.' };
  J.codes.push(c);
  const it = creerArme(def.arme, def.tier, 0); it.beta = true;
  J.maitrise[def.arme] = J.maitrise[def.arme] || { niv: 1, xp: 0 };
  ajouterSac(it, true); sauverMaintenant();
  annonceRare('Dagues des Ombres', 'Accès bêta débloqué : équipe-les depuis ton sac');
  return { ok: true, texte: def.texte + ' — ajoutées à ton sac !' };
}
function annonceRare(titre, sous) {
  const d = document.createElement('div'); d.className = 'annonceRare';
  d.innerHTML = `<h2>${titre}</h2><p>${sous}</p>`; document.body.appendChild(d); setTimeout(() => d.remove(), 4600);
  son('jingle_legend', 0.7); G.shake = 0.6;
  if (joueur) { onde(joueur.pos, '#9a5aff', 8, 1); emettre(V(joueur.pos.x, 1.4, joueur.pos.z), { n: 120, c1: '#e8d0ff', c2: '#3a0a6a', vit: 8, vie: 1.4, taille: 0.5, grav: 2 }); }
}
// 0,1 % de chance sur chaque boss et chaque victoire PvP
function tirageOmbre(tMin, tMax, source) {
  if (Math.random() >= (G.chanceOmbre ?? CHANCE_OMBRE)) return false;
  const t = Math.max(1, Math.min(8, tMin + Math.floor(Math.random() * (tMax - tMin + 1))));
  const it = creerArme('ombre', t, Math.random() < 0.5 ? 1 : 2);
  J.maitrise.ombre = J.maitrise.ombre || { niv: 1, xp: 0 };
  setTimeout(() => {
    ajouterSac(it, true); sauver(); setTimeout(() => exploit('ombre_rare'), 5000);
    annonceRare(`${nomObjet(it)} · T${t}`, source === 'pvp' ? 'Arraché à un adversaire : une chance sur mille' : 'Tombé d’un boss : une chance sur mille');
    UI.chat('Système', `${J.nom} vient d’obtenir ${nomObjet(it)} (T${t}) !`);
  }, 1200);
  return true;
}
// une ombre = 25 % de ta puissance, +2 % par tier au-dessus du T1, +3 % par enchantement
function forceOmbre() { const a = J.equip.arme || { tier: 1 }; return 0.25 + (a.tier - 1) * 0.02 + (a.ench || 0) * 0.03; }
function vitesseJoueur() { return joueur.st.vitesse * (joueur.sprintT > 0 ? 1.6 : 1) * (joueur.slowT > 0 ? 0.6 : 1); }
function fumeeOmbre(p) {
  emettre(V(p.x, 0.8, p.z), { n: 26, c1: '#b48aff', c2: '#0a0012', vit: 3.5, rayon: 0.6, vie: 0.7, taille: 0.6, grav: -1 });
  lueurSol(p, '#7a3aff', 1.8, 0.4, 0.6);
}
function teinteSpectrale(a, couleur, force) {
  for (const mt of a.mats) {
    mt.color.lerp(new THREE.Color(couleur), force);
    if (mt.emissive) { mt.emissive.set('#6a2aff').multiplyScalar(0.35); mt.userData.baseEmissive = mt.emissive.clone(); }
  }
}
