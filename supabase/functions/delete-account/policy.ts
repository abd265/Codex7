// Only call this after the exact JWT has been verified by Auth.getUser(token).
export function deletionAllowed(claims: Record<string, unknown>, user: { id: string; factors?: { status: string }[] }, now: number): boolean {
  if (claims.sub !== user.id || claims.role !== "authenticated" || !Array.isArray(claims.amr)) return false;
  const recent = (method: string) => claims.amr instanceof Array && claims.amr.some(entry => entry && entry.method === method && typeof entry.timestamp === "number" && Number.isFinite(entry.timestamp) && entry.timestamp >= now - 300 && entry.timestamp <= now + 30);
  if (!["password", "oauth", "otp", "id_token"].some(recent)) return false;
  if ((user.factors ?? []).some(f => f.status === "verified") && (claims.aal !== "aal2" || !recent("totp"))) return false;
  return true;
}
