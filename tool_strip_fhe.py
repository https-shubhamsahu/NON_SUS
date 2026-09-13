from pathlib import Path
import shutil

root = Path(r"c:\Users\shubh\_Active_Projects\NO_SUS\no_sus")
ws = root / "lib/features/workspace/presentation/pages/workspace_tab.dart"
text = ws.read_text(encoding="utf-8")
text = text.replace("import 'package:google_fonts/google_fonts.dart';\n", "")
needle = """          const _SealedTeaserCard()
              .animate()
              .fadeIn(duration: 340.ms)
              .slideY(begin: 0.05, end: 0),
          const SizedBox(height: NoSusTheme.s16),

"""
text = text.replace(needle, "")
start = text.find("class _SealedTeaserCard")
end = text.find("class _RecentlySavedSection")
if start == -1 or end == -1 or start >= end:
    raise SystemExit(f"markers missing start={start} end={end}")
ws.write_text(text[:start] + text[end:], encoding="utf-8")
print("workspace stripped")

dup = root / "supabase/migrations/20260826000000_two_digit_redeem_pin.sql"
if dup.exists():
    dup.unlink()
    print("removed duplicate migration")

receipt = root / "lib/features/share/presentation/widgets/share_receipt.dart"
if receipt.exists():
    receipt.unlink()
    print("removed unused share_receipt")

shield = root / "SHIELD.md"
archive = root / "docs/archive/SHIELD.md"
if shield.exists():
    archive.parent.mkdir(parents=True, exist_ok=True)
    shield.replace(archive)
    print("archived SHIELD.md")

for rel in [
    "lib/features/fhe",
    "lib/features/sealed",
    "lib/config/fhe_config.dart",
    "services/fhe-compute",
    "supabase/functions/fhe-proxy",
    "supabase/functions/sealed-api",
    "supabase/functions/pact-matcher",
    "test/features/fhe_test.dart",
    "test/features/sealed",
    ".claude/rules/no-sus-fhe.md",
]:
    path = root / rel
    if path.is_dir():
        shutil.rmtree(path)
        print("rmdir", rel)
    elif path.is_file():
        path.unlink()
        print("rm", rel)
