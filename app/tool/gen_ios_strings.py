"""Generates ios/Runner/en.lproj/InfoPlist.strings from lib/l10n/app_en.arb.

ARB stays the single source of truth for user-facing text; iOS permission prompts read their
explanations from InfoPlist.strings. (iOS has no usage-description key for notifications: that
prompt is explained by our own priming screen, which is already localised in the ARB.)
Run:  python3 tool/gen_ios_strings.py
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KEYS = {
    "NSCameraUsageDescription": "iosCameraUsage",
    "NSPhotoLibraryUsageDescription": "iosPhotoLibraryUsage",
    "NSLocationWhenInUseUsageDescription": "iosLocationUsage",
}


def render() -> str:
    arb = json.loads((ROOT / "lib/l10n/app_en.arb").read_text())
    lines = ["/* Generated from lib/l10n/app_en.arb by tool/gen_ios_strings.py. Do not edit. */"]
    for plist_key, arb_key in KEYS.items():
        value = arb[arb_key].replace("\\", "\\\\").replace('"', '\\"')
        lines.append(f'"{plist_key}" = "{value}";')
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    out = ROOT / "ios/Runner/en.lproj/InfoPlist.strings"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(render())
    print("wrote", out.relative_to(ROOT))
