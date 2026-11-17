// ======================= ÉTAPE 7 : PARLER LIBREMENT (IA si clé, sinon mode simple) =======================
const CLE_IA = 'breche-cle-ia';
function cleIA() { try { return localStorage.getItem(CLE_IA) || ''; } catch (e) { return ''; } }
async function demanderIA(systeme, histo) {
  const r = await fetch('https://api.anthropic.com/v1/messages', { method: 'POST', headers: { 'content-type': 'application/json', 'x-api-key': cleIA(), 'anthropic-version': '2023-06-01', 'anthropic-dangerous-direct-browser-access': 'true' },
    body: JSON.stringify({ model: 'claude-haiku-5-5', max_tokens: 300, system: systeme + '\nRéponds UNIQUEMENT en JSON : {"reponse": "ta réplique en français, 1 à 3 phrases, dans le personnage", "action": "<une des actions permises>"}. Ne sors jamais du personnage, ne mentionne jamais que tu es une IA.', messages: histo }) });
  if (!r.ok) throw new Error('HTTP ' + r.status);
  const j = await r.json(), t = (j.content || []).map(c => c.text || '').join('');
  const m = t.match(/\{[\s\S]*\}/); try { return m ? JSON.parse(m[0]) : { reponse: t, action: 'rien' }; } catch (e) { return { reponse: t.replace(/[{}"]/g, ''), action: 'rien' }; }
}
function intentionLocale(txt) {
  const t = txt.toLowerCase();
  if (/duel|seul à seul|un contre un|sans (mes )?ombres/.test(t)) return 'duel';
  if (/avoue|aveu|la vérité|mens|menteu/.test(t)) return 'pression';
  if (/meur|tuer|tue |crever|détrui|massacr|regarde|peur|écraser|briser/.test(t)) return 'menace';
  if (/pars|va-t|quitte|rentre|laisse|paix|épargn|recule|fuis/.test(t)) return 'raisonner';
  if (/viens|suis-moi|avec moi|accompagne/.test(t)) return 'suivre';
  if (/reste|garde|protège la ville/.test(t)) return 'garder';
  if (/\?|pourquoi|qui |où |comment|quand/.test(t)) return 'question';
  return 'autre';
}
// conversation générique : p = { nom, titre, modele, systeme(), local(intention, texte) -> {reponse, action}, appliquer(action) -> true si la scène se termine }
function conversationLibre(p) {
  const histo = [], lignes = []; let modeCle = false;
  const afficher = (attente) => UI.saisieLibre({ nom: p.nom, titre: p.titre + (cleIA() ? ' · IA' : ' · mode simple'), modele: p.modele, lignes, attente, sansCle: !cleIA() }, envoyer);
  async function envoyer(txt) {
    if (txt === '__cle__') { modeCle = true; lignes.push({ qui: 'lui', t: '[Colle ta clé API Anthropic (sk-ant-…) puis touche Dire. Elle reste uniquement sur ce téléphone. Écris « aucune » pour revenir au mode simple.]' }); return afficher(false); }
    if (!txt) return;
    if (modeCle) { modeCle = false; const k = txt.trim(); try { if (/^aucune$/i.test(k)) localStorage.removeItem(CLE_IA); else localStorage.setItem(CLE_IA, k); } catch (e) {} lignes.push({ qui: 'lui', t: cleIA() ? '[Clé enregistrée : réponses libres activées.]' : '[Mode simple.]' }); return afficher(false); } lignes.push({ qui: 'toi', t: txt }); afficher(true);
    let rep;
    if (cleIA()) { histo.push({ role: 'user', content: txt }); try { rep = await demanderIA(p.systeme(), histo); histo.push({ role: 'assistant', content: JSON.stringify(rep) }); } catch (e) { histo.pop(); rep = p.local(intentionLocale(txt), txt); rep.reponse += ' (IA injoignable : ' + e.message + ')'; } }
    else rep = p.local(intentionLocale(txt), txt);
    lignes.push({ qui: 'lui', t: rep.reponse || '…' });
    if (rep.action && rep.action !== 'rien' && p.appliquer(rep.action)) { afficher(false); setTimeout(() => UI.saisieLibre(null), 2200); return; }
    afficher(false);
  }
  afficher(false);
}
function parlerLibreChampion(e) {
  const P = e.persoC, F = rapportForce(e), O = ombresC(), victime = O.find(r => r.bourreau === e.nomChampion), enleve = etatVille().gens.find(g => g.statut === 'enleve');
  conversationLibre({ nom: e.nomChampion, titre: 'Champion de la Brèche', modele: 'Barbarian',
    systeme: () => `Tu es ${e.nomChampion}, champion des cultistes de la Brèche Écarlate, personnalité ${P} (arrogant = méprisant, cède très rarement ; prudent = calculateur, recule si le gardien est plus fort ; fanatique = ne recule JAMAIS, vit pour le Seigneur Écarlate). Tu attaques la Place des Cendres, une ville protégée par le gardien ${J.nom}, qui commande des ombres. Rapport de force : ${F > 1.5 ? 'le gardien est nettement plus fort que toi' : F > 0.9 ? 'vous êtes à peu près égaux' : 'tu es plus fort que lui'}. Tu as ${Math.round(e.pv / e.pvMax * 100)} % de tes forces. ${victime ? `Tu as détruit son ombre ${victime.nom}.` : ''} ${enleve ? `Tes cultistes ont enlevé ${enleve.nom} et l'ont emmené·e dans ${LIEUX[enleve.lieu ?? 0]} (tu peux le révéler ou non).` : ''} ${e.revenu ? 'Tu as déjà affronté ce gardien et tu es revenu te venger.' : ''} Actions permises : "rien" (la conversation continue), "retraite" (tu abandonnes l'attaque — seulement si c'est crédible pour ta personnalité et le rapport de force), "combat" (tu attaques), "duel" (tu acceptes un duel singulier sans ombres).`,
    local: (i) => {
      if (i === 'menace') { const ch = Math.max(0, (F - 0.7) * 0.8 + (1 - e.pv / e.pvMax) * 0.7 + { prudent: 0.3, arrogant: -0.25, fanatique: -2 }[P]); return Math.random() < ch ? { reponse: 'Tch… Très bien. Je pars. Pour cette fois.', action: 'retraite' } : { reponse: P === 'fanatique' ? 'Me menacer ? Je meurs pour la Brèche avec joie !' : 'Des mots. Rien que des mots, gardien.', action: Math.random() < 0.5 ? 'combat' : 'rien' }; }
      if (i === 'raisonner') return P === 'prudent' && F > 0.9 ? { reponse: 'Soit. La Brèche se souviendra de toi.', action: 'retraite' } : { reponse: P === 'arrogant' ? 'Partir ? Bats-toi seul contre moi si tu veux que je parte.' : 'La Brèche ne recule pas.', action: 'rien' };
      if (i === 'duel') return P === 'prudent' ? { reponse: 'Un duel ? Je ne suis pas idiot.', action: 'rien' } : { reponse: 'ENFIN un peu de courage ! Que personne n’intervienne !', action: 'duel' };
      if (i === 'question') return enleve ? { reponse: P === 'arrogant' ? `${enleve.nom} ? Va voir dans ${LIEUX[enleve.lieu ?? 0]}… si tu l’oses.` : `Le Seigneur Écarlate nous envoie. Tes habitants nourrissent la Brèche.`, action: 'rien' } : { reponse: 'Le Seigneur Écarlate nous envoie. Ta ville est sur son chemin.', action: 'rien' };
      return { reponse: hasard(OUVERTURES[P]), action: 'rien' };
    },
    appliquer: (a) => {
      if (a === 'retraite' && P !== 'fanatique') { retraiteChampion(e, 'Je pars…', F > 1.8); return true; }
      if (a === 'combat') { e.parle = false; UI.parole(e, 'Assez parlé !', 'menace'); return true; }
      if (a === 'duel') { duelV = e; for (const r of ombresC()) if (!r.mission) { r.ordreAvantDuel = r.ordre; r.ordre = 'escorte'; } e.parle = false; UI.toast('DUEL — tes ombres reculent', true); return true; }
      return false;
    } });
}
function parlerLibreCompagnon(a) {
  const c = a.compagnonV, morts = compagnons().filter(x => x.statut === 'mort').map(x => x.nom);
  conversationLibre({ nom: c.nom, titre: 'Compagnon d’armes', modele: a.data.modele || 'Knight',
    systeme: () => `Tu es ${c.nom}, compagnon·ne d'armes du gardien ${J.nom}, qui protège la Place des Cendres contre les cultistes de la Brèche Écarlate. Tu as fait ${c.expeditions} expéditions avec lui. ${morts.length ? `Tes camarades morts : ${morts.join(', ')}. Ça te pèse.` : ''} Moral de la ville : ${Math.round(etatVille().moral)} %. Tu es loyal·e mais franc·he, tu peux exprimer peur, doutes, désaccord. Actions permises : "rien", "suivre" (tu acceptes de l'accompagner dans la Brèche), "garder" (tu restes protéger la ville).`,
    local: (i) => i === 'suivre' ? { reponse: 'Je te couvre, comme toujours.', action: 'suivre' } : i === 'garder' ? { reponse: 'Personne ne touchera à la Place.', action: 'garder' } : { reponse: morts.length ? `Je pense encore à ${morts[0]}… Mais je suis là.` : hasard(['Prêt·e quand tu l’es.', 'La Brèche ne me fait pas peur, tant qu’on reste ensemble.']), action: 'rien' },
    appliquer: (x) => { if (x === 'suivre') c.ordre = 'expedition'; else if (x === 'garder') c.ordre = 'ville'; else return false; sauver(); return false; } });
}
function interrogerAccuse(af) {
  const a = parId(af.accuse), b = parId(af.plaignant); if (!a) return;
  conversationLibre({ nom: a.nom, titre: `Accusé·e · ${a.metier}`, modele: a.modele,
    systeme: () => `Tu es ${a.nom}, ${a.metier} de la Place des Cendres. Tu es jugé·e par le seigneur ${J.nom} : « ${af.titre} ». Les faits : ${af.recit} En vérité tu es ${af.coupable ? 'COUPABLE : tu mens et tu te défends, tu n\'avoues que si le seigneur te pousse intelligemment ou trouve une contradiction' : 'INNOCENT·E : tu te défends sincèrement, tu peux être en colère ou effrayé·e, tu n\'avoues jamais'}. Actions permises : "rien", "aveu" (uniquement si coupable et que tu craques).`,
    local: (i) => i === 'pression' || i === 'menace' ? (af.coupable && Math.random() < 0.35 ? { reponse: '…D’accord. C’est moi. Je… je n’avais pas le choix.', action: 'aveu' } : { reponse: af.coupable ? 'Je n’ai rien fait ! Demandez à qui vous voulez !' : `Je suis innocent·e ! ${b ? b.nom + ' ment !' : ''}`, action: 'rien' }) : { reponse: af.coupable ? 'Je… j’étais ailleurs. Je le jure.' : 'Je vous dis la vérité, seigneur. Je n’ai rien fait.', action: 'rien' },
    appliquer: (x) => { if (x === 'aveu' && af.coupable) { af.aveu = true; sauver(); return true; } return false; } });
}

