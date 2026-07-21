# Play Store listing copy — NO SUS

Paste-ready text for Play Console → Grow users → Store presence → Store listings.
Every claim below maps to a shipped feature — nothing aspirational, so the
listing can't drift out of Play's metadata policy or misrepresent the app.

## App name (30 max)

```
NO SUS
```

## Short description (80 max — this one is 76)

```
Secure study groups: encrypted files, burn notes & tamper-evident audit logs
```

Alternates if you want to A/B later (both ≤80):

```
Encrypted study workspace — secure sharing, self-destructing notes, audit log
```
```
Share files that protect themselves. Encrypted groups, burn notes, audit log.
```

## Full description (4000 max — this one is ~1,900)

```
NO SUS is a security-first workspace for sharing documents with people you trust — and proving nothing happened behind your back.

PRIVATE STUDY GROUPS
Create invite-only groups and keep notes and documents in an encrypted vault. Files open inside a secure viewer with watermarking, so every copy carries its reader's identity.

BURN NOTES & BURN FILES
Send self-destructing notes and files. They are encrypted on your device before upload, and the decryption key travels only inside the link — it never reaches our servers, so we couldn't read your content even if we wanted to. One view or download, and it's permanently deleted. Recipients don't need an account.

TAMPER-EVIDENT AUDIT LOG
Every file open, share, membership change, and screenshot attempt is written to a hash-chained ledger visible to your group. If a record is ever altered, the chain visibly breaks. Trust isn't promised — it's checkable.

BUILT-IN SCREEN PROTECTION
Screenshots and screen recording are blocked inside the app, and attempts are logged to the ledger. Links you share can require touch-to-reveal, so a glance at someone else's screen shows nothing.

DEVICE INTEGRITY
Rooted or tampered devices are detected and flagged. If an account shows serious risk signals, NO SUS can lock the session and require a fresh sign-in before anything else is opened.

YOUR DATA STAYS YOURS
No ads. No trackers. No selling data. Your account — and everything attached to it — can be permanently deleted any time from Profile → Danger Zone.

Built for study groups. Sharp enough for anything you'd rather keep NO SUS.
```

## Other listing fields

| Field | Value |
|---|---|
| App icon (512×512 PNG, ≤1MB) | `assets/icon/app_icon.png` — verified 512×512, 22.5KB ✓ |
| Feature graphic (1024×500, ≤15MB) | `store_listing/feature_graphic_1024x500.png` (generated) |
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

**Important:** modern phones capture at ~20:9, which Play will reject (needs exactly
9:16). Don't upload raw device screenshots — they must be framed/padded onto a
9:16 canvas. Capture raw screenshots of: Workspace tab, a group's file list, the
secure viewer with watermark, Burn Note creator, the Audit ledger. Drop them in
`store_listing/raw_screenshots/` and they can be batch-framed onto branded
1080×1920 canvases programmatically.

## Suggested release notes for the first listing (500 max)

```
First public release.
• Private study groups with an encrypted document vault
• Burn Notes & Burn Files — self-destructing, zero-knowledge sharing
• Tamper-evident audit ledger
• Screenshot blocking and watermarked viewing
```
