# Play Store listing copy — NO SUS

Paste-ready text for Play Console → Grow users → Store presence → Store listings.
Every claim below maps to a shipped feature — nothing aspirational, so the
listing can't drift out of Play's metadata policy or misrepresent the app.

## App name (30 max)

```
NO SUS
```

## Short description (80 max — this one is 71)

Keep in step with Play Console / `fastlane/metadata/android/en-IN/short_description.txt`.

```
Share documents watermarked to each viewer. Send self-destructing notes.
```

## Full description (4000 max)

Keep in step with Play Console / `fastlane/metadata/android/en-IN/full_description.txt`.
Do not say zero-knowledge, screenshot-proof, or that the server cannot see a pairing-code share.

```
NO SUS is a workspace for sharing documents with people you trust — and seeing who opened them.

WATERMARKED DOCUMENTS
Create invite-only study groups and share notes and files. Documents open in a viewer that watermarks each copy with the reader's identity, so a leak traces back to a person.

BURN NOTES & BURN FILES
Send self-destructing notes and files. They are encrypted on your device before upload. For a normal share link, the decryption key travels in the URL fragment and is not sent to our servers. Pairing-code shares are different: the AES key is stored on the server until the code is used or it expires (20 minutes by default). One view or download, and the payload is permanently deleted. Recipients don't need an account.

AUDIT LOG
File opens, shares, membership changes, and screenshot attempts are written to a hash-chained ledger your group can see. If a record is altered, the chain visibly breaks.

SCREEN PROTECTION
On Android, screenshots and screen recording are blocked inside the app, and attempts are logged. This is not available on web or other platforms. Links you share can require touch-to-reveal.

DEVICE INTEGRITY
Rooted or tampered Android devices are detected and flagged. If an account shows serious risk signals, NO SUS can lock the session and require a fresh sign-in.

YOUR DATA
No ads. No selling data. You can permanently delete your account from Profile → Settings → Danger Zone.

Built for study groups.
```

## Other listing fields

| Field | Value |
|---|---|
| App icon (512×512 PNG, ≤1MB) | `fastlane/metadata/android/en-IN/images/icon.png` (copied from `homepage/public/app_icon.png`) |
| Feature graphic (1024×500, 24-bit PNG, ≤15MB) | `fastlane/metadata/android/en-IN/images/featureGraphic.png` — generated from `tool/store_assets/feature_graphic.html` |
| Video | Leave empty (optional; needs a public/unlisted YouTube URL, ads off) |
| Privacy policy URL (App content section) | `https://nosus.foo/privacy.html` — verified live ✓ |
| Account deletion URL (Data safety section) | `https://nosus.foo/account-deletion.html` |

## Screenshot requirements (must capture manually — see notes)

| Slot | Count | Spec |
|---|---|---|
| Phone | 2–8 (min 2 required) | PNG/JPEG ≤8MB, **16:9 or 9:16 exactly**, each side 320–3840px. For store promotion eligibility: ≥4 screenshots at ≥1080px per side. Target: **1080×1920 portrait** |
| 7-inch tablet | up to 8 (min 1 to satisfy the form) | Same as phone: 16:9 / 9:16, 320–3840px |
| 10-inch tablet | up to 8 (min 1) | 16:9 / 9:16, each side **1080–7680px**. Target: **1600×2560 or 2560×1600** |
| Chromebook / Android XR | optional | Skip for v1 |

**Important:** Play phone screenshots must be ≥1080px per side with aspect ratio
≤ 2:1 (a Pixel 1080×2400 capture is 20:9 and will be rejected). Capture them from
a real device or emulator frame; do not rasterize widgets. Drop PNGs in
`fastlane/metadata/android/en-IN/images/phoneScreenshots/` when you have them.
Upload with Fastlane `upload_listing` when `PLAY_JSON_KEY` points at a
service-account JSON. Icon and feature graphic in that images folder are the
only listing images currently in git.

## Suggested release notes for the first listing (500 max)

```
First public release.
• Private study groups with watermarked document viewing
• Burn Notes & Burn Files — self-destructing shares
• Tamper-evident audit ledger
• Android screenshot blocking inside the app
```
