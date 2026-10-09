// A return page never grants rewards: only the signed webhook can do that.
Deno.serve((req: Request) => {
  if (req.method !== "GET") return new Response("Method Not Allowed", { status: 405 });
  const cancelled = new URL(req.url).searchParams.get("result") === "cancel";
  const title = cancelled ? "Paiement annulé" : "Retour dans Valdrune";
  const message = cancelled ? "Aucune récompense n'est ajoutée pour un paiement annulé." :
    "Retourne dans le jeu. Tes couronnes seront ajoutées dès que Stripe aura confirmé le paiement au serveur.";
  return new Response(`<!doctype html><html lang="fr"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Valdrune</title><style>body{background:#101827;color:#eee;font:18px system-ui;margin:0;min-height:100vh;display:grid;place-items:center}main{max-width:520px;padding:32px;text-align:center}h1{color:#ffd86b}p{line-height:1.6}</style><main><h1>${title}</h1><p>${message}</p><p>Tu peux fermer cette page et rouvrir Valdrune.</p></main></html>`, {
    headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store",
      "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'",
      "X-Content-Type-Options": "nosniff", "Referrer-Policy": "no-referrer" },
  });
});
