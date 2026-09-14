---
category: Actions
---
A link to the NO SUS web app (app.nosus.foo). On desktop and iOS it is a plain anchor. On Android, tapping it opens a bottom sheet with three choices: open the installed app, download the APK, or continue in the browser.

## Usage

```tsx
<AppLink className="inline-flex items-center gap-2 bg-white text-black px-10 py-4 text-xs font-bold uppercase tracking-wider hover:bg-black hover:text-white border border-white transition-all rounded-sm">
  Get Started Free ↗
</AppLink>
```

- AppLink has no styling of its own; pass it all through `className`. The site's call-to-action look is a white fill with black, bold, uppercase, widely tracked text, inverting to black on hover.
- On the site an `ArrowUpRight` icon from `lucide-react` follows the label. That icon library is not part of this kit, so use a ↗ character or leave it out.
- `onNavigate` runs when the Android sheet closes after navigation (the mobile menu uses it to close itself).
