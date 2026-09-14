# NO SUS Burn — 30s launch ad

Frame-accurate renderer for the authored eight-beat Burn ad. Choreography
is keyed to the same scene list as the original Design Component:

| Beat | Time | Picture |
|---|---|---|
| Type | 0:00–0:03 | Cursor types `gate code 4471. delete this.` |
| Reveal | 0:03–0:06 | Camera pulls back; Burn Note is pressed |
| Encrypt | 0:06–0:10 | Dashed ring around a lock. Super: *Encrypts in your browser.* |
| Ready | 0:10–0:15 | Pairing code `77`, in-browser QR, Copy Link |
| Open | 0:15–0:21 | Link travels to a phone; the note shows once, then erases |
| Gone | 0:21–0:24 | Same link tapped again; nothing opens |
| File | 0:24–0:27 | File tab; `handoff.pdf` drops in and seals. Super: *Notes or one file. No account.* |
| End | 0:27–0:30 | NO SUS wordmark. *Try it at nosus.foo.* |

The dummy share URL on screen is visual only (`#/burn/7f3a9c2e` has no
live key). The QR is generated locally from that same string.

## Rebuild

```sh
cd ads/burn
npm install
npm run build
npm run audio
npm run record
```

Outputs land in `out/`:

- `burn_ad_1920x1080.mp4`
- `burn_ad_1080x1920.mp4`
- `burn_ad_audio.wav`

Preview the composition in a browser at `public/index.html` (space to
pause, `0` to restart). Append `?record=1&w=1920&h=1080` for the
export framing.

Voiceover is synthesized with Edge TTS (`en-US-JennyNeural`) to the
pacing in `vendor/Burn_Ad_VO_script.md`. Re-record with a human reader
and drop the take in as `out/burn_ad_audio.wav` before `npm run record`
if you want the live voice.
