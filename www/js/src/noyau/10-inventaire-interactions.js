// ---------------- Inventaire / commerce ----------------
function ajouterSac(it, silencieux = false) {
  if (it.cat === 'potion') { J.potions += it.n || 1; if (joueur) joueur.potions = J.potions; return; }
  if (it.cat === 'butin') { const ex = J.sac.find(x => x.cat === 'butin' && x.type === it.type && (x.tier || 0) === (it.tier || 0)); if (ex) { ex.n += it.n; return; } }
  if (J.sac.length >= 40) { UI.toast('Sac plein : ' + nomObjet(it) + ' perdu'); return; }
  J.sac.push(it);
  if (!silencieux) UI.toast('+ ' + nomObjet(it));
}
const API = {
  reveler: () => revelerPuissance(),
  apparat: () => ouvrirApparat(),
  parolePNJ: (c) => parolePNJ(c),
  choisirLoup: (i) => choisirLoup(i),
  portraitLoup: () => portraitLoup(),
  talents: () => ({ type: (J.equip.arme || {}).type || 'epee', niv: niveauDe((J.equip.arme || {}).type || 'epee'), t: J.talents[(J.equip.arme || {}).type || 'epee'] || {}, slots: J.slotsTalent[(J.equip.arme || {}).type || 'epee'] || {} }),
  monterTalent: (id) => monterTalent(id),
  resetTalents: () => resetTalents(),
  placerCompetence: (id, k) => placerCompetence(id, k),
  ciblerPorteur: (camp) => ciblerPorteur(camp),
  classementGoulet: () => goulet ? lignesClassement() : null,
  reconstruireSorts: () => { if (joueur) UI.construireSorts(joueur); },
  basculerAuto: () => { if (!G.auto && pvpActif()) { UI.toast('Mode auto interdit en JcJ'); return false; } G.auto = !G.auto; try { localStorage.setItem('breche-auto', G.auto ? '1' : '0'); } catch (e) {} if (joueur) joueur.autoCible = null; UI.toast(G.auto ? 'Mode auto activé' : 'Mode auto désactivé'); return G.auto; },
  autoActif: () => !!G.auto,
  etat: () => J,
  son,
  touche: (k, bas) => {
    if (transition) return;
    if (k === 'ATK') { entree.atk = bas; return; }
    if (!bas) return;
    if (arene && arene.t > 0) return;
    if (k === 'POT') return boirePotion();
    if (k === 'CIBLE') { const c = choisirCible(16); joueur.cibleVerrou = joueur.cibleVerrou ? null : c; if (joueur.cibleVerrou) UI.toast('Cible : ' + (c.boss ? c.boss.nom : c.def.nom)); son('click_001', 0.4); return; }
    lancerSort(k);
  },
  equiper: (id) => {
    const i = J.sac.findIndex(x => x.id === id); if (i < 0) return;
    const it = J.sac[i]; const slot = it.cat === 'arme' ? 'arme' : it.type;
    if (!peutPorter(it)) { const nomM = MAITRISES.find(m => m.id === it.type).nom; UI.toast(`Niveau requis : ${nomM} ${niveauRequis(it)} (tu es niveau ${niveauDe(it.type)})`); son('error_001', 0.4); return; }
    const ipAvant = statsHeros(J.equip).ip;
    J.sac.splice(i, 1); if (J.equip[slot]) J.sac.push(J.equip[slot]); J.equip[slot] = it;
    const ipApres = statsHeros(J.equip).ip; if (ipApres !== ipAvant) setTimeout(() => UI.toast(`Puissance ${ipAvant} → ${ipApres} ${ipApres > ipAvant ? '▲' : '▼'}`), 300);
    son('metalLatch', 0.5); recalculer(); construireJoueur(); sauver();
    UI.toast(nomObjet(it) + ' équipé');
  },
  retirer: (slot) => { const it = J.equip[slot]; if (!it) return; if (slot === 'arme') { UI.toast('Garde au moins une arme en main'); return; } J.sac.push(it); J.equip[slot] = null; recalculer(); construireJoueur(); sauver(); },
  acheter: (it) => {
    const prix = valeurObjet(it);
    if (J.argent < prix) { UI.toast('Pas assez d’argent'); son('error_001', 0.3); return; }
    if (it.cat !== 'potion' && J.sac.length >= 40) { UI.toast('Sac plein'); return; }
    J.argent -= prix; const copie = { ...it, id: Date.now() + Math.floor(Math.random() * 1e6) };
    ajouterSac(copie, true); son('handleCoins', 0.6); UI.toast('Acheté : ' + nomObjet(it)); sauver();
  },
  vendre: (id) => {
    const i = J.sac.findIndex(x => x.id == id); if (i < 0) return;
    const it = J.sac[i]; const p = prixVente(it) * (it.n || 1);
    J.argent += p; J.sac.splice(i, 1); son('handleCoins', 0.6); UI.toast(`Vendu : ${nomObjet(it)} (+${p.toLocaleString('fr-FR')})`); sauver();
  },
  vendreButin: () => { let t = 0; J.sac = J.sac.filter(it => { if (it.cat === 'butin') { t += prixVente(it) * it.n; return false; } return true; }); J.argent += t; son('handleCoins', 0.7); UI.toast(`Butin vendu : +${t.toLocaleString('fr-FR')}`); sauver(); },
  rangerPotion: (id) => { const i = J.sac.findIndex(x => x.id == id); if (i >= 0) { J.potions += J.sac[i].n || 1; joueur.potions = J.potions; J.sac.splice(i, 1); sauver(); } },
  entrer: (id, hard) => entrerDonjon(id, { hard }),
  terres: () => entrerTerres(),
  ancestrales: (eq) => entrerAncestrales(eq),
  arene: (format, opts = {}) => entrerArene(format, opts),
  enchanter: (id) => enchanter(id),
  acheterRunes: (n) => { const prix = 5000 * n; if (J.argent < prix) { UI.toast('Pas assez d’argent'); son('error_001', 0.4); return false; } J.argent -= prix; ajouterSac(creerButin('rune', n), true); son('handleCoins', 0.5); sauver(); return true; },
  nbRunes: () => J.sac.filter(i => i.cat === 'butin' && i.type === 'rune').reduce((a, i) => a + (i.n || 1), 0),
  raresDebloques: () => ['ombre', 'orage', 'assassin', 'esprit', 'demon', 'invocateur'].filter(t => (t === 'ombre' && J.codes && J.codes.includes('BRECHE-OMBRE')) || J.equip.arme?.type === t || J.sac.some(i => i.type === t) || (J.debloques || []).includes(t)),
  ombreDebloquee: () => !!((J.codes && J.codes.length) || J.equip.arme?.type === 'ombre' || J.sac.some(i => i.type === 'ombre')),
  acheterIle: (type, taille) => acheterIle(type, taille),
  allerIle: (id) => { const ile = iles().find(i => i.id === id); if (ile) entrerIle(ile); },
  domaine: () => fonderDomaine(), infoDomaine: () => domaine() ? { niveau: DOMAINE_NIVEAUX[domaine().niveau].nom, tresor: Math.floor(domaine().tresor), revenu: revenuDomaine() } : null,
  piller: () => entrerIle(ileBot()),
  construire: (ile, plot, t) => construire(ile, plot, t),
  get ile() { return API_ILE; },
  musique: (on) => musiqueActive(on),
  parchemins: () => etatParchemins(),
  prixTP: () => PRIX_TP,
  acheterTP: () => { if (J.argent < PRIX_TP) { UI.toast('Pas assez d’argent'); son('error_001', 0.4); return false; } J.argent -= PRIX_TP; J.parchTP = (J.parchTP || 0) + 1; son('jingle_legend', 0.5); UI.toast('Parchemin de téléportation acheté'); sauver(); return true; },
  acheterParchemin: (id, n = 1) => { const p = PARCHEMINS[id]; const prix = BOUTIQUE_PARCH_GRATUITE ? 0 : p.prix * n; if (J.argent < prix) { UI.toast('Pas assez d’argent'); son('error_001', 0.4); return false; } J.argent -= prix; ajouterSac(creerParchemin(id, n), true); son('handleCoins', 0.5); sauver(); return true; },
  utiliserParchemin: (itemId) => utiliserParchemin(itemId),
  rang: (mode) => rangDe(mode), classement: (mode) => classementRang(mode), xpLog: () => J.xpLog || [],
  emote: (id) => emoteJoueur(id),
  visable: (k) => { const s = joueur && joueur.sorts[k]; return !!(s && s.portee > 0 && !['bouclier', 'soin', 'sprint', 'buff'].includes(s.type) && s.id !== 'legion'); },
  viseeDebut: (k) => { if (!joueur || joueur.mort || transition) return; visee = { k, s: joueur.sorts[k], dir: null, cible: null }; },
  viseeDir: (dx, dy) => { if (!visee) return; const d = DIR_DROITE.clone().multiplyScalar(dx).addScaledVector(DIR_HAUT, -dy); d.y = 0; if (d.lengthSq() < 1e-4) return; visee.dir = d.normalize(); visee.cible = cibleDansDirection(visee.dir, visee.s.portee); },
  viseeFin: (k, lancer) => { const v = visee; visee = null; cacherVisee(); if (!lancer) return; if (!v) { lancerSort(k); return; } viseeForcee = v.dir && (v.cible || !['reflet', 'pasOmbre', 'execution', 'charge'].includes(v.s.id)) ? { dir: v.dir, cible: v.cible, portee: v.s.portee } : null; if (v.cible) joueur.cible = v.cible; lancerSort(k); viseeForcee = null; },
  sylve: () => { const g = preparerGroupeSylve(); UI.rechercheGroupe(g, () => entrerSylve(g)); },
  modeleJoueur: () => (joueur && joueur.model) || null,
  code: (c) => utiliserCode(c),
  infosIle: (i) => infosIle(i),
  acheterArene: (it) => {
    const prix = prixTrophees(it);
    if ((J.trophees || 0) + (J.renom || 0) < prix) { UI.toast('Pas assez de trophées ni d’honneur'); son('error_001', 0.3); return; }
    if (J.sac.length >= 40) { UI.toast('Sac plein'); return; }
    { const r1 = Math.min(J.renom || 0, prix); J.renom = (J.renom || 0) - r1; J.trophees -= prix - r1; } // la renommée du Goulet paie en premier ajouterSac({ ...it, id: Date.now() + Math.floor(Math.random() * 1e6) }, true);
    son('jingle_loot', 0.5); UI.toast('Acheté : ' + nomObjet(it)); sauver();
  },
  inviter: (data) => {
    UI.toast(`Invitation envoyée à ${data.nom}…`); son('click_001', 0.4);
    setTimeout(() => {
      const ecart = data.ip - statsHeros(J.equip).ip;
      J.rushs = J.rushs || 0;
      if (ecart > 150 && J.rushs >= 3) { UI.toast(`${data.nom} a refusé l’invitation`); return; }
      if (Math.random() < (ecart > 150 ? 0.5 : 0.2)) { UI.toast(`${data.nom} a refusé l’invitation`); UI.chat(data.nom, ecart > 150 ? hasard(['t’es trop low dsl', 'reviens avec du T' + (Math.round((data.ip - 320) / 100) + 1), 'non merci', 'je groupe pas avec les débutants']) : hasard(['dsl je farm', 'pas maintenant', 'je vais déco bientôt', 'déjà en groupe', 'non']), 600); emoteBot(bots.find(b => b.nom === data.nom), ['bof', 'malin', 'oups'], 0.5); return; }
      groupe = data; selection = null; son('confirmation_001', 0.5);
      groupe.fort = ecart > 150; groupe.donjonsRestants = 1 + Math.floor(Math.random() * 3);
      UI.toast(`${data.nom} a rejoint ton groupe`); UI.chat(data.nom, hasard(['go', 'let’s go !', 'je te suis', 'on fait un donjon ?', 'salut, on y va']));
    }, 1200 + Math.random() * 900);
  },
  exclure: () => { if (!groupe) return; UI.toast(`${groupe.nom} a quitté le groupe`); groupe = null; son('close_001', 0.4); },
  duel: (data, mise) => {
    if (mise > J.argent) { UI.toast('Pas assez d’argent pour cette mise'); return; }
    UI.toast(`Défi envoyé à ${data.nom}${mise ? ` (mise ${mise.toLocaleString('fr-FR')})` : ''}…`);
    setTimeout(() => {
      if (Math.random() < (mise > 1000 ? 0.35 : 0.15)) { UI.toast(`${data.nom} refuse le duel`); UI.chat(data.nom, hasard(['non merci', 'trop cher pour moi', 'une autre fois'])); return; }
      J.argent -= mise; sauver(); UI.chat(data.nom, hasard(['ok, à l’arène', 'prépare-toi', 'tu vas regretter :)']));
      entrerArene('1v1', { duel: data, mise });
    }, 1300);
  },
  accepterInvasion: (v) => { J.accepteInvasion = v; sauver(); UI.toast(v ? 'Ton monde est ouvert aux invasions' : 'Ton monde est fermé aux invasions'); },
  envahir: () => { const ip = statsHeros(J.equip).ip; entrerDonjon(ip < 560 ? 0 : ip < 860 ? 1 : 2, { envahir: true }); },
  qualite: (q) => { G.qualite = q; try { localStorage.setItem('breche-qualite', q); } catch (e) {} appliquerNiveau({ haute: 2, moyenne: 1, basse: 0, auto: 2 }[q]); },
  reset: () => { efface = true; if (sauverT) clearTimeout(sauverT); try { localStorage.removeItem(CLE); } catch (e) {} location.reload(); },
};
UI.init(API);

// ---------------- Interactions ----------------
function majInteractions() {
  if (joueur.mort) { UI.action(null); return; }
  if (arene) return UI.action(null);
  if (modeActuel && modeActuel.id === 'ile') return interactionsIle();
  if (modeActuel && modeActuel.id === 'domaine') return interactionsDomaine();
  if (modeActuel && modeActuel.id === 'terres') { const r = interactionsTerres(); if (r !== null) return r; }
  if (captifV && !captifV.libre && dist2D(captifV.pos, joueur.pos) < 3.2) return UI.action(`Libérer ${captifV.g.nom}`, () => libererCaptif());
  if (!modeActuel || modeActuel.id === 'ville') {
    if (portailV && dist2D(portailV.pos, joueur.pos) < 3.2) return UI.action(portailV.canal ? `Refermer le portail… ${Math.round(portailV.ferme * 100)} %` : 'Refermer le portail', () => { portailV.canal = true; });
    for (const a of compActeurs) if (!a.mort && dist2D(a.pos, joueur.pos) < 2.6) return UI.action(`Parler à ${a.nom}`, () => parlerCompagnon(a));
    if (raidV) for (const e of pillards()) if (e.champion && !e.parle && !e.retraite && dist2D(e.pos, joueur.pos) < 5.5) return UI.action(`Parlementer avec ${e.nomChampion}`, () => parlerChampion(e));
    if (!V1 && monde.taverne && dist2D(joueur.pos, monde.taverne.porte) < 4) return UI.action('Entrer au Croc-Rouge', () => entrerTaverne());
    if (marchand && dist2D(joueur.pos, marchand.pos) < 5) return UI.action('Parler à Borin', () => UI.dialogueMarchand());
    if (graveuse && dist2D(joueur.pos, graveuse.pos) < 4.5) return UI.action('Graver des runes', () => UI.runes());
    if (dist2D(joueur.pos, monde.portail.pos) < 9) return UI.action('Franchir la Brèche', () => UI.menuPortail());
    if (monde.portailArene && dist2D(joueur.pos, monde.portailArene.pos) < 9) return UI.action('Entrer dans l’Arène', () => UI.menuArene(groupe));
    if (monde.portailGoulet && dist2D(joueur.pos, monde.portailGoulet.pos) < 6) { const eg = etatPortailGoulet(); if (eg.ouvert) return UI.action(`Goulet des Braises · 10 contre 10 (${Math.floor(eg.reste / 60)}:${String(Math.floor(eg.reste % 60)).padStart(2, '0')})`, () => entrerGoulet()); }
    if ((passeur && dist2D(joueur.pos, passeur.pos) < 4.5) || (monde.portailIle && dist2D(joueur.pos, monde.portailIle.pos) < 5)) return UI.action('Les Îles', () => UI.menuIles(infosIles()));
    return UI.action(null);
  }
  if (monde.crypte && crypteEtat) {
    const C = monde.crypte, E = crypteEtat;
    if (!E.ouverte && dist2D(joueur.pos, C.murObj.pos) < 3.4) return UI.action('Briser le mur fissuré', () => briserMurCrypte());
    if (!E.prise && dist2D(joueur.pos, C.socle) < 3.4) return E.libre ? UI.action('Prendre la relique', () => prendreRelique()) : UI.action('Relique scellée', () => UI.toast('Abats les gardiens de la crypte'));
  }
  for (const c of coffres) {
    if (c.ouvert || dist2D(joueur.pos, c.pos) > 3.6) continue;
    if (c.depouille) return UI.action('Fouiller la dépouille', () => ouvrirDepouille(c));
    if (!(c.boss.mort || c.boss.etat === 'possede')) return UI.action('Coffre scellé', () => UI.toast(`Bats ${(c.boss.boss && c.boss.boss.nom) || c.boss.nom || 'ses gardiens'} pour l’ouvrir`));
    return UI.action('Ouvrir le ' + c.def.nom.toLowerCase(), () => ouvrirCoffre(c));
  }
  if (taverne) return actionTaverne();
  if (sortie && dist2D(joueur.pos, sortie.pos) < 3.2) return mission ? UI.action('Abandonner la mission', () => entrerTaverne()) : UI.action('Retourner sur la Place', () => fondu(() => lancerHub()));
  UI.action(null);
}
function ouvrirCoffre(c, auto = false) {
  if (c.final) return ouvrirCoffreFinal(c);
  c.ouvert = true; UI.action(null); if (c.couleur === 'legendaire') exploit('coffre_legende');
  let pret = false, attente = null; const quandPret = (f) => { if (pret) f(); else attente = f; };
  if (auto) { son('creak1', 0.6); if (c.lid) ajouterVfx(new THREE.Group(), (t) => { c.lid.rotation.x = -Math.min(1, t / 0.5) * 1.9; if (t > 0.6) return false; }); emettre(V(c.pos.x, 1.2, c.pos.z), { n: 60, c1: '#fff2c0', c2: c.def.color, vit: 6, vie: 1, taille: 0.4, grav: 4, monte: 3 }); pret = true; }
  else ceremonieCoffre(c, () => { pret = true; if (attente) attente(); });
  { const sp = projeter(V(c.pos.x, 1.2, c.pos.z)); G.sourceArgentCoffre = sp; }
  const loot = lootCoffre(c.couleur, modeActuel, c.mega ? 3 : c.boss.idx, rangK());
  if (MODES.includes(modeActuel) || modeActuel && modeActuel.sylve) loot.argent = Math.round(loot.argent * (1 + 0.25 * rangDe('donjon').i) * (1 + bonusParch('argent')));
  { const bd = bonusParch('drop'); if (bd > 0) { const extra = lootCoffre(c.couleur, modeActuel, c.boss.idx || 0).objets; for (const it of extra) if (Math.random() < bd * 1.6) loot.objets.push(it); if (extra.length && Math.random() < bd) loot.objets.push(extra[0]); } }
  if (c.mega) {
    loot.argent *= 8; const tm = modeActuel.tiers[1];
    loot.objets.push(...[0, 1, 2].map(() => Math.random() < 0.5 ? creerArme(hasard(CLASSES_BASE), tm, 3 + (Math.random() < 0.4 ? 1 : 0)) : creerArmure(hasard(['casque', 'plastron', 'bottes']), tm, 3 + (Math.random() < 0.4 ? 1 : 0))), creerButin('rune', 12));
    const g0 = G.chanceOmbre; G.chanceOmbre = 0.05; tirageOmbre(tm, tm, 'boss'); G.chanceOmbre = g0;
  }
  if (J.accepteInvasion) loot.argent = Math.round(loot.argent * 1.25);
  if (modeHard) loot.argent *= 3;
  loot.bonus = [];
  { const rk = (MODES.includes(modeActuel) || modeActuel && modeActuel.sylve) ? rangDe('donjon') : null; if (rk && rk.i) loot.bonus.push({ pct: 25 * rk.i, txt: 'rang ' + rk.r.nom, i: '♛', c: rk.r.c2 }); }
  { const bp = Math.round(bonusParch('argent') * 100); if (bp) loot.bonus.push({ pct: bp, txt: 'parchemin d’argent', i: '¤', c: '#e8902a' }); }
  if (J.accepteInvasion) loot.bonus.push({ pct: 25, txt: 'zone d’invasion', i: '⚔', c: '#c0281a' });
  if (modeHard) loot.bonus.push({ pct: 200, txt: 'mode Hard', i: '☠', c: '#7a0a1a' });
  if (coequipiers().length) { // en groupe, le coffre est partagé en deux
    const a = coequipiers()[0]; const moitie = Math.round(loot.argent / 2);
    loot.allie = { nom: a.nom, argent: loot.argent - moitie, objets: loot.objets.filter((_, i) => i % 2 === 1) };
    loot.argent = moitie; loot.objets = loot.objets.filter((_, i) => i % 2 === 0);
  }
  if (auto) { // l'escouade ramasse tout : butin ajouté directement et affiché à l'écran
    J.argent += loot.argent; for (const it of loot.objets) ajouterSac(it, true); son('handleCoins', 0.5); c.beam.visible = false; sauver();
    UI.butinFlash(c.couleur, loot); return;
  }
  quandPret(() => UI.butin(c.couleur, loot, () => { G.sourceArgent = { x: innerWidth / 2, y: innerHeight * 0.42 }; J.argent += loot.argent; for (const it of loot.objets) ajouterSac(it, true); son('handleCoins', 0.6); sauver(); c.beam.visible = false; }, { mode: modeActuel }));
}

function interactionsIle() {
  const ile = monde.ile;
  if (dist2D(joueur.pos, monde.portail.pos) < 3.5) return UI.action('Retourner sur la Place', () => fondu(() => lancerHub()));
  if (monde.etranger) {
    const gardes = ennemis.filter(e => e.gardeIle && !e.mort).length;
    if (dist2D(joueur.pos, monde.coffrePos) < 3.2) return gardes ? UI.action('Coffre gardé', () => UI.toast(`Il reste ${gardes} garde${gardes > 1 ? 's' : ''}`)) : (monde.pille ? UI.action(null) : UI.action('Piller le coffre', pillerCoffre));
    return UI.action(null);
  }
  if (intendant && dist2D(joueur.pos, intendant.pos) < 4) return UI.action('Parler à Oswin', () => UI.menuIntendant(ile, infosIle(ile)));
  if (assaut && !assaut.fini) return UI.action(null);
  if (!recolteJ) {
    let best = null, bd = Infinity;
    for (const n of monde.noeuds) { if (n.pv <= 0) continue; const d = dist2D(n.pos, joueur.pos) - n.rayon; if (d < 2.2 && d < bd) { bd = d; best = n; } }
    if (best) return UI.action(ILE_TYPES[ile.type].verbe, () => commencerRecolte(best));
  } else return UI.action('Arrêter', arreterRecolte);
  for (const p of monde.plots) if (!p.bati && dist2D(p.pos, joueur.pos) < 3.6) return UI.action('Construire ici', () => UI.menuConstruction(ile, p.idx, infosIle(ile)));
  if (dist2D(joueur.pos, monde.coffrePos) < 3) return UI.action('Voir le coffre', () => UI.menuIntendant(ile, infosIle(ile), 'coffre'));
  UI.action(null);
}
function pillerCoffre() {
  const bot = monde.ile; monde.pille = true; const res = ILE_TYPES[bot.type].res;
  const butin = Math.floor((bot.coffre[res] || 0) * 0.4);
  const cible = iles().find(i => i.type === bot.type) || iles()[0];
  let ok = 0; if (cible) ok = ajouterRes(cible, res, butin);
  const reste = butin - ok; const argent = Math.round(reste * ILE_TYPES[bot.type].prix * 0.7); J.argent += argent;
  son('jingle_legend', 0.6); emettre(V(monde.coffrePos.x, 1.2, monde.coffrePos.z), { n: 80, c1: '#fff2c0', c2: '#ffc84a', vit: 6, vie: 1, taille: 0.4, grav: 4 });
  UI.butinPillage({ res, butin, ok, cible: cible ? cible.nom : null, reste, argent, proprio: bot.proprio.nom, ile: bot.nom });
  sauver();
}
function infosIle(ile) {
  majProduction();
  const prix = {}; for (const t in BATIMENTS) prix[t] = prixBatiment(ile, t);
  return { cap: capaciteIle(ile), vitesse: vitesseIle(ile), maxOuv: maxOuvriers(ile), prix, total: totalCoffre(ile), assaut: ile.assaut, besoin: ILE_NIVEAUX[ile.niveau + 1] || 0, nbEmpl: nbEmplacements(ile), argent: J.argent,
    prodHeure: Math.round(Math.min(ile.ouvriers || 0, maxOuvriers(ile)) * vitesseIle(ile) * 450) };
}
function infosIles() { majProduction(); majDomaine(); return { iles: iles().map(i => ({ ile: i, ...infosIle(i) })), argent: J.argent, ip: statsHeros(J.equip).ip, nomJ: J.nom, domaine: domaine() ? { niveau: DOMAINE_NIVEAUX[domaine().niveau].nom, tresor: Math.floor(domaine().tresor), revenu: revenuDomaine() } : null }; }

// ---------------- Entrées ----------------
function initEntrees() {
  const zone = $('#zoneJoy'), joy = $('#joy'), stick = joy.querySelector('.stick');
  let id = null, cx = 0, cy = 0;
  const R = () => joy.offsetWidth * 0.42;
  zone.addEventListener('pointerdown', (e) => {
    id = e.pointerId; zone.setPointerCapture(id);
    cx = e.clientX; cy = e.clientY;
    joy.style.left = cx + 'px'; joy.style.bottom = (innerHeight - cy) + 'px'; joy.style.transform = 'translate(-50%,50%)';
  });
  zone.addEventListener('pointermove', (e) => {
    if (e.pointerId !== id) return;
    let dx = e.clientX - cx, dy = e.clientY - cy; const l = Math.hypot(dx, dy), r = R();
    if (l > r) { dx *= r / l; dy *= r / l; }
    stick.style.transform = `translate(${dx}px,${dy}px)`;
    entree.jx = dx / r; entree.jy = -dy / r;
  });
  const fin = (e) => { if (e.pointerId !== id) return; id = null; entree.jx = entree.jy = 0; stick.style.transform = ''; joy.style.left = ''; joy.style.bottom = ''; };
  zone.addEventListener('pointerup', fin); zone.addEventListener('pointercancel', fin); zone.addEventListener('lostpointercapture', fin);
  // filet de sécurité : si le doigt est levé ailleurs (une fenêtre s'est ouverte par-dessus), le joystick se relâche quand même
  window.addEventListener('pointerup', fin, true); window.addEventListener('pointercancel', fin, true);
  // tap sur la scène : choisir une cible ou interagir ; un tracé dessine un signe de sort
  initGestes($('#scene'), {
    actif: () => enJeu && joueur && !joueur.mort && !!modeActuel && G.gestes !== false,
    couleur: () => COUL_SIGNE[J.equip.arme ? J.equip.arme.type : 'epee'] || '#ffb347',
    tap: (e) => tapScene(e),
    rate: () => { UI.toast('Signe non reconnu'); son('error_001', 0.2); },
    lancer: (cle, debut, centre) => lancerParSigne(cle, debut, centre),
  });
  function tapScene(e) {
    if (!enJeu || !joueur) return;
    if (loupChoisi) { envoyerLoup(e.clientX, e.clientY); return; }
    let best = null, bd = 70;
    for (const en of vivants()) { const s = projeter(V(en.pos.x, 1.2, en.pos.z)); const d = Math.hypot(s.x - e.clientX, s.y - e.clientY); if (d < bd) { bd = d; best = en; } }
    if (best) { joueur.cibleVerrou = best; son('click_001', 0.3); return; }
    if (!modeActuel) {
      let bb = null, bd2 = 60;
      for (const b of bots) { const s = projeter(V(b.pos.x, 1.2, b.pos.z)); const d = Math.hypot(s.x - e.clientX, s.y - e.clientY); if (d < bd2) { bd2 = d; bb = b; } }
      if (bb) { selection = bb; son('select_001', 0.4); majCadreAutre(); return; }
      selection = null;
    }
    if (marchand) { const s = projeter(V(marchand.pos.x, 1.2, marchand.pos.z)); if (Math.hypot(s.x - e.clientX, s.y - e.clientY) < 70 && dist2D(joueur.pos, marchand.pos) < 7) UI.dialogueMarchand(); }
  }
  window.addEventListener('keydown', (e) => {
    entree.clavier[e.key] = true;
    const k = e.key.toUpperCase();
    if (['Q', 'W', 'E', 'R', 'D', 'F'].includes(k)) API.touche(k, true);
    if (k === 'G') API.touche('A', true);
    if (k === 'O' && J.escouade) ouvrirCommandeOmbres();
    if (k === '1') API.touche('POT', true);
    if (k === 'I') UI.ouvrirInventaire();
    if (e.key === 'Tab' && goulet) { e.preventDefault(); UI.classementGoulet(UI.classementOuvert() ? null : { live: true }); }
    if (k === 'T') API.touche('CIBLE', true);
  });
  window.addEventListener('keyup', (e) => { entree.clavier[e.key] = false; });
  // zoom : molette, ou deux doigts sur la scène (pincer)
  const zoomer = (f) => { G.camZoom = Math.max(0.25, Math.min(1.7, (G.camZoom || 1) * f)); try { localStorage.setItem('breche-zoom', G.camZoom.toFixed(2)); } catch (er) {} };
  window.addEventListener('wheel', (e) => { if (e.target.closest && e.target.closest('#regl,#inv,#butin,.parchemin,#dlgRelique,#dialTaverne,#tabMissions,#cmdOmbres')) return; zoomer(e.deltaY > 0 ? 1.06 : 0.94); }, { passive: true });
  let pince = null;
  const scene = $('#scene');
  { let dr = null;
    scene.addEventListener('pointerdown', (e) => { if (e.button === 1) return; dr = { id: e.pointerId, x: e.clientX, y: e.clientY, bouge: false }; });
    scene.addEventListener('pointermove', (e) => {
      if (!dr || e.pointerId !== dr.id || pince) return; const vue = G.camVue || 'iso'; if (vue === 'iso') return;
      const dx = e.clientX - dr.x, dy = e.clientY - dr.y; if (!dr.bouge && Math.hypot(dx, dy) < 12) return; dr.bouge = true;
      const sens = G.camSens || 1; G.camYaw -= dx * 0.008 * sens; if (vue === 'libre') G.camPitchLibre = Math.max(0.1, Math.min(1.35, (G.camPitchLibre ?? 0.62) + dy * 0.005 * sens));
      dr.x = e.clientX; dr.y = e.clientY; G.dragT = G.t;
    });
    const finDr = (e) => { if (dr && e.pointerId === dr.id) dr = null; }; scene.addEventListener('pointerup', finDr); scene.addEventListener('pointercancel', finDr);
  }
  scene.addEventListener('touchstart', (e) => { if (e.touches.length === 2) pince = Math.hypot(e.touches[0].clientX - e.touches[1].clientX, e.touches[0].clientY - e.touches[1].clientY); }, { passive: true });
  scene.addEventListener('touchmove', (e) => { if (e.touches.length !== 2 || !pince) return; const d = Math.hypot(e.touches[0].clientX - e.touches[1].clientX, e.touches[0].clientY - e.touches[1].clientY); if (Math.abs(d - pince) > 8) { zoomer(pince / d > 1 ? 1.04 : 0.96); pince = d; } }, { passive: true });
  scene.addEventListener('touchend', () => { pince = null; }, { passive: true });
  $('#btnInv').onclick = () => UI.ouvrirInventaire();
  $('#cadreAutre').onclick = () => {
    const d = selection ? selection.data : groupe || (allies[0] && allies[0].data);
    if (!d || modeActuel) return;
    UI.menuJoueur(d, !!(groupe && groupe.nom === d.nom), !!groupe);
  };
  $('#btnReg').onclick = () => UI.reglages();
  $('#btnOmbres').onclick = () => ouvrirCommandeOmbres(); { const b = $('#btnRoyaume'); if (b) b.onclick = () => ouvrirRoyaume(); }
  { const b = $('#btnArmes'); if (b) b.onclick = () => rangerArmes(); }
  { const b = $('#btnAggro'); if (b) b.onclick = () => basculerAgression(); }
  { const b = $('#btnDemon'); if (b) b.onclick = () => basculerDemon(); }
  { const b = $('#btnPacte'); if (b) b.onclick = () => ouvrirAutel(); }
  $('#btnCam').onclick = () => { const vues = ['iso', 'heros', 'libre'], noms = { iso: 'Vue isométrique', heros: 'Vue héros : derrière ton personnage (glisse pour tourner)', libre: 'Vue libre : glisse pour tourner, pince pour zoomer' };
    G.camVue = vues[(vues.indexOf(G.camVue || 'iso') + 1) % 3]; if (G.camVue === 'heros' && joueur) G.camYaw = joueur.angle + Math.PI; try { localStorage.setItem('breche-vue', G.camVue); } catch (e) {} UI.toast(noms[G.camVue]); son('click_001', 0.4); };
  $('#avatarCv').parentElement.onclick = () => ouvrirRenommee(); $('#avatarCv').parentElement.style.cursor = 'pointer';
  $('#btnChat').onclick = () => UI.chat(J.nom, 'Salut tout le monde !');
  $('#btnEmote').onclick = (ev) => { ev.stopPropagation(); son('click_001', 0.4); UI.panneauEmotes(); };
  let quitConf = 0;
  $('#btnQuitter').onclick = () => {
    if (!modeActuel) return;
    if (Date.now() - quitConf > 2500) { quitConf = Date.now(); UI.toast(arene ? 'Touche encore pour abandonner le combat' : 'Touche encore pour quitter le donjon'); return; }
    fondu(() => lancerHub());
  };
}

// ---------------- Portes : elles s'ouvrent quand quelqu'un approche, se referment derrière lui ----------------
let porteT = 0;
function majPortes(dt) {
  const L = monde && monde.portes; if (!L || !L.length) return;
  porteT -= dt;
  if (porteT <= 0) {
    porteT = 0.15;
    for (const P of L) {
      let pres = false;
      for (const a of G.acteurs) { if (!a.root.parent) continue; const p = a.root.position; if (Math.abs(p.x - P.pos.x) + Math.abs(p.z - P.pos.z) < P.rayon * 1.3 && Math.hypot(p.x - P.pos.x, p.z - P.pos.z) < P.rayon) { pres = true; break; } }
      if (pres && !P.ouvert) { son('doorOpen_1', 0.35, 0.95); P.ouvert = true; } else if (!pres && P.ouvert) { P.ouvert = false; P.fermeT = 0.9; }
    }
  }
  for (const P of L) {
    if (!P.battant) continue;
    const but = P.ouvert ? 1 : 0, v = P.ouvert ? 3.2 : 1.8;
    const avant = P.ouv; P.ouv += Math.sign(but - P.ouv) * Math.min(Math.abs(but - P.ouv), dt * v);
    // petit rebond en fin de course : la porte « claque » doucement
    const e = P.ouv < 1 ? 1 - Math.pow(1 - P.ouv, 3) : 1;
    P.battant.rotation.y = P.sens * e * 1.75;
    if (avant > 0.02 && P.ouv <= 0.02 && !P.ouvert) son('creak1', 0.25, 1.2);
  }
}
// ---------------- Diagnostic de fluidité (Réglages → Afficher les FPS) ----------------
// mesure le temps de chaque système du jeu : en cas de saccade, l'écran dit QUI a pris le temps
let PROF_ON = false; const PROF = {}, PROF_MAX = {}; let profGel = '';
function profNote(n, d) { PROF[n] = (PROF[n] || 0) + d; if (d > (PROF_MAX[n] || 0)) PROF_MAX[n] = d; }
function instrumenter() {
  if (PROF_ON) return; PROF_ON = true;
  const W = (n, f) => function (...a) { const t = performance.now(); try { return f.apply(this, a); } finally { profNote(n, performance.now() - t); } };
  majJoueur = W('majJoueur', majJoueur);
  majEnnemis = W('majEnnemis', majEnnemis);
  majAllies = W('majAllies', majAllies);
  majProjectiles = W('majProjectiles', majProjectiles);
  majBots = W('majBots', majBots);
  majEscouade = W('majEscouade', majEscouade);
  majCommandeOmbres = W('majCommandeOmbres', majCommandeOmbres);
  majServiteurs = W('majServiteurs', majServiteurs);
  majScenes = W('majScenes', majScenes);
  majTK = W('majTK', majTK);
  majLames = W('majLames', majLames);
  majPortes = W('majPortes', majPortes);
  majVueOmbre = W('majVueOmbre', majVueOmbre);
  majInteractions = W('majInteractions', majInteractions);
  majMini = W('majMini', majMini);
  majParchemins = W('majParchemins', majParchemins);
  sauverMaintenant = W('sauverMaintenant', sauverMaintenant);
  majInvasion = W('majInvasion', majInvasion);
  majArene = W('majArene', majArene);
  majSylve = W('majSylve', majSylve);
  majMission = W('majMission', majMission);
  majRegards = W('majRegards', majRegards);
  majAuras = W('majAuras', majAuras);
  majDomaine = W('majDomaine', majDomaine);
  majProduction = W('majProduction', majProduction);
  majOuvriers = W('majOuvriers', majOuvriers);
  majMeuteJoueur = W('majMeuteJoueur', majMeuteJoueur);
  majTaverne = W('majTaverne', majTaverne);
  majCrypte = W('majCrypte', majCrypte);
  UI.majPlaques = W('plaques', UI.majPlaques); UI.majHud = W('hud', UI.majHud); UI.gainArgent = W('bourse', UI.gainArgent); UI.nombre = W('nombres', UI.nombre);
}
function rapportProf(n, dureeMs) {
  const top = Object.entries(PROF).sort((a, b) => b[1] - a[1]).slice(0, 5).map(([k, v]) => `${k.replace(/^maj/, '')} ${(v / n).toFixed(1)}ms (max ${Math.round(PROF_MAX[k] || 0)})`).join(' · ');
  for (const k in PROF) { delete PROF[k]; delete PROF_MAX[k]; }
  return top;
}
