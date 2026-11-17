// ======================= MODE AGRESSION : tu peux frapper n'importe qui… mais on s'en souviendra =======================
function passantsProches() { return [...(modeActuel ? [] : bots), ...(taverne ? taverne.clients : []), ...(modeActuel && modeActuel.id === 'domaine' ? [] : [])].filter(b => !b.mort && b.root && b.root.parent && b.root.visible !== false); }
// ---------------- Possession démoniaque ----------------
// le démon prend le corps : il fonce à la vitesse de la lumière des ténèbres sur chaque ennemi et le pulvérise d'un coup, puis rafle les coffres.
// il se nourrit de ta vie : chaque exécution coûte un peu, et si la puissance totale des ennemis dépasse la tienne, il te ronge chaque seconde.
let demon = null;
const ANIMS_DEMON = ['2H_Melee_Attack_Spin', '1H_Melee_Attack_Slice_Diagonal', '2H_Melee_Attack_Slice', '1H_Melee_Attack_Chop', 'Unarmed_Melee_Attack_Kick', 'Unarmed_Melee_Attack_Punch_A'];
function basculerDemon() {
  if (demon) return finDemon('Le démon relâche ton corps…');
  if (!modeActuel || joueur.mort) return UI.toast('Le démon ne s’éveille qu’au combat : donjon, île, terres…');
  if (joueur.pv < joueur.st.pvMax * 0.5) return UI.toast('Pas assez de vie : le démon dévorerait ce qu’il te reste (50 % minimum)');
  demon = { pause: 0.9, combo: 0, drainT: 0, drainAcc: 0, hudT: 0 };
  document.body.classList.add('demon'); const b = $('#btnDemon'); if (b) b.classList.add('actif');
  ralenti(0.7, 0.2); onde(joueur.pos, '#ff1a2a', 7, 0.8); onde(joueur.pos, '#1a0004', 4, 0.6);
  emettre(V(joueur.pos.x, 1, joueur.pos.z), { n: 90, c1: '#ff2a3a', c2: '#000000', dir: V(0, 1, 0), vit: 9, disp: 2, rayon: 1.2, vie: 1.1, taille: 0.6 });
  son('impactGeneric_light_000', 0.8, 0.45); annonce('demon', 'POSSESSION DÉMONIAQUE', true);
  UI.chat(J.nom, hasard(['…il est là', 'je ne contrôle plus rien', 'COURS.']));
  UI.demon && UI.demon({ on: true });
}
function finDemon(msg) {
  demon = null; document.body.classList.remove('demon'); const b = $('#btnDemon'); if (b) b.classList.remove('actif');
  UI.demon && UI.demon(null); if (joueur && !joueur.mort) { joueur.invuln = Math.max(joueur.invuln, 0.6); joueur.jouer('Idle'); }
  if (msg) UI.toast(msg);
}
function proieDemon(e) { return !e.mort && e.etat !== 'possede' && !e.tk && !estPassant(e) && dist2D(e.pos, joueur.pos) < 75; }
function majDemon(dt) {
  const j = joueur, st = j.st;
  // puissance : la tienne contre celle de tous les ennemis de la zone
  const Pj = Math.round(st.pvMax * 6); let Pe = 0; for (const e of ennemis) if (proieDemon(e)) Pe += e.pvMax; Pe = Math.round(Pe);
  if (Pe > Pj) { const d = st.pvMax * Math.min(0.2, 0.035 * Pe / Pj) * dt; j.pv -= d; demon.drainAcc += d; demon.drainT -= dt;
    if (demon.drainT <= 0) { demon.drainT = 0.5; UI.nombre(V(j.pos.x, 2.4, j.pos.z), '-' + Math.round(demon.drainAcc), 'joueur'); demon.drainAcc = 0; emettre(V(j.pos.x, 1.2, j.pos.z), { n: 8, c1: '#ff2a3a', c2: '#000', dir: V(0, 1, 0), vit: 3, vie: 0.6, taille: 0.35 }); } }
  if (j.pv <= 0) { finDemon(null); UI.toast('Le démon t’a consumé…', true); mourirJoueur(); return; }
  demon.hudT -= dt; if (demon.hudT <= 0) { demon.hudT = 0.25; UI.demon && UI.demon({ on: true, Pj, Pe, combo: demon.combo, pv: j.pv / st.pvMax }); }
  if (Math.random() < dt * 25) emettre(V(j.pos.x + rnd(-0.4, 0.4), 0.4, j.pos.z + rnd(-0.4, 0.4)), { n: 1, c1: '#ff2a3a', c2: '#000000', dir: V(0, 1, 0), vit: 2.5, vie: 0.6, taille: 0.45 });
  if (demon.pause > 0) { demon.pause -= dt; j.maj(dt); return; }
  // cible : l'ennemi le plus proche, sinon un coffre libéré
  let c = null, bd = Infinity;
  for (const e of ennemis) if (proieDemon(e)) { const d = dist2D(e.pos, j.pos); if (d < bd) { bd = d; c = e; } }
  let coffre = null;
  if (!c) for (const k of coffres) if (!k.ouvert && !k.final && (!k.boss || k.boss.mort || k.boss.etat === 'possede')) { const d = dist2D(k.pos, j.pos); if (d < 75 && d < bd) { bd = d; coffre = k; } }
  if (!c && !coffre) { j.jouer('Idle'); j.maj(dt); demon.pause = 0.3; return; }
  const cible = c ? c.pos : coffre.pos, de = j.pos.clone();
  const vers = pointLibrePres(cible, c ? 1.1 + (c.rayon || 0.5) : 1.4, c ? 1.8 + (c.rayon || 0.5) : 2.2);
  // la ruée : une traînée d'ombre et de sang, des silhouettes laissées derrière
  traineeRouge(de, vers, '#ff1a2a');
  const n = Math.max(3, Math.round(de.distanceTo(vers) / 2.5)); for (let i = 1; i < n; i++) { const p = de.clone().lerp(vers, i / n); emettre(V(p.x, 1.1, p.z), { n: 2, c1: '#000000', c2: '#3a0008', vit: 0.4, rayon: 0.3, vie: 0.5, taille: 1.1 }); }
  j.pos.copy(vers); j.angle = Math.atan2(cible.x - vers.x, cible.z - vers.z); j.root.rotation.y = j.angle; j.invuln = Math.max(j.invuln, 0.35);
  const anim = ANIMS_DEMON.find(a => j.actions[a]); if (anim) j.jouer(anim, { boucle: false, forcer: true, fondu: 0.05 });
  son('impactMetal_medium_001', 0.5, 0.6 + Math.random() * 0.3);
  if (c) {
    const cout = st.pvMax * (c.boss ? 0.09 : Math.min(0.03, 0.004 * Math.sqrt(c.pvMax / st.pvMax * 8)));
    j.pv -= cout; UI.nombre(V(c.pos.x, 2.8, c.pos.z), c.boss ? 'EXÉCUTÉ' : Math.round(c.pv), 'crit');
    onde(c.pos, '#ff2a3a', c.boss ? 7 : 3.2, 0.35); emettre(V(c.pos.x, 1.2, c.pos.z), { n: c.boss ? 120 : 40, c1: '#ff3a4a', c2: '#000000', vit: c.boss ? 12 : 7, disp: 1, vie: 0.7, taille: 0.45 });
    c.pv = 0; tuer(c); demon.combo++;
    if (c.boss) { ralenti(0.9, 0.12); G.shake = Math.min(1, G.shake + 0.5); demon.pause = 0.55; annonce('demon' + demon.combo, `${(c.boss && c.boss.nom) || 'Boss'} exécuté`, true); }
    else { demon.pause = rnd(0.1, 0.18); if (demon.combo % 6 === 0) ralenti(0.25, 0.3); }
  } else { ouvrirCoffre(coffre, true); demon.pause = 0.35; }
  j.maj(dt);
}
// ---------------- Invocateur : transfert + pacte (gacha) ----------------
function transfert() {
  const v = directionVisee(14), de = joueur.pos.clone();
  let p = v.cible ? v.point.clone().addScaledVector(v.dir, -1.6) : joueur.pos.clone().addScaledVector(v.dir, viseeForcee ? 14 : 10);
  if (monde.marche && !monde.marche(p.x, p.z)) { for (let k = 13; k > 1 && !monde.marche(p.x, p.z); k--) p = de.clone().addScaledVector(v.dir, k); }
  p = pointLibrePres(p, 0, 1.5);
  emettre(V(de.x, 1, de.z), { n: 40, c1: '#ffffff', c2: '#3a5aff', vit: 5, disp: 0.6, vie: 0.5, taille: 0.4 }); onde(de, '#6a8aff', 2.5, 0.3);
  joueur.pos.copy(p); faireFace(v.dir); joueur.invuln = Math.max(joueur.invuln, 0.25);
  emettre(V(p.x, 1, p.z), { n: 50, c1: '#ffffff', c2: '#3a5aff', dir: V(0, 1, 0), vit: 6, disp: 0.8, vie: 0.6, taille: 0.45 }); onde(p, '#9ab8ff', 3.5, 0.35);
  son('forceField_000', 0.4, 1.6); joueur.jouer('Spellcast_Raise', { boucle: false, forcer: true, fin: () => joueur.jouer(joueur.def.idle) });
}
const PACTE = [
  { r: 'Légendaire', p: 0.03, k: 3.2, vie: 120, s: 1.4, c: '#ffb020', ange: 'Archange Séraphiel', demon: 'Bélial, Prince des Enfers' },
  { r: 'Épique', p: 0.12, k: 1.7, vie: 85, s: 1.15, c: '#c06aff', ange: 'Séraphin du Jugement', demon: 'Seigneur des Abîmes' },
  { r: 'Rare', p: 0.30, k: 1.05, vie: 65, s: 1.0, c: '#4aa8ff', ange: 'Valkyrie céleste', demon: 'Succube de cendre' },
  { r: 'Commun', p: 1, k: 0.6, vie: 45, s: 0.85, c: '#c8c8c8', ange: 'Chérubin', demon: 'Diablotin' },
];
// ---- le gacha en cartes : on tire des cartes (anges / démons), les doublons les font monter en étoiles, on en place 3 dans son deck
const CARTES = [];
for (const R of PACTE) for (const ange of [true, false]) CARTES.push({ id: (ange ? 'a_' : 'd_') + R.r, nom: ange ? R.ange : R.demon, ange, R });
function etatCartes() { J.cartes = J.cartes || {}; J.deck = J.deck || [null, null, null]; return { cartes: J.cartes, deck: J.deck }; }
function niveauCarte(id) { const n = (J.cartes || {})[id] || 0; return n <= 0 ? 0 : Math.min(5, 1 + Math.floor(Math.log2(n))); } // 1, 2, 4, 8, 16 exemplaires → ★1 à ★5
function coutTirage(k = 0) { const g = J.pacte || (J.pacte = { n: 0, jour: '', sec: 0 }); const j = new Date().toDateString(); if (g.jour !== j) { g.jour = j; g.n = 0; } return Math.round(600 * Math.pow(1.12, g.n + k) * (1 + ((J.equip.arme || {}).tier || 1) * 0.3)); }
function coutTirages(nb) { let t = 0; for (let k = 0; k < nb; k++) t += coutTirage(k); return Math.round(t * (nb >= 10 ? 0.9 : 1)); }
function tirerCartes(nb) {
  const cout = coutTirages(nb); if (J.argent < cout) { UI.toast(`Il te faut ${UI.abrege(cout)} pièces`); return null; }
  J.argent -= cout; UI.majBourse(J.argent); etatCartes(); J.pacte.n += nb;
  const res = [];
  for (let i = 0; i < nb; i++) {
    J.pacte.sec = (J.pacte.sec || 0) + 1; let t = Math.random(), R = PACTE[3];
    if (J.pacte.sec >= 60) R = PACTE[0]; else for (const x of PACTE) { if (t < x.p) { R = x; break; } t -= x.p; }
    if (nb >= 10 && i === nb - 1 && !res.some(c => c.R.k >= 1.7) && R.k < 1.7) R = PACTE[1]; // un ×10 garantit au moins une épique
    if (R === PACTE[0]) J.pacte.sec = 0;
    const an = Math.random() < 0.5, c = CARTES.find(x => x.R === R && x.ange === an); const avant = niveauCarte(c.id);
    J.cartes[c.id] = (J.cartes[c.id] || 0) + 1; res.push({ ...c, nouveau: avant === 0, monte: niveauCarte(c.id) > avant && avant > 0, niv: niveauCarte(c.id) });
  }
  if (!J.deck.some(Boolean)) { const best = [...new Set(res.map(r => r.id))].sort((a, b) => CARTES.find(x => x.id === b).R.k - CARTES.find(x => x.id === a).R.k).slice(0, 3); best.forEach((id, i) => J.deck[i] = id); }
  sauver(); son(res.some(r => r.R.k >= 3) ? 'jingle_legend' : 'forceField_000', 0.5, 1.2);
  return res;
}
function ouvrirAutel() {
  etatCartes();
  UI.autel(() => ({ cartes: CARTES.map(c => ({ ...c, n: J.cartes[c.id] || 0, niv: niveauCarte(c.id) })), deck: J.deck, c1: coutTirage(), c10: coutTirages(10), argent: J.argent, pitie: 60 - (J.pacte ? J.pacte.sec || 0 : 0) }),
    { tirer: (nb) => tirerCartes(nb), placer: (slot, id) => { etatCartes(); if (id && J.deck.includes(id)) J.deck[J.deck.indexOf(id)] = null; J.deck[slot] = id; sauver(); } });
}
function invoquerDeck() {
  etatCartes(); const deck = J.deck.filter(Boolean);
  if (!deck.length) { UI.toast('Ton deck est vide : place tes cartes à l’Autel des pactes', true); ouvrirAutel(); return false; }
  const vivantes = allies.filter(x => x.invoc === 'pacte' && !x.mort);
  if (vivantes.length) { // déjà là : W change leur ordre
    J.ordrePacte = J.ordrePacte === 'garde' ? 'chasse' : 'garde';
    UI.toast(J.ordrePacte === 'garde' ? 'Ordre : PROTÉGEZ-MOI — tes sbires reviennent autour de toi' : 'Ordre : CHASSEZ — tes sbires partent tuer tout ce qu’ils trouvent', true);
    for (const x of vivantes) { x.objectif = null; onde(x.pos, J.ordrePacte === 'garde' ? '#9ad8ff' : '#ff4a3a', 1.6, 0.3); }
    joueur.cds.W = 1; return true;
  }
  J.ordrePacte = 'chasse';
  deck.forEach((id, i) => { const c = CARTES.find(x => x.id === id); if (c) invoquerCarte(c, niveauCarte(id), i); });
  UI.toast('Tes sbires partent chasser · relance W pour les rappeler (ou les renvoyer)', true);
  return true;
}
function coutPacte() { const g = J.pacte || (J.pacte = { n: 0, jour: '', sec: 0 }); const j = new Date().toDateString(); if (g.jour !== j) { g.jour = j; g.n = 0; } return Math.round(800 * Math.pow(1.45, g.n) * (1 + ((J.equip.arme || {}).tier || 1) * 0.35)); }
function pacteInvocation() { if (!modeActuel) { ouvrirAutel(); return false; } return invoquerDeck(); }
function invoquerCarte(C, niv, i) {
  const R = C.R, ange = C.ange, nom = C.nom, coul = ange ? '#fff2c0' : '#ff2a1a', bonus = 1 + 0.2 * (niv - 1);
  const ang = joueur.angle + (i - 1) * 1.1, pos = pointLibrePres(V(joueur.pos.x + Math.sin(ang) * 3, 0, joueur.pos.z + Math.cos(ang) * 3), 0, 1.5);
  // mise en scène : colonne de lumière (ange) ou de flammes (démon), couleur de la rareté
  onde(pos, R.c, 3 + R.k, 0.6); onde(pos, coul, 2, 0.4);
  emettre(V(pos.x, 0.5, pos.z), { n: 40 + R.k * 40, c1: coul, c2: R.c, dir: V(0, 1, 0), vit: 8 + R.k * 3, disp: 0.6, rayon: 0.8, vie: 1.2, taille: 0.5 });
  if (R.k >= 3) ralenti(0.6, 0.3);
  son(R.k >= 3 ? 'jingle_legend' : 'forceField_000', R.k >= 3 ? 0.6 : 0.35, ange ? 1.4 : 0.7);
  const ipJ = statsHeros(J.equip).ip, st = joueur.st;
  const a = creerCombattant(pos, { nom, guilde: R.r.toUpperCase(), equip: genererEquipRival(ipJ, ange ? 'epee' : 'epee'), modele: ange ? 'Knight' : 'Barbarian' }, 'allie');
  UI.retirerPlaque(a);
  Object.assign(a, { invoc: 'pacte', vieT: R.vie, potions: 0, cdRempart: 1e9, specT: rnd(1, 3), ip: undefined, autonome: true, perso: 'loyal', modeA: 'explorer', modeT: 1e9, trait: 'tranquille', parlerT: 1e9, st: { ...a.st, vitesse: (a.st && a.st.vitesse || 5) * 1.35 } });
  a.pvMax = a.pv = Math.round(st.pvMax * R.k * bonus); a.dmg = st.degats * R.k * bonus; a.reduction = Math.min(0.6, st.reduction * 0.8);
  a.root.scale.setScalar(R.s); teinteSpectrale(a, ange ? '#fff0b0' : '#5a0008', R.k >= 1.7 ? 0.65 : 0.45);
  UI.plaque(a, { nom: (ange ? '✦ ' : '♆ ') + nom, guilde: `${'★'.repeat(niv)} ${R.r} · ${R.vie} s`, classe: 'allie pacte', vie: true, lettre: false });
  { const pl = a.root; const d = document.querySelector('#labels .plaque:last-child .n'); if (d) d.style.color = R.c; }
  a.jouer('Spellcast_Raise', { boucle: false, fin: () => a.jouer(a.armeDef.idle) });
  if (i === 0) UI.toast('Ton deck répond à l’appel', false);
}
function estPassant(e) { return !ennemis.includes(e) && (bots.includes(e) || (taverne && taverne.clients.includes(e))); }
function basculerAgression() {
  G.agression = !G.agression; const b = $('#btnAggro'); if (b) b.classList.toggle('actif', G.agression);
  UI.toast(G.agression ? '⚠ MODE AGRESSION : tu peux frapper n’importe qui. Chaque meurtre se paiera.' : 'Mode agression désactivé', G.agression);
  son(G.agression ? 'lowFrequency_explosion_000' : 'click_001', 0.4, 1.2);
}
const CRIS_PASSANTS = ['AU MEURTRE !', 'Il est devenu fou !', 'Gardes ! GARDES !', 'Courez !!', 'Tu vas le payer, ' + '{nom} !', 'Ma famille te le fera payer…'];
function blesserPassant(e, d) {
  if (e.mort) return;
  if (!e.pvMax) { e.pvMax = e.pv = Math.max(800, joueur.st.degats * 3.5); }
  e.pv -= d; e.frapper && e.frapper(); UI.nombre(V(e.pos.x, 2.2, e.pos.z), Math.round(d), '');
  emettre(V(e.pos.x, 1.2, e.pos.z), { n: 10, c1: '#ff6a5a', c2: '#5a0a0a', vit: 4, vie: 0.4, taille: 0.3, grav: 8 });
  if (!e.crieT || G.t > e.crieT) { e.crieT = G.t + 3; UI.parole && UI.parole(e, hasard(['Aïe ! Mais t’es malade ?!', 'Arrête ! ARRÊTE !', 'Pourquoi tu fais ça ?!']), 'peur'); }
  if (e.pv <= 0) tuerPassant(e);
}
function tuerPassant(e) {
  e.mort = true; e.jouer('Death_A', { boucle: false, forcer: true }); son('impactGeneric_light_000', 0.5, 0.6);
  J.haine = (J.haine || 0) + 1; J.victimes = [...(J.victimes || []), e.nom].slice(-20);
  const temoins = passantsProches().filter(x => x !== e && dist2D(x.pos, e.pos) < 18);
  for (const t of temoins.slice(0, 4)) { UI.parole && UI.parole(t, hasard(CRIS_PASSANTS).replace('{nom}', J.nom), 'peur'); t.regard = joueur.pos; }
  UI.chat('Système', `${J.nom} a tué ${e.nom || 'un passant'} de sang-froid.`);
  if (J.haine === 1) UI.toast('Les gens de la Place te regardent autrement… ils n’oublieront pas.', true);
  if (J.haine >= 3 && domaine() && !J.vengeance) { J.vengeance = { t: Date.now() + rnd(90, 180) * 1000, n: Math.min(30, 5 * J.haine) }; UI.toast('On murmure qu’une bande prépare une vengeance contre ton royaume…', true); }
  else if (J.vengeance) J.vengeance.n = Math.min(30, 5 * J.haine);
  const ee = e; programmer(4, () => { if (taverne && taverne.clients.includes(ee)) { G.scene.remove(ee.root); UI.retirerPlaque(ee); taverne.clients.splice(taverne.clients.indexOf(ee), 1); } else { ee.root.visible = false; UI.retirerPlaque(ee); programmer(60, () => { ee.mort = false; ee.pv = ee.pvMax; ee.root.visible = true; ee.jouer('Idle', { forcer: true }); }); } });
  sauver();
}
// la vengeance : une ombre vient te prévenir à genoux ; si tu n'es pas là pour défendre, ton royaume est pillé
function majVengeance() {
  const V0 = J.vengeance; if (!V0 || Date.now() < V0.t) return;
  if (!V0.prevenu) { V0.prevenu = true; V0.t = Date.now() + 120000; UI.manga([{ nom: 'Kael', titre: 'Ombre de ' + J.nom, modele: 'Rogue_Hooded', texte: `Maître… ${V0.n} hommes marchent sur ton royaume pour venger leurs morts. Dépêche-toi de venir, ou ils pilleront tout !`, couleur: '#b07aff', choc: true }]); son('lowFrequency_explosion_000', 0.6, 0.7); return; }
  if (modeActuel && modeActuel.id === 'domaine') { J.vengeance = null; attaqueVengeurs(V0.n); return; }
  // personne pour défendre : pillage
  J.vengeance = null; const d = domaine(); if (!d) return;
  const perdu = Math.floor(d.tresor * 0.6); d.tresor -= perdu; const morts = (d.serviteurs || []).splice(0, Math.ceil((d.serviteurs || []).length / 2));
  J.haine = Math.max(0, J.haine - 2); sauver();
  UI.manga([{ nom: 'Kael', titre: 'Ombre de ' + J.nom, modele: 'Rogue_Hooded', texte: `Trop tard, maître… Ils ont pillé ${fmtN(perdu)} ¤ du trésor${morts.length ? ` et tué ${morts.length} de tes serviteurs. Il faudra les recruter à nouveau` : ''}.`, couleur: '#ff5a5a', choc: true }]);
}
function attaqueVengeurs(n) {
  UI.toast(`LES VENGEURS ATTAQUENT : ${n} assaillants !`, true); UI.flashInvasion && UI.flashInvasion(); son('lowFrequency_explosion_000', 0.7, 0.7);
  const ipJ = statsHeros(J.equip).ip, vagues = Math.ceil(n / 8); let reste = n;
  const vague = (k) => { if (!modeActuel || modeActuel.id !== 'domaine') return; const nb = Math.min(8, reste); reste -= nb;
    for (let i = 0; i < nb; i++) { const d = donneesBot(ipJ * rnd(0.55, 0.85)); d.guilde = 'VENGEURS'; const p = pointLibrePres(V(rnd(-20, 20), 0, 32), 0, 6); const v = creerCombattant(p, d, 'ennemi'); v.voleur = true; v.potions = 0; effetArrivee(p); }
    if (reste > 0) programmer(25, () => vague(k + 1)); };
  vague(0);
}
// ---------------- Ranger / sortir les armes ----------------
// la lame disparaît dans un nuage d'étincelles ; on se bat aux sorts et à la magie pure, puis on la ressort quand on veut
function noeudsArme() { const d = joueur.def; return [d.node, d.node2].filter(Boolean).map(n => joueur.nodes[n] || joueur.nodes[n.replace(/\./g, '')]).filter(Boolean); }
function rangerArmes(ranger = !joueur.rangee) {
  if (!joueur || joueur.mort) return;
  joueur.rangee = ranger; G.armesRangees = ranger;
  const main = noeudsArme()[0], p = V(); if (main) main.getWorldPosition(p); else p.set(joueur.pos.x, 1.2, joueur.pos.z);
  joueur.jouer('Interact', { boucle: false, forcer: true, vitesse: 1.5, fin: () => joueur.jouer(ranger ? 'Idle' : joueur.def.idle) });
  programmer(0.28, () => {
    for (const n of noeudsArme()) n.visible = !ranger;
    if (main) main.getWorldPosition(p);
    emettre(p, { n: 26, c1: '#fff2c0', c2: ranger ? '#9a6aff' : TIERS[J.equip.arme.tier].color, vit: 3.2, vie: 0.6, taille: 0.3 });
    son(ranger ? 'cloth1' : 'drawKnife2', 0.45, ranger ? 1.2 : 1);
  });
  UI.toast(ranger ? 'Armes rangées : tu combats à la magie' : 'Armes en main');
  const b = $('#btnArmes'); if (b) b.classList.toggle('actif', ranger);
}
// ---------------- Sorts par signes ----------------
const COUL_SIGNE = { epee: '#ffd27a', arbalete: '#9aff7a', baton: '#ff8a3a', ombre: '#b07aff', orage: '#7ab8ff', assassin: '#ff4a5a', demon: '#ff1a2a', invocateur: '#ffe08a' };
G.gestes = false; // sorts par signes retirés : boutons classiques
function ralenti(duree, k) { if (G._parOmbre) return; G.ralentiT = Math.max(G.ralentiT || 0, duree); G.ralentiK = k; }
function cibleEcran(x, y, rayon) {
  let best = null, bd = rayon;
  for (const en of vivants()) { const s = projeter(V(en.pos.x, 1.2, en.pos.z)); if (!s.visible) continue; const d = Math.hypot(s.x - x, s.y - y); if (d < bd) { bd = d; best = en; } }
  return best;
}
function lancerParSigne(cle, debut, centre) {
  if (!joueur || joueur.mort) return false;
  const s = joueur.sorts[cle];
  if (!s) { UI.toast('Aucun sort sur ce signe'); return false; }
  if ((joueur.cds[cle] || 0) > 0) { UI.toast(`${s.nom} : encore ${Math.ceil(joueur.cds[cle])} s`); son('error_001', 0.25); return false; }
  if (joueur.energie < s.energie) { UI.toast('Pas assez d’énergie'); son('error_001', 0.25); return false; }
  if (arene && arene.t > 0) return false;
  // l'ennemi sur lequel on a dessiné devient la cible
  const c = cibleEcran(debut[0], debut[1], 120) || cibleEcran(centre[0], centre[1], 150) || (joueur.cibleVerrou && !joueur.cibleVerrou.mort ? joueur.cibleVerrou : null) || choisirCible(18);
  if (c) joueur.cibleVerrou = c;
  son('forceField_000', 0.25, 1.8);
  const lancer = () => { viseeForcee = c ? { cible: c } : null; lancerSort(cle); viseeForcee = null; };
  bondStyle(c, lancer);
  return true;
}
// saut acrobatique avant le sort : les combattants bondissent sur la cible, les tireurs font une vrille en arrière
function bondStyle(c, apres) {
  const type = J.equip.arme ? J.equip.arme.type : 'epee';
  const melee = ['epee', 'orage', 'assassin', 'ombre', 'demon'].includes(type);
  const dep = joueur.pos.clone();
  let arr = null;
  if (c && melee) { const d = dist2D(c.pos, dep); if (d > 3.2 && d < 16) { const dir = V(c.pos.x - dep.x, 0, c.pos.z - dep.z).normalize(); arr = pointLibreProche(V(c.pos.x - dir.x * (c.rayon + 1.4), 0, c.pos.z - dir.z * (c.rayon + 1.4)), 0.6); } }
  if (!melee) { const ang = c ? Math.atan2(c.pos.x - dep.x, c.pos.z - dep.z) : joueur.angle; arr = pointLibreProche(V(dep.x - Math.sin(ang) * 2.6, 0, dep.z - Math.cos(ang) * 2.6), 0.6); if (c) { joueur.angle = ang; joueur.root.rotation.y = ang; } }
  if (!arr) { apres(); ralenti(0.06, 0.15); return; }
  const duree = melee ? 0.34 : 0.3, haut = melee ? 2.6 : 1.4;
  joueur.verrouAtk = false; joueur.verrouT = Math.max(joueur.verrouT, duree); joueur.invuln = Math.max(joueur.invuln, duree + 0.1);
  if (melee) { joueur.angle = Math.atan2(arr.x - dep.x, arr.z - dep.z); joueur.root.rotation.y = joueur.angle; }
  joueur.jouer(melee ? 'Dodge_Forward' : 'Dodge_Backward', { boucle: false, forcer: true, vitesse: 1.7 });
  const coul = COUL_SIGNE[type] || '#ffd27a';
  son('cloth1', 0.5, 1.3);
  const jB = joueur;
  ajouterVfx(new THREE.Group(), (t) => {
    if (joueur !== jB) return false;
    const k = Math.min(1, t / duree), e = k * k * (3 - 2 * k);
    joueur.pos.x = dep.x + (arr.x - dep.x) * e; joueur.pos.z = dep.z + (arr.z - dep.z) * e;
    joueur.root.position.y = Math.sin(k * Math.PI) * haut;
    if (melee) joueur.model.rotation.x = Math.sin(k * Math.PI) * -0.5; // corps penché en plein saut
    emettre(V(joueur.pos.x, 0.9 + joueur.root.position.y, joueur.pos.z), { n: 3, c1: '#ffffff', c2: coul, vit: 0.8, vie: 0.35, taille: 0.5, rayon: 0.4 });
    if (k >= 1) {
      joueur.root.position.y = 0; joueur.model.rotation.x = 0;
      onde(arr, coul, melee ? 5 : 3, 0.45); emettre(V(arr.x, 0.3, arr.z), { n: 40, c1: '#ffffff', c2: coul, vit: 7, vie: 0.6, taille: 0.45, hemi: true, grav: 5 });
      G.shake = Math.max(G.shake, melee ? 0.55 : 0.25); ralenti(0.07, 0.12);
      apres(); return false;
    }
  });
}
// ---------------- Abîme : le sol explose sous les pieds chaque seconde ----------------
function majAbime(dt) {
  if (!modeActuel || !modeActuel.abime || !joueur || joueur.mort) return;
  G.abimeT = (G.abimeT || 0) - dt; if (G.abimeT > 0) return; G.abimeT = 1;
  let src = null, bd = 30; for (const e of ennemis) { if (e.mort || PAISIBLES.includes(e.etat)) continue; const d = dist2D(e.pos, joueur.pos); if (d < bd) { bd = d; src = e; } }
  if (!src) return;
  const n = src.boss ? 3 : 1;
  for (let i = 0; i < n; i++) {
    const a = Math.random() * 6.28, r0 = i === 0 ? rnd(0, 1.2) : rnd(3, 7);
    const p = V(joueur.pos.x + Math.cos(a) * r0, 0, joueur.pos.z + Math.sin(a) * r0);
    const R = src.boss ? rnd(4.5, 6.5) : rnd(3.2, 4.4);
    tele(p, R, 0.85, '#ff1a3a', () => { if (src.mort && !src.boss) return; onde(p, '#ff2a4a', R + 1, 0.4); emettre(V(p.x, 0.4, p.z), { n: 40, c1: '#ffd0d8', c2: '#ff0a2a', vit: 8, vie: 0.6, taille: 0.6, hemi: true }); son('explosionCrunch_000', 0.25, 1.3); toucherZone(src, p, R, src.dmg * (src.boss ? 2.6 : 1.8)); });
  }
}
// ---------------- Mode auto ----------------
function pvpActif() {
  if (arene || goulet) return true;
  if (invasion && !invasion.fini && (invasion.mode === 'menee' || (invasion.rivaux || []).some(r => !r.mort) || invasion.rival && !invasion.rival.mort)) return true;
  return ennemis.some(e => e.rival && !e.mission && !e.mort);
}
function couperAuto(msg) {
  G.auto = false; try { localStorage.setItem('breche-auto', '0'); } catch (e) {}
  if (joueur) joueur.autoCible = null;
  UI.toast(msg); const b = document.getElementById('btnAuto'); if (b) b.classList.remove('on');
}
function dangerAuto(p, marge) { for (const z of dangers) { if (z.camp === 'allie' || z.camp === 'joueur') continue; const dx = p.x - z.p.x, dz = p.z - z.p.z; if (dx * dx + dz * dz < (z.r + marge) ** 2) return z; } return null; }
function cibleAuto(j) {
  let best = null, bd = 1e9;
  for (const e of ennemis) {
    if (e.mort || e.camp === 'allie' || e.camp === 'joueur' || e.furtifT > 0 || e.pnj) continue;
    const d = dist2D(e.pos, j.pos);
    const sc = d + (e.boss && d > 12 ? 40 : 0) + (d > 32 ? 20 : 0);
    if (sc < bd) { bd = sc; best = e; }
  }
  return best;
}
function modeAuto(j, dt, bloque) {
  j.autoT = (j.autoT || 0) - dt;
  if (j.autoT <= 0 || !j.autoCible || j.autoCible.mort) { j.autoT = 0.35; j.autoCible = cibleAuto(j); }
  if (j.pv < j.st.pvMax * 0.35 && j.potions > 0 && !(j.cds.POT > 0) && j.potionT <= 0) boirePotion();
  const v = j.st.vitesse * (1 + bonusParch('vitesse')) * (j.orageT > 0 ? 1.4 : 1) * (j.sprintT > 0 ? 1.6 : 1) * (j.slowT > 0 ? 0.6 : 1);
  // esquive des zones rouges
  const z = bloque ? null : dangerAuto(j.pos, 0.9);
  if (z) {
    const dir = V(j.pos.x - z.p.x, 0, j.pos.z - z.p.z); if (dir.lengthSq() < 0.01) dir.set(Math.sin(j.angle + 1.57), 0, Math.cos(j.angle + 1.57)); dir.normalize();
    let ok = false;
    for (const k of [0, 0.7, -0.7, 1.4, -1.4, 2.2, -2.2]) {
      const a = Math.atan2(dir.x, dir.z) + k, dx = Math.sin(a) * v * dt, dz = Math.cos(a) * v * dt;
      const np = V(j.pos.x + Math.sin(a) * 1.5, 0, j.pos.z + Math.cos(a) * 1.5);
      if (!libre(np.x, np.z, 0.5)) continue;
      const ax = j.pos.x, az = j.pos.z; deplacer(j, dx, dz);
      if (Math.hypot(j.pos.x - ax, j.pos.z - az) > v * dt * 0.3) { ok = true; j.angle = tourner(j.angle, a, dt * 14); j.root.rotation.y = j.angle; break; }
    }
    if (ok) { j.jouer(j.def.run); return false; }
  }
  const c = j.autoCible; if (!c) return false;
  j.cible = c;
  const d = dist2D(c.pos, j.pos) - c.rayon;
  if (d > j.st.portee * 0.9 && !bloque && !(j.spinT > 0 || j.tornadeT > 0)) {
    const ax = j.pos.x, az = j.pos.z;
    allerVers(j, c.pos, dt, v);
    if (dangerAuto(j.pos, 0.6)) { j.pos.x = ax; j.pos.z = az; j.jouer(j.def.idle); return false; } // n'entre pas dans une zone rouge
    const mx = j.pos.x - ax, mz = j.pos.z - az;
    if (mx * mx + mz * mz > 1e-6) { j.angle = tourner(j.angle, Math.atan2(mx, mz), dt * 12); j.root.rotation.y = j.angle; }
    j.jouer(j.def.run);
  }
  const aPortee = d <= j.st.portee + 0.3;
  // sorts : un toutes les ~0,6 s, quand la cible est à portée
  j.autoSortT = (j.autoSortT || 0) - dt;
  if (j.autoSortT <= 0 && !j.sortAttente && j.verrouT <= 0.15) {
    j.autoSortT = 0.6;
    const ordre = ['W', 'E', 'Q'];
    if (j.sorts.R && j.pv < j.st.pvMax * 0.5) ordre.unshift('R');
    for (const k of ordre) {
      const s = j.sorts[k]; if (!s || (j.cds[k] || 0) > 0 || j.energie < s.energie) continue;
      const portee = s.portee > 0 ? s.portee : 6;
      if (k !== 'R' && d > portee + 1) continue;
      if (s.id === 'curee' && (j.combo || 0) < 4) continue;
      lancerSort(k); break;
    }
  }
  return aPortee;
}
