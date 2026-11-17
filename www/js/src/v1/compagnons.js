// ======================= ÉTAPE 5 : COMPAGNONS D'ARMES (mort définitive) + escorte vulnérable =======================
const NOMS_COMPAGNONS = ['Bérenger', 'Ysa', 'Corentin', 'Maëlle', 'Galeran', 'Sixtine', 'Enguerrand', 'Rosalinde', 'Aymeric', 'Léonce'];
let compActeurs = [];
function compagnons() { const v = etatVille(); if (!v.compagnons) v.compagnons = NOMS_COMPAGNONS.slice(0, 3).map(nom => ({ nom, statut: 'vivant', ordre: 'expedition', kills: 0, expeditions: 0 })); return v.compagnons; }
function creerCompagnon(c, pos) {
  let d = donneesBot(statsHeros(J.equip).ip);
  for (let k = 0; c.type && d.equip.arme.type !== c.type && k < 12; k++) d = donneesBot(statsHeros(J.equip).ip);
  c.type = d.equip.arme.type; d.nom = c.nom; d.guilde = ''; d.niv = Math.max(1, ((J.maitrise[J.equip.arme.type] || {}).niv || 1) + ri(0, 2));
  const a = creerCombattant(pos, d, 'allie'); a.compagnonV = c;
  Object.assign(a, { autonome: true, perso: 'loyal', modeA: 'suivre', modeT: 1e9 });
  compActeurs.push(a); return a;
}
function deployerCompagnons(expedition) {
  compActeurs = [];
  for (const c of compagnons()) if (c.statut === 'vivant' && (!expedition || c.ordre === 'expedition')) { creerCompagnon(c, pointLibrePres(expedition ? monde.spawn : joueur.pos, 1.5, 3.5)); if (expedition) c.expeditions++; }
}
function mortCompagnon(a) {
  const c = a.compagnonV; a.jouer('Death_A', { boucle: false });
  c.statut = 'mort'; c.mortLe = Date.now(); { const v = etatVille(); v.volontaire = Math.max(v.volontaire || 0, Date.now() + 20 * 60000); } c.lieu = modeActuel ? (modeActuel.lieu || 'la Place') : 'la Place';
  emettre(V(a.pos.x, 1, a.pos.z), { n: 30, c1: '#ff4a4a', c2: '#3a0505', vit: 4, vie: 1, taille: 0.35, grav: 6 });
  UI.toast(`${c.nom} est mort·e. Pour toujours.`, true); son('lowFrequency_explosion_000', 0.6, 0.6);
  journalVille(`${c.nom}, compagnon d’armes, est tombé·e dans ${c.lieu} après ${c.expeditions} expédition(s).`); moralVille(-8);
  const ami = compActeurs.find(x => x !== a && !x.mort); if (ami) programmer(1.5, () => UI.parole(ami, hasard([`${c.nom} ! NON !`, `On aurait dû reculer… ${c.nom}…`, `Je te vengerai, ${c.nom}.`])));
  sauver();
}
function parlerCompagnon(a) {
  const c = a.compagnonV, v = etatVille(), morts = compagnons().filter(x => x.statut === 'mort'), pertes = v.gens.filter(g => g.statut !== 'vivant').length;
  const texte = morts.length ? `${hasard(morts).nom} me manque. Chaque fois qu’on passe la Brèche, je me demande qui ne reviendra pas.` : pertes ? `On a perdu ${pertes} habitant(s). Je ne veux plus voir ça. Dis-moi quoi faire.` : hasard(['Prêt·e quand tu l’es, gardien.', 'La Brèche ne nous fait pas peur tant qu’on reste ensemble.', 'Les habitants dorment mieux depuis que tu es là.']);
  UI.dialogueTaverne({ nom: c.nom, titre: `Compagnon d’armes · ${c.expeditions} expédition(s) · ${c.ordre === 'expedition' ? 'te suit dans la Brèche' : 'garde la ville'}`, modele: a.data.modele || 'Knight', texte, options: [
    { label: 'Viens avec moi dans la Brèche.', sous: 'Il ou elle t’accompagnera en donjon', action: () => { c.ordre = 'expedition'; UI.dialogueTaverne(null); UI.parole(a, 'Je te couvre.'); sauver(); } },
    { label: 'Reste ici et protège la ville.', sous: 'Restera sur la Place pendant tes expéditions', action: () => { c.ordre = 'ville'; UI.dialogueTaverne(null); UI.parole(a, 'Personne ne touchera à la Place.'); sauver(); } },
    { label: '💬 Parler librement', sous: 'Écris ce que tu veux', action: () => { UI.dialogueTaverne(null); parlerLibreCompagnon(a); } },
    { label: 'Rien. Repose-toi.', action: () => UI.dialogueTaverne(null) }] });
}
function volontaires() {
  const v = etatVille(), C = compagnons();
  if (C.filter(c => c.statut === 'vivant').length >= 3 || Date.now() < (v.volontaire || 0)) return;
  const nom = NOMS_COMPAGNONS.find(n => !C.some(c => c.nom === n)); if (!nom) return;
  C.push({ nom, statut: 'vivant', ordre: 'expedition', kills: 0, expeditions: 0 }); v.volontaire = Date.now() + 20 * 60000;
  journalVille(`${nom} rejoint tes compagnons d’armes.`); programmer(4, () => UI.toast(`${nom} veut combattre à tes côtés`, true));
}
// le captif libéré peut mourir pendant l'évasion
function blesserCaptif(c, d) {
  c.pv -= d; UI.nombre(V(c.pos.x, 2.2, c.pos.z), Math.round(d), 'allie'); c.frapper && c.frapper();
  if (c.pv > 0) { if ((c.criT2 = (c.criT2 || 0) - 1) < 0) { c.criT2 = 4; UI.parole(c, hasard(['Aaah ! Aide-moi !', 'Ils me frappent !', 'Protège-moi !'])); } return; }
  c.mort = true; c.jouer('Death_A', { boucle: false }); UI.retirerPlaque(c);
  c.g.statut = 'mort'; journalVille(`${c.g.nom} (${c.g.metier}) est mort·e pendant l’évasion.`); moralVille(-12);
  UI.toast(`${c.g.nom} est mort·e pendant l’évasion…`, true); son('lowFrequency_explosion_000', 0.5, 0.7); sauver();
}

