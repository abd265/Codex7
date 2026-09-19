#!/usr/bin/env python3
"""Print the reviewable Supabase Auth PATCH payload; never send a request."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
settings = json.loads((root / "supabase/auth-settings.json").read_text())
for name in ("confirmation", "recovery"):
    template = (root / f"supabase/templates/{name}.html").read_text()
    if template.count("{{ .Token }}") != 1 or "{{ .ConfirmationURL }}" in template:
        raise ValueError(f"{name} must contain one OTP token and no confirmation-link flow")
    settings[f"mailer_templates_{name}_content"] = template
if settings["mailer_otp_length"] != 6 or settings["mailer_otp_exp"] != 600:
    raise ValueError("OTP settings must match the native form and email copy")
print(json.dumps(settings, indent=2))
