# NO SUS — Mascot & Motion Design Bible
### Lux & Nox — Character, Behavior, and Animation System

> Scope note: this document designs the mascot/motion layer only. It does not propose any
> change to layout, navigation, features, or architecture. Every recommendation is additive —
> it describes where a small, meaningful animation could live inside the **existing** screens,
> named against the actual files in this repo, for a motion designer + Flutter dev to pick up.

---

## 1. Character Guide

### Lux — The White Cat
| | |
|---|---|
| **Archetype** | The Scholar / The Guide |
| **Represents** | knowledge, guidance, collaboration, curiosity, learning |
| **Emotional palette** | curious, warm, encouraging, quietly playful |
| **Never shows** | worry, urgency, panic — Lux never delivers bad news |
| **Signature read** | occupies the white field of the mark; the black eye-dot and the small ear notch already visible in the logo are Lux's most legible identifying details at small sizes |
| **Motion voice** | leans toward the viewer, slow blinks, head-tilts — "I noticed something / let me show you" |

### Nox — The Black Cat
| | |
|---|---|
| **Archetype** | The Guardian / The Verifier |
| **Represents** | privacy, protection, verification, security, confidence |
| **Emotional palette** | calm, watchful, resolute, occasionally stern — never aggressive |
| **Never shows** | fear or panic — even "Alert" is composed: standing guard, not scared |
| **Signature read** | occupies the black field; sits low and still more than Lux; tail curls protectively rather than swishing |
| **Motion voice** | paw-stamps down to confirm, positions between the viewer and a problem — "handled" |

### The Relationship
- **Yin-yang, not rivals.** Neither is "good" or "bad" — they're complementary halves of one trust system. They are never shown competing, one dominating, or in conflict.
- **Scarcity is the point.** Default state is *apart* — each living quietly in their own region of a screen. A joint appearance is reserved for real trust milestones (session start/end, successful verification, a completed mutual action). That scarcity is what makes the together-moments land.
- **One does not narrate the other.** If Lux is guiding, Nox does not simultaneously alert — unless the moment is deliberately nuanced ("saved — but here's a heads-up"), in which case they occupy visually separate zones, never overlapping gestures.

### Hard Constraints (non-negotiable, repeated here because they're load-bearing)
Pixel-art only · monochrome only (pure black/white) · no gradients · no shadows · no glow ·
no blur · no paper textures · no ink splashes · no realistic lighting · no 3D · no
glassmorphism · no skeuomorphism · no color accents · no anime styling · no cartoon
exaggeration · silhouette, proportions, and facial expressions from the source logo are
fixed and must not be redrawn.

---

## 2. Behavior Guide

1. **Rule of One Motion** — every appearance performs exactly one clear action, then returns to idle or exits. No compound "showing off" animations.
2. **Rule of Scarcity** — the mascot does not live on every card or every button. It appears at decision points, waiting points, and outcome points only.
3. **Rule of Non-Competition** — Lux and Nox never deliver conflicting signals in the same moment/region.
4. **Rule of Silence** — no sound design is prescribed here; motion alone must carry the meaning.
5. **Rule of Held Frames** — favor sprite-style held poses (2–4 frame idle breathing loops) over continuous real-time tweening, even though Rive is technically capable of smooth interpolation.
6. **Default answer is "don't animate."** Every recommendation below had to earn its place by improving comprehension, not decoration.

---

## 3. Motion Principles

- **Pixel-grid snapping** — all translation happens in whole grid-steps matching the blocky units visible in the source mark; no sub-pixel smoothing.
- **Frame economy** — 6–12 unique poses per state, played at **8–12 fps**, using **Hold/Constant** keyframe interpolation in Rive (never Ease/Smooth) to preserve the sprite feel.
- **Stepped, not eased** — reject ease-in-out curves; motion should read like classic 2D game sprites.
- **Silhouette integrity** — at every single frame, the figure must still read as the cat from the logo; no frame where a limb overlaps into an unreadable blob or breaks the black/white split.
- **Low amplitude** — idle breathing bob ≈ 2–3 grid units; walk-cycle traversal never exceeds roughly one mascot-width.
- **Directional bias** — Lux tends to move forward/upward (approach, discovery); Nox tends to hold ground or settle (guarding, verifying).

---

## 4. Animation Catalogue

Each state below is designed to be a **self-contained Rive animation** on the character's artboard, callable independently by a state-machine input.

### Lux — 13 States

| State | Body | Ears | Eyes | Tail | Breathing | Idle / Transition Notes |
|---|---|---|---|---|---|---|
| **Idle** | Seated, weight settled, tiny bob | Neutral, occasional single flick | Open, slow blink every ~3s | Loose curl, gentle sway | 2-frame chest rise/fall loop | Default rest state; loops indefinitely |
| **Sleep** | Curled into a low, compact ball | Flattened back | Closed (single flat line) | Wrapped around body | Slow, wider-amplitude breathing | Entered after prolonged inactivity; exits only via Wake |
| **Wake** | Uncurls, head lifts first, then body | Ears rise from flat to upright | Snap open, one blink | Uncurls with body | Breathing normalizes over the clip | One-shot; always transitions into Idle |
| **Walk** | 2–4 pose walk-cycle, small forward steps | Slight bounce per step | Forward-facing, steady | Swings opposite to stride | Held during motion | One-shot traversal, distance capped to ~1 mascot-width |
| **Look Around** | Head/torso turns L→center→R | Rotate to track head | Track the head turn | Still | Normal idle breathing continues | One-shot; used for "searching" or empty states |
| **Think** | Slight forward lean, head tilts down | One ear rotates back | Half-lidded, occasional upward glance | Tip flicks slowly | Slowed breathing | Loop while a process is pending (upload, AI, sync) |
| **Observe** | Still, slightly forward-set posture | Both ears forward, alert-but-calm | Wide, fixed on a focal point | Still, tip only | Normal | Loop; used while something is being read/reviewed |
| **Guide** | Leans toward viewer, one paw gestures outward | Forward | Warm, open | Neutral sway | Normal | One-shot, resolves back to Idle; pairs with onboarding/tooltips |
| **Celebrate** | Small hop, brief arch of the back | Both perk fully upright | Bright, wide | Quick upward flick | Brief quickened breath | One-shot, short (<1s active motion) — success only |
| **Wait** | Seated, chin slightly lifted | Neutral | Slow blink cycle, longer holds | Still | Slightly slowed | Loop for "waiting on the user" (e.g. empty search, form) |
| **Sit** | Grounded seated base pose | Neutral | Neutral open | Resting, still | Normal | The base pose most other states return to |
| **Stretch** | Elongates forward, back arches | Ears relax back briefly | Squint, then reopen | Extends fully, then relaxes | Deep single breath | One-shot, plays on long-idle timeout before Sleep |
| **Return To Logo** | Folds back into the exact static yin-yang silhouette pose | Return to logo position | Return to logo position | Return to logo position | Settles to a single still frame | One-shot bookend; used at session start/end |

### Nox — 14 States

| State | Body | Ears | Eyes | Tail | Breathing | Idle / Transition Notes |
|---|---|---|---|---|---|---|
| **Idle** | Seated low, compact, still | Neutral, minimal movement | Open, infrequent slow blink | Curled close to body | 2-frame subtle rise/fall | Default rest; stiller than Lux's idle by design |
| **Sleep** | Low, flattened, tucked | Flattened | Closed | Wrapped tight | Slow, wide | Entered after prolonged inactivity |
| **Wake** | Rises from flattened to seated in one clean motion | Ears rise sharply, no drift | Snap open | Uncurls | Normalizes | One-shot into Idle |
| **Walk** | Low, deliberate 2–4 pose cycle | Still, forward | Forward, steady | Low, minimal swing | Held | One-shot, deliberate/slower cadence than Lux's walk |
| **Observe** | Still, low, weight forward | Forward, locked | Fixed, unblinking longer holds | Still | Normal | Loop; used while a security check is in progress |
| **Protect** | Positions low and squared, chest slightly forward | Both forward, flattened slightly (defensive, not aggressive) | Steady, wide | Low, still | Normal | Loop; used behind blur-until-touch / gated content |
| **Approve** | Single, small forward nod | Neutral | Brief soft-close, reopen | Single slow flick | Normal | One-shot, quiet — confirmation without celebration |
| **Verify** | Head lowers slightly, focused | One ear rotates as if listening | Narrowed, scanning left-right once | Still | Normal | Loop while a hash/signature check runs |
| **Guard** | Squared, grounded stance, slightly forward | Both forward | Wide, steady | Still, low | Normal | Loop for "protecting this content/session" contexts |
| **Alert** | Ears and posture sharpen; weight shifts forward — composed, not startled | Both snap fully forward | Wide, fixed | Stiffens, tip only twitches | Slightly quickened | One-shot then holds in a firm stance until resolved |
| **Stamp** | Single decisive downward paw motion | Neutral | Brief close on impact, reopen | Still | Single held breath on impact | One-shot; the "sealed/confirmed" beat — pairs with audit verification |
| **Sit** | Grounded base pose | Neutral | Neutral | Resting | Normal | Base pose most states return to |
| **Stretch** | Low elongation, minimal arch (more restrained than Lux) | Relax briefly | Squint, reopen | Extends, retracts | Single deep breath | One-shot before Sleep on long idle |
| **Return To Logo** | Folds back into exact static yin-yang silhouette pose | Return to logo position | Return to logo position | Return to logo position | Settles still | One-shot bookend; mirrors Lux's, plays in sync for joint moments |

---

## 5. Interaction Catalogue — Flutter App

Mapped against the real screens/files in this codebase. "Both" appearances are intentionally rare per the Scarcity rule.

| Interaction | File(s) | Mascot | Why / Emotion | Trigger | Loop / One-shot | Notes |
|---|---|---|---|---|---|---|
| **Splash Screen** | `lib/screens/splash_screen.dart` | Both | Bookend the session; calm confidence on open | App launch | One-shot: Sleep→Wake→Return-to-Logo | Preload `.riv` assets here — this idle window is the natural place to warm the cache |
| **Loading (generic)** | shared indicator wherever used | Lux | "Working on it," not "something's wrong" | Any async wait >400ms | Loop: Think | Only show past a short delay threshold — don't animate for near-instant loads |
| **Home / Workspace tab** | `lib/features/workspace/presentation/pages/workspace_tab.dart` | Lux | Curiosity/orientation on a content hub | Tab first opened this session | One-shot: Look Around → Idle | Do not replay on every tab revisit, only first-per-session |
| **Vault (empty)** | `lib/features/vault/presentation/pages/vault_tab.dart` | Nox | "Nothing to guard yet" — sets tone before content exists | Vault has 0 files | Loop: Sit/Idle | Pairs with existing empty-state copy, doesn't replace it |
| **Study Desk / secure viewer** | `components/secure_viewer/secure_document_viewer.dart`, `blur_reveal_layer.dart` | Nox | Reinforces "this is protected" during blur-until-touch | Document opened, still blurred | Loop: Protect/Guard | **Approve** one-shot exactly on the user's reveal tap — ties mascot directly to the existing gesture |
| **Audit Log** | `lib/features/audit/presentation/pages/audit_tab.dart` | Nox | Verification is Nox's whole identity | Chain check runs (`verify_audit_chain`) | Loop: Verify → one-shot **Stamp** on valid result | Stamp must co-occur with the existing verified badge/text, never replace it |
| **Groups (empty)** | `lib/features/groups/widgets/empty_states.dart` | Lux | Inviting, not alarming, first-run tone | No groups joined yet | Loop: Wait/Look Around | |
| **SecureSend — create link** | `lib/features/share/presentation/widgets/share_link_dialog.dart` | Lux (first use) → Nox (on confirm) | Lux explains, Nox confirms the trust boundary | Dialog opened / link created | One-shot each | Lux only on first-ever use (persisted flag), not every time |
| **SecureSend — anonymous viewer** | `lib/features/share/presentation/screens/anonymous_share_viewer_screen.dart` | Nox | Recipient has no account — Nox signals "still protected" | Token validated | One-shot: Verify → Approve | |
| **Burn Notes — composing** | `lib/features/share/presentation/screens/burn_note_creator_screen.dart` | Nox | Sets expectation: this is guarded, ephemeral | Screen opened | Loop: Guard | |
| **Burn Notes — countdown** | `lib/features/share/presentation/screens/burn_note_viewer_screen.dart` | Nox | Urgency without panic as the burn approaches | Countdown active | Loop: Guard → **Alert** under 10s remaining → **Return To Logo** one-shot at burn | The existing numeric countdown remains the primary signal; mascot is reinforcement only |
| **Upload — in progress** | `lib/features/groups/widgets/upload_modal.dart`, `file_card.dart` | Lux | Active, working, non-alarming | Upload starts | Loop: Think | |
| **Upload / Download — Success** | same | Lux | Reward completion | Operation completes | One-shot: Celebrate | Keep brief — under 1s of active motion, per Rule of One Motion |
| **Upload / Download — Failure** | same | Nox | Something needs attention, composed not scary | Operation errors | One-shot: Alert (settles to Idle, not held indefinitely) | Must accompany existing error text, never stand alone |
| **View Document** | `secure_document_viewer.dart` | Nox | Ongoing protection while reading | Document open | Loop: Observe | Very low visual priority — small, corner-anchored, never over the content |
| **Permission Denied** | wherever RLS/auth errors surface | Nox | Boundary enforcement, calm authority | Denied action | One-shot: Alert → Guard (holds) | |
| **Verification** (any RPC/chain check) | audit, share-fetch validation, etc. | Nox | Nox's core identity | Verification RPC in flight | Loop: Verify | |
| **AI Thinking** (legacy FHE demo, if ever reactivated) | `features/fhe/*` | Lux | Curious processing, not backend mystery | AI/compute call in flight | Loop: Think | Out of scope while this feature is disconnected — reserved for if it's re-enabled |
| **Search** | any search field | Lux | Curiosity | Empty query / typing | Loop: Look Around | |
| **Refresh (pull-to-refresh, manual)** | list screens | Lux | Small, quick acknowledgement | Refresh triggered | One-shot: brief Look Around | Must not block the refresh gesture itself |
| **Notifications** (share-view snackbar) | `main.dart` `_showNotificationBanner` | Nox | A view was logged — Nox's domain | Realtime event fires | One-shot: small inline Observe glance | Icon-scale only, inline with the existing SnackBar — not a full-screen takeover |
| **Offline** | connectivity loss anywhere | Nox | Protective pause, not a crisis | Connection lost | Loop: Sit (still, waiting) | |
| **Online (reconnected)** | same | Lux | Relief / resumption | Connection restored | One-shot: Wake → Idle | |
| **Login** | `features/auth/presentation/screens/auth_screen.dart` | Both (brief) | Session opening trust moment | Successful auth | One-shot: Return-to-Logo reverse (unfold) → each goes to Idle | Mirrors Splash; scarce, only at true session start |
| **Logout** | `features/profile/presentation/screens/profile_screen.dart` | Both | Session closing trust moment | User signs out | One-shot: Return To Logo | |
| **Onboarding** | `features/onboarding/presentation/screens/onboarding_screen.dart` + step widgets | Lux | Guidance is Lux's whole identity | Each step transition | One-shot: Guide, per step | Single persistent widget driven by a state input — do not rebuild per PageView page |
| **Settings** | `features/profile/presentation/screens/advanced_settings_screen.dart` | Nox | Configuration = trust/control | Screen opened | Loop: Idle (low-key presence) | Lowest-priority placement — settings is a utility screen, keep mascot minimal |
| **Empty States (general)** | `groups/widgets/empty_states.dart` and others | Lux | Inviting first-use tone | Zero-content state | Loop: Wait / Look Around | |
| **Confirmation Dialogs** (delete, revoke) | various | Nox | Weighing a consequential action | Dialog opens | Loop: Idle → one-shot **Approve** only after user confirms | Never animate on the destructive option itself — only after the decision is made |

---

## 6. Interaction Catalogue — Website (Marketing Site)

The repo currently only contains the Flutter Web build (`web/`), not a separate marketing site. These recommendations are forward-looking, using the exact same `.riv` assets (portable to plain web via `rive.js` / `@rive-app/canvas`) for whenever a marketing site is built.

| Interaction | Mascot | Behavior | Trigger | Loop / One-shot | Notes |
|---|---|---|---|---|---|
| **Landing Hero** | Both | Yin-yang breathing idle, replacing/augmenting the static logo mark | Page load | Loop: Idle | The calmest, slowest loop in the whole system — it's the brand's front door |
| **Scroll** | Lux | Look Around, triggered per-section | Section enters viewport (IntersectionObserver) | One-shot per section entry | Throttle to once per section, never per scroll pixel |
| **Hover (desktop)** | Context-dependent | Small ear-perk / lean-in | Mouse hover | One-shot | Must have a `:focus-visible` equivalent for keyboard users — hover-only is not accessible |
| **Buttons — primary CTA** | Lux | Lean-in nod | Hover/focus | One-shot | |
| **Buttons — destructive** | Nox | Ear-flick only (Alert-lite, not full alarm) | Hover/focus | One-shot | |
| **Footer** | Both | Slow duo idle, essentially wallpaper-level | Always visible in footer | Loop | Lowest visual priority on the page |
| **404** | Both | Nox "looks around, can't find it" + Lux "search" gesture | Page load | One-shot → settle to loop | Calm, not panicked — matches brand voice even when something's wrong |
| **Loading (page load / transition)** | Lux or Nox | Think loop | Route change / asset load | Loop | |
| **Empty Search** | Lux | Wait pose beside "no results" copy | Search returns nothing | Loop | |
| **Page Transitions** | Both | Brief walk-off / walk-on, 150–250ms | Route change | One-shot | Must respect reduced-motion → fallback to plain fade, no mascot movement |

---

## 7. Rive Architecture

### Files
```
lux.riv    — Lux artboard + State Machine "SM_Lux"
nox.riv    — Nox artboard + State Machine "SM_Nox"
duo.riv    — Joint artboard + State Machine "SM_Duo" (used only for the scarce together-moments:
             Splash, Login, Logout, 404, Landing Hero, Page Transitions)
```
Keeping "together" moments in a single `duo.riv` avoids having to hand-sync two independently
playing instances — the whole point of a together-moment is that it reads as one composition.

### State Machine Inputs (per character machine)
| Input | Type | Purpose |
|---|---|---|
| `stateIndex` | Number | Drives which catalogued state plays (0 = Idle, 1 = Sleep, … matching table order above) |
| `reducedMotion` | Boolean | When true, forces the artboard to the static Idle held-frame regardless of `stateIndex`, and disables looping |
| `oneShotDone` | Trigger (output) | Fired back to the host app when a one-shot animation completes, so Flutter can chain the next state (e.g. Wake → Idle) without hardcoded durations |

A single `Number` input rather than many booleans/triggers keeps the contract simple to drive
from a Dart enum (`MascotState.values.indexOf(...)`) and simple to reuse identically on the web
side.

### Internal Rig Structure (per artboard)
Separate named bone/shape groups so future animators can retarget without rebuilding: `body`,
`ear_L`, `ear_R`, `eye_L`, `eye_R`, `tail`. Every catalogued state is authored as its own
**Animation** inside the State Machine, entered/exited via `stateIndex` equality conditions.

### Naming Convention
- Files: `snake_case.riv`
- State machines: `SM_PascalCase`
- Animation/state names inside Rive: `PascalCase` matching the catalogue table exactly (`Idle`,
  `Sleep`, `Wake`, `Guide`, `Stamp`, …) so there is zero translation layer between design docs,
  Rive editor, and code.

### Reusable Flutter Component (design intent — not implemented here)
A single `MascotView` widget wraps `RiveAnimation.asset`, and a `MascotController` exposes a
narrow API (`play(MascotState state)`, `setReducedMotion(bool)`) so no screen ever talks to the
Rive SDK directly — this keeps the mascot swappable/upgradable later without touching feature
code.

### Folder Structure (proposed)
```
assets/
  mascot/
    lux.riv
    nox.riv
    duo.riv
    fallback/
      lux_idle.png     # static reduced-motion / load-failure fallback
      nox_idle.png
      duo_idle.png
```

### Web Reuse
The identical `.riv` files load via `@rive-app/canvas` (or `rive.js`) on a future marketing
site — same state-machine contract, same input names, zero duplicated authoring between
Flutter and web.

---

## 8. Performance Guide

- Cap simultaneous active State Machine instances on any single screen to **1–2**.
- Preload `.riv` assets during the Splash Screen — it's already an idle window and the natural
  place to warm the decode cache before the mascot is needed elsewhere.
- Avoid rebuilding the Rive widget on every parent rebuild; scope state-input updates narrowly
  (e.g. via a `ValueListenableBuilder` around just the controller) rather than rebuilding the
  whole widget subtree.
- Target **<150KB per `.riv` file** — a pixel-art rig with few bones and no gradient/blur layers
  should comfortably hit this, which matters most for Flutter Web's network payload.
- Pause playback when the app is backgrounded (`AppLifecycleState.paused`) and when the
  mascot's tab isn't the active `PageView` page — `main.dart`'s `WorkspaceHome` already keeps
  all five tabs alive via `PageView`, so each tab's mascot instance should pause, not just
  become invisible, when off-screen.
- No special-casing needed for Android vs iOS vs Desktop browsers beyond standard responsive
  sizing — the rig's simplicity is what keeps this uniform across targets.

---

## 9. Accessibility Guide

- **Reduced motion is load-bearing, not optional.** Respect `MediaQuery.of(context).disableAnimations`
  in Flutter and `prefers-reduced-motion` in CSS on any future web surface. When active, every
  mascot instance snaps to its static Idle held-frame and all loops/transitions are disabled —
  the mascot still appears (it's brand identity, not decoration) but frozen.
- Ship the static fallback PNGs (`assets/mascot/fallback/`) for reduced-motion contexts and as a
  graceful degrade if a `.riv` asset fails to load.
- Mark mascot widgets `Semantics(excludeSemantics: true)` by default — they're reinforcement,
  not information. For the few interactions where the mascot *echoes* a state change (burn-note
  countdown Alert, audit-chain Stamp), confirm the existing text/badge already carries that
  information independently — per the Interaction Catalogue above, it always does. The mascot
  must never become the sole carrier of anything required.
- No animation in this system exceeds ~12fps holds — well under the 3Hz strobe threshold for
  photosensitive safety by construction.
- Contrast is inherently maximal (pure black/white), satisfying WCAG without extra work.

---

## 10. Future Expansion Recommendations

- **Sealed (shelved feature):** when/if unshelved, the mutual-reveal moment — two people's
  private signals matching — is the natural home for the system's most significant joint
  animation. The **Return To Logo** state already exists for exactly this: the yin-yang visually
  reforming as confirmation of a match.
- **No color reskins**, ever — including seasonal/holiday variants. If a limited one-shot
  novelty is wanted later, keep it to a single monochrome silhouette accessory, never a repaint.
- **Merch/stickers:** each catalogued static "Idle held-frame" pose doubles as sticker-pack
  source art at zero extra design cost.
- **Additional Nox homes** as the product grows (admin actions, future subscription/paywall
  moments): apply the Scarcity rule before adding any of them — the bar is "does this improve
  comprehension," not "could this have a cat."
- **Localization-free by design** — since the whole system communicates through body language
  with no text/dialogue, it needs no rework as the product adds languages.

---

*This document defines character, behavior, and motion only. No application layout, UI,
architecture, navigation, or feature logic is proposed or implied to change.*
