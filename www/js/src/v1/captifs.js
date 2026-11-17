// ======================= ÉTAPE 4 : SAUVER LES ENLEVÉS DANS LA BRÈCHE =======================
const DELAI_SACRIFICE = 45 * 60000; // après ça, il est trop tard
let captifV = null;
function verifierSacrifices() {
  const v = etatVille(); let n = 0;
  for (const g of v.gens) if (g.statut === 'enleve') {
    if (!g.enleveLe) g.enleveLe = Date.now(); if (g.lieu === undefined) g.lieu = 0;
    if (Date.now() - g.enleveLe > DELAI_SACRIFICE) { g.statut = 'sacrifie'; n++; journalVille(`Trop tard. ${g.nom} (${g.metier}) a été sacrifié·e dans ${LIEUX[g.lieu]}.`); programmer(2 + n, () => UI.toast(`Trop tard… ${g.nom} a été sacrifié·e dans la Brèche`, true)); moralVille(-10); }
  }
}
function placerCaptif(id) {
  const v = etatVille(); verifierSacrifices();
  const g = v.gens.find(x => x.statut === 'enleve' && x.lieu === id); if (!g) return;
  const s = monde.bossSalles[3] || monde.bossSalles[monde.bossSalles.length - 1]; if (!s) return;
  const a = new Acteur(g.modele, { hauteur: 1.95 });
  a.montrerSeul([], Object.keys(a.nodes).filter(n => /Sword|Axe|Shield|Crossbow|Staff|Wand|Knife|Throwable|Spellbook|Offhand/.test(n)));
  a.root.position.copy(pointLibrePres(s.centre.clone().add(V(-2.5, 0, -2.5)), 0, 2)); G.scene.add(a.root);
  Object.assign(a, { g, pos: a.root.position, angle: 0, libre: false, criT: 0, hauteurPlaque: 2.4, camp: 'allie', mort: false, rayon: 0.5, pv: Math.round(joueur.st.pvMax * 0.45), pvMax: Math.round(joueur.st.pvMax * 0.45), reduction: 0, st: { pvMax: Math.round(joueur.st.pvMax * 0.45), reduction: 0 }, stunT: 0, slowT: 0, invuln: 0, dots: [] });
  a.jouer('Sit_Floor_Idle'); 
  UI.plaque(a, { nom: g.nom, guilde: 'CAPTIF·VE — ' + g.metier.toUpperCase(), classe: 'pnj', vie: false, lettre: false });
  captifV = a;
  const reste = Math.max(1, Math.ceil((DELAI_SACRIFICE - (Date.now() - g.enleveLe)) / 60000));
  setTimeout(() => UI.toast(`${g.nom} est retenu·e ici, près du dernier gardien · ${reste} min avant le sacrifice`, true), 1800);
}
function libererCaptif() {
  const c = captifV; if (!c || c.libre) return;
  c.libre = true; c.jouer('Cheer', { boucle: false, forcer: true, fin: () => c.jouer('Idle') });
  UI.retirerPlaque(c); UI.plaque(c, { nom: c.g.nom, guilde: 'TE SUIT', classe: 'allie', vie: false, lettre: false });
  UI.parole(c, hasard(['Tu es venu… tu es vraiment venu…', 'Je savais que tu viendrais !', 'Sors-moi d’ici, je t’en supplie !']));
  UI.toast(`${c.g.nom} est libéré·e — ramène-le·la en vie en sortant du donjon`, true); son('jingle_win', 0.5);
}
function majCaptif(dt) {
  const c = captifV; if (!c) return;
  c.maj(dt); c.criT -= dt; if (c.mort) return;
  const d = dist2D(c.pos, joueur.pos);
  if (!c.libre) { if (d < 14 && c.criT <= 0) { c.criT = 9; UI.parole(c, hasard(['À l’aide… par ici…', 'Pitié… quelqu’un…', `C’est toi ? Le gardien de la Place ?`])); } return; }
  if (d > 14) { c.pos.copy(pointLibrePres(joueur.pos, 0, 2)); return; }
  if (d > 2.6) { allerVers(c, joueur.pos, dt, Math.max(3.2, joueur.st.vitesse * 0.95)); c.jouer('Running_A'); }
  else { c.jouer('Idle'); c.angle = tourner(c.angle, Math.atan2(joueur.pos.x - c.pos.x, joueur.pos.z - c.pos.z), dt * 5); c.root.rotation.y = c.angle; }
}
function finirCaptif() {
  const c = captifV; if (!c) return; captifV = null;
  G.scene.remove(c.root); UI.retirerPlaque(c);
  if (!c.libre || c.mort || joueur.mort) return;
  c.g.statut = 'vivant'; delete c.g.enleveLe;
  journalVille(`Tu as ramené ${c.g.nom} (${c.g.metier}) vivant·e ${deLieu(LIEUX[c.g.lieu])}.`); moralVille(12);
  programmer(2.5, () => { UI.toast(`${c.g.nom} est de retour sur la Place ! Le peuple t’acclame`, true); son('jingle_win', 0.6); const cc = citoyens.find(x => x.g === c.g); if (cc) UI.parole(cc, 'Je suis rentré·e… Merci. Merci du fond du cœur.'); });
  sauver();
}

