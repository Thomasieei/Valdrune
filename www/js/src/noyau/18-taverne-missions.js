// ======================= TAVERNE DU CROC-ROUGE, PUISSANCE DISSIMULÉE ET MISSIONS =======================
let taverne = null, mission = null;
const ipReel = () => (joueur && joueur.st ? joueur.st.ip : statsHeros(J.equip).ip);
const ipAffiche = () => J.dissimule ? Math.max(100, Math.round(ipReel() * 0.3)) : ipReel();
function majAffichagePuissance() {
  if (!joueur) return;
  UI.retirerPlaque(joueur);
  const tR = titreRenom(); joueur.estJoueur = true; UI.plaque(joueur, { nom: J.nom, guilde: 'CROW ZERO' + (tR.i ? ` · <span class="titreR" style="color:${tR.c}">${tR.nom}</span>` : ''), classe: 'allie joueur moi' + (J.dissimule ? ' dissimule' : ''), vie: false, ip: ipAffiche() });
  $('#ipHud').textContent = `Niv. ${niveauHeros(J.equip)} · ⚔ ${J.dissimule ? ipAffiche() + ' ?' : ipReel()}`;
  UI.boutonReveler(!!J.dissimule, () => revelerPuissance());
}
function dissimuler(oui) {
  J.dissimule = !!oui; sauver(); majAffichagePuissance();
  UI.toast(oui ? 'Puissance dissimulée : les autres te voient à peine à 30 %' : 'Ta puissance est de nouveau visible');
}
// ---- l'éveil : la révélation de ta vraie force ----
function majEveil(dt) {
  if (!joueur || !(joueur.eveilT > 0)) return;
  joueur.eveilT -= dt;
  if (Math.random() < dt * 30) emettre(V(joueur.pos.x + rnd(-0.6, 0.6), 0.2, joueur.pos.z + rnd(-0.6, 0.6)), { n: 1, c1: '#fff0c0', c2: '#ff2a1a', dir: V(0, 1, 0), vit: 4, disp: 0.6, vie: 0.7, taille: 0.45 });
  if (joueur.eveilT <= 0) UI.toast('L’éveil se dissipe');
}
function revelerPuissance() {
  if (!joueur || joueur.mort) return;
  if (!J.dissimule) { UI.toast('Ta puissance est déjà visible de tous'); return; }
  J.dissimule = false; sauver();
  const p = joueur.pos.clone();
  // mise en scène : ralenti, onde de choc, colonne d'aura, écran qui tremble
  ralenti(1.1, 0.22); G.shake = 1.1; UI.intention('#ffb02a');
  for (let k = 0; k < 3; k++) programmer(k * 0.12, () => onde(p, k === 1 ? '#ffffff' : '#ff3a1a', 9 + k * 4, 0.7));
  emettre(V(p.x, 0.5, p.z), { n: 160, c1: '#fff4c0', c2: '#ff2a1a', vit: 12, vie: 1.1, taille: 0.6, hemi: true });
  emettre(V(p.x, 1, p.z), { n: 80, c1: '#ffffff', c2: '#ffb02a', dir: V(0, 1, 0), vit: 14, disp: 0.8, vie: 1.2, taille: 0.5 });
  lueurSol(p, '#ff6a1a', 6, 1.4, 1); son('lowFrequency_explosion_000', 0.8, 0.6); cor('pris');
  const pret = !(J.eveilPret > Date.now());
  if (pret) { joueur.eveilT = 15; J.eveilPret = Date.now() + 120000; UI.toast('ÉVEIL : +30 % de dégâts, +15 % de vitesse · 15 s', true); }
  majAffichagePuissance();
  // réactions de tous ceux qui t'ont vu
  const temoins = [...(taverne ? taverne.clients : []), ...allies.filter(a => !a.mort && !a.loup), ...ennemis.filter(e => !e.mort && e.combattant)].filter(x => dist2D(x.pos, p) < 22);
  const ipJ = ipReel(); let plusFort = null;
  temoins.forEach((x, i) => {
    const sonIp = x.ip || (x.data && x.data.ip) || 0;
    if (sonIp > ipJ * 1.05 && x.rivalTaverne) { plusFort = x; return; }
    programmer(0.5 + i * 0.25, () => { if (x.mort) return; UI.parole(x, hasard(TAVERNE_LIGNES.choc), 'choc'); });
    if (taverne && x.client) { programmer(1.8 + i * 0.3, () => UI.parole(x, hasard(TAVERNE_LIGNES.respect))); J.taverne.respect[x.nom] = (J.taverne.respect[x.nom] || 0) + 1; }
  });
  if (mission && mission.equipe) { const c = allies.find(a => a.compagnon && !a.mort); if (c) programmer(1.2, () => panneauCompagnon(c, 'eveil', true)); for (const a of allies) if (a.compagnon) J.taverne.lien[a.compagnon.id] = Math.min(100, (J.taverne.lien[a.compagnon.id] || 0) + 4); }
  if (taverne) {
    if (taverne.attente) programmer(2.2, () => { for (const c of taverne.file) if (c !== 'joueur') { c.dest = hasard(monde.places).clone().add(V(rnd(-0.6, 0.6), 0, rnd(-0.6, 0.6))); } taverne.file = ['joueur']; servirJoueur(); });
    if (plusFort) programmer(1.4, () => { UI.parole(plusFort, hasard(TAVERNE_LIGNES.rire), 'choc'); programmer(1.6, () => defiRival(plusFort)); });
  }
  sauver();
}
// ---- la taverne ----
function creerClient(data, pos, angle) {
  const a = new Acteur(data.modele, { hauteur: 2.0 });
  habiller(a, data.equip, ARMES[data.equip.arme.type]);
  a.root.position.copy(pos); a.root.rotation.y = angle; G.scene.add(a.root);
  Object.assign(a, { pos: a.root.position, angle, nom: data.nom, data, ip: data.ip, client: true, hauteurPlaque: 2.55, dest: null, ligneT: rnd(3, 12) });
  a.jouer('Idle');
  UI.plaque(a, { nom: data.nom, guilde: data.guilde, classe: 'allie joueur', vie: false, ip: data.ip, niv: data.niv });
  return a;
}
function entrerTaverne() {
  fondu(() => {
    viderMonde(); invasion = null; arene = null; selection = null; UI.boss(null);
    modeActuel = { id: 'taverne', taverne: true, nom: 'Taverne', lieu: 'Le Croc-Rouge', argent: 0, xp: 0, tiers: [1, 1], mobTier: 1 };
    monde = construireTaverne();
    if (!G.scene.background || !G.scene.background.isColor) G.scene.background = new THREE.Color();
    G.scene.background.set('#120a06'); G.scene.fog.color.set('#1a0e08'); G.scene.fog.density = 0.02;
    G.hemi.color.set('#ffd0a0'); G.hemi.groundColor.set('#3a2010'); G.hemi.intensity = 0.95; G.sun.color.set('#ffc890'); G.sun.intensity = 0.9;
    construireJoueur(monde.spawn.clone()); joueur.angle = Math.PI; joueur.root.rotation.y = Math.PI;
    G.camTarget.copy(joueur.pos);
    const ipJ = ipReel(), pris = [RIVAL_TAVERNE.nom];
    const client = (ipC, type = null) => { const d = donneesBot(ipC, pris, 0); if (type) { d.equip = genererEquipRival(ipC, type); d.modele = ARMES[type].model; } pris.push(d.nom); d.ip = Math.max(120, Math.round(ipC + rnd(-25, 25))); return d; };
    taverne = { clients: [], file: [], attente: null, t: 0 };
    // Mira, la tavernière, et Ysolde, l'oracle
    const mira = creerClient({ nom: 'Mira', guilde: 'TAVERNIÈRE', equip: genererEquipRival(300, 'arbalete'), modele: 'Rogue', ip: 0, niv: 0 }, monde.mira, 0); mira.pnj = true; UI.retirerPlaque(mira); UI.plaque(mira, { nom: 'Mira', guilde: 'TAVERNIÈRE', classe: 'pnj', vie: false });
    const ysolde = creerClient({ nom: 'Ysolde', guilde: 'ORACLE', equip: genererEquipRival(300, 'baton'), modele: 'Mage', ip: 0, niv: 0 }, monde.oracle, -Math.PI / 2); ysolde.pnj = true; UI.retirerPlaque(ysolde); UI.plaque(ysolde, { nom: 'Ysolde', guilde: 'ORACLE', classe: 'pnj', vie: false });
    for (const pnj of [mira, ysolde]) for (const n of Object.keys(pnj.nodes)) if (/Sword|Axe|Shield|Crossbow|Staff|Wand|Knife|Throwable|Spellbook/.test(n)) pnj.nodes[n].visible = false;
    taverne.clients.push(mira, ysolde); taverne.mira = mira; taverne.ysolde = ysolde;
    // la file au comptoir : des habitués souvent plus forts que ta puissance apparente
    for (let i = 0; i < 3; i++) { const c = creerClient(client(ipJ * rnd(0.55, 0.9)), monde.file[i], Math.PI); taverne.clients.push(c); taverne.file.push(c); }
    // les clients attablés (parfois Brakkus le Colosse, plus fort que toi)
    monde.places.forEach((p, i) => {
      if (i === 0 && Math.random() < 0.7) { const d = client(ipJ * 1.18, RIVAL_TAVERNE.arme); d.nom = RIVAL_TAVERNE.nom; d.guilde = RIVAL_TAVERNE.guilde; const c = creerClient(d, p, rnd(0, 6)); c.rivalTaverne = true; taverne.clients.push(c); return; }
      if (Math.random() < 0.25) return;
      taverne.clients.push(creerClient(client(ipJ * rnd(0.4, 0.95)), p, rnd(0, 6.28)));
    });
    for (const c of taverne.clients) if (!c.pnj && Math.random() < 0.3) c.jouer('Cheer', { boucle: true, vitesse: 0.5 });
    UI.journal('Le Croc-Rouge', 'Commande au comptoir, consulte Ysolde ou prends une mission au tableau.');
    UI.zone('Le Croc-Rouge', 'Taverne · missions');
    $('#btnQuitter').hidden = true;
    // accueil selon ta réputation
    const respecte = Object.values(J.taverne.respect).reduce((a, b) => a + b, 0) >= 3;
    programmer(1.2, () => { const c = taverne && taverne.clients.find(x => !x.pnj && !x.rivalTaverne); if (c) UI.parole(c, !J.dissimule && titreRenom().i >= 1 && Math.random() < 0.65 ? parolePNJ('clients') : respecte && !J.dissimule ? hasard(TAVERNE_LIGNES.salutRespect) : J.dissimule || ipAffiche() < ipReel() ? hasard(TAVERNE_LIGNES.moque) : hasard(TAVERNE_LIGNES.ambiance)); });
    musique('fond');
  });
}
function majTaverne(dt) {
  taverne.t += dt;
  for (const c of taverne.clients) {
    if (c.dest) {
      const d = dist2D(c.pos, c.dest);
      if (d > 0.15) { const k = Math.min(1, 2.4 * dt / d); c.pos.x += (c.dest.x - c.pos.x) * k; c.pos.z += (c.dest.z - c.pos.z) * k; c.angle = tourner(c.angle, Math.atan2(c.dest.x - c.pos.x, c.dest.z - c.pos.z), dt * 10); c.root.rotation.y = c.angle; if (!c.marche) { c.marche = true; c.jouer('Walking_A'); } }
      else { c.dest = null; c.marche = false; c.jouer('Idle'); if (taverne.file.includes(c)) { c.angle = Math.PI; c.root.rotation.y = Math.PI; } }
    }
    // l'ambiance : les clients parlent entre eux, et de toi quand tu sembles faible
    if (!c.pnj && (c.ligneT -= dt) <= 0) {
      c.ligneT = rnd(7, 15);
      const proche = dist2D(c.pos, joueur.pos) < 7, faible = (ipAffiche() < (c.ip || 0) * 0.9) && !(J.taverne.respect[c.nom] > 0 && !J.dissimule);
      UI.parole(c, proche && faible ? hasard(TAVERNE_LIGNES.moque) : proche && J.taverne.respect[c.nom] > 0 && !J.dissimule ? hasard(TAVERNE_LIGNES.salutRespect) : hasard(TAVERNE_LIGNES.ambiance));
    }
    c.maj(dt);
  }
  // la file d'attente avance : un client servi toutes les 6 s
  const A = taverne.attente; if (!A) return;
  A.t -= dt;
  if (A.t <= 0) {
    A.t = 6;
    const tete = taverne.file[0];
    if (tete === 'joueur') { servirJoueur(); return; }
    taverne.file.shift(); UI.parole(tete, hasard(['Une pinte, Mira !', 'Merci, ma belle.', 'Le ragoût, comme d’hab.'])); taverne.mira.jouer('Interact', { boucle: false, fin: () => taverne.mira.jouer('Idle') });
    tete.dest = hasard(monde.places).clone().add(V(rnd(-0.8, 0.8), 0, rnd(-0.8, 0.8)));
    // un costaud te passe devant si tu as l'air faible
    if (!A.coupe && ipAffiche() < ipReel() * 0.95 && Math.random() < 0.45) {
      const brute = taverne.clients.find(c => !c.pnj && !taverne.file.includes(c) && (c.ip || 0) > ipAffiche() && dist2D(c.pos, joueur.pos) < 12);
      if (brute) { A.coupe = true; const iJ = taverne.file.indexOf('joueur'); taverne.file.splice(iJ, 0, brute); UI.parole(brute, hasard(TAVERNE_LIGNES.passeDevant), 'choc'); }
    }
    placerFile();
    if (Math.random() < 0.6) { const c = taverne.file.find(x => x !== 'joueur' && (x.ip || 0) > ipAffiche()); if (c) UI.parole(c, hasard(TAVERNE_LIGNES.moque)); }
  }
  UI.fileAttente({ devant: taverne.file.indexOf('joueur'), t: Math.ceil(A.t), dissimule: !!J.dissimule }, { reveler: () => revelerPuissance(), quitter: () => quitterFile() });
}
function placerFile() { taverne.file.forEach((c, i) => { const p = monde.file[Math.min(i, monde.file.length - 1)]; if (c === 'joueur') { joueur.pos.copy(p); joueur.angle = Math.PI; joueur.root.rotation.y = Math.PI; } else c.dest = p.clone(); }); }
function rejoindreFile() {
  if (taverne.attente) return;
  // si ta puissance visible impressionne, on te laisse passer
  const fortVisible = !J.dissimule && taverne.file.every(c => (c.ip || 0) < ipReel() * 0.9);
  if (fortVisible) { const c = taverne.file[0]; if (c) UI.parole(c, hasard(TAVERNE_LIGNES.respect)); taverne.file.unshift('joueur'); servirJoueur(); return; }
  taverne.file.push('joueur'); taverne.attente = { t: 6, coupe: false }; placerFile();
  UI.toast(`Tu fais la queue · ${taverne.file.length - 1} client${taverne.file.length > 2 ? 's' : ''} devant toi`);
}
function quitterFile() { if (!taverne || !taverne.attente) return; taverne.file = taverne.file.filter(x => x !== 'joueur'); taverne.attente = null; UI.fileAttente(null); joueur.pos.set(2.5, 0, 0); }
function servirJoueur() {
  taverne.attente = null; taverne.file = taverne.file.filter(x => x !== 'joueur'); UI.fileAttente(null);
  joueur.pos.copy(monde.comptoir); joueur.angle = Math.PI; joueur.root.rotation.y = Math.PI;
  dialogueMira();
}
const prixTaverne = (base) => Math.round(base * Math.max(1, Math.pow((J.equip.arme || { tier: 1 }).tier, 1.6)));
function dialogueMira() {
  const now = Date.now();
  UI.dialogueTaverne({ nom: 'Mira', titre: 'Tavernière du Croc-Rouge', modele: 'Rogue', texte: parolePNJ('mira') + ' Qu’est-ce que je te sers ?',
    options: [
      { label: `Ragoût du Croc-Rouge · ${fmtN(prixTaverne(4000))} ¤`, sous: '+10 % de vie et de dégâts pendant 20 min' + (J.repas > now ? ` (actif ${Math.ceil((J.repas - now) / 60000)} min)` : ''), action: () => acheterTaverne(prixTaverne(4000), () => { J.repas = Date.now() + 20 * 60000; recalculer(); }, 'Ragoût avalé : +10 % de vie et de dégâts') },
      { label: `Hydromel de l’aventurier · ${fmtN(prixTaverne(3000))} ¤`, sous: '+20 % d’expérience pendant 20 min' + (J.hydromel > now ? ` (actif ${Math.ceil((J.hydromel - now) / 60000)} min)` : ''), action: () => acheterTaverne(prixTaverne(3000), () => { J.hydromel = Date.now() + 20 * 60000; }, 'Hydromel bu : +20 % d’expérience') },
      { label: J.dissimule ? 'Montrer à nouveau ma puissance' : 'Dissimuler ma puissance', sous: J.dissimule ? 'Tout le monde verra ta vraie force' : 'Les autres ne verront que 30 % de ta force… à toi de choisir quand la révéler', action: () => { dissimuler(!J.dissimule); dialogueMira(); } },
      { label: 'Une rumeur ?', sous: 'Mira entend tout', action: () => UI.toast(hasard(TAVERNE_LIGNES.ambiance), true) },
    ] });
  J.taverne.respect.Mira = J.taverne.respect.Mira || 0;
}
function acheterTaverne(prix, effet, msg) { if (J.argent < prix) { UI.toast('Pas assez d’argent'); son('error_001', 0.4); return; } J.argent -= prix; effet(); sauver(); son('handleCoins', 0.5); UI.toast(msg, true); UI.dialogueTaverne(null); }
function dialogueOracle() {
  const prix = prixTaverne(9000);
  UI.dialogueTaverne({ nom: 'Ysolde', titre: 'Oracle', modele: 'Mage', texte: J.prophetie ? 'Ta prophétie t’attend dans ta prochaine aventure. Va.' : 'Les cartes murmurent ton nom… Veux-tu connaître ta fortune ?',
    options: [{ label: `Prophétie de fortune · ${fmtN(prix)} ¤`, sous: '+40 % d’or lors de ta prochaine mission ou de ton prochain donjon', desactive: !!J.prophetie, action: () => acheterTaverne(prix, () => { J.prophetie = true; }, 'Ysolde a lu ton avenir : +40 % d’or au prochain combat') }] });
}
function defiRival(r) {
  UI.dialogueTaverne({ nom: r.nom, titre: RIVAL_TAVERNE.titre, modele: r.data.modele, texte: `Pas mal, ton petit numéro. Mais moi, ça ne m’impressionne pas. Viens le prouver dans l’Arène.`,
    options: [{ label: 'Accepter le duel', sous: `${r.nom} · ⚔ ${r.ip}`, action: () => { UI.dialogueTaverne(null); const d = { ...r.data, kPv: 1.15, kDg: 1.1 }; entrerArene('1v1', { duel: d }); } }, { label: 'Ignorer', action: () => { UI.dialogueTaverne(null); UI.parole(r, 'C’est bien ce que je pensais.'); } }] });
}
function actionTaverne() {
  const p = joueur.pos;
  if (taverne.attente) return UI.action(null);
  if (dist2D(p, monde.comptoir) < 3.4) return UI.action('Commander au comptoir', () => rejoindreFile());
  if (dist2D(p, monde.tableau) < 3.6) return UI.action('Tableau des missions', () => ouvrirMissions());
  if (dist2D(p, monde.oracle) < 3.4) return UI.action('Consulter Ysolde', () => dialogueOracle());
  if (dist2D(p, monde.sortie) < 2.6) return UI.action('Sortir sur la Place', () => fondu(() => lancerHub()));
  UI.action(null);
}
// ---- missions d'aventure ----
function genererOffres() {
  const offres = [], vus = new Set();
  while (offres.length < 4) {
    const M = hasard(MISSIONS); if (vus.has(M.id)) continue; vus.add(M.id);
    const etoiles = [1, 2, 3, 4, 5][offres.length + (Math.random() < 0.5 ? 1 : 0)] || 3;
    offres.push({ id: M.id, faction: Math.floor(Math.random() * FACTIONS.length), etoiles });
  }
  J.taverne.offres = offres; sauver(); return offres;
}
const tierMoyen = () => { const l = ['arme', 'casque', 'plastron', 'bottes'].map(s => J.equip[s]).filter(Boolean); return l.reduce((a, b) => a + b.tier, 0) / Math.max(1, l.length); };
const recompenseMission = (o) => Math.round(60000 * o.etoiles * (0.5 + 0.25 * tierMoyen()));
function ouvrirMissions() {
  const offres = J.taverne.offres || genererOffres();
  const ip = ipReel();
  UI.tableauMissions(offres.map(o => { const M = MISSIONS.find(x => x.id === o.id), F = FACTIONS[o.faction]; return { ...o, titre: M.titre, resume: M.resume, faction: F.nom, couleur: F.couleur, boss: `${M.boss.nom}, ${M.boss.titre}`, recompense: recompenseMission(o), modele: ARMES[M.boss.arme] ? ARMES[M.boss.arme].model : 'Knight', conseil: Math.round(Math.max(300, ip) * (0.75 + 0.1 * o.etoiles) / 10) * 10, nbSolo: 6 * 2 + 3 * 3 + 1, nbEquipe: 6 * 3 + 3 * 4 + 1 }; }),
    (o, equipe) => entrerMission(offres.find(x => x.id === o.id), equipe), { ip, reussies: J.taverne.missions || 0 });
}
function auraMeurtriere(e, couleur, k = 1) {
  const ring = new THREE.Mesh(new THREE.RingGeometry(0.7, 1.25, 32), new THREE.MeshBasicMaterial({ color: couleur, transparent: true, opacity: 0.6, blending: THREE.AdditiveBlending, depthWrite: false }));
  ring.rotation.x = -Math.PI / 2; G.scene.add(ring);
  e.auraM = { ring, couleur, k };
}
function donneesElite(F, nom, ipJ, kPv, kDg, type = null) {
  type = type || hasard(['epee', 'arbalete', 'baton']);
  const equip = genererEquipRival(ipJ, type);
  return { nom, guilde: F.nom.toUpperCase(), equip, niv: niveauHeros(J.equip), ip: ipJ, modele: type === 'arbalete' && Math.random() < 0.5 ? 'Rogue' : ARMES[type].model, kPv, kDg, skill: 0.85 };
}
async function entrerMission(offre, equipe) {
  UI.tableauMissions(null);
  if (!assetsSylvePrets) { UI.toast('Départ en mission…'); try { await chargerAssets(ASSETS_SYLVE.map(k => [k, `assets/sylve/${k}.json`]), () => {}); assetsSylvePrets = true; } catch (er) {} }
  const M = MISSIONS.find(x => x.id === offre.id), F = FACTIONS[offre.faction];
  memoriserMode(M.titre, () => entrerMission(offre, equipe));
  fondu(() => {
    viderMonde(); invasion = null; arene = null; selection = null;
    const t = Math.max(1, Math.min(8, Math.round(tierMoyen())));
    modeActuel = { id: 'mission', mission: true, nom: 'Mission', lieu: M.titre, argent: 1, xp: 6 + offre.etoiles * 3, tiers: [t, t], mobTier: t, prophetie: !!J.prophetie };
    if (J.prophetie) { J.prophetie = false; sauver(); }
    monde = construireSylve();
    // en mission, pas de gardiens du Sanctuaire : les ronces de passage n'ont pas lieu d'être (elles bloquaient la suite)
    for (const b of monde.barrieres || []) b.groupe.removeFromParent();
    monde.collisions = monde.collisions.filter(c => c.barriere === undefined); monde._cg = null; monde.barrieres = [];
    if (!G.scene.background || !G.scene.background.isColor) G.scene.background = new THREE.Color();
    G.scene.background.set('#2a1a2a'); G.scene.fog.color.set('#3a2030'); G.scene.fog.density = 0.016;
    G.hemi.color.set('#ffc8b0'); G.hemi.groundColor.set('#2a1a22'); G.hemi.intensity = 1.05; G.sun.intensity = 1.35; G.sun.color.set('#ffb08a');
    construireJoueur(monde.spawn.clone()); joueur.pv = joueur.st.pvMax; joueur.energie = joueur.st.energieMax;
    G.camTarget.copy(joueur.pos);
    const ipJ = ipReel(), force = 0.62 + 0.1 * offre.etoiles, solo = !equipe;
    // compagnons
    if (equipe) for (const C of COMPAGNONS) {
      const d = calerSurJoueur(donneesBot(ipJ, [], 0)); d.nom = C.nom; d.guilde = C.titre.toUpperCase(); d.equip = genererEquipRival(ipJ, C.arme); d.modele = ARMES[C.arme].model;
      const a = creerCombattant(pointLibrePres(monde.spawn, 1.5, 3.5), d, 'allie'); a.membreSylve = true; a.compagnon = C; a.tenueCouleur(C.couleur);
    }
    // escouades d'élite le long du chemin, lieutenants dans les clairières, chef à la fin
    let pack = 900; const prenoms = [...F.elites].sort(() => Math.random() - 0.5);
    const escouade = (pts, n, chef, kPv, kDg) => { const id = pack++; let leader = null; for (let i = 0; i < n; i++) { const nom = i === 0 && chef ? `${prenoms[(id) % prenoms.length]} ${hasard(F.titres)}` : prenoms[(id + i + 1) % prenoms.length]; const e = creerCombattant(pts[i % pts.length].clone().add(V(rnd(-1.5, 1.5), 0, rnd(-1.5, 1.5))), donneesElite(F, nom, ipJ, kPv, kDg), 'ennemi'); Object.assign(e, { mission: true, etat: 'idle', pack: id, chasseur: false }); e.tenueCouleur(F.tenue); auraMeurtriere(e, F.couleur, i === 0 && chef ? 1.4 : 1); if (i === 0) leader = e; } return leader; };
    mission = { offre, M, F, equipe, debut: G.t, evts: new Set(), chefs: [], boss: null, phase: 1, fini: false };
    monde.packs.filter((p, i) => i % 2 === 0).slice(0, 6).forEach(pk => escouade(pk.pts, solo ? 2 : 3, false, force * 0.8, force * 0.75));
    monde.salles.slice(0, 3).forEach(s => mission.chefs.push(escouade([s.c, s.c, s.c], solo ? 3 : 4, true, force, force * 0.8)));
    { const s = monde.salles[3]; const d = donneesElite(F, `${M.boss.nom}, ${M.boss.titre}`, ipJ, (solo ? 4.2 : 6.5) * force, 1.25 * force, M.boss.arme); const b = creerCombattant(s.c.clone(), d, 'ennemi');
      Object.assign(b, { mission: true, missionBoss: true, etat: 'idle', pack: 999, hauteurPlaque: 3.5, rayon: 0.85 }); b.root.scale.setScalar(1.45); b.tenueCouleur(F.tenue); auraMeurtriere(b, F.couleur, 2.2); mission.boss = b; }
    creerSortie(monde.sortie);
    UI.journal(M.titre, M.resume);
    UI.zone(M.titre, `${'★'.repeat(offre.etoiles)}${'☆'.repeat(5 - offre.etoiles)} · ${equipe ? 'En équipe' : 'En solo'}`);
    $('#btnQuitter').hidden = false;
    programmer(0.8, () => {
      UI.titreManga(M.titre, `${F.nom} · ${'★'.repeat(offre.etoiles)}`);
      const C = allies.filter(a => a.compagnon);
      const pan = C.length ? C.slice(0, 2).map(a => ({ nom: a.nom, titre: a.compagnon.titre, modele: a.data.modele, texte: hasard(a.compagnon.debut), couleur: a.compagnon.couleur })) : [{ nom: J.nom, titre: 'en solo', modele: joueur.cle, texte: hasard(['Seul. Comme toujours. C’est mieux ainsi.', 'Personne pour me ralentir. Allons-y.', 'Ils ne savent pas encore à qui ils ont affaire.']), couleur: '#ffd27a' }];
      programmer(2.2, () => UI.manga(pan));
    });
  });
}
function panneauCompagnon(a, cle, fort = false) {
  if (!a || !a.compagnon) return;
  UI.manga([{ nom: a.nom, titre: a.compagnon.titre, modele: a.data.modele, texte: hasard(a.compagnon[cle]), couleur: a.compagnon.couleur, choc: fort }]);
}
function majMission(dt) {
  const Mi = mission; if (Mi.fini) return;
  // auras meurtrières
  for (const e of ennemis) if (e.auraM) {
    const A = e.auraM; if (e.mort) { if (A.ring.parent) G.scene.remove(A.ring); continue; }
    A.ring.position.set(e.pos.x, 0.06 + solY(e.pos.x, e.pos.z), e.pos.z); const s = (0.9 + Math.sin(G.t * 5 + e.pack) * 0.12) * A.k * (e.root.scale.x); A.ring.scale.set(s, s, s);
    if (e.etat !== 'idle' && Math.random() < dt * 14 * A.k) emettre(V(e.pos.x + rnd(-0.5, 0.5), 0.3, e.pos.z + rnd(-0.5, 0.5)), { n: 1, c1: A.couleur, c2: '#0a0000', dir: V(0, 1, 0), vit: 3 * A.k, disp: 0.5, vie: 0.8, taille: 0.45 * A.k, frein: 0.6 });
  }
  const once = (k, f) => { if (!Mi.evts.has(k)) { Mi.evts.add(k); f(); } };
  const C = allies.filter(a => a.compagnon && !a.mort);
  // un lieutenant se réveille : intimidation et pression meurtrière
  Mi.chefs.forEach((ch, i) => { if (ch && ch.etat !== 'idle') once('chef' + i, () => {
    UI.intention(Mi.F.couleur); UI.titreManga(ch.nom, Mi.F.nom);
    const pan = [{ nom: ch.nom, titre: Mi.F.nom, modele: ch.data.modele, texte: hasard(['Encore des vermines de la Taverne…', 'Vous n’auriez jamais dû venir ici.', 'Tu sens cette pression ? C’est ta mort qui approche.', `Tremblez devant ${Mi.F.nom} !`, 'Je vais prendre mon temps avec toi.']), couleur: Mi.F.couleur, choc: true }];
    if (C.length) { const a = hasard(C); pan.push({ nom: a.nom, titre: a.compagnon.titre, modele: a.data.modele, texte: hasard(['Attention, celui-là est différent !', 'Son aura… elle est meurtrière.', 'Reste concentré !']), couleur: a.compagnon.couleur }); }
    ralenti(0.5, 0.35); UI.manga(pan);
  }); });
  // le chef
  const B = Mi.boss;
  if (B && !B.mort && B.etat !== 'idle') once('boss', () => {
    UI.intention(Mi.F.couleur); G.shake = 0.8; ralenti(0.8, 0.3); UI.titreManga(B.nom, Mi.F.nom);
    const pan = [{ nom: B.nom, titre: Mi.F.nom, modele: B.data.modele, texte: Mi.M.intro, couleur: Mi.F.couleur, choc: true }];
    if (C.length) { const a = hasard(C); pan.push({ nom: a.nom, titre: a.compagnon.titre, modele: a.data.modele, texte: hasard(a.compagnon.boss), couleur: a.compagnon.couleur }); }
    UI.manga(pan);
  });
  if (B && !B.mort && Mi.phase === 1 && B.pv < B.pvMax * 0.5) {
    Mi.phase = 2; B.dmg *= 1.3; B.st.vitesse *= 1.15; B.auraM.k *= 1.5; B._dps = (B._dps || 0) * 1.3;
    UI.intention(Mi.F.couleur); G.shake = 1; ralenti(0.7, 0.25); onde(B.pos, Mi.F.couleur, 12, 0.8); son('lowFrequency_explosion_000', 0.7, 0.5);
    UI.manga([{ nom: B.nom, titre: 'SECONDE PHASE', modele: B.data.modele, texte: Mi.M.phase2, couleur: Mi.F.couleur, choc: true }]);
  }
  // blessures : les compagnons s'inquiètent
  for (const a of C) if (a.pv < a.pvMax * 0.3) once('blesse' + a.nom, () => panneauCompagnon(a, 'blesse'));
  if (joueur.pv < joueur.st.pvMax * 0.3 && !joueur.mort) once('joueurBlesse', () => { if (C.length) panneauCompagnon(hasard(C), 'joueurBlesse', true); else UI.manga([{ nom: J.nom, titre: '', modele: joueur.cle, texte: hasard(['Pas… maintenant…', 'Je ne tomberai pas ici.', 'Encore… un effort…']), couleur: '#ffd27a' }]); });
}
function mortEnnemiMission(e) {
  if (e.auraM && e.auraM.ring.parent) G.scene.remove(e.auraM.ring);
  setTimeout(() => { e.descendre = true; }, 3500);
  const gain = Math.round(recompenseMission(mission.offre) * 0.02 * (mission.offre && modeActuel.prophetie ? 1.4 : 1));
  J.argent += gain; UI.nombre(V(e.pos.x, 2.4, e.pos.z), `+${fmtN(gain)} ¤`, 'info');
  gagnerXP(Math.round(10 * modeActuel.xp * (e.missionBoss ? 12 : 1.5)));
  if (e.missionBoss) victoireMission();
}
function victoireMission() {
  document.querySelectorAll('.titreManga').forEach(n => n.remove());
  const Mi = mission; Mi.fini = true; if (Mi.offre && Mi.offre.etoiles >= 5) exploit('mission_5');
  ralenti(1.2, 0.25); G.shake = 1; UI.boss(null);
  for (const e of ennemis) if (!e.mort && e.mission) { e.pv = 0; tuer(e); }
  const base = recompenseMission(Mi.offre), gain = Math.round(base * (modeActuel.prophetie ? 1.4 : 1));
  J.argent += gain; gagnerXPRelatif(0.006 * Mi.offre.etoiles);
  J.taverne.missions = (J.taverne.missions || 0) + 1;
  if (Mi.equipe) for (const C of COMPAGNONS) J.taverne.lien[C.id] = Math.min(100, (J.taverne.lien[C.id] || 0) + 6 + Mi.offre.etoiles);
  const objet = objetSylve(modeActuel.tiers[0], Math.min(4, 1 + Math.floor(Mi.offre.etoiles / 2))); ajouterSac(objet, true);
  genererOffres(); sauver(); cor('capture');
  const pan = [{ nom: Mi.boss.nom, titre: Mi.F.nom, modele: Mi.boss.data.modele, texte: Mi.M.mort, couleur: Mi.F.couleur }];
  const C = allies.filter(a => a.compagnon && !a.mort); if (C.length) pan.push(...C.slice(0, 2).map(a => ({ nom: a.nom, titre: a.compagnon.titre, modele: a.data.modele, texte: hasard(a.compagnon.fin), couleur: a.compagnon.couleur })));
  UI.manga(pan, () => {
    const lignes = [`${'★'.repeat(Mi.offre.etoiles)} · ${Mi.equipe ? 'En équipe' : 'En solo'} · ${Math.round((G.t - Mi.debut) / 60)} min`, `+ ${fmtN(gain)} d’argent${modeActuel.prophetie ? ' (prophétie +40 %)' : ''}`, `Butin : ${nomObjet(objet)}`];
    if (Mi.equipe) lignes.push(`Liens : ${COMPAGNONS.map(C => `${C.nom} ${J.taverne.lien[C.id]}`).join(' · ')}`);
    UI.resultatArene({ victoire: true, titre: 'Mission accomplie', lignes, refaire: null }, () => entrerTaverne());
  });
}
function echecMission() {
  document.querySelectorAll('.titreManga').forEach(n => n.remove());
  if (mission) mission.fini = true;
  setTimeout(() => UI.mort('Tu es tombé au combat. Tes compagnons t’ont ramené au Croc-Rouge. La mission est perdue, mais ton or est intact.', () => entrerTaverne()), 1600);
}

