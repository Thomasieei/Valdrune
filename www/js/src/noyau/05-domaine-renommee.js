// ======================= LE DOMAINE : château évolutif, serviteurs, trésor et voleurs =======================
let serviteurs = [];
function domaine() { return J.domaine || null; }
function aServiteur(k) { const d = domaine(); return !!(d && d.serviteurs.includes(k)); }
function revenuDomaine() { const d = domaine(); if (!d) return 0; const N = DOMAINE_NIVEAUX[d.niveau]; return Math.round(N.revenu * (1 + (aServiteur('fermier') ? 0.2 : 0) + (aServiteur('intendant') ? 0.3 : 0)) * (1 + titreRenom().i * 0.04)); }
function ombreGardeDomaine() { return J.escouade && J.ombresC ? J.ombresC.find(r => r.mission && r.mission.type === 'ile' && r.mission.ile === -1) : null; }
function majDomaine() {
  const d = domaine(); if (!d) return;
  const now = Date.now(), N = DOMAINE_NIVEAUX[d.niveau];
  const h = Math.min(24, Math.max(0, now - (d.maj || now)) / 3.6e6); d.maj = now;
  d.tresor = Math.min(N.cap, (d.tresor || 0) + revenuDomaine() * h);
  // les voleurs tentent leur chance de temps en temps (rien si le trésor est presque vide)
  if (!d.prochainVol) d.prochainVol = now + rnd(90, 150) * 60000;
  if (now >= d.prochainVol) {
    d.prochainVol = now + rnd(90, 150) * 60000;
    if (d.tresor > N.cap * 0.15) {
      const voleur = hasard(BOTS)[0];
      if (monde && monde.type === 'domaine' && !transition) { attaqueVoleurs(voleur); }
      else {
        const garde = aServiteur('garde'), om = ombreGardeDomaine();
        const repousse = Math.random() < (om ? 0.95 : garde ? 0.85 : 0.25);
        const perte = repousse ? 0 : Math.round(d.tresor * 0.4); d.tresor -= perte;
        journalDomaine(repousse ? `${voleur} a tenté de voler ton trésor : ${om ? om.nom : garde ? 'Aldwin et la garde' : 'tes gens'} l’ont chassé.` : `${voleur} a volé ${fmtN(perte)} ¤ dans ton trésor !`);
        if (!repousse) UI.toast(`Ton domaine a été pillé : -${fmtN(perte)} ¤`, true); else if (om || garde) UI.toast('Un voleur a été chassé de ton domaine');
      }
    }
  }
  sauver();
}
function journalDomaine(t) { const d = domaine(); d.journal = d.journal || []; d.journal.unshift({ t: Date.now(), txt: t }); d.journal.length = Math.min(d.journal.length, 8); }
function fonderDomaine() {
  if (domaine()) return entrerDomaine();
  if (!iles().length) { UI.toast('Il te faut d’abord une île : le domaine se bâtit sur tes terres'); son('error_001', 0.4); return; }
  if (J.argent < PRIX_DOMAINE) { UI.toast(`Fonder un domaine coûte ${fmtN(PRIX_DOMAINE)} ¤`); son('error_001', 0.4); return; }
  J.argent -= PRIX_DOMAINE;
  J.domaine = { niveau: 0, serviteurs: [], tresor: 0, maj: Date.now(), graine: Math.floor(Math.random() * 1e9), journal: [] };
  journalDomaine('Tu as planté ta bannière : le domaine est fondé.');
  sauver(); son('jingle_legend', 0.6); UI.toast('DOMAINE FONDÉ', true);
  entrerDomaine();
}
async function entrerDomaine() {
  const d = domaine(); if (!d) return;
  if (!assetsSylvePrets) { try { await chargerAssets(ASSETS_SYLVE.map(k => [k, `assets/sylve/${k}.json`]), () => {}); assetsSylvePrets = true; } catch (e) {} }
  if (!assetsChateauPrets) { UI.toast('Les bannières se lèvent sur ton domaine…'); try { await chargerAssets(ASSETS_CHATEAU.map(k => [k, `assets/chateau/${k}.json`]), () => {}); assetsChateauPrets = true; } catch (e) { console.warn('château', e); } }
  fondu(() => {
    viderMonde(); invasion = null; arene = null; selection = null;
    majDomaine();
    modeActuel = { id: 'domaine', nom: 'Domaine', lieu: `Domaine de ${J.nom}`, argent: 0, xp: 0, tiers: [1, 1], mobTier: 1 };
    monde = construireDomaine(d); G.solH = monde.solH; grilleIle();
    construireJoueur(monde.spawn.clone()); joueur.pv = joueur.st.pvMax; joueur.energie = joueur.st.energieMax;
    G.camTarget.copy(joueur.pos);
    G.scene.background.set('#8fb8d8'); G.scene.fog.color.set('#a8c8dc'); G.scene.fog.density = 0.006; G.hemi.intensity = 1.35; G.sun.intensity = 1.7; G.sun.color.set('#fff2d8');
    creerServiteurs();
    if (aServiteur('cuisinier')) { J.repasDomaine = Date.now() + 30 * 60000; recalculer(); programmer(2, () => UI.toast('Margot t’a préparé un festin : +8 % de vie pendant 30 min')); }
    creerSortie(monde.portail.pos.clone().add(V(0, 0, -2.5)));
    UI.journal(`Domaine de ${J.nom}`, `${DOMAINE_NIVEAUX[d.niveau].nom} · trésor ${fmtN(Math.floor(d.tresor))} / ${fmtN(DOMAINE_NIVEAUX[d.niveau].cap)} ¤ · ${fmtN(revenuDomaine())} ¤/h`, null);
    UI.zone(`Domaine de ${J.nom}`, DOMAINE_NIVEAUX[d.niveau].nom);
    $('#btnQuitter').hidden = false;
  });
}
function creerServiteurs() {
  serviteurs = [];
  const d = domaine(); if (!d) return;
  for (const k of d.serviteurs) {
    const S = SERVITEURS[k], P = monde.postes[k] || {};
    const a = new Acteur(S.modele, { hauteur: 2.0 });
    const armes = Object.keys(a.nodes).filter(n => /Sword|Axe|Shield|Crossbow|Staff|Wand|Knife|Throwable|Mug|Spellbook|Helmet|Hat/.test(n));
    a.montrerSeul(k === 'garde' ? ['1H_Sword', 'Round_Shield'] : k === 'forgeron' ? ['1H_Axe'] : k === 'intendant' ? ['Spellbook_open'] : k === 'cuisinier' ? ['Mug'] : [], armes);
    const p0 = P.pos ? P.pos.clone() : (P.pts ? P.pts[0].clone() : V(0, 0, 0));
    a.root.position.copy(p0); a.pos = a.root.position; a.hauteurPlaque = 2.6; a.angle = 0; G.scene.add(a.root);
    Object.assign(a, { role: k, P, i: 0, t: rnd(0, 2), parleT: 0 });
    a.jouer('Idle');
    UI.plaque(a, { nom: S.nom, guilde: S.role.toUpperCase(), classe: 'pnj', vie: false });
    serviteurs.push(a);
  }
}
function majServiteurs(dt) {
  for (const a of serviteurs) {
    if (a.tk) { a.maj(dt); continue; }
    a.t -= dt;
    const P = a.P;
    if (P.pts) { // fermière et garde : elles vont de point en point (et travaillent à chaque arrêt)
      const but = P.pts[a.i % P.pts.length];
      if (dist2D(a.pos, but) > 1.2) { allerVers(a, but, dt, a.role === 'garde' ? 1.8 : 1.6); a.jouer('Walking_A'); a.t = a.role === 'fermier' ? rnd(4, 7) : rnd(2, 4); }
      else if (a.t <= 0) a.i++;
      else { a.jouer(a.role === 'fermier' ? 'PickUp' : 'Idle'); if (a.role === 'fermier' && Math.random() < dt * 0.8) emettre(V(a.pos.x, 0.4, a.pos.z - 0.6), { n: 3, c1: '#9a7a4a', c2: '#5a3a22', vit: 1.2, vie: 0.5, taille: 0.25, grav: 5 }); }
    } else if (P.pos) {
      if (dist2D(a.pos, P.pos) > 0.8) { allerVers(a, P.pos, dt, 1.6); a.jouer('Walking_A'); }
      else {
        if (P.regard) { a.angle = tourner(a.angle, Math.atan2(P.regard.x - a.pos.x, P.regard.z - a.pos.z), dt * 5); a.root.rotation.y = a.angle; }
        if (a.role === 'forgeron') { if (a.t <= 0) { a.t = 1.1; a.jouer('1H_Melee_Attack_Chop', { boucle: false, forcer: true, vitesse: 0.9, fin: () => a.jouer('Idle') }); programmer(0.45, () => { const e = monde.postes && monde.postes.enclume; if (e) { emettre(e.clone(), { n: 10, c1: '#fff0a0', c2: '#ff6a00', vit: 4, vie: 0.4, taille: 0.18, grav: 6 }); if (dist2D(joueur.pos, a.pos) < 18) son('impactMetal_medium_001', 0.18, 1.4 + Math.random() * 0.2); } }); } }
        else if (a.role === 'cuisinier' || a.role === 'intendant') { if (a.t <= 0) { a.t = rnd(3, 6); a.jouer('Interact', { boucle: false, forcer: true, fin: () => a.jouer('Idle') }); } }
        else a.jouer('Idle');
      }
    }
    // ils te parlent quand tu passes (pas en boucle)
    const dj = dist2D(a.pos, joueur.pos); a.regard = dj < 7 ? joueur.pos : null;
    if (dj < 6 && !a._salue && G.t > a.parleT) { a._salue = true; a.parleT = G.t + 40; UI.parole(a, hasard(PAROLES_SERVITEURS[a.role])); }
    if (dj > 12) a._salue = false;
    if (dj < 55) a.maj(dt);
  }
}
// des voleurs débarquent pendant que tu es là : à toi de défendre ton trésor
function attaqueVoleurs(nom) {
  UI.toast('DES VOLEURS DANS TON DOMAINE !', true); UI.flashInvasion && UI.flashInvasion(); son('lowFrequency_explosion_000', 0.6, 0.8);
  const ipJ = statsHeros(J.equip).ip;
  for (let i = 0; i < 3; i++) {
    const d = donneesBot(ipJ * (i === 0 ? 0.85 : 0.65)); d.nom = i === 0 ? nom : hasard(['Tire-laine', 'Coupe-bourse', 'Ombre furtive']); d.guilde = 'VOLEURS';
    const p = pointLibrePres(V(rnd(-20, 20), 0, 30), 0, 6); const v = creerCombattant(p, d, 'ennemi'); v.voleur = true; v.potions = 0; effetArrivee(p);
  }
  if (aServiteur('garde')) { const g = serviteurs.find(s => s.role === 'garde'); if (g) UI.parole(g, 'Aux armes ! Protégez le trésor du maître !'); }
}
function finVoleur(e) {
  const reste = ennemis.filter(x => x.voleur && !x.mort).length;
  if (!reste) { const b = Math.round(DOMAINE_NIVEAUX[domaine().niveau].revenu * 0.5); J.argent += b; journalDomaine(`Tu as chassé toi-même les voleurs : +${fmtN(b)} ¤ récupérés sur eux.`); UI.toast(`Voleurs repoussés ! +${fmtN(b)} ¤`, true); son('jingle_win', 0.6); sauver(); }
  setTimeout(() => { e.descendre = true; }, 2500);
}
function infosDomaine() {
  majDomaine();
  const d = domaine(), N = DOMAINE_NIVEAUX[d.niveau], S = DOMAINE_NIVEAUX[d.niveau + 1] || null;
  const res = { bois: 0, minerai: 0, recolte: 0 }; for (const i of iles()) for (const r in res) res[r] += i.coffre[r] || 0;
  return { niveau: d.niveau, N, S, tresor: Math.floor(d.tresor), revenu: revenuDomaine(), res, argent: J.argent, journal: d.journal || [],
    serviteurs: Object.entries(SERVITEURS).map(([k, s]) => ({ k, ...s, embauche: d.serviteurs.includes(k), dispo: d.niveau >= s.niv })) };
}
function ouvrirDomaine() {
  UI.domaine(infosDomaine(), {
    collecter: () => { const d = domaine(); const g = Math.floor(d.tresor); if (g <= 0) return; J.argent += g; d.tresor -= g; son('handleCoins', 0.7); UI.toast(`+${fmtN(g)} ¤ du trésor`); journalDomaine(`Tu as collecté ${fmtN(g)} ¤.`); sauver(); ouvrirDomaine(); },
    agrandir: () => {
      const d = domaine(), S = DOMAINE_NIVEAUX[d.niveau + 1]; if (!S) return;
      const inf = infosDomaine();
      if (J.argent < S.cout) { UI.toast('Pas assez d’argent'); son('error_001', 0.4); return; }
      for (const r in S.res) if (inf.res[r] < S.res[r]) { UI.toast(`Il manque des ressources de tes îles (${r})`); son('error_001', 0.4); return; }
      J.argent -= S.cout;
      for (const r in S.res) { let reste = S.res[r]; for (const i of iles()) { const p = Math.min(reste, i.coffre[r] || 0); i.coffre[r] -= p; reste -= p; if (!reste) break; } }
      d.niveau++; journalDomaine(`Ton domaine devient : ${S.nom}.`); sauver();
      UI.domaine(null); annonceRare(`${S.nom}`, 'Ton domaine grandit');
      const p = joueur.pos.clone(); entrerDomaine(); setTimeout(() => { if (joueur) { joueur.pos.copy(p); G.camTarget.copy(p); } }, 900);
    },
    embaucher: (k) => {
      const d = domaine(), S = SERVITEURS[k]; if (!S || d.serviteurs.includes(k)) return;
      if (J.argent < S.prix) { UI.toast('Pas assez d’argent'); son('error_001', 0.4); return; }
      J.argent -= S.prix; d.serviteurs.push(k); journalDomaine(`${S.nom}, ${S.role.toLowerCase()}, entre à ton service.`); sauver(); recalculer();
      UI.domaine(null); UI.toast(`${S.nom} entre à ton service`, true); son('confirmation_001', 0.6);
      const p = joueur.pos.clone(); entrerDomaine(); setTimeout(() => { if (joueur) { joueur.pos.copy(p); G.camTarget.copy(p); } }, 900);
    },
  });
}
function interactionsDomaine() {
  if (dist2D(joueur.pos, monde.trone) < 3.6) return UI.action('Gouverner ton domaine', () => ouvrirDomaine());
  if (dist2D(joueur.pos, monde.tresorPos) < 3.2) return UI.action(`Trésor : ${fmtN(Math.floor(domaine().tresor))} ¤`, () => ouvrirDomaine());
  for (const a of serviteurs) if (dist2D(a.pos, joueur.pos) < 3) return UI.action(`Parler à ${SERVITEURS[a.role].nom}`, () => { UI.parole(a, hasard(PAROLES_SERVITEURS[a.role])); if (a.role === 'intendant') ouvrirDomaine(); });
  if (monde.postes && monde.postes.enclume && dist2D(joueur.pos, monde.postes.enclume) < 3) return UI.action('Forger à l’enclume', () => ouvrirAtelier('forge'));
  if (monde.postes && monde.postes.cuisinier && dist2D(joueur.pos, monde.postes.cuisinier.pos) < 3.2) return UI.action('Cuisiner', () => ouvrirAtelier('cuisine'));
  if (sortie && dist2D(joueur.pos, sortie.pos) < 3.2) return UI.action('Retourner sur la Place', () => fondu(() => lancerHub()));
  return UI.action(null);
}
// ---- atelier du domaine : forger son équipement soi-même (mini-jeu au marteau) et cuisiner ----
function stockRes(r) { return iles().reduce((a, i) => a + (i.coffre[r] || 0), 0); }
function prendreRes(cout) {
  for (const r in cout) if (r !== 'argent' && stockRes(r) < cout[r]) { UI.toast(`Il te manque ${fmtN(cout[r] - stockRes(r))} ${r} (tes îles le produisent)`); son('error_001', 0.4); return false; }
  if ((cout.argent || 0) > J.argent) { UI.toast('Pas assez d’argent'); son('error_001', 0.4); return false; }
  for (const r in cout) { if (r === 'argent') { J.argent -= cout.argent; continue; } let reste = cout[r]; for (const i of iles()) { const p = Math.min(reste, i.coffre[r] || 0); i.coffre[r] -= p; reste -= p; if (!reste) break; } }
  return true;
}
function recettesAtelier(type) {
  const N = domaine() ? domaine().niveau : 0, tMax = Math.min(8, 3 + N);
  if (type === 'cuisine') return [
    { id: 'potions', nom: '5 potions de soin', desc: 'Margot ou toi : marmite, herbes, et ça repart.', cout: { recolte: 120, argent: 5000 } },
    { id: 'banquet', nom: 'Banquet de guerre', desc: '+10 % de dégâts pendant 30 minutes.', cout: { recolte: 300, bois: 80, argent: 40000 } },
    { id: 'festin', nom: 'Festin du seigneur', desc: '+8 % de vie pendant 60 minutes.', cout: { recolte: 220, argent: 25000 } },
  ];
  const cl = J.equip.arme ? J.equip.arme.type : 'epee', R = [];
  for (let t = Math.max(2, tMax - 2); t <= tMax; t++) {
    const k = Math.pow(t, 1.6);
    R.push({ id: 'arme', t, nom: `${ARMES[cl].court} T${t}`, desc: 'Ta propre arme, forgée de tes mains. Plus tes coups de marteau sont justes, meilleure est la qualité.', cout: { minerai: Math.round(60 * k), bois: Math.round(30 * k), argent: Math.round(8000 * t * t) } });
    for (const sl of ['casque', 'plastron', 'bottes']) R.push({ id: sl, t, nom: `${sl[0].toUpperCase() + sl.slice(1)} T${t}`, desc: 'Une pièce d’armure à ta mesure.', cout: { minerai: Math.round(45 * k), bois: Math.round(15 * k), argent: Math.round(6000 * t * t) } });
  }
  R.push({ id: 'runes', nom: '5 runes d’enchantement', desc: 'Gravées à la forge, pour Ysolde.', cout: { minerai: 400, argent: 15000 } });
  return R;
}
function ouvrirAtelier(type) {
  if (!iles().length) return UI.toast('Il te faut une île pour fournir le bois, le minerai et les récoltes');
  UI.atelier({ type, stock: { bois: stockRes('bois'), minerai: stockRes('minerai'), recolte: stockRes('recolte'), argent: J.argent }, recettes: recettesAtelier(type), domaineNiv: domaine() ? DOMAINE_NIVEAUX[domaine().niveau].nom : '' }, (rec) => {
    if (!prendreRes(rec.cout)) return;
    if (rec.id === 'potions') { J.potions = (J.potions || 0) + 5; UI.toast('+5 potions'); son('confirmation_001', 0.5); }
    else if (rec.id === 'banquet') { J.banquet = Date.now() + 30 * 60000; recalculer(); UI.toast('Banquet de guerre : +10 % de dégâts (30 min)', true); son('jingle_win', 0.5); }
    else if (rec.id === 'festin') { J.repasDomaine = Date.now() + 60 * 60000; recalculer(); UI.toast('Festin : +8 % de vie (60 min)', true); son('jingle_win', 0.5); }
    else if (rec.id === 'runes') { ajouterSac(creerButin('rune', 5), true); UI.toast('+5 runes d’enchantement'); son('impactMining_000', 0.6); }
    else { // mini-jeu du marteau
      joueur.jouer('1H_Melee_Attack_Chop', { boucle: false, forcer: true, fin: () => joueur.jouer(joueur.def.idle) });
      UI.forge((score) => {
        const q = score >= 2.7 ? 4 : score >= 2.2 ? 3 : score >= 1.6 ? 2 : score >= 0.9 ? 1 : 0;
        const cl = J.equip.arme ? J.equip.arme.type : 'epee';
        const it = rec.id === 'arme' ? creerArme(cl, rec.t, q) : creerArmure(rec.id, rec.t, q);
        it.forge = J.nom; ajouterSac(it, true);
        const e = monde.postes.enclume; emettre(V(e.x, 1.3, e.z), { n: 80, c1: '#fff2c0', c2: '#ff7a1a', vit: 6, vie: 0.9, taille: 0.35, grav: 6 });
        son(q >= 3 ? 'jingle_legend' : 'jingle_loot', 0.55); UI.toast(`Tu as forgé : ${nomObjet(it)} — ${['Normal', 'Bon', 'Remarquable', 'Excellent', 'Chef-d’œuvre'][q]}`, q >= 3);
        if (q >= 4) exploit && exploit('chef_oeuvre');
        sauver();
      }, (coup) => { const e = monde.postes.enclume; emettre(V(e.x, 1.25, e.z), { n: 14 + coup * 10, c1: '#fff8d0', c2: '#ff8a2a', vit: 4 + coup * 3, vie: 0.5, taille: 0.25, grav: 8 }); son('impactMetal_medium_001', 0.5, 0.8 + coup * 0.2); G.shake = 0.1 + coup * 0.1; joueur.jouer('1H_Melee_Attack_Chop', { boucle: false, forcer: true, vitesse: 1.4, fin: () => joueur.jouer(joueur.def.idle) }); });
    }
    sauver();
  });
}

// ======================= APPARAT : l'aura meurtrière (cosmétique au prix fort) =======================
function apparat() { return (J.apparat = J.apparat || { possede: [], aura: null }); }
function auraEquipee() { const a = apparat(); return a.aura ? APPARAT.find(x => x.id === a.aura) : null; }
function ouvrirApparat() {
  const a = apparat();
  UI.apparat(APPARAT.map(x => ({ ...x, possede: a.possede.includes(x.id), equipe: a.aura === x.id })), J.argent, (id, action) => {
    const x = APPARAT.find(y => y.id === id); if (!x) return;
    if (action === 'acheter') { if (J.argent < x.prix) { UI.toast('Pas assez d’argent'); son('error_001', 0.4); return; } J.argent -= x.prix; a.possede.push(id); a.aura = id; son('jingle_legend', 0.6); UI.toast(`${x.nom} : elle est à toi`, true); }
    else if (action === 'equiper') { a.aura = id; UI.toast(`${x.nom} équipée`); }
    else if (action === 'retirer') { a.aura = null; UI.toast('Aura retirée'); }
    sauver(); majBoutonAura(); ouvrirApparat();
  });
}
function majBoutonAura() { const A = auraEquipee(); UI.boutonAura(A ? A : null, () => deployerAura()); }
// aura permanente : anneau au sol, flammèches et volutes, sur toi et tes ombres
const auras = new Map();
function majAuras(dt) {
  const A = auraEquipee();
  const porteurs = A && joueur && !joueur.mort ? [joueur, ...escouade.filter(o => !o.mort)] : [];
  for (const [p, v] of auras) if (!porteurs.includes(p) || v.id !== (A && A.id)) { G.scene.remove(v.g); auras.delete(p); }
  for (const p of porteurs) {
    let v = auras.get(p);
    if (!v) {
      const g = new THREE.Group(); const k = p === joueur ? 1 : 0.7;
      const m1 = new THREE.Mesh(new THREE.RingGeometry(0.75 * k, 1.15 * k, 40), new THREE.MeshBasicMaterial({ color: A.c1, transparent: true, opacity: 0.55, blending: THREE.AdditiveBlending, depthWrite: false })); m1.rotation.x = -Math.PI / 2;
      const m2 = new THREE.Mesh(new THREE.CircleGeometry(1.5 * k, 32), new THREE.MeshBasicMaterial({ color: A.c1, map: texRond(), transparent: true, opacity: 0.35, blending: THREE.AdditiveBlending, depthWrite: false })); m2.rotation.x = -Math.PI / 2;
      const col = new THREE.Mesh(new THREE.CylinderGeometry(0.55 * k, 0.9 * k, 2.6 * k, 20, 1, true), new THREE.MeshBasicMaterial({ color: A.c1, transparent: true, opacity: 0.1, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide })); col.position.y = 1.3 * k;
      g.add(m2, m1, col); G.scene.add(g); v = { g, m1, col, k, id: A.id }; auras.set(p, v);
    }
    const y = (G.solH ? G.solH(p.pos.x, p.pos.z) : 0) + 0.12;
    v.g.position.set(p.pos.x, y, p.pos.z); v.m1.rotation.z += dt * 1.6; v.col.material.opacity = 0.07 + 0.05 * Math.sin(G.t * 3 + v.k);
    const s = 1 + 0.08 * Math.sin(G.t * 4); v.m1.scale.set(s, s, s);
    if (Math.random() < dt * 10 * v.k) emettre(V(p.pos.x + rnd(-0.5, 0.5) * v.k, y + 0.2, p.pos.z + rnd(-0.5, 0.5) * v.k), { n: 1, c1: A.c3, c2: A.c1, dir: V(0, 1, 0), vit: 1.6 * v.k, disp: 0.25, vie: 0.9, taille: 0.32 * v.k, frein: 0.4 });
  }
}
// déploiement : la caméra tourne autour de toi, la terre tremble un peu, et tout le monde a peur (sans empêcher le combat)
let auraCdT = -99;
function deployerAura() {
  const A = auraEquipee(); if (!A || !joueur || joueur.mort || transition || sceneOmbre) return;
  if (G.t < auraCdT) { UI.toast(`Ton aura se recharge (${Math.ceil(auraCdT - G.t)} s)`); return; }
  auraCdT = G.t + 40;
  const yaw0 = G.camYaw, d0 = G.camDist; G.camLibre = true; G.camCible = joueur.pos.clone(); G.camDist = Math.max(12, d0 * 0.6);
  joueur.jouer('Spellcast_Raise' in joueur.actions ? 'Spellcast_Raise' : 'Cheer', { boucle: false, forcer: true, vitesse: 0.8, fin: () => joueur.jouer(joueur.def.idle) });
  son('lowFrequency_explosion_000', 0.8, 0.55); son('forceField_000', 0.6, 0.5);
  ajouterVfx(new THREE.Group(), (t) => {
    const k = Math.min(1, t / 2.4), e = k < 0.5 ? 2 * k * k : 1 - Math.pow(-2 * k + 2, 2) / 2;
    G.camYaw = yaw0 + e * Math.PI * 2;
    if (t < 1.6) G.shake = Math.max(G.shake || 0, 0.22); // tremblement léger : on sent la puissance, sans mal de tête
    if (Math.random() < 0.4) emettre(V(joueur.pos.x + rnd(-1.2, 1.2), 0.3, joueur.pos.z + rnd(-1.2, 1.2)), { n: 2, c1: A.c1, c2: A.c2, dir: V(0, 1, 0), vit: 6, disp: 0.4, vie: 0.9, taille: 0.4 });
    if (t > 2.6) { G.camLibre = false; G.camCible = null; G.camDist = d0; return false; }
  });
  for (let i = 0; i < 3; i++) programmer(i * 0.35, () => onde(joueur.pos, i === 1 ? A.c3 : A.c1, 10 + i * 5, 1));
  emettre(V(joueur.pos.x, 1.2, joueur.pos.z), { n: 70, c1: A.c1, c2: A.c2, vit: 10, vie: 1.1, taille: 0.45, grav: -1 });
  lueurSol(joueur.pos, A.c1, 7, 1.6, 0.55);
  // réactions : tout le monde se tourne vers toi, recule, et certains le disent
  const autour = [];
  for (const e of ennemis) if (!e.mort) autour.push([e, e.boss ? 'boss' : 'ennemi']);
  for (const b of bots) autour.push([b, 'bot']);
  for (const p of [marchand, graveuse, passeur, intendant]) if (p) autour.push([p, 'pnj']);
  if (taverne) for (const c of taverne.clients) autour.push([c, c.pnj ? 'pnj' : 'bot']);
  for (const a of allies) if (!a.invoc && !a.loup) autour.push([a, 'bot']);
  for (const o of escouade) autour.push([o, 'ombre']);
  const proches = autour.filter(([a]) => a.pos && dist2D(a.pos, joueur.pos) < 28).sort((x, y) => dist2D(x[0].pos, joueur.pos) - dist2D(y[0].pos, joueur.pos));
  let parles = 0;
  for (const [a, type] of proches) {
    a.regard = joueur.pos;
    if (type !== 'ombre') {
      const d = V(a.pos.x - joueur.pos.x, 0, a.pos.z - joueur.pos.z).normalize(); let r = 0;
      ajouterVfx(new THREE.Group(), (t, dt) => { if (r < 1.8 && !a.mort) { const st = Math.min(1.8 - r, dt * 4); if (libre(a.pos.x + d.x * st, a.pos.z + d.z * st, 0.5)) { a.pos.x += d.x * st; a.pos.z += d.z * st; } r += st; } if (t > 0.6) return false; });
      if (a.angle !== undefined && a.root) { a.angle = Math.atan2(-d.x, -d.z); a.root.rotation.y = a.angle; }
      if (a.actions && a.actions.Hit_A) a.jouer('Hit_A', { boucle: false, forcer: true, vitesse: 0.6, fin: () => a.jouer && a.jouer(a.armeDef ? a.armeDef.idle : (a.actions.Idle_Combat ? 'Idle_Combat' : 'Idle')) });
      if (type === 'ennemi' || type === 'boss') a.stunT = Math.max(a.stunT || 0, type === 'boss' ? 0.6 : 1.4); // le choc fige un instant, puis le combat reprend
    }
    if (parles < 4 && (type !== 'bot' || Math.random() < 0.5)) { parles++; programmer(0.4 + parles * 0.35, () => UI.parole(a, hasard(CHOC_AURA[type]), type === 'ombre' ? '' : 'peur')); }
  }
  if (!modeActuel) programmer(2, () => UI.chat(hasard(BOTS)[0], hasard(CHOC_AURA.bot)));
  if (!aExploit('aura')) { J.auraDeployee = (J.auraDeployee || 0) + 1; }
}

// ======================= RENOMMÉE : tes vrais exploits, ton titre, et ce que le monde en dit =======================
function gloirePts() { return (J.gloire && J.gloire.pts) || 0; }
function titreRenom(p = gloirePts()) { let i = 0; TITRES_RENOM.forEach((x, k) => { if (p >= x[0]) i = k; }); const t = TITRES_RENOM[i]; return { i, nom: t[1], c: t[2], seuil: t[0], suivant: TITRES_RENOM[i + 1] || null }; }
function aExploit(id) { return !!(J.gloire && J.gloire.liste.some(e => e.id === id)); }
function exploit(id) {
  const X = EXPLOITS[id]; if (!X) return;
  J.gloire = J.gloire || { pts: 0, liste: [] };
  if (aExploit(id)) return;
  const avant = titreRenom();
  J.gloire.liste.push({ id, t: Date.now() }); if (J.gloire.liste.length > 150) J.gloire.liste.splice(0, J.gloire.liste.length - 150); J.gloire.pts += X.pts;
  const apres = titreRenom();
  sauver();
  setTimeout(() => {
    UI.exploit(`${J.nom} ${X.t3}`, X.pts, apres);
    UI.chat('Système', `${J.nom} ${X.t3} !`);
    if (apres.i > avant.i) setTimeout(() => annonceRare(`Renommée : ${apres.nom}`, 'Ton nom circule désormais bien au-delà de la Place'), 2600);
    majAffichagePuissance();
  }, 1100);
}
function exploitDonjon() {
  const solo = !groupe && !coequipiers().length && !J.escouade;
  const ids = [['cryptes', 'cryptes_solo'], ['forteresse', 'forteresse_solo'], ['gouffre', 'gouffre_solo'], ['abime', 'abime_solo']][modeActuel.id];
  if (!ids) return;
  exploit(ids[0]); if (solo) exploit(ids[1]);
}
function exploitNiveau() { const n = niveauHeros(J.equip); if (n >= 25) exploit('niveau_25'); if (n >= 50) exploit('niveau_50'); if (n >= 80) exploit('niveau_80'); }
// ce que dit un PNJ : jamais la même réplique deux fois de suite, plus de chances de parler de tes exploits récents
function parolePNJ(cle) {
  const P = PAROLES_PNJ[cle]; if (!P) return '';
  const T = titreRenom(), ex = (J.gloire && J.gloire.liste) || [], cands = [];
  for (const l of P.general) cands.push({ l, w: 1 });
  for (const l of (P.renom[T.i] || [])) cands.push({ l, w: 1.4 });
  for (const e of ex.slice(-5)) { const X = EXPLOITS[e.id]; if (!X) continue; const recent = Date.now() - e.t < 6 * 3.6e6; for (const l of P.exploit) cands.push({ l: l.replace('{exploit3}', X.t3).replace('{exploit}', X.t2), w: recent ? 2.2 : 0.8 }); }
  J.vuPNJ = J.vuPNJ || {}; const vus = J.vuPNJ[cle] || (J.vuPNJ[cle] = []);
  let pool = cands.filter(c => !vus.includes(c.l)); if (!pool.length) { vus.length = 0; pool = cands; }
  let r = Math.random() * pool.reduce((s, c) => s + c.w, 0), choix = pool[0];
  for (const c of pool) { r -= c.w; if (r <= 0) { choix = c; break; } }
  vus.push(choix.l); if (vus.length > 16) vus.shift();
  return choix.l.replace(/\{nom\}/g, J.nom);
}
// les PNJ t'interpellent quand tu passes près d'eux (jamais en boucle)
let parolePNJT = 0;
function majParolesPNJ(dt) {
  parolePNJT -= dt; if (parolePNJT > 0) return;
  for (const [a, cle] of [[marchand, 'borin'], [graveuse, 'ysolde'], [passeur, 'aldric'], [intendant, 'oswin']]) {
    if (!a) continue; const d = dist2D(a.pos, joueur.pos);
    if (d > 13) a._salue = false;
    if (d < 7 && !a._salue && G.t > (a._parleT || 0)) { a._salue = true; a._parleT = G.t + 45; parolePNJT = 6; UI.parole(a, parolePNJ(cle)); return; }
  }
}
// les autres joueurs parlent de toi dans le chat de la Place (rarement, jamais la même phrase)
let rumeurT = rnd(70, 140);
function majRumeurs(dt) {
  if (modeActuel || !J.gloire || !J.gloire.liste.length) return;
  rumeurT -= dt; if (rumeurT > 0) return;
  rumeurT = rnd(110, 220) / (1 + titreRenom().i * 0.25);
  const e = hasard(J.gloire.liste.slice(-6)), X = EXPLOITS[e.id]; if (!X) return;
  J.vuRumeur = J.vuRumeur || []; let l = hasard(RUMEURS_CHAT.filter(x => !J.vuRumeur.includes(x)));
  if (!l) { J.vuRumeur = []; l = hasard(RUMEURS_CHAT); }
  J.vuRumeur.push(l); if (J.vuRumeur.length > 7) J.vuRumeur.shift();
  const b = hasard(bots.length ? bots : [{ nom: hasard(BOTS)[0] }]);
  UI.chat(b.nom, l.replace(/\{nom\}/g, J.nom).replace('{exploit2}', X.t2).replace('{exploit}', X.t3));
}
// la fortune se remarque : sur la Place, les joueurs parlent de ta bourse (jamais deux fois la même phrase de suite)
const PAROLES_FORTUNE = [
  [500000, ['{nom} vient de passer, sa bourse tintait à chaque pas', 'quelqu’un a vu le sac d’or de {nom} ? il est énorme', '{nom} paie toujours rubis sur l’ongle chez Borin', 'faut que je demande à {nom} comment il fait son or']],
  [5e6, ['{nom} a plus d’or que la banque de la Place, sérieux', 'j’ai vu {nom} acheter sans même regarder le prix', 'si {nom} rachète la taverne je serais pas surpris', '{nom} c’est un seigneur maintenant, faut lui faire la révérence', 'les marchands se battent pour servir {nom}']],
  [50e6, ['{nom} a une fortune de roi, on parle de lui jusqu’aux îles', 'paraît que {nom} dort sur des piles de pièces', 'le Trésor de {nom}… même les bandits n’osent plus y penser', 'quand {nom} arrive sur la Place, le prix des potions monte', 'je travaille pour {nom} le mois prochain, il paie en or massif']],
];
let fortuneT = 60, vuFortune = [];
let echoT = 90;
function majEchosArene(dt) {
  if (modeActuel && modeActuel.id !== 'taverne' || !J.echosArene || !J.echosArene.length) return;
  echoT -= dt; if (echoT > 0) return; echoT = rnd(110, 220);
  const E = hasard(J.echosArene.slice(-3));
  const l = hasard(E.rang ? [`${J.nom} est passé ${E.rang} à l’arène, Orvald l’a crié dans toutes les tribunes`, `t’as entendu ? ${J.nom} monte ${E.rang}, ça commence à faire peur`] : [`paraît que ${E.txt}`, `j’étais en tribune : ${E.txt}, quel match`, `${E.txt}… Orvald en parle encore`, `on raconte que ${E.txt}, faut que je voie ça`]);
  const b = hasard(bots.length ? bots : [{ nom: hasard(BOTS)[0] }]); UI.chat(b.nom, l);
}
function majFortune(dt) {
  if (modeActuel || !joueur) return;
  fortuneT -= dt; if (fortuneT > 0) return; fortuneT = rnd(140, 260);
  let lignes = null; for (const [min, l] of PAROLES_FORTUNE) if (J.argent >= min) lignes = l;
  if (!lignes) return;
  let l = hasard(lignes.filter(x => !vuFortune.includes(x))) || hasard(lignes); vuFortune.push(l); if (vuFortune.length > 6) vuFortune.shift();
  const b = hasard(bots.length ? bots : [{ nom: hasard(BOTS)[0] }]);
  UI.chat(b.nom, l.replace(/\{nom\}/g, J.nom));
  // les passants proches se retournent sur toi un instant
  for (const x of bots) if (x.root && dist2D(x.pos, joueur.pos) < 9) { x.regard = joueur.pos; programmer(rnd(2, 4), () => { if (x.regard === joueur.pos) x.regard = null; }); }
}
function ouvrirRenommee() {
  const T = titreRenom();
  UI.renommee({ nom: J.nom, pts: gloirePts(), titre: T, exploits: ((J.gloire && J.gloire.liste) || []).slice().reverse().map(e => ({ txt: `${J.nom} ${EXPLOITS[e.id] ? EXPLOITS[e.id].t3 : ''}`, pts: EXPLOITS[e.id] ? EXPLOITS[e.id].pts : 0, t: e.t })),
    rumeurs: [['Borin', parolePNJ('borin')], ['Mira', parolePNJ('mira')], ['Ysolde', parolePNJ('ysolde')]] });
}

