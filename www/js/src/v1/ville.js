// ======================= LA VILLE À PROTÉGER (V1) : habitants, raids, enlèvements, deuil =======================
// Chaque habitant a un nom et un métier. Les morts restent morts. Les enlevés restent enlevés.
const MODE_VILLE = { id: 'ville', nom: 'Ville', lieu: 'Place des Cendres', argent: 1, xp: 1, tiers: [1, 2], mobTier: 1 };
const NOMS_VILLE = ['Mira', 'Aldric', 'Jehanne', 'Bastien', 'Isaure', 'Gaspard', 'Elise', 'Thibaut', 'Clémence', 'Roland', 'Agathe', 'Martin', 'Brune', 'Odon', 'Perrine', 'Hugues', 'Sibylle', 'Gautier', 'Aelis', 'Renaud', 'Ombeline', 'Tristan', 'Mahaut', 'Lancelin'];
const METIERS_VILLE = [['boulanger|boulangère', 'Mage'], ['forgeron|forgeronne', 'Barbarian'], ['tisserand|tisserande', 'Rogue'], ['tanneur|tanneuse', 'Barbarian'], ['herboriste|herboriste', 'Mage'], ['charpentier|charpentière', 'Knight'], ['marchand|marchande', 'Rogue_Hooded'], ['meunier|meunière', 'Knight'], ['brasseur|brasseuse', 'Rogue'], ['sonneur de cloches|sonneuse de cloches', 'Knight'], ['potier|potière', 'Mage'], ['pêcheur|pêcheuse', 'Rogue_Hooded']];
const FEMININS = new Set(['Mira', 'Jehanne', 'Isaure', 'Elise', 'Clémence', 'Agathe', 'Brune', 'Perrine', 'Sibylle', 'Aelis', 'Ombeline', 'Mahaut']);
const metierDe = (m, nom) => m.split('|')[FEMININS.has(nom) ? 1 : 0];
const deLieu = (l) => l.replace(/^les /, 'des ').replace(/^le /, 'du ').replace(/^(la |l’)/, 'de $1');
const CRIS_PEUR = ['Au secours !', 'Les monstres ! Fuyez !', 'À l’aide, par pitié !', 'Ils sont là !', 'Protégez-nous !', 'Courez !'];
const CRIS_DEUIL = ['Non… pas {n}…', '{n} ! NON !', 'Ils ont tué {n}…', 'Où étais-tu quand {n} est tombé·e ?', '{n} ne méritait pas ça…'];
const MERCI = ['Merci… je croyais que c’était fini.', 'Tu m’as sauvé la vie !', 'Je ne l’oublierai jamais.', 'Que les dieux te gardent !'];
let citoyens = [], raidV = null, prochainRaidV = 0;
function etatVille() {
  if (!J.ville) {
    const noms = [...NOMS_VILLE].sort(() => Math.random() - 0.5);
    J.ville = { moral: 70, raids: 0, journal: [], arrivee: 0, gens: noms.slice(0, 14).map((nom, i) => ({ id: i + 1, nom, metier: metierDe(METIERS_VILLE[i % METIERS_VILLE.length][0], nom), modele: METIERS_VILLE[i % METIERS_VILLE.length][1], statut: 'vivant' })) };
  }
  return J.ville;
}
function journalVille(t) { const v = etatVille(); v.journal.unshift({ t: Date.now(), txt: t }); v.journal.length = Math.min(v.journal.length, 12); }
function majBandeauVille() {
  if (!modeActuel || modeActuel.id !== 'ville') return;
  const v = etatVille(), n = v.gens.filter(g => g.statut === 'vivant').length;
  UI.zone('Place des Cendres', `👥 ${n} · ♥ ${Math.round(v.moral)}%${raidV ? ' · ⚠ RAID' : ''}`);
}
function moralVille(d) { const v = etatVille(); v.moral = Math.max(0, Math.min(100, v.moral + d)); majBandeauVille(); }
function creerCitoyens() {
  const v = etatVille();
  // un nouveau venu s'installe de temps en temps si la ville se vide
  const vivantsN = v.gens.filter(g => g.statut === 'vivant').length;
  if (vivantsN < 10 && Date.now() > (v.arrivee || 0)) {
    const pris = new Set(v.gens.map(g => g.nom)); const nom = NOMS_VILLE.find(n => !pris.has(n)) || ('Voyageur ' + (v.gens.length + 1));
    const m = hasard(METIERS_VILLE), met = metierDe(m[0], nom); v.gens.push({ id: v.gens.length + 1, nom, metier: met, modele: m[1], statut: 'vivant' });
    v.arrivee = Date.now() + 15 * 60000; journalVille(`${nom}, ${met}, s’installe sur la Place.`);
    programmer(3, () => UI.toast(`${nom} (${met}) s’installe dans ta ville`));
  }
  citoyens = [];
  for (const g of v.gens) {
    if (g.statut !== 'vivant') continue;
    const a = new Acteur(g.modele, { hauteur: 1.95 });
    a.montrerSeul([], Object.keys(a.nodes).filter(n => /Sword|Axe|Shield|Crossbow|Staff|Wand|Knife|Throwable|Spellbook|Offhand/.test(n)));
    let p, k = 0; do { p = V(rnd(-24, 22), 0, rnd(-20, 20)); } while (!libre(p.x, p.z, 0.6) && ++k < 30);
    a.root.position.copy(p); a.root.rotation.y = rnd(0, 6.28); G.scene.add(a.root);
    Object.assign(a, { g, pos: a.root.position, angle: a.root.rotation.y, etat: 'flane', t: rnd(0, 5), but: null, coups: 3, criT: 0, hauteurPlaque: 2.5, citoyen: true });
    a.jouer(Math.random() < 0.3 ? 'Sit_Floor_Idle' : 'Idle');
    UI.plaque(a, { nom: g.nom, guilde: g.metier.toUpperCase(), classe: 'pnj', vie: false, lettre: false });
    citoyens.push(a);
  }
}
function viderVille() { finDuel(); viderPortailVille(); if (raidV && raidV.beam) G.scene.remove(raidV.beam); { const b = $('#btnRoyaume'); if (b) b.hidden = true; } finirCaptif(); compActeurs = []; for (const c of citoyens) { G.scene.remove(c.root); UI.retirerPlaque(c); } citoyens = []; raidV = null; }
function pillards() { return ennemis.filter(e => e.raidV && !e.mort && !e.parti); }
function majCitoyens(dt) {
  const P = pillards(); // une seule fois par image
  for (const c of citoyens) {
    if (c.etat === 'mort' || c.etat === 'parti') { c.maj(dt); continue; }
    if (c.etat === 'capture') { const r = c.porteur; if (r) { c.pos.set(r.pos.x - Math.sin(r.angle) * 0.9, 0, r.pos.z - Math.cos(r.angle) * 0.9); c.angle = r.angle; c.root.rotation.y = r.angle; } c.jouer('Hit_A'); c.maj(dt); continue; }
    c.criT -= dt;
    // la peur : le monstre le plus proche
    let m = null, md = 11; for (const e of P) { const d = dist2D(e.pos, c.pos); if (d < md) { md = d; m = e; } }
    if (m) {
      if (c.etat !== 'fuite') { c.etat = 'fuite'; if (c.criT <= 0) { c.criT = 6; UI.parole(c, hasard(CRIS_PEUR), 'menace'); } }
      const dir = V(c.pos.x - m.pos.x, 0, c.pos.z - m.pos.z).normalize();
      const dest = V(c.pos.x + dir.x * 6, 0, c.pos.z + dir.z * 6);
      avancerVers(c, dest, dt, 3.4); c.jouer('Running_A');
    } else {
      if (c.etat === 'fuite') { c.etat = 'flane'; c.t = rnd(2, 4); c.but = null; }
      c.t -= dt;
      if (c.but) { if (dist2D(c.pos, c.but) < 0.8) { c.but = null; c.t = rnd(3, 8); c.jouer(Math.random() < 0.25 ? 'Sit_Floor_Idle' : 'Idle'); } else { avancerVers(c, c.but, dt, 1.5); c.jouer('Walking_A'); } }
      else if (c.t <= 0) { let p, k = 0; do { p = V(c.pos.x + rnd(-10, 10), 0, c.pos.z + rnd(-10, 10)); } while (!libre(p.x, p.z, 0.6) && ++k < 12); if (k < 12) c.but = p; else c.t = 2; }
      const dj = dist2D(c.pos, joueur.pos); if (dj < 3 && !c.but) { c.angle = tourner(c.angle, Math.atan2(joueur.pos.x - c.pos.x, joueur.pos.z - c.pos.z), dt * 5); c.root.rotation.y = c.angle; }
    }
    if (dist2D(c.pos, joueur.pos) < 60) c.maj(dt);
  }
}
function mortCitoyen(c, tueur) {
  c.etat = 'mort'; c.g.statut = 'mort'; c.jouer('Death_A', { boucle: false, fondu: 0.1 });
  emettre(V(c.pos.x, 1, c.pos.z), { n: 26, c1: '#ff3a3a', c2: '#6a0a0a', vit: 4, vie: 0.8, taille: 0.3, grav: 8 });
  son('lowFrequency_explosion_000', 0.5, 1.3);
  UI.toast(`${c.g.nom}, ${c.g.metier}, a été tué·e`, true);
  journalVille(`${c.g.nom} (${c.g.metier}) a été tué·e par ${tueur.def.nom.toLowerCase()} pendant le raid.`);
  if (raidV) raidV.morts.push(c.g.nom);
  moralVille(-12);
  // ceux qui l'ont vu tomber
  const temoin = citoyens.find(x => x !== c && x.etat !== 'mort' && x.etat !== 'capture' && dist2D(x.pos, c.pos) < 16);
  if (temoin) programmer(1.2, () => UI.parole(temoin, hasard(CRIS_DEUIL).split('{n}').join(c.g.nom)));
  setTimeout(() => { if (citoyens.includes(c)) { UI.retirerPlaque(c); c.descendre = true; } }, 4000);
  programmer(6, () => { if (modeActuel && modeActuel.id === 'ville') construireCimetiere(); });
  sauver();
}
function lancerRaidVille() {
  const v = etatVille(); v.raids++;
  const ip = statsHeros(J.equip).ip, tier = Math.max(1, Math.min(8, (ip - 300) / 100 + 1)) * 0.9;
  const tr = v.traitre ? parId(v.traitre) : null; if (tr) { delete v.traitre; UI.toast(`${tr.nom} a ouvert la porte : le raid est massif !`, true); }
  const n = Math.max(3, Math.min(11, 4 + Math.floor(v.raids / 2) - (v.fortif || 0) + (tr ? 3 : 0))), entree = hasard(monde.entreesVille);
  raidV = { entree, morts: [], enleves: [], sauves: 0, n, beam: colonneLumiere(entree, '#ff3a2a') };
  UI.toast(`ALERTE — des cultistes attaquent (${directionDe(entree)}) — colonne rouge !`, true); UI.flashInvasion && UI.flashInvasion();
  son('lowFrequency_explosion_000', 0.7, 0.7); G.shake = 0.4;
  for (let i = 0; i < n; i++) {
    const cle = i < 2 ? 'cultiste' : hasard(['minion', 'guerrier', 'brute', 'cultiste']);
    const p = pointLibrePres(entree, 0, 4);
    const e = creerEnnemi(MOBS[cle], p, tier, 900 + v.raids); e.raidV = true; e.etat = 'chasse'; e.ravisseur = i < 2; e.cibleCit = null;
    if (e.ravisseur) UI.plaque(e, { nom: 'Ravisseur', classe: 'ennemi', lettre: false });
    effetArrivee(p);
  }
  if (v.raids >= 2) {
    const anciens = rivaux().filter(x => x.issue !== 'tue'), rv = anciens.length && Math.random() < 0.4 ? hasard(anciens) : null;
    const p = pointLibrePres(entree, 0, 4), nomC = rv ? rv.nom : hasard(['Gorvak le Brutal', 'Skarn le Moqueur', 'Brakka Sang-Fier', 'Vorth l’Insolent', 'Ulgra la Sourde', 'Kethe Œil-Rouge']);
    const e = creerEnnemi(MOBS.brute, p, tier * 1.3, 900 + v.raids); e.raidV = true; e.champion = true; e.nomChampion = nomC; e.etat = 'chasse'; e.persoC = rv ? rv.perso : hasard(['arrogant', 'arrogant', 'prudent', 'fanatique']); e.revenu = rv ? rv.issue : null;
    e.pvMax = e.pv = e.pvMax * (rv ? 5.2 : 4); e.dmg *= rv ? 3.6 : 3; e.root.scale.multiplyScalar(1.35); e.hauteurPlaque *= 1.35;
    UI.retirerPlaque(e); UI.plaque(e, { nom: nomC, classe: 'ennemi', lettre: false }); effetArrivee(p);
    programmer(1.5, () => { if (!e.mort) UI.parole(e, rv ? `GARDIEN ! ${nomC.split(' ')[0]} est revenu !` : hasard(OUVERTURES[e.persoC]), 'menace'); });
  }
  majBandeauVille();
}
// renvoie true si le pillard s'occupe des habitants (sinon combat normal contre toi et tes ombres)
function majPillardVille(e, d, dt) {
  if (e.parle) { e.jouer('Idle'); e.angle = tourner(e.angle, Math.atan2(joueur.pos.x - e.pos.x, joueur.pos.z - e.pos.z), dt * 6); e.root.rotation.y = e.angle; return true; }
  if (e.retraite) { // on le voit littéralement partir
    const sortie = raidV ? raidV.entree : e.pos; allerVers(e, sortie, dt, e.def.vitesse * 0.9); e.jouer('Running_A');
    if (dist2D(e.pos, sortie) < 2.5) { e.parti = true; e.root.visible = false; UI.retirerPlaque(e); effetArrivee(e.pos.clone()); }
    return true;
  }
  if (e.champion) { majChampion(e); return e.parle; } // le champion cherche le combat : toi et tes ombres
  if (e.pv < e.pvMax && !e.porte && d < 14) return false; // tu l'as provoqué : il se retourne contre toi
  if (d < 4.5 && !e.porte) return false;
  if (e.porte) { // il emporte un habitant vers la sortie
    allerVers(e, raidV ? raidV.entree : e.pos, dt, e.def.vitesse * 0.75); e.jouer('Running_A');
    if (!raidV || dist2D(e.pos, raidV.entree) < 2.5) {
      const c = e.porte; c.etat = 'parti'; c.g.statut = 'enleve'; c.g.enleveLe = Date.now(); c.g.lieu = Math.floor(Math.random() * 3); c.root.visible = false; UI.retirerPlaque(c);
      e.parti = true; e.root.visible = false; UI.retirerPlaque(e); effetArrivee(e.pos.clone());
      UI.toast(`${c.g.nom} a été enlevé·e par les cultistes !`, true); journalVille(`${c.g.nom} (${c.g.metier}) a été enlevé·e et emmené·e dans la Brèche.`);
      if (raidV) raidV.enleves.push(c.g.nom); moralVille(-8); sauver();
    }
    return true;
  }
  if (!e.cibleCit || e.cibleCit.etat === 'mort' || e.cibleCit.etat === 'capture' || e.cibleCit.etat === 'parti' || (e.choixT = (e.choixT || 0) - dt) <= 0) {
    e.choixT = 1.5; let best = null, bd = Infinity;
    for (const c of citoyens) { if (c.etat === 'mort' || c.etat === 'capture' || c.etat === 'parti') continue; const dc = dist2D(c.pos, e.pos); if (dc < bd) { bd = dc; best = c; } }
    e.cibleCit = best;
  }
  const c = e.cibleCit; if (!c) return false;
  const dc = dist2D(c.pos, e.pos);
  if (dc > 1.7) { allerVers(e, c.pos, dt, e.def.vitesse * 1.05); e.jouer('Running_A'); return true; }
  e.angle = tourner(e.angle, Math.atan2(c.pos.x - e.pos.x, c.pos.z - e.pos.z), dt * 10); e.root.rotation.y = e.angle;
  if (e.atkT > 0) { e.jouer('Idle_Combat'); return true; }
  e.atkT = 1.3;
  if (e.ravisseur) { c.etat = 'capture'; c.porteur = e; e.porte = c; UI.parole(c, hasard(['Lâchez-moi !', 'NON ! Aidez-moi !', 'Au secours !']), 'menace'); UI.toast(`${c.g.nom} est emporté·e ! Rattrape le ravisseur !`, true); son('cloth1', 0.6); return true; }
  e.jouer(e.def.atk, { boucle: false, forcer: true, fin: () => e.jouer('Idle_Combat') });
  programmer(0.4, () => { if (e.mort || c.etat === 'mort' || c.etat === 'capture') return; c.coups--; emettre(V(c.pos.x, 1.2, c.pos.z), { n: 10, c1: '#ff6a6a', c2: '#8a1a1a', vit: 3, vie: 0.4, taille: 0.22, grav: 8 }); son('impactGeneric_light_000', 0.4, 1.2); if (c.coups <= 0) mortCitoyen(c, e); else if (c.criT <= 0) { c.criT = 4; UI.parole(c, hasard(CRIS_PEUR), 'menace'); } });
  return true;
}
function finPillard(e) {
  if (!e.porte) return;
  const c = e.porte; e.porte = null; c.porteur = null; c.etat = 'flane'; c.t = 3; c.coups = Math.max(1, c.coups);
  if (raidV) raidV.sauves++; moralVille(4);
  journalVille(`Tu as arraché ${c.g.nom} aux mains d’un ravisseur.`);
  programmer(0.8, () => UI.parole(c, hasard(MERCI))); UI.toast(`${c.g.nom} est sauvé·e !`, true); son('jingle_win', 0.5);
}
function majVille(dt) {
  majCitoyens(dt); majRoyaume(); majPortailVille(dt);
  if (!raidV) { if (G.t > prochainRaidV && !transition) lancerRaidVille(); return; }
  if (pillards().length) return;
  // bilan du raid
  const R = raidV; raidV = null; finDuel(); if (R.beam) G.scene.remove(R.beam); prochainRaidV = G.t + rnd(150, 240) + 30 * (royaume().fortif || 0);
  const pertes = R.morts.length + R.enleves.length;
  if (!pertes) { moralVille(6); J.argent += 400 * R.n; journalVille(`Raid repoussé sans perte (${R.n} assaillants).`); }
  else journalVille(`Raid repoussé. Morts : ${R.morts.join(', ') || 'aucun'}. Enlevés : ${R.enleves.join(', ') || 'aucun'}.`);
  const L = [`${R.n} assaillants`, R.sauves ? `${R.sauves} habitant(s) arraché(s) aux ravisseurs` : null, R.morts.length ? `Morts : ${R.morts.join(', ')}` : null, R.enleves.length ? `Enlevés : ${R.enleves.join(', ')}` : null, !pertes ? `Aucune perte · +${fmtN(400 * R.n)} ¤ offerts par les habitants` : null].filter(Boolean);
  UI.journal(pertes ? 'La ville est en deuil' : 'La ville est sauve', L.join(' · '));
  UI.toast(pertes ? `Raid terminé — ${pertes} habitant(s) perdu(s)` : 'Raid repoussé, aucune perte !', true);
  son(pertes ? 'lowFrequency_explosion_000' : 'jingle_win', 0.5, pertes ? 0.6 : 1);
  if (pertes) { const s = citoyens.find(c => c.etat === 'flane'); if (s) programmer(2, () => UI.parole(s, pertes > 1 ? 'Tant de morts… La Brèche nous dévorera tous.' : 'On l’enterrera ce soir…')); }
  majBandeauVille(); sauver();
}

