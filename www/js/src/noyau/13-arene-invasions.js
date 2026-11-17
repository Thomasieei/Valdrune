// ---------------- Arène ----------------
function entrerArene(format, opts = {}) {
  if (!opts.duel) memoriserMode(`Arène ${format}${opts.letale ? ' létale' : ''}`, () => entrerArene(format, { letale: opts.letale }));
  else G.dernier = null;
  fondu(() => {
    viderMonde(); invasion = null; selection = null;
    modeActuel = { id: 'arene', nom: 'Arène', lieu: 'Arène des Échos', argent: 0, xp: 0, tiers: [1, 1], mobTier: 1 };
    monde = construireArene();
    construireJoueur(monde.spawn.clone());
    joueur.pv = joueur.st.pvMax; joueur.energie = joueur.st.energieMax; joueur.cds = {};
    joueur.angle = Math.PI / 2; joueur.root.rotation.y = joueur.angle;
    G.camTarget.copy(joueur.pos); G.scene.fog.density = 0.008; G.scene.fog.color.set('#3a2a3a'); G.scene.background.set('#2a1e30'); G.hemi.color.set('#ffe0c0'); G.hemi.groundColor.set('#4a3020'); G.hemi.intensity = 1.15; G.sun.color.set('#ffd8a8'); G.sun.intensity = 1.9;
    const ipJ = statsHeros(J.equip).ip;
    arene = { format, duel: opts.duel || null, mise: opts.mise || 0, letale: !!opts.letale, fini: false, t: 3.6, dernier: 4 };
    const pris = [];
    if (format === '2v2') { const m = groupe || calerSurJoueur(donneesBot(ipJ + rnd(-40, 40), [], rangDe('arene').i)); pris.push(m.nom); const a = creerCombattant(monde.spawnAllie.clone(), m, 'allie'); a.angle = Math.PI / 2; a.root.rotation.y = a.angle; }
    const n = format === '2v2' ? 2 : 1;
    for (let i = 0; i < n; i++) {
      const rgA = rangDe('arene').i;
      const d = i === 0 && opts.duel ? opts.duel : calerSurJoueur(donneesBot(ipJ + rnd(-40, 60) + 30 * rgA, pris, rgA), 3, rgA * 2); pris.push(d.nom);
      d.skill = Math.max([0.55, 0.7, 0.8, 0.9, 0.95, 0.98][rgA] || 0.55, Math.min(0.98, 0.06 * rgA + 0.5 + Math.min(0.35, (J.trophees || 0) / 3000) + rnd(-0.15, 0.2) + (format === '2v2' ? 0.08 : 0)));
      const r = creerCombattant(monde.spawnsRivaux[i].clone(), d, 'ennemi');
      r.angle = -Math.PI / 2; r.root.rotation.y = r.angle; r.potions = 1;
    }
    for (const e of ennemis) emoteBot(e, ['salut', 'diable', 'toi', 'malin'], 0.6, rnd(1.5, 3.5));
    const rivaux = ennemis.map(e => `${e.nom} (⚔ ${e.ip} · ${e.skill >= 0.75 ? 'Expert' : e.skill >= 0.55 ? 'Confirmé' : 'Débutant'})`).join(' et ');
    UI.journal('Arène des Échos', `${format === '2v2' ? 'Équipe adverse' : 'Adversaire'} : ${rivaux}`, null);
    UI.zone(opts.letale ? 'Arène létale' : 'Arène des Échos', opts.duel ? `Duel · mise ${fmtN(opts.mise)}` : (format === '2v2' ? '2 contre 2' : '1 contre 1') + (opts.letale ? ' · stuff en jeu' : ''));
    if (opts.letale) { setTimeout(() => UI.toast('ARÈNE LÉTALE : le perdant repart à poil', true), 700); G.hemi.color.set('#ff6a6a'); }
    $('#btnQuitter').hidden = false;
    son('forceField_000', 0.6, 0.6);
    G.renderer.compile(G.scene, G.camera);
    arene.presentation = true; programmer(0.8, presenterArene);
    ecransArene(true);
  });
}
// ---- le présentateur de l'Arène des Échos : il annonce les champions avec leurs vrais chiffres, puis le chrono démarre ----
const PRESENTATEUR = { nom: 'Orvald', titre: 'la Voix des Échos', modele: 'Barbarian', couleur: '#ffcf4a' };
function statsArene(nom, ip) {
  if (nom === J.nom) { J.areneStats = J.areneStats || { v: 0, d: 0, serie: 0 }; return J.areneStats; }
  J.areneBots = J.areneBots || {};
  if (!J.areneBots[nom]) { const n = Math.floor(rnd(4, 40) + (ip || 300) / 40); const v = Math.floor(n * rnd(0.35, 0.75)); J.areneBots[nom] = { v, d: n - v, serie: Math.random() < 0.5 ? Math.floor(rnd(1, 6)) : -Math.floor(rnd(1, 3)) }; const k = Object.keys(J.areneBots); if (k.length > 120) delete J.areneBots[k[0]]; }
  return J.areneBots[nom];
}
function ficheChampion(nom, ip, rang) {
  const S = statsArene(nom, ip), tot = S.v + S.d;
  const serie = S.serie >= 3 ? `INVAINCU depuis ${S.serie} duels !` : S.serie > 0 ? `sur une série de ${S.serie} victoire${S.serie > 1 ? 's' : ''}` : S.serie <= -3 ? `qui reste sur ${-S.serie} défaites… il a soif de revanche` : S.serie < 0 ? 'qui vient de mordre la poussière et veut se racheter' : 'qui fait ses débuts ici';
  return tot ? `${S.v} victoire${S.v > 1 ? 's' : ''}, ${S.d} défaite${S.d > 1 ? 's' : ''}, ${serie}${rang ? ' — rang ' + rang : ''} !` : `Un nouveau venu ! Aucun combat dans cette arène… montre-nous ce que tu vaux !`;
}
function presenterArene() {
  if (!arene || arene.fini) return;
  const moi = [joueur, ...allies.filter(a => !a.invoc && !a.loup)], eux = ennemis.filter(e => e.rival);
  const rg = rangDe('arene').r.nom;
  const P = (texte, choc) => ({ nom: PRESENTATEUR.nom, titre: PRESENTATEUR.titre, modele: PRESENTATEUR.modele, texte, couleur: PRESENTATEUR.couleur, choc });
  const pan = [P(hasard(['Mesdames et messieurs… BIENVENUE à l’Arène des Échos !', 'Silence dans les tribunes ! Le sang va couler ce soir !', 'Peuple de la Brèche, levez-vous ! Le duel commence !']))];
  pan.push(P(`À ma gauche… ${moi.map(x => x.nom || J.nom).join(' et ')} ! ${ficheChampion(J.nom, joueur.st.ip, rg)}`, (J.areneStats || {}).serie >= 3));
  for (const e of eux) pan.push({ ...P(`À ma droite… ${e.nom}, ⚔ ${e.ip} ! ${ficheChampion(e.nom, e.ip)}`), cote: 'd' });
  if (arene.letale) pan.push(P('Et attention… c’est une arène LÉTALE ! Le perdant repartira sans rien sur le dos !', true));
  pan.push(P(hasard(['Combattants… en position ! Que le meilleur gagne !', 'Que les Échos retiennent vos noms… COMBATTEZ !', 'Trois… deux… non, attendez le signal !']), true));
  son('jingle_win', 0.35, 0.8);
  for (const e of eux) programmer(2.5, () => !e.mort && e.jouer('Cheer', { boucle: false, forcer: true }));
  joueur.jouer('Cheer', { boucle: false, forcer: true, fin: () => joueur.jouer(joueur.def.idle) });
  UI.manga(pan, () => { if (arene) { arene.presentation = false; arene.t = 3.6; arene.dernier = 4; } });
}
// annonce finale : vainqueur, série, changement de rang ; le vaincu quitte l'arène
function annonceFinArene(victoire, rangAvant, rangApres) {
  const moi = J.areneStats, P = (texte, choc) => ({ nom: PRESENTATEUR.nom, titre: PRESENTATEUR.titre, modele: PRESENTATEUR.modele, texte, couleur: PRESENTATEUR.couleur, choc });
  const r = ennemis.find(e => e.rival), nomR = r ? r.nom : 'son adversaire';
  const pan = [P(victoire ? `VICTOIRE DE ${J.nom.toUpperCase()} ! ${moi.serie >= 3 ? `${moi.serie} victoires d’affilée, toujours invaincu !` : `Sa ${moi.v}ᵉ victoire dans l’arène !`}` : `${nomR} l’emporte ! ${J.nom} tombe… ${moi.d} défaite${moi.d > 1 ? 's' : ''} au compteur.`, victoire)];
  if (rangAvant && rangApres && rangApres.i !== rangAvant.i) pan.push(P(rangApres.i > rangAvant.i ? `Et écoutez-moi bien : ${J.nom} passe de ${rangAvant.r.nom} à ${rangApres.r.nom.toUpperCase()} !` : `Aïe… ${J.nom} redescend de ${rangAvant.r.nom} à ${rangApres.r.nom}.`, rangApres.i > rangAvant.i));
  UI.manga(pan);
  const txt = victoire ? `${J.nom} a battu ${nomR} à l’arène${moi.serie >= 3 ? ` (${moi.serie} victoires d’affilée)` : ''}` : `${nomR} a battu ${J.nom} à l’arène`;
  J.echosArene = [...(J.echosArene || []), { txt, t: Date.now(), rang: rangApres && rangAvant && rangApres.i > rangAvant.i ? rangApres.r.nom : null }].slice(-6);
  // le vaincu se relève et quitte l'arène par sa porte
  if (victoire) for (const e of ennemis.filter(x => x.rival)) programmer(2.2, () => {
    if (!e.root.parent) return; e.descendre = false; e._sortie = true; e.jouer('Walking_A', { forcer: true });
    const porte = V(20, 0, e.pos.z * 0.2); ajouterVfx(new THREE.Group(), (t, dt) => { if (!e.root.parent) return false; e.descendre = false; const d = dist2D(e.pos, porte); if (d < 0.8 || t > 8) { G.scene.remove(e.root); UI.retirerPlaque(e); return false; } const v = V(porte.x - e.pos.x, 0, porte.z - e.pos.z).normalize(); e.pos.x += v.x * dt * 1.6; e.pos.z += v.z * dt * 1.6; e.angle = Math.atan2(v.x, v.z); e.root.rotation.y = e.angle; e.root.position.y = 0; e.maj(dt); });
  });
}
// les deux grands écrans au-dessus des tribunes retransmettent le duel en direct
function ecransArene(on) {
  if (!on) { G.ecrans = null; return; }
  const rt = new THREE.WebGLRenderTarget(320, 180); rt.texture.colorSpace = THREE.SRGBColorSpace;
  const cam = new THREE.PerspectiveCamera(42, 16 / 9, 0.5, 120), meshes = [];
  for (const s of [-1, 1]) {
    const cadre = new THREE.Mesh(new THREE.BoxGeometry(9.4, 5.6, 0.4), new THREE.MeshStandardMaterial({ color: '#2a1a12', roughness: 0.8 }));
    const ecran = new THREE.Mesh(new THREE.PlaneGeometry(8.8, 4.95), new THREE.MeshBasicMaterial({ map: rt.texture, toneMapped: false }));
    const g = new THREE.Group(); g.add(cadre); ecran.position.z = 0.21; g.add(ecran);
    g.position.set(0, 13, s * 31); g.rotation.y = s > 0 ? Math.PI : 0; monde.groupe.add(g); meshes.push(g);
  }
  G.ecrans = { rt, cam, meshes, a: 0 };
}
function majEcransArene(dt) {
  const E = G.ecrans; if (!E || !arene) return;
  const c = ennemis.find(e => e.rival && !e.mort) || ennemis[0];
  const m = c ? V((joueur.pos.x + c.pos.x) / 2, 1, (joueur.pos.z + c.pos.z) / 2) : joueur.pos.clone();
  E.a += dt * 0.15; const d = 9 + (c ? Math.min(8, dist2D(joueur.pos, c.pos) * 0.5) : 0);
  E.cam.position.set(m.x + Math.cos(E.a) * d, 4.2, m.z + Math.sin(E.a) * d); E.cam.lookAt(m.x, 1.1, m.z);
}


function majArene(dt) {
  majEcransArene(dt);
  if (!arene || arene.fini || arene.presentation) return;
  if (arene.t > 0) {
    arene.t -= dt;
    const n = Math.ceil(arene.t);
    if (n !== arene.dernier && n <= 3 && n >= 1) { arene.dernier = n; UI.compteur(n); son('click_001', 0.6, 0.8); }
    if (arene.t <= 0) { UI.compteur('Combat !'); son('impactPlate_heavy_000', 0.7, 0.7); }
  }
}
function verifierArene() {
  if (!arene || arene.fini) return;
  const rivaux = ennemis.filter(e => e.rival && !e.mort).length;
  if (rivaux === 0) finArene(true);
  else if (equipeJoueur().length === 0) finArene(false);
}
function finArene(victoire) {
  arene.fini = true; UI.boss(null);
  if (victoire && !arene.duel) { const t = J.equip.arme ? J.equip.arme.tier : 1; tirageOmbre(Math.max(1, t - 1), Math.min(8, t + 1), 'pvp'); }
  if (victoire && !arene.duel) { J.victoiresArene = (J.victoiresArene || 0) + 1; if (J.victoiresArene >= 10) exploit('arene_10'); if (J.victoiresArene >= 50) exploit('arene_50'); }
  if (victoire && arene.duel && arene.duel.nom === RIVAL_TAVERNE.nom) exploit('duel_brakkus');
  const lignes = [];
  if (arene.duel) {
    if (victoire) { J.argent += arene.mise * 2; lignes.push(arene.mise ? `+ ${fmtN(arene.mise * 2)} d’argent (mises remportées)` : 'Duel amical remporté'); }
    else lignes.push(arene.mise ? `Mise perdue : ${fmtN(arene.mise)}` : 'Duel amical perdu');
  } else if (victoire) { const tr = Math.round((arene.letale ? 200 : 100) * (1 + 0.25 * rangDe('arene').i)); J.trophees = (J.trophees || 0) + tr; lignes.push(`🏆 +${tr} trophées (total ${fmtN(J.trophees)})`);
    const gainA = Math.round((arene.letale ? 120000 : 40000) * (1 + 0.5 * rangDe('arene').i) * (arene.format === '1v1' ? 1 : 1.3)); J.argent += gainA; lignes.push(`+ ${fmtN(gainA)} d’argent`); }
  else lignes.push('Aucun trophée cette fois');
  if (arene.letale && !victoire) {
    const perdus = ['arme', 'casque', 'plastron', 'bottes'].map(s => J.equip[s]).filter(Boolean);
    const type = J.equip.arme ? J.equip.arme.type : 'epee';
    J.equip = { arme: creerArme(type === 'ombre' ? 'epee' : type, 1, 0), casque: null, plastron: null, bottes: null };
    lignes.push(`Arène létale : tu perds tout ton équipement porté (${perdus.map(it => nomObjet(it)).join(', ') || 'rien'}). Il te reste ton argent et ton sac.`);
  }
  if (arene.letale && victoire) lignes.push('Arène létale : fouille la dépouille des perdants avant de partir.');
  const rangAvant = rangDe('arene');
  if (!arene.duel) changerRang('arene', victoire ? GAIN_RANG * (arene.letale ? 1.5 : 1) : -PERTE_RANG, victoire ? 'Victoire en arène' : 'Défaite en arène');
  { const S = statsArene(J.nom); if (victoire) { S.v++; S.serie = Math.max(0, S.serie) + 1; } else { S.d++; S.serie = Math.min(0, S.serie) - 1; }
    for (const e of ennemis.filter(x => x.rival)) { const R = statsArene(e.nom, e.ip); if (victoire) { R.d++; R.serie = Math.min(0, R.serie) - 1; } else { R.v++; R.serie = Math.max(0, R.serie) + 1; } }
    annonceFinArene(victoire, rangAvant, rangDe('arene')); }
  const xp = gagnerXPRelatif(victoire ? (arene.duel ? 0.05 : 0.12) : 0.03);
  setTimeout(() => montrerXP(victoire ? 'Victoire en arène' : 'Combat d’arène'), 400);
  lignes.push(`+ ${fmtN(xp)} XP de maîtrise sur ton équipement porté`);
  son(victoire ? 'jingle_win' : 'lowFrequency_explosion_000', 0.6, victoire ? 1 : 0.6);
  if (victoire) for (const a of [joueur, ...allies]) if (a.mort) programmer(1.2, () => {
    a.mort = false; a.pv = (a === joueur ? a.st.pvMax : a.pvMax) * 0.3; a.jouer(a === joueur ? a.def.idle : a.armeDef.idle);
    onde(a.pos, '#ffd27a', 4, 0.8); emettre(V(a.pos.x, 1, a.pos.z), { n: 60, c1: '#fff2c0', c2: '#ffd27a', vit: 4, vie: 1.1, taille: 0.45, monte: 4 }); son('confirmation_001', 0.5, 0.8);
    UI.toast(a === joueur ? 'Ton équipe a gagné : tu te relèves' : `${a.nom} se relève`);
  });
  if (victoire && !joueur.mort) joueur.jouer('Cheer', { boucle: false });
  for (const a of allies) if (!a.mort && victoire) a.jouer('Cheer', { boucle: false });
  for (const e of ennemis) if (!e.mort) { e.jouer('Cheer', { boucle: false }); UI.chat(e.nom, hasard(RIVAL_GAGNE)); emoteBot(e, ['ez', 'mdr', 'clown', 'bof'], 1, 0.4); }
  if (victoire) { const r = ennemis.find(e => e.rival); if (r) { setTimeout(() => UI.chat(r.nom, hasard(RIVAL_PERD)), 800); emoteBot(r, ['gg', 'ouin', 'rage'], 0.8, 1.2); } for (const a of allies) if (!a.mort && !a.invoc) emoteBot(a, ['gg', 'feu', 'ez'], 0.7, 1.6); }
  sauver();
  const finir = () => UI.resultatArene({ victoire, lignes, refaire: G.dernier ? G.dernier.nom : null }, (refaire) => { if (refaire && G.dernier) G.dernier.fn(); else fondu(() => lancerHub()); });
  if (arene.letale && victoire) {
    const morts = ennemis.filter(e => e.rival);
    const suivant = (i) => { if (i >= morts.length) return finir(); const r = morts[i]; UI.depouille(r.nom, r.ip, Object.values(r.equip).filter(Boolean), r.argent, (pris) => { J.argent += r.argent; for (const it of pris) ajouterSac(it, true); son('handleCoins', 0.6); sauver(); suivant(i + 1); }); };
    setTimeout(() => suivant(0), 2600);
  } else setTimeout(finir, 6500);
}

// ---------------- Invasions ----------------
function effetArrivee(pos) {
  onde(pos, '#ff2a2a', 5, 0.8); onde(pos, '#ffb08a', 3, 0.6); lueurSol(pos, '#ff1a1a', 3, 1.4, 1);
  emettre(V(pos.x, 0.3, pos.z), { n: 80, c1: '#ff8a6a', c2: '#8a0000', dir: V(0, 1, 0), vit: 9, disp: 2, rayon: 1, vie: 1.2, taille: 0.6, frein: 1.5 });
  son('lowFrequency_explosion_000', 0.8, 0.8); son('forceField_000', 0.6, 0.6); G.shake = 0.6;
}
function majInvasion(dt) {
  if (invasion && invasion.rivaux && rivauxVivants().length) {
    // positions révélées brièvement toutes les ~14 s
    invasion.revealT -= dt; if (invasion.revele > 0) invasion.revele -= dt;
    if (invasion.revealT <= 0) { invasion.revealT = rnd(12, 16); invasion.revele = 2.6; son('forceField_000', 0.35, 1.8); UI.ping(); }
  }
  if (!invasion || invasion.rival || joueur.mort || transition) return;
  invasion.t -= dt; if (invasion.t > 0) return;
  lancerInvasion();
}
function lancerInvasion() {
  const ipJ = statsHeros(J.equip).ip;
  const n = coequipiers().length ? 2 : 1; const pris = [];
  const rk = rangDe('donjon').i;
  const datas = Array.from({ length: n }, () => { const d = donneesBot(ipJ + Math.round(rnd(-50, 90)) + 30 * rk, pris); d.skill = Math.min(0.97, (d.skill || 0.55) + 0.05 * rk); pris.push(d.nom); return d; });
  const salles = monde.salles.filter(s => s.type === 'normale');
  invasion.rivaux = [];
  if (invasion.mode === 'subie') {
    // ils arrivent loin de toi et te cherchent ; toi aussi tu les cherches
    const s = [...salles].sort((a, b) => dist2D(b.centre, joueur.pos) - dist2D(a.centre, joueur.pos))[Math.floor(Math.random() * 2)] || salles[0];
    for (const d of datas) { const pos = pointLibrePres(s.centre, 0, 4); effetArrivee(pos); const r = creerCombattant(pos, d, 'ennemi'); r.chasseur = true; invasion.rivaux.push(r); }
    invasion.rival = invasion.rivaux[0];
    alerteInvasion(n, true);
    setTimeout(() => invasion && invasion.rivaux.forEach((r, i) => !r.mort && setTimeout(() => UI.chat(r.nom, hasard(RIVAL_ARRIVEE)), i * 1400)), 1800);
    UI.journal('Invasion !', `${n === 2 ? `${datas[0].nom} et ${datas[1].nom} sont venus` : `${datas[0].nom} est venu`} te dépouiller. Trouve-${n === 2 ? 'les' : 'le'} avant qu’${n === 2 ? 'ils' : 'il'} te trouve${n === 2 ? 'nt' : ''}.`, null);
  } else {
    const s = [...salles].sort((a, b) => dist2D(b.centre, joueur.pos) - dist2D(a.centre, joueur.pos))[Math.floor(Math.random() * 3)] || salles[0];
    for (const d of datas) { const r = creerCombattant(pointLibrePres(s.centre, 0, 4), d, 'ennemi'); r.attaqueT = 0; r.jouer(r.armeDef.idle); invasion.rivaux.push(r); }
    invasion.rival = invasion.rivaux[0];
    alerteInvasion(n, false);
    UI.journal('Invasion', `Traque ${datas.map(d => d.nom).join(' et ')} et prends-leur tout. Leur position apparaît par moments sur la carte.`, null);
    setTimeout(() => invasion && invasion.rivaux.forEach(r => !r.mort && UI.chat(r.nom, hasard(['?? un envahisseur', 'sérieux pas maintenant', 'viens alors', 'oh non']))), 6000);
  }
  invasion.revealT = 4; invasion.revele = 0;
}
function victoireRival(e) {
  UI.boss(null); G.shake = 0.8;
  tirageOmbre(Math.max(1, e.equip.arme.tier - 1), e.equip.arme.tier, 'pvp');
  son('jingle_win', 0.6);
  UI.toast(`${e.nom} est vaincu !`, true);
  setTimeout(() => UI.chat(e.nom, hasard(RIVAL_PERD)), 900);
  emoteBot(e, ['rage', 'ouin', 'gg', 'rip'], 0.75, 0.5);
  onde(e.pos, '#ff3a2a', 8, 1); emettre(V(e.pos.x, 1.5, e.pos.z), { n: 90, c1: '#ffd27a', c2: '#ff2a2a', vit: 8, vie: 1.2, taille: 0.45, grav: 3 });
  const pos = pointLibrePres(e.pos, 0.5, 1.5);
  const obj = cloner('chest_gold', pos.x, 0, pos.z, Math.PI / 4, 1.5);
  obj.traverse(o => { if (o.isMesh) { o.material = o.material.clone(); o.material.color = new THREE.Color('#ffffff').lerp(new THREE.Color('#ff3a3a'), 0.45); o.material.emissive = new THREE.Color('#ff1a1a'); o.material.emissiveIntensity = 0.35; o.castShadow = true; } });
  G.scene.add(obj);
  const beam = faisceau(V(pos.x, 0, pos.z), '#ff2a3a', 16, 0.9); G.scene.add(beam);
  coffres.push({ obj, beam, couleur: 'rival', def: { color: '#ff2a3a', nom: 'Dépouille' }, boss: { mort: true }, pos, ouvert: false, lid: obj.getObjectByName('chest_lid'), depouille: true, rival: e });
  UI.journal(e.pillard ? 'Pillard éliminé' : invasion && invasion.mode === 'menee' ? 'Invasion réussie' : 'Invasion repoussée', `Fouille la dépouille de ${e.nom} : choisis ce que tu gardes.`, null);
  if (e.pillard) { raid = null; UI.boss(null); }
  gagnerXPRelatif(0.1); setTimeout(() => montrerXP('Joueur vaincu'), 1500);
  if (invasion && !rivauxVivants().length) invasion.fini = true;
  setTimeout(() => { e.descendre = true; }, 3500);
  sauver();
}
function ouvrirDepouille(c, auto = false) {
  c.ouvert = true; UI.action(null); if (c.couleur === 'legendaire') exploit('coffre_legende');
  son('creak1', 0.7); son('jingle_legend', 0.5);
  if (c.lid) ajouterVfx(new THREE.Group(), (t) => { c.lid.rotation.x = -Math.min(1, t / 0.6) * 1.9; if (t > 0.7) return false; });
  emettre(V(c.pos.x, 1.2, c.pos.z), { n: 90, c1: '#ffe0c0', c2: '#ff2a3a', vit: 7, vie: 1.2, taille: 0.45, grav: 4, monte: 4 });
  const r = c.rival; const objets = Object.values(r.equip).filter(Boolean);
  if (auto) { J.argent += r.argent; for (const it of objets) ajouterSac(it, true); c.beam.visible = false; sauver(); UI.butinFlash('legendaire', { argent: r.argent, objets }); return; }
  setTimeout(() => UI.depouille(r.nom, r.ip, objets, r.argent, (pris) => {
    J.argent += r.argent; for (const it of pris) ajouterSac(it, true);
    son('handleCoins', 0.6); c.beam.visible = false; sauver();
    UI.toast(pris.length ? `${pris.length} objet${pris.length > 1 ? 's' : ''} ajouté${pris.length > 1 ? 's' : ''} au sac` : 'Tu laisses son équipement');
    if (invasion && invasion.mode === 'menee') UI.journal('Invasion réussie', 'Rentre sur la Place par le portail violet du début.', 1);
  }), 700);
}
function defaiteRival() {
  const r = invasion.rival;
  UI.boss(null);
  const perdus = ['arme', 'casque', 'plastron', 'bottes'].map(s => J.equip[s]).filter(Boolean);
  const type = J.equip.arme ? J.equip.arme.type : 'epee';
  J.equip = { arme: creerArme(type, 1, 0), casque: null, plastron: null, bottes: null };
  const perte = Math.round(J.argent * 0.05); J.argent -= perte;
  sauver();
  son('lowFrequency_explosion_000', 0.7, 0.5);
  setTimeout(() => { if (!r.mort) { r.jouer('Cheer', { boucle: false }); UI.chat(r.nom, hasard(RIVAL_GAGNE)); } }, 800);
  const liste = perdus.map(it => `${nomObjet(it)} (${TIERS[it.tier].roman})`).join(', ');
  setTimeout(() => UI.mort(`${r.nom} (puissance ${r.ip}) t’a vaincu et emporte tout ton équipement porté : ${liste || 'rien'}. Tu perds aussi ${perte.toLocaleString('fr-FR')} pièces. Tu repars avec une arme rouillée ; ton sac est intact.`, () => fondu(() => lancerHub())), 1800);
}

