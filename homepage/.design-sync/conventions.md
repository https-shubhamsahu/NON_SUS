# NO SUS Burn ad kit: how to build with it

The real components from nosus.foo, for ads and promo frames about Burn Notes and Burn Files. They live on `window.NoSus`: `NoSusLogo`, `BurnTool`, `ShareQr`, `AppLink`.

## Setup

- Load `styles.css`. It carries the Geist and Geist Mono faces, the brand tokens, and the only utility classes that exist (see below).
- Put everything on the brand black. The components are white-on-black and disappear on light grounds. Use a root like `<div className="min-h-screen bg-brand-black text-white font-sans">`.
- `BurnTool` is live: it encrypts in the browser and calls the NO SUS backend. Use it as the hero object. Its idle tabs (Note / File / Redeem) are what renders; the READY TO SHARE card needs a real upload.

## Styling idiom: Tailwind v4 utilities, precompiled

There is no Tailwind runtime. A class works only if it is in `styles.css`. Stick to this vocabulary:

| Family | Classes |
|---|---|
| Brand color | `bg-`/`text-`/`border-` + `brand-black` (#080808), `brand-gray-dark` (#141414), `brand-gray` (#1e1e1e), `brand-gray-light` (#888888), `white`, `black`; `text-white/50`, `border-white/10`, `border-white/20`, `border-white/80` |
| Type | `font-sans`, `font-mono`, `font-medium`, `font-semibold`, `font-bold`, `font-black`, `uppercase`, `tracking-tighter`, `tracking-tight`, `tracking-wide`, `tracking-wider`, `tracking-widest`, `leading-none`/`tight`/`relaxed`, `tabular-nums`, `text-xs` to `text-9xl` |
| Layout | `flex`, `grid`, `grid-cols-1` to `4`, `flex-col`, `items-*`, `justify-*`, `gap-`/`p-`/`px-`/`py-`/`pt-`/`pb-`/`m-`/`mt-`/`mb-` with 0–6, 8, 10, 12, 16, 20, 24, `max-w-xs` to `max-w-7xl`, `mx-auto`, `w-full`, `h-full`, `min-h-screen`, `relative`, `absolute`, `inset-0`, `overflow-hidden`, `aspect-square`, `aspect-video` |
| Shape | `rounded`, `rounded-sm` to `rounded-2xl`, `rounded-full`, `border`, `border-2`, `border-4`, `border-dashed` |

Layout, type size, and `grid-cols` classes also take `sm:`, `md:`, and `lg:`. For anything else, use inline `style` with the CSS variables `--color-brand-black`, `--color-brand-gray-dark`, `--color-brand-gray`, `--color-brand-gray-light`, `--font-sans`, and `--font-mono`.

## The look

Swiss and flat. Black ground, white type, #888 for secondary text, Geist. Labels are small, bold, uppercase, and widely tracked (`text-xs font-bold uppercase tracking-widest`). Calls to action are a white fill with black text. There are no gradients, glows, neon, fire, or matrix effects.

## Copy that is allowed

Allowed: "Encrypts in your browser." "The key lives in the link." "One open, then it's gone." "No account." "Tell them the two-digit code." "Try it at nosus.foo."

Never write:
- screenshot-proof;
- that the server never sees the key;
- "if it leaks you'll know who";
- that the homepage sends several files at once;
- invented stats, user counts, or testimonials.

## Example

```tsx
const { NoSusLogo, BurnTool, AppLink } = window.NoSus;

<div className="min-h-screen bg-brand-black text-white font-sans flex flex-col items-center justify-center gap-8 p-8">
  <h1 className="text-5xl md:text-7xl font-black tracking-tighter text-center">One open. Then it's gone.</h1>
  <p className="font-mono text-xs uppercase tracking-widest text-brand-gray-light">Encrypts in your browser. No account.</p>
  <div className="w-full max-w-2xl"><BurnTool /></div>
  <div className="flex items-center gap-6">
    <NoSusLogo sizeClass="text-2xl" />
    <AppLink className="inline-flex items-center bg-white text-black px-6 py-2 text-xs font-bold uppercase tracking-wider border border-white rounded-full">Try it at nosus.foo</AppLink>
  </div>
</div>
```

Per-component notes are in each `components/<group>/<Name>/<Name>.prompt.md`.
