# Linktree — founding-team contact form

Paste this into Linktree. Do not put the form on nosus.foo; submissions
stay in Linktree Audience. This is recruiting copy, not a product API.

Honesty bounds: one operator today. No invented headcount, waitlist
size, salary, or equity. The form does not create a NO SUS account.

## Linktree admin steps

1. Links → **+ Add** → search **Contact form** → Add.
2. Title: `Join the founding team`
3. Start from **Blank Form**.
4. Turn **Name** and **Email** on, required.
5. Turn **Phone** / **Country** off unless you actually want them.
6. **+ Add field** for the custom questions below.
7. Paste the intro and thank-you.
8. Thumbnail: `out/nosus_linktree_founding_thumb.png`
9. Put this link at the top. Prioritize it if you use that toggle.
10. Audience Settings → turn on **Get email notifications**.

Responses live under **Audience → Manage**.

Pro/Premium: Custom T&Cs can point at `https://nosus.foo/privacy.html`.
Say in the intro that answers go through Linktree, not the app.

## Profile (optional)

**Display name:** `NO SUS`

**Bio:**
```
Send a sensitive document and still see who opened it.
One person today. Looking for a founding team.
```

Second link (ghost/normal URL, not the form):
- Title: `Open the product`
- URL: `https://nosus.foo`

## Form copy

**Link title**
```
Join the founding team
```

**Intro**
```
NO SUS is one person today. This is not a mailing list. Tell me what you would want to own on an encrypted-docs product.
```

**Fields**

| Linktree field | Required | Prompt |
|---|---|---|
| Name | yes | (built-in) |
| Email | yes | (built-in) |
| Custom | no | What do you want to own at NO SUS? |
| Custom | no | Links (GitHub, site, X — whatever shows the work) |
| Message | no | Why you. Be specific. What would you ship in the first 30 days? |
| Custom | no | Time you can actually give (nights, weekends, hours per week) |

Placeholder for “own”: `Engineering, design, growth, ops, or a specific hole you see`

**Thank-you**
```
Got it. I'll read it. If it's a fit I'll email you.
```

**Submit button** (if editable): `Send`

## Preview

`public/linktree-preview.html` is a phone mock of the button and the
form so you can read the copy before pasting. It does not submit.

Rebuild the thumbnail:

```sh
cd ads/brand
node scripts/render.mjs
```
