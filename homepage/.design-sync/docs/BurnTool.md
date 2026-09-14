---
category: Burn
---
The Burn circle from the nosus.foo hero: a one-time encrypted handoff for a note or a single file, with no account.

## Usage

```tsx
<div className="w-full max-w-2xl">
  <BurnTool />
</div>
```

BurnTool takes no props and is live: it encrypts in the browser and talks to the NO SUS backend. It opens on the File tab. Visitors switch between Note, File, and Redeem.

## What it shows

- **Idle:** a 380–440px white-bordered circle on `bg-brand-black/95`. It has a pill tab switch (Note / File / Redeem) and a dashed drop zone ("CLICK OR DRAG FILE HERE", up to the file size limit) or a note textarea. File shares get an "Expires in" choice.
- **Working:** a spinning dashed ring with a lock and a status line: ENCRYPTING IN BROWSER…, UPLOADING CIPHERTEXT…, SEALING….
- **Done:** the circle becomes a rounded card. It shows READY TO SHARE, "Their code" as a huge 2-digit number, a QR (`ShareQr`) of the share link, a Copy Link pill, and "Burn another".

Only the idle tabs render in a static preview; working and done need a real upload.

## Copy rules for anything built around it

Say only what ships:
- Encrypts in your browser. The key lives in the link. One open, then it's gone. No account. Try it at nosus.foo. Tell them the two-digit code.

Never say:
- screenshot-proof;
- that the server never sees the key (false when a 2-digit code is issued);
- "if it leaks you'll know who" (that is watermarked document sharing, a different feature);
- that the homepage shares several files at once (it takes one file);
- invented stats, user counts, or testimonials.

No neon, fire, or matrix imagery. Keep it Swiss: black, white type, #888 gray, Geist.
