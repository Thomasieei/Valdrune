// ---------------- Îles ----------------
let recolteJ = null, ouvriers = [], intendant = null, passeur = null, assaut = null, raid = null, ileVolee = null;
const RES_LABEL = { bois: 'Bois', minerai: 'Minerai', recolte: 'Récoltes' };
const heureMs = 3600 * 1000;
function prochaineHeure(h, depuis = Date.now()) { const d = new Date(depuis); d.setHours(h, 0, 0, 0); if (d.getTime() <= depuis) d.setDate(d.getDate() + 1); return d.getTime(); }
function iles() { return (J.iles = J.iles || []); }
function nbBati(ile, t) { return ile.batiments.filter(b => b.t === t).length; }
function maxOuvriers(ile) { return nbBati(ile, 'maison'); }
function vitesseIle(ile) { return 1 + 0.001 * ile.batiments.length + 0.05 * (ile.niveau - 1); }
function capaciteIle(ile) { return nbBati(ile, 'foyer') ? Infinity : 1000 * (1 + ile.taille); }
function stockIle(ile) { return ile.coffre[ILE_TYPES[ile.type].res] || 0; }
function totalCoffre(ile) { return Object.values(ile.coffre).reduce((a, b) => a + b, 0); }
function ajouterRes(ile, res, n) {
  const cap = capaciteIle(ile); const tot = totalCoffre(ile);
  const ajout = Math.max(0, Math.min(n, cap - tot));
  ile.coffre[res] = (ile.coffre[res] || 0) + ajout;
  return ajout;
}
function prixBatiment(ile, t) { const d = BATIMENTS[t]; return Math.round(d.prix * Math.pow(d.croiss || 1, nbBati(ile, t))); }
// production des ouvriers : tourne même quand le joueur est ailleurs (12 h max hors ligne)
function majProduction() {
  const now = Date.now();
  for (const ile of iles()) {
    const dt = Math.min(12 * heureMs, Math.max(0, now - (ile.maj || now))) / 1000;
    ile.maj = now;
    const n = Math.min(ile.ouvriers || 0, maxOuvriers(ile));
    if (!n || !dt) continue;
    ile.reste = (ile.reste || 0) + n * vitesseIle(ile) * dt / 8 * (ombreGardeIle(ile) ? 1.15 : 1); // une ombre surveille les ouvriers : +15 %
    const entier = Math.floor(ile.reste); ile.reste -= entier;
    if (entier) ajouterRes(ile, ILE_TYPES[ile.type].res, entier);
  }
}
function acheterIle(type, taille) {
  const prix = ILE_TAILLES[taille].prix;
  if (J.argent < prix) { UI.toast('Pas assez d’argent'); son('error_001', 0.4); return; }
  J.argent -= prix;
  const n = iles().filter(i => i.type === type).length;
  const ile = { id: 'i' + Date.now(), graine: Math.floor(Math.random() * 1e9), type, taille, niveau: 1, nom: `${ILE_TYPES[type].nom}${n ? ' ' + (n + 1) : ''}`,
    coffre: { bois: 0, minerai: 0, recolte: 0 }, batiments: [], ouvriers: 0, gardes: 0, champion: false, livre: 0, maj: Date.now(), assaut: prochaineHeure(HEURE_ASSAUT) };
  iles().push(ile);
  if (!J.prochainRaid) J.prochainRaid = Date.now() + rnd(100, 140) * 60000;
  sauver(); son('jingle_legend', 0.6);
  UI.toast(`${ILE_TAILLES[taille].nom} achetée !`, true);
  entrerIle(ile);
}
function ileBot() {
  const ip = statsHeros(J.equip).ip;
  const type = hasard(Object.keys(ILE_TYPES)); const taille = Math.floor(Math.random() * 3);
  const proprio = donneesBot(ip);
  const ile = { id: 'bot', graine: Math.floor(Math.random() * 1e9), type, taille, niveau: 1 + Math.floor(Math.random() * 5), nom: `Île de ${proprio.nom}`, proprio,
    coffre: { bois: 0, minerai: 0, recolte: 0 }, batiments: [], gardes: 3, champion: true };
  ile.coffre[ILE_TYPES[type].res] = Math.round(rnd(2000, 9000) * (1 + taille));
  const n = nbEmplacements(ile); const types = ['maison', 'maison', 'maison', 'route', 'jardin', 'puits', 'moulin', 'tour', 'foyer', 'atelier'];
  for (let i = 0; i < n; i++) if (Math.random() < 0.75) ile.batiments.push({ plot: i, t: types[i % types.length] });
  return ile;
}

function entrerIle(ile, opts = {}) {
  fondu(() => {
    viderMonde(); invasion = null; arene = null; selection = null; assaut = null; recolteJ = null;
    majProduction();
    const etr = ile.id === 'bot';
    modeActuel = { id: 'ile', nom: ile.nom, lieu: ile.nom, argent: 0, xp: 0, tiers: [1, 1], mobTier: 1 };
    monde = construireIle(ile, etr);
    grilleIle();
    construireJoueur(monde.spawn.clone());
    joueur.pv = joueur.st.pvMax; joueur.energie = joueur.st.energieMax;
    G.camTarget.copy(joueur.pos);
    G.scene.background.set('#8fb8d8'); G.scene.fog.color.set('#9cc2dc'); G.scene.fog.density = 0.006; G.hemi.intensity = 1.35; G.sun.intensity = 1.7; G.sun.color.set('#fff2d8');
    if (groupe) Object.assign(creerCombattant(pointLibrePres(monde.spawn, 1.5, 3), groupe, 'allie'), { autonome: true, perso: 'loyal', modeA: 'explorer', modeT: 20 });
    // gardes de l'île : sur ton île ils te défendent, chez les autres ils défendent le coffre
    const ipJ = statsHeros(J.equip).ip;
    const postes = [[-5, 3], [3, -5], [-6, -6], [6, 6]];
    const nG = etr ? ile.gardes : ile.gardes || 0;
    for (let i = 0; i < nG + ((etr || ile.champion) ? 1 : 0); i++) {
      const champ = i === nG;
      const def = champ ? CHAMPION_ILE : GARDES_ILE[i];
      const d = donneesBot(ipJ * def.ratio);
      d.nom = etr ? `${def.nom} de ${ile.proprio.nom}` : def.nom; d.guilde = etr ? ile.proprio.guilde : 'GARDE DE L’ÎLE';
      const pp = pointLibrePres(monde.coffrePos.clone().add(V(postes[i][0], 0, postes[i][1])), 0, 2);
      const g = creerCombattant(pp, d, etr ? 'ennemi' : 'allie');
      g.garde = true; g.poste = pp.clone(); g.gardeIle = etr;
      if (champ) { g.root.scale.setScalar(1.25); g.hauteurPlaque = 3.1; g.pvMax = g.pv = g.pvMax * 1.6; }
      g.jouer(g.armeDef.idle);
    }
    // l'ombre de garde patrouille entre les ouvriers et le coffre
    { const go = !etr && ombreGardeIle(ile); if (go) { const pp = pointLibrePres(monde.coffrePos.clone().add(V(0, 0, 4)), 0, 3); const g = creerCombattant(pp, { nom: go.nom, guilde: 'OMBRE DE GARDE', equip: J.equip, modele: 'Rogue_Hooded', sansRecalage: true }, 'allie'); g.garde = true; g.poste = pp.clone(); g.pvMax = g.pv = Math.round(joueur.st.pvMax * 1.2); g.dmg = joueur.st.degats * 0.9; teinteSpectrale(g, '#140c20', 0.8); g.jouer(g.armeDef.idle); programmer(1.5, () => UI.parole(g, hasard(['Rien à signaler, maître. Tes ouvriers travaillent bien.', 'Des voiles au loin cette nuit. Elles ont fait demi-tour.', 'Ton île est calme, maître. Grâce à moi.', 'J’ai compté les tonneaux deux fois. Rien ne manque.']))); } }
    if (!etr) {
      intendant = new Acteur('Mage', { hauteur: 2.0 });
      habiller(intendant, genererEquipRival(300, 'baton'), ARMES.baton);
      intendant.root.position.copy(monde.intendantPos); intendant.pos = intendant.root.position; intendant.hauteurPlaque = 2.6;
      intendant.root.rotation.y = Math.atan2(monde.spawn.x - monde.intendantPos.x, monde.spawn.z - monde.intendantPos.z);
      intendant.jouer('Idle'); G.scene.add(intendant.root);
      monde.collisions.push({ x: intendant.pos.x, z: intendant.pos.z, r: 0.7 });
      UI.plaque(intendant, { nom: 'Oswin', guilde: 'INTENDANT', classe: 'pnj', vie: false });
      const n = Math.min(ile.ouvriers || 0, maxOuvriers(ile), 10);
      for (let i = 0; i < n; i++) creerOuvrier(ile, i);
    }
    const T = ILE_TYPES[ile.type];
    UI.zone(ile.nom, etr ? 'Pillage' : `${ILE_TAILLES[ile.taille].nom} · niv. ${ile.niveau}`);
    if (etr) { UI.journal('Pillage', `Élimine les gardes de ${ile.proprio.nom} pour ouvrir son coffre. Tu ne peux rien récolter ici.`, null); setTimeout(() => UI.toast(`Île de ${ile.proprio.nom}`, true), 600); }
    else { journalIle(ile); setTimeout(() => UI.toast(ile.nom, true), 600); if (!ile.vu) { ile.vu = true; setTimeout(() => UI.toast('Parle à Oswin, ton intendant : il t’explique tout'), 2400); } }
    $('#btnQuitter').hidden = true;
    if (opts.raid) lancerRaidSurPlace(ile, opts.raid);
    if (opts.assaut) lancerAssaut(ile);
    G.renderer.compile(G.scene, G.camera);
    sauver();
  });
}
function journalIle(ile) {
  const T = ILE_TYPES[ile.type];
  const cap = capaciteIle(ile);
  UI.journal(ile.nom, `${T.label} : ${fmtN(stockIle(ile))}${cap < Infinity ? ' / ' + fmtN(cap) : ''} · Ouvriers ${Math.min(ile.ouvriers || 0, maxOuvriers(ile))}/${maxOuvriers(ile)} · Assaut à ${HEURE_ASSAUT} h`, null);
}

// ---- ouvriers (visuels : la production est calculée par majProduction) ----
function creerOuvrier(ile, i) {
  const T = ILE_TYPES[ile.type];
  const a = new Acteur(T.ouvrier, { hauteur: 1.95 });
  const tous = Object.keys(a.nodes).filter(n => /Sword|Axe|Shield|Crossbow|Staff|Wand|Knife|Throwable|Mug|Spellbook|Offhand/.test(n));
  a.montrerSeul(ile.type === 'bois' ? ['1H_Axe'] : [], tous);
  if (ile.type === 'mine') a.attacher('tool_pickaxe', 'handslot.r', { echelle: 0.75 });
  const cape = Object.keys(a.nodes).find(n => n.endsWith('_Cape')); if (cape) a.teinter(cape, T.couleur, 0.55);
  a.root.position.copy(pointLibrePres(monde.coffrePos, 2, 5)); a.pos = a.root.position;
  G.scene.add(a.root);
  Object.assign(a, { etat: 'cherche', t: rnd(0, 2), cible: null, angle: 0, hauteurPlaque: 2.5 });
  UI.plaque(a, { nom: hasard(['Bram', 'Lutz', 'Ivo', 'Mara', 'Tibo', 'Nell', 'Gus', 'Odile', 'Pip', 'Rune']), guilde: 'OUVRIER', classe: 'pnj', vie: false, lettre: false });
  ouvriers.push(a);
}
// grille de marche de l'île (1,5 m) : ouvriers, gardes et bandits contournent les bâtiments au lieu de s'y coller
function grilleIle() {
  const C = 1.5, Rm = monde.rayonMonde + 14, W = Math.ceil(Rm * 2 / C), g = new Uint8Array(W * W), saveG = monde.grille; monde.grille = null;
  for (let z = 0; z < W; z++) for (let x = 0; x < W; x++) { const px = -Rm + x * C + C / 2, pz = -Rm + z * C + C / 2; g[z * W + x] = libre(px, pz, 0.55) ? 1 : 0; }
  Object.assign(monde, { grille: g, grilleW: W, grilleH: W, grilleC: C, grilleX0: -Rm, grilleZ0: -Rm });
}
function majOuvriers(dt) {
  const ile = monde.ile; if (!ile) return;
  for (const o of ouvriers) {
    o.t -= dt;
    if (o.etat === 'cherche') {
      const vivants = monde.noeuds.filter(n => n.pv > 0);
      o.cible = hasard(vivants.length ? vivants : monde.noeuds);
      o.etat = 'va'; o.jouer('Walking_A');
    } else if (o.etat === 'va' || o.etat === 'retour') {
      const but = o.etat === 'va' ? o.cible.pos : monde.coffrePos;
      const d = dist2D(o.pos, but);
      if (d < (o.etat === 'va' ? o.cible.rayon + 1.6 : 2.6)) { o.butLibre = null;
        if (o.etat === 'va') { o.etat = 'recolte'; o.t = rnd(4, 7); o.jouer(ile.type === 'cueillette' ? 'PickUp' : '1H_Melee_Attack_Chop', { vitesse: ile.type === 'cueillette' ? 0.8 : 0.9 }); }
        else { o.etat = 'depose'; o.t = 1.2; o.jouer('Interact'); if (o.charge) { o.charge.removeFromParent(); o.charge = null; } }
        o.angle = Math.atan2(but.x - o.pos.x, but.z - o.pos.z); o.root.rotation.y = o.angle;
      } else {
        if (!o.butLibre || o.butPour !== but) { o.butPour = but; o.butLibre = pointLibrePres(but, o.etat === 'va' ? o.cible.rayon + 0.6 : 1.2, o.etat === 'va' ? o.cible.rayon + 1.4 : 2.2, 0.5); o.chemin = null; }
        allerVers(o, o.butLibre, dt, 2.6);
      }
    } else if (o.etat === 'recolte') {
      if (Math.random() < dt * 1.3) effetRecolte(o.cible, ile.type, 0.4);
      if (o.t <= 0) {
        o.etat = 'retour'; o.jouer('Walking_A');
        const cle = ile.type === 'bois' ? 'Wood_Log_A' : ile.type === 'mine' ? (o.cible && o.cible.obj.children[1] ? 'Iron_Nuggets' : 'Iron_Nuggets') : 'proc_citrouille';
        o.charge = o.attacher(cle, 'handslot.l', { echelle: cle === 'proc_citrouille' ? 0.45 : 0.8 });
      }
    } else if (o.etat === 'depose' && o.t <= 0) o.etat = 'cherche';
    if (o.pos.distanceTo(joueur.pos) < 50) o.maj(dt);
  }
}
function effetRecolte(n, type, force = 1) {
  if (!n) return;
  const p = V(n.pos.x, type === 'bois' ? 1.4 : 1.2, n.pos.z);
  if (type === 'bois') emettre(p, { n: Math.round(10 * force), c1: '#d8a868', c2: '#7a4a22', vit: 4, vie: 0.6, taille: 0.25, grav: 8, hemi: true });
  else if (type === 'mine') emettre(p, { n: Math.round(12 * force), c1: '#fff2b0', c2: '#9aa0aa', vit: 5, vie: 0.4, taille: 0.2, grav: 9 });
  else emettre(p, { n: Math.round(10 * force), c1: '#9dff6a', c2: '#ff6a8a', vit: 3, vie: 0.7, taille: 0.25, grav: 4 });
  noeudReel(n, true); n.secoue = 0.25;
  if (force >= 1) son(type === 'bois' ? 'chop' : type === 'mine' ? (Math.random() < 0.5 ? 'impactMining_000' : 'impactMining_001') : 'handleSmallLeather', 0.5);
}
function majNoeuds(dt) {
  for (const n of monde.noeuds) {
    if (n.secoue > 0) { n.secoue -= dt; n.obj.rotation.z = Math.sin(n.secoue * 60) * 0.04 * (n.secoue / 0.25); }
    if (n.pv <= 0) { n.regenT -= dt; if (n.regenT <= 0) { n.pv = n.pvMax; n.obj.visible = true; n.souche.visible = false; n.obj.scale.setScalar(0.01); n.pousse = 1; } }
    if (n.pousse > 0) { n.pousse = Math.max(0, n.pousse - dt * 1.5); n.obj.scale.setScalar(1 - n.pousse); }
    if (n.reel && n.pv > 0 && !(n.secoue > 0) && !(n.pousse > 0)) noeudReel(n, false);
  }
}
// ---- récolte par le joueur (uniquement sur ses îles) ----
function commencerRecolte(n) {
  const ile = monde.ile; const T = ILE_TYPES[ile.type];
  if (capaciteIle(ile) - totalCoffre(ile) <= 0) { UI.toast('Coffre plein : construis ta maison ou vends des ressources'); son('error_001', 0.4); return; }
  recolteJ = { n, t: 0.35, outil: null };
  const arme = joueur.nodes[joueur.def.node]; if (arme) arme.visible = false;
  if (T.outil) recolteJ.outil = joueur.attacher(T.outil, 'handslot.r', { echelle: 0.75 });
  joueur.angle = Math.atan2(n.pos.x - joueur.pos.x, n.pos.z - joueur.pos.z); joueur.root.rotation.y = joueur.angle;
}
function arreterRecolte() {
  if (!recolteJ) return;
  if (recolteJ.outil) recolteJ.outil.removeFromParent();
  const arme = joueur.nodes[joueur.def.node]; if (arme) arme.visible = true;
  recolteJ = null; joueur.jouer(joueur.def.idle);
}
function majRecolteJoueur(dt) {
  if (!recolteJ) return;
  const bouge = Math.hypot(entree.jx, entree.jy) > 0.12 || entree.atk || joueur.mort;
  const n = recolteJ.n;
  if (bouge || n.pv <= 0 || dist2D(n.pos, joueur.pos) > n.rayon + 3) return arreterRecolte();
  recolteJ.t -= dt;
  if (recolteJ.t > 0) return;
  recolteJ.t = 1.35;
  const ile = monde.ile; const T = ILE_TYPES[ile.type];
  joueur.jouer(ile.type === 'cueillette' ? 'PickUp' : '1H_Melee_Attack_Chop', { boucle: false, forcer: true, vitesse: ile.type === 'cueillette' ? 1.1 : 1.0 });
  programmer(ile.type === 'cueillette' ? 0.55 : 0.45, () => {
    if (!recolteJ || recolteJ.n !== n) return;
    effetRecolte(n, ile.type, 1);
    const gain = Math.round(rnd(2, 4) * vitesseIle(ile));
    const ok = ajouterRes(ile, T.res, gain);
    UI.nombre(V(n.pos.x, 2.6, n.pos.z), ok ? `+${ok} ${T.label}` : 'Coffre plein', ok ? 'soin' : 'info');
    n.pv--;
    if (n.pv <= 0) { noeudReel(n, true); n.obj.visible = false; n.souche.visible = true; n.regenT = 40; arreterRecolte(); son('impactPlank_medium_000', 0.5, 0.8); }
    if (!ok) arreterRecolte();
    journalIle(ile); sauver();
  });
}
// ---- construction ----
function construire(ile, plot, t) {
  const prix = prixBatiment(ile, t);
  if (J.argent < prix) { UI.toast('Pas assez d’argent'); son('error_001', 0.4); return; }
  if (BATIMENTS[t].unique && nbBati(ile, t)) { UI.toast('Déjà construit'); return; }
  J.argent -= prix; ile.batiments.push({ plot, t }); sauver();
  son('jingle_loot', 0.5); UI.toast(`${BATIMENTS[t].nom} construit · +0,1 % de vitesse`);
  const pos = joueur.pos.clone();
  entrerIleSansFondu(ile, pos);
}
function entrerIleSansFondu(ile, pos) { // reconstruit l'île en gardant la position du joueur
  const garde = { pv: joueur.pv };
  entrerIle(ile);
  setTimeout(() => { if (joueur && monde.ile === ile) { joueur.pos.copy(pos); G.camTarget.copy(pos); } }, 650);
}
// ---- intendant : améliorer, vendre, ouvriers, sécurité ----
const API_ILE = {
  livrer: (ile) => {
    const besoin = ILE_NIVEAUX[ile.niveau + 1]; if (!besoin) return UI.toast('Niveau maximum atteint');
    const res = ILE_TYPES[ile.type].res;
    const manque = besoin - (ile.livre || 0);
    const don = Math.min(manque, ile.coffre[res] || 0);
    if (!don) { UI.toast(`Il te faut du ${RES_LABEL[res].toLowerCase()} dans ton coffre`); return; }
    ile.coffre[res] -= don; ile.livre = (ile.livre || 0) + don;
    if (ile.livre >= besoin) { ile.niveau++; ile.livre = 0; son('jingle_legend', 0.6); UI.toast(`${ile.nom} passe au niveau ${ile.niveau} !`, true); sauver(); entrerIleSansFondu(ile, joueur.pos.clone()); return; }
    son('handleCoins', 0.5); UI.toast(`Livré : ${fmtN(don)} ${RES_LABEL[res]}`); sauver(); journalIle(ile);
  },
  vendre: (ile, res, part) => {
    const n = Math.floor((ile.coffre[res] || 0) * part); if (!n) return;
    const prix = ILE_TYPES[RESSOURCES[res]].prix;
    ile.coffre[res] -= n; J.argent += n * prix; son('handleCoins', 0.7);
    UI.toast(`Vendu ${fmtN(n)} ${RES_LABEL[res]} : +${fmtN(n * prix)}`); sauver(); journalIle(ile);
  },
  invoquer: (ile, delta) => {
    const v = Math.max(0, Math.min(maxOuvriers(ile), (ile.ouvriers || 0) + delta));
    if (v === (ile.ouvriers || 0)) { if (delta > 0) UI.toast('Construis une maison d’ouvrier pour en invoquer un de plus'); return; }
    majProduction(); ile.ouvriers = v; sauver();
    if (delta > 0 && monde.ile === ile && ouvriers.length < 10) { creerOuvrier(ile, ouvriers.length); onde(ouvriers[ouvriers.length - 1].pos, '#ffd25a', 3, 0.6); }
    if (delta < 0 && monde.ile === ile && ouvriers.length > v) { const o = ouvriers.pop(); G.scene.remove(o.root); UI.retirerPlaque(o); }
    son('confirmation_001', 0.4); journalIle(ile);
  },
  garde: (ile, i) => {
    const def = i === 'champion' ? CHAMPION_ILE : GARDES_ILE[i];
    if (i !== 'champion' && i !== (ile.gardes || 0)) return;
    if (J.argent < def.prix) { UI.toast('Pas assez d’argent'); son('error_001', 0.4); return; }
    J.argent -= def.prix; if (i === 'champion') ile.champion = true; else ile.gardes = (ile.gardes || 0) + 1;
    sauver(); son('jingle_win', 0.5); UI.toast(`${def.nom} recruté`); entrerIleSansFondu(ile, joueur.pos.clone());
  },
};

// ---- assaut des bandits (chaque jour à 21 h) ----
function lancerAssaut(ile) {
  assaut = { ile, fini: false };
  UI.flashInvasion(); UI.toast('ASSAUT DES BANDITS', true); UI.toast('Défends ton coffre !');
  son('lowFrequency_explosion_000', 0.7, 0.7);
  const ipJ = statsHeros(J.equip).ip;
  for (let i = 0; i < 6; i++) {
    const chef = i === 5;
    const d = donneesBot(ipJ * (chef ? 0.95 : 0.7));
    d.nom = chef ? 'Chef des bandits' : hasard(['Bandit des récifs', 'Pilleur', 'Écumeur', 'Coupe-jarret']); d.guilde = 'BANDITS';
    const a = Math.random() * 6.28; const p = pointLibrePres(monde.centre.clone().add(V(Math.cos(a) * monde.rayonMonde * 0.75, 0, Math.sin(a) * monde.rayonMonde * 0.75)), 0, 4);
    const b = creerCombattant(p, d, 'ennemi'); b.bandit = true; b.potions = chef ? 1 : 0;
    if (chef) { b.root.scale.setScalar(1.2); b.pvMax = b.pv = b.pvMax * 1.5; }
    effetArrivee(p);
  }
  UI.journal('Assaut des bandits', 'Élimine tous les bandits. Si tu tombes, ils emportent 70 % de ton coffre.', null);
}
function butinBandits(ile) { return Math.round(4000 * (1 + ile.taille) * (1 + ile.niveau * 0.25)); }
function finCombatIle(e) {
  setTimeout(() => { e.descendre = true; }, 3000);
  const restants = ennemis.filter(x => x.rival && !x.mort && (x.bandit || x.gardeIle));
  if (restants.length) return;
  if (assaut && !assaut.fini) {
    assaut.fini = true; const b = butinBandits(assaut.ile);
    J.argent += b; son('jingle_win', 0.6); UI.toast('Assaut repoussé !', true); exploit('defense_ile'); UI.toast(`Le coffre des bandits : +${fmtN(b)}`);
    gagnerXPRelatif(0.06); journalIle(assaut.ile); sauver();
  } else if (monde.etranger) {
    UI.toast('Le coffre est sans défense !', true); son('jingle_win', 0.6);
    UI.journal('Pillage', `Ouvre le coffre de ${monde.ile.proprio.nom} et repars par le portail doré.`, 1);
    gagnerXPRelatif(0.08);
  }
}
function majAssauts() {
  const now = Date.now();
  for (const ile of iles()) {
    if (!ile.assaut) ile.assaut = prochaineHeure(HEURE_ASSAUT);
    if (!ile.alerte && ile.assaut - now < 15 * 60000 && ile.assaut > now) { ile.alerte = true; UI.toast(`Les bandits attaquent ${ile.nom} dans 15 min`); }
    if (now < ile.assaut) continue;
    ile.assaut = prochaineHeure(HEURE_ASSAUT, now); ile.alerte = false;
    if (monde.type === 'ile' && monde.ile === ile && !assaut) { lancerAssaut(ile); continue; }
    // absent : les gardes s'en chargent, sinon les bandits pillent 70 % du coffre
    const lignes = [];
    const gOmbre = ombreGardeIle(ile);
    if (gOmbre) { const b = Math.round(butinBandits(ile) * 0.35); J.argent += b; lignes.push(`${NOM_O(gOmbre)} a repoussé les bandits sur ${ile.nom}.`, `Ta part de leur coffre (35 %) : +${fmtN(b)}`); exploit('defense_ile'); }
    else if ((ile.gardes || 0) > 0 || ile.champion) {
      const b = Math.round(butinBandits(ile) * 0.1); J.argent += b;
      lignes.push(`Tes gardes ont repoussé les bandits sur ${ile.nom}.`, `Ta part de leur coffre (10 %) : +${fmtN(b)}`, 'Sois présent à 21 h pour récupérer 100 % du butin.');
    } else {
      const pertes = []; for (const r in ile.coffre) { const p = Math.floor(ile.coffre[r] * 0.7); if (p) { ile.coffre[r] -= p; pertes.push(`${fmtN(p)} ${RES_LABEL[r]}`); } }
      lignes.push(`Personne ne défendait ${ile.nom}.`, pertes.length ? `Les bandits ont emporté 70 % du coffre : ${pertes.join(', ')}` : 'Ton coffre était vide : ils sont repartis bredouilles.', 'Recrute des gardes chez Oswin, ou sois là à 21 h.');
    }
    sauver(); UI.rapport('Assaut des bandits', lignes);
  }
}
// ---- pillards (autres joueurs) : de temps en temps, environ toutes les 2 h ----
function majRaids() {
  if (!iles().length || raid || transition || arene) return;
  if (!J.prochainRaid) J.prochainRaid = Date.now() + rnd(100, 140) * 60000;
  if (Date.now() < J.prochainRaid) return;
  J.prochainRaid = Date.now() + rnd(100, 140) * 60000; sauver();
  const ile = hasard(iles());
  const d = donneesBot(statsHeros(J.equip).ip + rnd(-60, 90));
  raid = { ile, d };
  son('lowFrequency_explosion_000', 0.6, 0.9);
  UI.alerteRaid(d, ile, (choix) => {
    if (choix === 'y aller') entrerIle(ile, { raid: d });
    else resoudreRaidGardes(ile, d);
  });
}
function resoudreRaidGardes(ile, d) {
  raid = null;
  const ipJ = statsHeros(J.equip).ip;
  const defense = (ile.gardes || 0) * 0.32 * ipJ + (ile.champion ? 0.55 * ipJ : 0) + (ombreGardeIle(ile) ? 1.2 * ipJ : 0); // une ombre de garde pèse lourd
  const lignes = [];
  if (defense > 0 && defense * rnd(0.75, 1.25) > d.ip * 0.8) {
    const b = Math.round(60 * Math.pow(2.3, d.equip.arme.tier - 1)); J.argent += b;
    lignes.push(`Tes gardes ont repoussé ${d.nom} (⚔ ${d.ip}).`, `Butin récupéré sur lui : +${fmtN(b)}`);
  } else {
    const pertes = []; for (const r in ile.coffre) { const p = Math.floor(ile.coffre[r] * 0.25); if (p) { ile.coffre[r] -= p; pertes.push(`${fmtN(p)} ${RES_LABEL[r]}`); } }
    lignes.push(`${d.nom} (⚔ ${d.ip}) a pillé ${ile.nom}${defense ? ' malgré tes gardes' : ''}.`, pertes.length ? `Perdu : ${pertes.join(', ')}` : 'Ton coffre était vide.');
  }
  sauver(); UI.rapport('Pillage de ton île', lignes);
}
function lancerRaidSurPlace(ile, d) {
  const p = pointLibrePres(monde.coffrePos, 2, 4);
  effetArrivee(p);
  const r = creerCombattant(p, d, 'ennemi'); r.pillard = true; r.volT = 45;
  ileVolee = ile; raid = { ile, d, r };
  UI.toast(`${d.nom} vide ton coffre !`, true);
  UI.journal('Pillard !', `Tue ${d.nom} avant qu’il ne s’enfuie avec 25 % de ton coffre.`, 0);
  setTimeout(() => !r.mort && UI.chat(r.nom, hasard(['oups, pris la main dans le sac', 'trop tard', 'merci pour le bois :)'])), 1500);
}
function majPillard(dt) {
  if (!raid || !raid.r) return;
  const r = raid.r;
  if (r.mort) { raid = null; return; }
  r.volT -= dt;
  UI.journal('Pillard !', `${r.nom} vide ton coffre : il s’enfuit dans ${Math.ceil(r.volT)} s.`, 1 - r.volT / 45);
  if (r.volT <= 0) {
    const ile = raid.ile; const pertes = [];
    for (const k in ile.coffre) { const p = Math.floor(ile.coffre[k] * 0.25); if (p) { ile.coffre[k] -= p; pertes.push(`${fmtN(p)} ${RES_LABEL[k]}`); } }
    effetArrivee(r.pos); G.scene.remove(r.root); UI.retirerPlaque(r); r.mort = true; ennemis.splice(ennemis.indexOf(r), 1);
    UI.boss(null); raid = null; sauver();
    UI.rapport('Le pillard s’est enfui', [pertes.length ? `Perdu : ${pertes.join(', ')}` : 'Ton coffre était vide.']);
    journalIle(ile);
  }
}

