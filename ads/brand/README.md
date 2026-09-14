# NO SUS brand banners

Horizontal and square lockups of the Lux/Nox yin-yang mark plus the
canonical **NO SUS** wordmark (Geist Black, gray square stop — not a
period glyph). Background is `#080808`. No tagline; copy does not
outrun the cryptography.

The mark source is `src/lux-nox-source.png`. White square backing is
knocked out before composite so the circle sits on the near-black field.

## Rebuild

```sh
cd ads/brand
node scripts/render.mjs
```

Needs the Playwright install from `ads/burn/` (`npm install` there)
and Google Chrome. Outputs:

- `out/nosus_banner_1920x640.png` — wide banner
- `out/nosus_banner_1500x500.png` — X / social header
- `out/nosus_banner_1280x640.png` — GitHub social preview
- `out/nosus_banner_1080x1080.png` — square lockup
