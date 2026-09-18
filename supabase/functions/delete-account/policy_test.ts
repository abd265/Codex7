import { deletionAllowed } from "./policy.ts";
const now = 1_700_000_000;
const user = { id: "baker-a", factors: [{ status: "verified" }] };
const base = { sub: "baker-a", role: "authenticated", aal: "aal2", amr: [{ method: "password", timestamp: now - 30 }, { method: "totp", timestamp: now - 10 }] };
function check(value: boolean, wanted: boolean) { if (value !== wanted) throw new Error(`Expected ${wanted}, got ${value}`); }
Deno.test("fresh MFA session may delete only its own user", () => {
  check(deletionAllowed(base, user, now), true);
  check(deletionAllowed({ ...base, sub: "baker-b" }, user, now), false);
  check(deletionAllowed({ ...base, role: "anon" }, user, now), false);
});
Deno.test("password recovery and fresh TOTP do not refresh a stale first factor", () => {
  check(deletionAllowed({ ...base, amr: [{ method: "password", timestamp: now - 301 }, { method: "totp", timestamp: now }] }, user, now), false);
  check(deletionAllowed({ ...base, amr: [{ method: "recovery", timestamp: now }, { method: "totp", timestamp: now }] }, user, now), false);
});
Deno.test("MFA enrollment requires an elevated session and fresh second factor", () => {
  check(deletionAllowed({ ...base, aal: "aal1" }, user, now), false);
  check(deletionAllowed({ ...base, amr: [{ method: "password", timestamp: now }] }, user, now), false);
  check(deletionAllowed({ ...base, amr: [{ method: "password", timestamp: now }, { method: "totp", timestamp: now - 301 }] }, user, now), false);
});
Deno.test("malformed or future authentication times fail closed", () => {
  for (const amr of [null, {}, [], [{ method: "password", timestamp: "1700000000" }], [{ method: "password", timestamp: now + 1000 }], [{ method: "password", timestamp: NaN }]]) {
    check(deletionAllowed({ ...base, amr }, { id: "baker-a" }, now), false);
  }
});
Deno.test("MFA-free social sessions do not require a non-existent second factor", () => {
  check(deletionAllowed({ ...base, aal: "aal1", amr: [{ method: "oauth", timestamp: now }] }, { id: "baker-a", factors: [] }, now), true);
  check(deletionAllowed({ ...base, aal: "aal1", amr: [{ method: "oauth", timestamp: now }] }, user, now), false);
});
