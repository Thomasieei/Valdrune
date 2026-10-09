import { createClient } from "npm:@supabase/supabase-js@2.117.3";
import Stripe from "npm:stripe@22.6.0";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (data: unknown, status = 200) => new Response(JSON.stringify(data), {
  status, headers: { ...cors, "Content-Type": "application/json", "Cache-Control": "no-store" },
});
const envKey = (legacy: string, modern: string) => Deno.env.get(legacy) ||
  JSON.parse(Deno.env.get(modern) || "{}").default || "";
const uuid = (value: unknown) => typeof value === "string" &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
const events = ["checkout.session.completed", "checkout.session.async_payment_succeeded",
  "checkout.session.async_payment_failed", "checkout.session.expired", "charge.refunded"];
const merchantId = "acct_1U9gLI2a80QQbpq2"; // Eclat rouge: the account connected by the owner.

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  if (req.method !== "POST") return json({ error: "Méthode refusée" }, 405);
  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const publicKey = envKey("SUPABASE_ANON_KEY", "SUPABASE_PUBLISHABLE_KEYS");
    const serviceKey = envKey("SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_SECRET_KEYS");
    const bearer = req.headers.get("Authorization") || "";
    if (!bearer.startsWith("Bearer ")) return json({ error: "Connexion au jeu requise" }, 401);
    const client = createClient(url, publicKey, { auth: { persistSession: false } });
    const { data: { user }, error: authError } = await client.auth.getUser(bearer.slice(7));
    if (authError || !user) return json({ error: "Session expirée : reconnecte le jeu" }, 401);
    const raw = await req.text();
    if (raw.length > 600000) return json({ error: "Sauvegarde trop volumineuse" }, 413);
    let body: Record<string, any>;
    try { body = JSON.parse(raw); } catch { return json({ error: "Requête invalide" }, 400); }
    if (!body || typeof body !== "object" || Array.isArray(body)) return json({ error: "Requête invalide" }, 400);
    const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
    const rpc = async (name: string, args: Record<string, unknown>) => {
      const { data, error } = await admin.rpc(name, args);
      if (error) throw new Error(error.message);
      return data;
    };
    const sync = () => rpc("valdrune_wallet_sync", { p_user_id: user.id });
    if (body.action === "sync") return json(await sync());
    if (body.action === "spend") {
      if (!uuid(body.request_id) || typeof body.offer_id !== "string" ||
        !Number.isInteger(body.free_part) || body.free_part < 0) return json({ error: "Achat invalide" }, 400);
      return json(await rpc("valdrune_reserve_spend", { p_user_id: user.id,
        p_request_id: body.request_id, p_offer_id: body.offer_id, p_free_part: body.free_part }));
    }
    if (body.action === "finish") {
      if (!uuid(body.receipt_id)) return json({ error: "Reçu invalide" }, 400);
      return json(await rpc("valdrune_finish_delivery", { p_user_id: user.id,
        p_receipt_id: body.receipt_id, p_state: body.state || null, p_cancel: body.cancel === true }));
    }

    // Valdrune has its own credentials. The shared STRIPE_SECRET_KEY belongs to another game/account.
    let stripeKey = Deno.env.get("VALDRUNE_STRIPE_RESTRICTED_KEY") || Deno.env.get("VALDRUNE_STRIPE_SECRET_KEY");
    if (!stripeKey) {
      const { data, error } = await admin.from("private_service_config").select("secret_value")
        .eq("key", "valdrune_stripe_api_key").maybeSingle();
      if (error) throw new Error(error.message);
      stripeKey = data?.secret_value || "";
    }
    if (!stripeKey) return json({ error: "La boutique nécessite la clé Stripe du compte Eclat rouge",
      ready: false, key_configured: false, expected_account_id: merchantId, code: "stripe_key_missing" }, 503);
    const stripe = new Stripe(stripeKey, { apiVersion: "2026-08-26.dahlia",
      httpClient: Stripe.createFetchHttpClient(), maxNetworkRetries: 2, timeout: 10000 });
    const livemode = /^(sk|rk)_live_/.test(stripeKey);
    const account = await stripe.accounts.retrieveCurrent();
    if (account.id !== merchantId) return json({ ready: false, code: "stripe_account_mismatch",
      error: "La clé Stripe ne correspond pas au compte Eclat rouge" }, 503);
    if (body.action === "cancel_checkout") {
      if (!uuid(body.request_id)) return json({ error: "Commande invalide" }, 400);
      const { data: order, error } = await admin.from("valdrune_orders").select("*")
        .eq("id", body.request_id).eq("user_id", user.id).maybeSingle();
      if (error) throw new Error(error.message);
      if (!order) return json({ ok: true });
      if (order.stripe_session_id && ["created", "checkout_open"].includes(order.status)) {
        const session = await stripe.checkout.sessions.retrieve(order.stripe_session_id);
        if (session.status === "open") await stripe.checkout.sessions.expire(session.id);
        if (session.payment_status !== "paid") {
          const { error: updateError } = await admin.from("valdrune_orders").update({ status: "expired" })
            .eq("id", order.id).in("status", ["created", "checkout_open"]);
          if (updateError) throw new Error(updateError.message);
        }
      }
      return json({ ok: true });
    }
    if (body.action !== "status" && body.action !== "checkout") return json({ error: "Action inconnue" }, 400);

    // Only inspect Valdrune's dedicated webhook in the expected merchant account.
    const hooks = await stripe.webhookEndpoints.list({ limit: 100 });
    const hook = hooks.data.find((h) => h.url === `${url}/functions/v1/valdrune-stripe-webhook` && h.status === "enabled");
    const { data: storedSecret, error: configError } = await admin.from("private_service_config")
      .select("key").eq("key", "valdrune_stripe_webhook_signing_secret").maybeSingle();
    if (configError) throw new Error(configError.message);
    const secretReady = !!Deno.env.get("VALDRUNE_STRIPE_WEBHOOK_SECRET") || !!storedSecret;
    const webhookReady = secretReady && !!hook && events.every((e) =>
      hook.enabled_events.includes("*") || hook.enabled_events.includes(e));
    const canCharge = !livemode || account.charges_enabled === true;
    const ready = webhookReady && canCharge;
    if (body.action === "status") return json({ ready, livemode, webhook_ready: webhookReady,
      charges_enabled: account.charges_enabled, activation_required: !canCharge,
      key_configured: true, account_id: account.id, endpoint_found: !!hook, signing_secret_configured: secretReady,
      missing_events: hook ? events.filter((e) => !hook.enabled_events.includes("*") && !hook.enabled_events.includes(e)) : events,
      error: ready ? null : !canCharge ? "Les paiements réels ne sont pas encore activés" : "Paiements indisponibles" });
    if (!canCharge) return json({ error: "Les paiements réels ne sont pas encore activés", code: "stripe_account_inactive" }, 503);
    if (!webhookReady) return json({ error: "Paiements indisponibles", code: "stripe_webhook_incomplete" }, 503);
    if (!uuid(body.request_id) || typeof body.offer_id !== "string") return json({ error: "Commande invalide" }, 400);
    await sync();
    const { data: product, error: productError } = await admin.from("valdrune_catalog").select("*")
      .eq("id", body.offer_id).eq("kind", "cash").eq("active", true).maybeSingle();
    if (productError) throw new Error(productError.message);
    if (!product) return json({ error: "Offre indisponible" }, 400);
    let { data: order, error: readError } = await admin.from("valdrune_orders").select("*")
      .eq("id", body.request_id).eq("user_id", user.id).maybeSingle();
    if (readError) throw new Error(readError.message);
    if (!order) {
      const { data, error } = await admin.from("valdrune_orders").insert({ id: body.request_id,
        user_id: user.id, offer_id: product.id, amount_cents: product.amount_cents,
        currency: product.currency, crowns_reward: product.crowns_reward, livemode }).select("*").single();
      if (error) {
        if (error.code === "23505") return json({ error: "Cette commande existe déjà. Vérifie tes achats avant de réessayer" }, 409);
        throw new Error(error.message);
      }
      order = data;
    }
    if (order.offer_id !== product.id || order.livemode !== livemode) return json({ error: "Commande incompatible" }, 409);
    if (order.status === "paid") return json({ paid: true, order_id: order.id, ...await sync() });
    if (["refunded", "expired", "failed"].includes(order.status)) return json({ error: "Commande terminée : ouvre un nouvel achat", terminal: true }, 409);
    if (order.checkout_url && order.stripe_session_id) {
      const existing = await stripe.checkout.sessions.retrieve(order.stripe_session_id);
      if (existing.status === "open") return json({ order_id: order.id, checkout_url: existing.url, livemode });
      if (existing.payment_status === "paid") return json({ pending: true, order_id: order.id });
      if (existing.status === "complete") return json({ pending: true, order_id: order.id });
      await admin.from("valdrune_orders").update({ status: "expired" }).eq("id", order.id).eq("status", "checkout_open");
      return json({ error: "Ce paiement a expiré : ouvre un nouvel achat", terminal: true }, 409);
    }
    const metadata = { app: "valdrune", order_id: order.id, user_id: user.id, offer_id: product.id };
    const returnUrl = `${url}/functions/v1/valdrune-payment-return`;
    const session = await stripe.checkout.sessions.create({
      mode: "payment", locale: "fr", origin_context: "mobile_app",
      integration_identifier: "valdrune_v94_vrkqszhm",
      client_reference_id: order.id, metadata, payment_intent_data: { metadata },
      success_url: `${returnUrl}?result=success`, cancel_url: `${returnUrl}?result=cancel`,
      line_items: [{ quantity: 1, price_data: { currency: order.currency,
        unit_amount: order.amount_cents, product_data: { name: `Valdrune · ${product.name}` } } }],
    }, { idempotencyKey: `valdrune-${order.id}` });
    if (!session.url) throw new Error("Checkout URL missing");
    const { error: updateError } = await admin.from("valdrune_orders").update({
      stripe_session_id: session.id, checkout_url: session.url, status: "checkout_open", updated_at: new Date().toISOString(),
    }).eq("id", order.id).eq("status", "created");
    if (updateError) throw new Error(updateError.message);
    return json({ order_id: order.id, checkout_url: session.url, livemode });
  } catch (e) {
    const message = e instanceof Error ? e.message : "";
    // Never return tokens, database errors, or Stripe credentials to the game.
    if (message.includes("Insufficient paid crowns")) return json({ error: "Solde de couronnes insuffisant" }, 409);
    if (message.includes("Delivery pending")) return json({ error: "Un achat est en cours de livraison" }, 409);
    if (message.includes("Invalid offer") || message.includes("Request conflict") || message.includes("Unknown delivery")) return json({ error: "Achat invalide" }, 400);
    console.error("valdrune-commerce failed", e instanceof Stripe.errors.StripeError ?
      { type: e.type, code: e.code, param: e.param,
        message: e.message.replace(/\b[rs]k_(live|test)_[A-Za-z0-9]+/g, "[redacted]").slice(0, 240) } :
      { type: "backend_error", message: message.slice(0, 160) });
    return json({ error: "Boutique indisponible. Aucun achat non confirmé n'est accordé",
      code: e instanceof Stripe.errors.StripeError ? e.code || e.type : "backend_error",
      param: e instanceof Stripe.errors.StripeError ? e.param || null : null }, 503);
  }
});
