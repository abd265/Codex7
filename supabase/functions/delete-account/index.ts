// Deploy inside the bakery owner's Supabase project. Never bundle these secrets in iOS.
import { createClient } from "npm:@supabase/supabase-js@2.57.4";
import { createRemoteJWKSet, importPKCS8, jwtVerify, SignJWT } from "npm:jose@6.1.0";

const appleKeys = createRemoteJWKSet(new URL("https://appleid.apple.com/auth/keys"));
const failure = (status: number) => new Response(JSON.stringify({ error: "Account deletion could not be completed. Reauthenticate and retry." }), { status, headers: { "Content-Type": "application/json", "Cache-Control": "no-store" } });

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return failure(405);
  try {
    if (!request.headers.get("content-type")?.startsWith("application/json")) return failure(415);
    const bodyText = await request.text();
    if (bodyText.length > 8192) return failure(413);
    const body = JSON.parse(bodyText);
    const authorization = request.headers.get("Authorization") ?? "";
    if (!authorization.startsWith("Bearer ")) return failure(401);
    const token = authorization.slice(7);
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { autoRefreshToken: false, persistSession: false } });
    // getUser verifies this exact token at the Auth service before any decoded claim is trusted.
    const { data: { user }, error } = await admin.auth.getUser(token);
    if (error || !user) return failure(401);
    const encoded = token.split(".")[1];
    const claims = JSON.parse(atob(encoded.replace(/-/g, "+").replace(/_/g, "/")));
    if (claims.sub !== user.id || claims.role !== "authenticated") return failure(401);
    const now = Math.floor(Date.now() / 1000);
    const recent = (claims.amr ?? []).some((entry: { method: string; timestamp: number }) => ["password", "oauth", "otp", "id_token"].includes(entry.method) && Number.isFinite(entry.timestamp) && entry.timestamp >= now - 300 && entry.timestamp <= now + 30);
    if (!recent) return failure(403);
    const hasMFA = (user.factors ?? []).some(f => f.status === "verified");
    if (hasMFA && (claims.aal !== "aal2" || !(claims.amr ?? []).some((entry: { method: string; timestamp: number }) => entry.method === "totp" && entry.timestamp >= now - 300 && entry.timestamp <= now + 30))) return failure(403);

    const appleIdentity = user.identities?.find(identity => identity.provider === "apple");
    if (appleIdentity) {
      if (typeof body.appleAuthorizationCode !== "string" || !body.appleAuthorizationCode) return failure(400);
      const clientID = Deno.env.get("APPLE_CLIENT_ID")!;
      const privateKey = await importPKCS8(Deno.env.get("APPLE_PRIVATE_KEY")!.replace(/\\n/g, "\n"), "ES256");
      const clientSecret = await new SignJWT({}).setProtectedHeader({ alg: "ES256", kid: Deno.env.get("APPLE_KEY_ID")! }).setIssuer(Deno.env.get("APPLE_TEAM_ID")!).setSubject(clientID).setAudience("https://appleid.apple.com").setIssuedAt(now).setExpirationTime(now + 300).sign(privateKey);
      const exchange = await fetch("https://appleid.apple.com/auth/token", { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: new URLSearchParams({ client_id: clientID, client_secret: clientSecret, code: body.appleAuthorizationCode, grant_type: "authorization_code" }) });
      if (!exchange.ok) return failure(403);
      const apple = await exchange.json();
      const { payload } = await jwtVerify(apple.id_token, appleKeys, { issuer: "https://appleid.apple.com", audience: clientID });
      if (payload.sub !== appleIdentity.identity_data?.sub && payload.sub !== appleIdentity.id) return failure(403);
      const revocation = await fetch("https://appleid.apple.com/auth/revoke", { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: new URLSearchParams({ client_id: clientID, client_secret: clientSecret, token: apple.refresh_token ?? apple.access_token, token_type_hint: apple.refresh_token ? "refresh_token" : "access_token" }) });
      if (!revocation.ok) return failure(502);
    }
    const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
    if (deleteError) return failure(500);
    return new Response(null, { status: 204, headers: { "Cache-Control": "no-store" } });
  } catch {
    // No tokens, authorization codes, TOTP secrets or provider responses in logs.
    return failure(500);
  }
});
