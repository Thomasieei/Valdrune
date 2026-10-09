import { createClient } from "npm:@supabase/supabase-js@2.117.3";
import Stripe from "npm:stripe@22.6.0";

const envKey = (legacy: string, modern: string) => Deno.env.get(legacy) ||
  JSON.parse(Deno.env.get(modern) || "{}").default || "";
const events = new Set(["checkout.session.completed", "checkout.session.async_payment_succeeded",
  "checkout.session.async_payment_failed", "checkout.session.expired", "charge.refunded"]);

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const raw = await req.text();
  if (raw.length > 1000000) return new Response("Payload too large", { status: 413 });
  const signature = req.headers.get("Stripe-Signature");
  if (!signature) return new Response("Bad signature", { status: 400 });
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = envKey("SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_SECRET_KEYS");
  if (!url || !serviceKey) return new Response("Server configuration missing", { status: 503 });
  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
  let secret = Deno.env.get("VALDRUNE_STRIPE_WEBHOOK_SECRET") || "";
  if (!secret) {
    const { data, error } = await admin.from("private_service_config").select("secret_value")
      .eq("key", "valdrune_stripe_webhook_signing_secret").maybeSingle();
    if (error) return new Response("Server configuration unavailable", { status: 503 });
    secret = data?.secret_value || "";
  }
  if (!secret) return new Response("Webhook configuration missing", { status: 503 });
  // Constructing/verifying an event does not call Stripe or use a merchant API key.
  const stripe = new Stripe("sk_test_signature_verification_only", { apiVersion: "2026-08-26.dahlia",
    httpClient: Stripe.createFetchHttpClient() });
  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(raw, signature, secret, 300,
      Stripe.createSubtleCryptoProvider());
  } catch {
    return new Response("Bad signature", { status: 400 });
  }
  if (!events.has(event.type)) return new Response("ok");
  const object = event.data.object as unknown as Record<string, any>;
  if (object.metadata?.app !== "valdrune" && event.type !== "charge.refunded") return new Response("ok");
  // PostgreSQL validates amounts, ownership, livemode and applies each credit/refund once.
  const { error } = await admin.rpc("valdrune_stripe_event", { p_type: event.type, p_object: object });
  if (error) {
    console.error("Valdrune fulfillment failed", { code: error.code });
    return new Response("Fulfillment failed", { status: 500 });
  }
  return new Response("ok");
});
