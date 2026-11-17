// ======================= ÉTAPE 6 : LE ROYAUME — trésor, impôts, décrets, justice =======================
const IMPOTS = { leger: { nom: 'Léger', parMin: 3, moral: 1 }, normal: { nom: 'Normal', parMin: 6, moral: 0 }, lourd: { nom: 'Lourd', parMin: 11, moral: -2 } };
let prochaineAffaire = 0;
function royaume() { const v = etatVille(); if (v.tresor === undefined) Object.assign(v, { tresor: 0, impot: 'normal', fortif: 0, affaires: [], dernierImpot: Date.now() }); return v; }
const vivantsVille = () => etatVille().gens.filter(g => g.statut === 'vivant');
function percevoirImpots() {
  const v = royaume(), now = Date.now(), min = Math.min(480, (now - v.dernierImpot) / 60000); if (min < 1) return;
  const I = IMPOTS[v.impot], n = vivantsVille().length;
  v.tresor += Math.round(n * I.parMin * min * (0.5 + v.moral / 100)); v.dernierImpot = now;
  if (I.moral) moralVille(I.moral * min / 5);
  // fin des peines de prison
  for (const g of v.gens) if (g.statut === 'prison' && now > g.libereLe) { g.statut = 'vivant'; journalVille(`${g.nom} a purgé sa peine et retrouve la Place.`); }
}
// ---- justice ----
const AFFAIRES = [
  { type: 'vol', p: 0.6, titre: (a, b) => `${b.nom} accuse ${a.nom} de vol`, recit: (a, b) => `${b.nom} jure avoir vu ${a.nom} s’enfuir avec sa bourse après le dernier raid. ${a.nom} affirme qu’il ou elle aidait les blessés à ce moment-là.` },
  { type: 'bagarre', p: 0.7, titre: (a, b) => `Rixe entre ${a.nom} et ${b.nom}`, recit: (a, b) => `${a.nom} aurait frappé ${b.nom} au visage devant la fontaine. ${a.nom} dit avoir été provoqué·e : ${b.nom} l’aurait traité·e de lâche pendant le raid.` },
  { type: 'complice', p: 0.35, titre: (a) => `${a.nom} soupçonné·e d’aider la Brèche`, recit: (a, b) => `${b.nom} raconte avoir vu ${a.nom} parler à un cultiste la nuit, près de l’ancien portail. ${a.nom} nie tout et parle de jalousie.` },
  { type: 'deserteur', p: 0.55, titre: (a) => `${a.nom} a fui pendant le raid`, recit: (a, b) => `Pendant la dernière attaque, ${a.nom} aurait abandonné ${b.nom} blessé·e pour sauver sa peau. ${a.nom} dit qu’il ou elle allait chercher de l’aide.` },
];
function nouvelleAffaire() {
  const v = royaume(), V_ = vivantsVille(); if (V_.length < 4 || v.affaires.length >= 2) return;
  const T = hasard(AFFAIRES), [a, b] = [...V_].sort(() => Math.random() - 0.5);
  v.affaires.push({ id: Date.now(), type: T.type, accuse: a.id, plaignant: b.id, coupable: Math.random() < T.p, titre: T.titre(a, b), recit: T.recit(a, b), enquete: 0 });
  UI.toast('⚖ Une affaire attend ton jugement (bouton Royaume)', true); son('select_001', 0.5); sauver();
}
const parId = (id) => etatVille().gens.find(g => g.id === id);
function rendreVerdict(af, verdict) {
  const v = royaume(), a = parId(af.accuse); v.affaires = v.affaires.filter(x => x !== af); UI.dialogueTaverne(null);
  if (!a || a.statut !== 'vivant') return;
  const puni = verdict !== 'acquitter', C = af.coupable;
  if (verdict === 'amende') { v.tresor += 300; }
  if (verdict === 'prison') { a.statut = 'prison'; a.libereLe = Date.now() + 20 * 60000; const c = citoyens.find(x => x.g === a); if (c) { c.etat = 'parti'; fumeeOmbre(c.pos); G.scene.remove(c.root); UI.retirerPlaque(c); citoyens.splice(citoyens.indexOf(c), 1); } }
  if (verdict === 'bannir') { a.statut = 'banni'; const c = citoyens.find(x => x.g === a); if (c) { c.etat = 'parti'; UI.parole(c, C ? '…Je ne reviendrai pas.' : 'Je suis innocent·e ! Vous le regretterez tous !'); setTimeout(() => { G.scene.remove(c.root); UI.retirerPlaque(c); }, 2500); } }
  const lib = { acquitter: 'acquitté·e', amende: 'condamné·e à une amende', prison: 'emprisonné·e 20 min', bannir: 'banni·e de la ville' }[verdict];
  journalVille(`Jugement : ${a.nom} ${lib} (${af.titre.toLowerCase()}).`);
  UI.toast(`${a.nom} ${lib}`, true);
  if (puni && C) moralVille(verdict === 'bannir' && af.type !== 'complice' ? -1 : 3);
  if (!puni && !C) moralVille(2);
  // la vérité finit toujours par éclater
  programmer(rnd(70, 150), () => {
    if (puni && !C) { const d = verdict === 'bannir' ? -15 : verdict === 'prison' ? -8 : -4; moralVille(d); journalVille(`La vérité éclate : ${a.nom} était innocent·e. Le peuple doute de ta justice.`); UI.toast(`La vérité éclate : ${a.nom} était innocent·e…`, true); }
    else if (!puni && C && af.type === 'complice') { moralVille(-6); etatVille().traitre = a.id; journalVille(`${a.nom} a de nouveau ouvert la porte aux cultistes. Le prochain raid sera plus violent.`); UI.toast(`${a.nom} a trahi la ville !`, true); }
    else if (!puni && C) { moralVille(-3); journalVille(`${a.nom} a récidivé. Les habitants murmurent que tu es trop clément.`); }
    sauver();
  });
  sauver();
}
function ouvrirAffaire(af) {
  const a = parId(af.accuse), b = parId(af.plaignant); if (!a) return;
  const now = Date.now();
  let texte = af.recit + ` <br><i>La foule murmure : « ${Math.random() < (af.coupable ? 0.7 : 0.3) ? 'Coupable !' : 'Laissez-le·la tranquille !'} »</i>`;
  if (af.aveu) texte += `<br><b style="color:#ff8a6a">${a.nom} A AVOUÉ.</b>`;
  if (af.enquete && now >= af.enquete) texte += `<br><b>Rapport de ton ombre :</b> ${(Math.random() < 0.9) === af.coupable ? `${a.nom} est coupable.` : `${a.nom} est innocent·e.`}`;
  else if (af.enquete) texte += `<br><b>Une ombre enquête…</b> rapport dans ${Math.ceil((af.enquete - now) / 60000)} min.`;
  const opts = [];
  if (!af.enquete) opts.push({ label: '🕵 Enquêter d’abord', sous: 'Une ombre fouille la vérité (3 min)', action: () => { af.enquete = Date.now() + 3 * 60000; UI.dialogueTaverne(null); UI.toast('Une ombre se glisse dans la ville…'); sauver(); } });
  opts.push({ label: '💬 Interroger l’accusé·e', sous: 'Écris tes questions', action: () => { UI.dialogueTaverne(null); interrogerAccuse(af); } });
  opts.push({ label: 'Acquitter', sous: 'Libre', action: () => rendreVerdict(af, 'acquitter') });
  opts.push({ label: 'Amende', sous: '+300 ¤ au trésor', action: () => rendreVerdict(af, 'amende') });
  opts.push({ label: 'Emprisonner', sous: '20 min hors de la Place', action: () => rendreVerdict(af, 'prison') });
  opts.push({ label: 'Bannir', sous: 'Définitif', action: () => rendreVerdict(af, 'bannir') });
  UI.dialogueTaverne({ nom: af.titre, titre: `Accusé·e : ${a.nom} (${a.metier}) · Plaignant·e : ${b ? b.nom : '—'}`, modele: a.modele, texte, options: opts });
}
// ---- le panneau du royaume ----
function ouvrirRoyaume() {
  percevoirImpots();
  const v = royaume(), n = vivantsVille().length, I = IMPOTS[v.impot];
  const perdus = v.gens.filter(g => g.statut === 'mort' || g.statut === 'sacrifie').length, prison = v.gens.filter(g => g.statut === 'prison').length, bannis = v.gens.filter(g => g.statut === 'banni').length;
  const coutF = 5000 * (v.fortif + 1);
  const texte = `<b>${n}</b> habitants · moral <b>${Math.round(v.moral)} %</b> · trésor <b>${fmtN(Math.floor(v.tresor))} ¤</b><br>Impôt <b>${I.nom}</b> (${I.parMin} ¤/habitant/min) · fortifications <b>${v.fortif}/3</b><br>Morts ou sacrifiés : ${perdus} · en prison : ${prison} · bannis : ${bannis}`;
  const opts = [];
  for (const af of v.affaires) opts.push({ label: '⚖ ' + af.titre, sous: 'Rendre la justice', action: () => ouvrirAffaire(af) });
  opts.push({ label: `💰 Impôt : ${I.nom}`, sous: 'Léger → le peuple t’aime · Lourd → le trésor se remplit, le moral chute', action: () => { const k = Object.keys(IMPOTS); v.impot = k[(k.indexOf(v.impot) + 1) % k.length]; journalVille(`Décret : impôt ${IMPOTS[v.impot].nom.toLowerCase()}.`); sauver(); ouvrirRoyaume(); } });
  if (v.fortif < 3) opts.push({ label: `🏰 Fortifier la Place (${fmtN(coutF)} ¤)`, sous: 'Raids moins nombreux et plus espacés', desactive: v.tresor < coutF, action: () => { v.tresor -= coutF; v.fortif++; journalVille(`Décret : fortifications niveau ${v.fortif}.`); moralVille(4); UI.toast('Les palissades montent autour de la Place', true); sauver(); ouvrirRoyaume(); } });
  opts.push({ label: '🍖 Offrir un festin (2 000 ¤)', sous: 'Moral +15', desactive: v.tresor < 2000, action: () => { v.tresor -= 2000; moralVille(15); journalVille('Tu offres un festin au peuple.'); for (const c of citoyens) if (Math.random() < 0.4) UI.parole(c, hasard(['Longue vie au gardien !', 'À la santé du seigneur !', 'Enfin une bonne nouvelle !'])); sauver(); ouvrirRoyaume(); } });
  if (v.tresor >= 100) opts.push({ label: `🪙 Te servir dans le trésor (+${fmtN(Math.floor(v.tresor))} ¤)`, sous: 'Le peuple le verra : moral −8', action: () => { J.argent += Math.floor(v.tresor); v.tresor = 0; moralVille(-8); journalVille('Tu as vidé le trésor pour toi-même.'); UI.majArgent && UI.majArgent(); sauver(); ouvrirRoyaume(); } });
  opts.push({ label: '📜 Chronique de la ville', action: () => UI.dialogueTaverne({ nom: 'Chronique', titre: 'Les derniers événements', modele: 'Mage', texte: v.journal.slice(0, 8).map(x => '• ' + x.txt).join('<br>') || 'Rien encore.', options: [{ label: '← Retour', action: () => ouvrirRoyaume() }] }) });
  UI.dialogueTaverne({ nom: 'Royaume de la Place des Cendres', titre: `Seigneur ${J.nom}`, modele: ARMES[J.equip.arme.type].model, texte, options: opts });
}
function majRoyaume() {
  const b = $('#btnRoyaume'); if (b && b.hidden) b.hidden = false;
  if (b) b.classList.toggle('alerte', royaume().affaires.length > 0);
  if ((G.majRoyT = (G.majRoyT || 0) - 1) <= 0) { G.majRoyT = 600; percevoirImpots(); }
  if (G.t > prochaineAffaire) { prochaineAffaire = G.t + rnd(240, 420); if (!raidV) nouvelleAffaire(); }
}

