# NO SUS landing — design tokens

**Style:** Minimalism & Swiss Style (high contrast, grid, sans, low decoration).

**Why:** Privacy tool for students in India — dark-first ink UI that feels serious and honest; light mode is warm paper, not pure white. No rose/lavender Soft UI, no green/blue brand accent.

Other agents **must** consume these tokens. Do not invent hex in sections.

## Surfaces (use these — flip with theme)

| Utility | Role |
|---------|------|
| `bg-background` / `text-foreground` | Page |
| `bg-card` / `text-card-foreground` | Raised panels |
| `bg-muted` / `text-muted-foreground` | Subtle fills / secondary copy |
| `border-border` | Borders |
| `bg-accent` / `text-accent-foreground` | Primary CTA (ink↔paper, not chroma) |
| `ring-ring` / focus via globals | Focus ring |
| `text-destructive` / `bg-destructive` | Errors |

**Do not** use `bg-brand-black` / `bg-brand-gray*` for surfaces that should flip in light mode. Brand utilities are fixed ink for marks and legacy sections.

## Brand (fixed — dark ink palette)

| Token | Hex | Notes |
|-------|-----|--------|
| `brand-black` | `#080808` | Ink background |
| `brand-gray-dark` | `#141414` | Raised |
| `brand-gray` | `#1e1e1e` | Border / muted fill |
| `brand-gray-light` | `#888888` | Large type / disabled only — **not** body muted |

## Color table

### Dark (default)

| Role | Hex |
|------|-----|
| background | `#080808` |
| foreground | `#FFFFFF` |
| card | `#141414` |
| muted | `#1E1E1E` |
| muted-foreground | `#B8B8B8` (~9:1 on ink) |
| border | `#1E1E1E` |
| accent | `#FFFFFF` |
| accent-foreground | `#080808` |
| ring | `#FFFFFF` |
| destructive | `#DC2626` |

### Light (`data-theme="light"` or OS light when unset)

| Role | Hex |
|------|-----|
| background | `#F4F1EA` (warm paper) |
| foreground | `#141414` |
| card | `#FBFAF7` |
| muted | `#EBE6DC` |
| muted-foreground | `#4A453F` (≥4.5:1 on paper) |
| border | `rgba(20,20,20,0.12)` |
| accent | `#141414` |
| accent-foreground | `#F4F1EA` |
| ring | `#141414` |
| destructive | `#B91C1C` |
| card shadow | `0 1px 3px rgba(20,20,20,0.08)` (light only) |

## Theme activation

1. **Default:** dark (no `data-theme`, no light OS preference).
2. **OS light:** `@media (prefers-color-scheme: light)` on `html:not([data-theme="dark"])`.
3. **Explicit:** `html[data-theme="light"|"dark"]` via `ThemeToggle` → `localStorage` key `nosus-theme`.

## Type (Geist Sans + Geist Mono — already in `layout.tsx`)

| Step | Size |
|------|------|
| Label | 12px |
| Body | 16px (min), line-height 1.5 |
| Lead | 20px |
| H2 | 32px |
| H1 | 48–60px |

No Google Fonts CDN, no second family, no emoji icons.

## Spacing / radii / motion

- **Spacing:** 4, 8, 12, 16, 24, 32, 48, 64, 96
- **Radii:** `0` swiss rules · `12px` cards (`.paper-card`) · `999px` pills
- **Shadows:** almost none; soft card shadow in light only
- **Motion:** 150–250ms `ease-out`; `prefers-reduced-motion` kills decorative animation (incl. luxnox)
- **Touch:** 44×44px minimum hit targets

## Helpers

- `.swiss-grid`, `.pixel-divider`, `.paper-card` — theme-variable colors
- `.btn`, `.btn-primary`, `.btn-ghost` — optional control chrome
- `ThemeToggle` — `src/components/ui/ThemeToggle.tsx`

## Do / don’t

- **Do** stay cryptographically honest — no zero-knowledge / “server cannot see it” claims beyond what ships
- **Do** draw QR in-browser — never a third-party QR API (AES key in fragment)
- **Don’t** import external fonts or emoji-as-icons
- **Don’t** use pure white page backgrounds or chromatic brand accents (green/blue/rose)
