# Lux & Nox — AI Image-Gen Prompt Library

Draft-only. Every image this produces is a **starting point for a designer to clean up and
rig in Rive** — not a final asset. Goal is consistent pose/silhouette drafts the designer can
trace/vectorize, not production-ready art.

---

## 0. Tool choice (matters more than the prompt wording)

General-purpose models (Midjourney, DALL·E, default Stable Diffusion) fight you on true 1-bit
pixel art — they add anti-aliasing and soft edges no matter how hard you ask. Prefer a model
actually built for pixel-art/game-sprite generation:

1. **PixelLab.ai** (recommended) — purpose-built for game sprites, has an explicit
   "character consistency across poses/rotations" feature, which is exactly this job: one
   character, many poses.
2. **Retro Diffusion** (retrodiffusion.ai) — strong hard-pixel/low-color-count output, Aseprite
   plugin if the designer works there.
3. **Leonardo.Ai** — has a PixelArt-tuned model, more accessible/free-tier.
4. Fallback: Midjourney/DALL·E + manual posterize-to-2-colors and pixelate/downsample in any
   image editor afterward (Photoshop "Mosaic" + "Threshold", or GIMP equivalent) to force it
   back to true 1-bit.

**If the tool supports an image reference / style reference** (Midjourney `--sref`, PixelLab's
reference upload, image-to-image in SD), feed it the source mark
(`assets/icon/LuxandNox.png`) as the reference every time — this matters far more for
consistency than any wording below.

---

## 1. Master style block

Prepend this to **every single prompt** below, verbatim:

> Pixel-art silhouette illustration, strictly 1-bit black-and-white (pure black on pure white
> only, no gray, no gradients, no anti-aliasing), large chunky square pixels forming visible
> jagged "staircase" edges like a coarse retro 8-bit game sprite — NOT a smooth vector cutout.
> A single solid-black minimalist cat silhouette. No internal linework, no fur texture, no
> shading, no outline stroke around the black shape — only one small square eye mark and one
> small triangular ear notch as the sole interior details. No whiskers, no nose. Centered on a
> plain flat white square canvas, full body, calm and minimal, matching the aesthetic of a
> classic yin-yang symbol redrawn as pixel art.

**Negative prompt** (if the tool supports one):
> color, gradient, anti-aliasing, smooth vector curves, outline stroke, gray tones, shading,
> blur, realistic fur, 3d render, glossy, text, watermark, second character, background
> scenery, multiple colors, soft edges

**Consistency rules for every generation:**
- Same square canvas size every time (pick one, e.g. 1024×1024) so a designer can align frames.
- Same camera framing every time (side-on or 3/4 view — pick one and stick to it across all poses).
- Generate 4–6 seeds per pose, keep the cleanest silhouette, discard anything with stray
  anti-aliased pixels or broken proportions.
- These prompts describe **one shared cat body** — Lux and Nox are the same anatomy, mirrored.
  Generate each pose once, then the designer duplicates it for both characters (one kept
  black/solid, one inverted to white-fill-on-black-outline or recolored) and adjusts posture per
  the personality notes in brackets below.

---

## 2. Per-pose prompts

Append the pose line to the master style block above. `[Both]` poses are shared body/anatomy;
`[Lux]`/`[Nox]` notes describe the personality lean the designer should apply to that
character's version (per docs/design/MASCOT_MOTION_BIBLE.md).

| Pose | Prompt to append | Personality note |
|---|---|---|
| **Idle** `[Both]` | "the cat sitting upright, calm resting pose, tail curled loosely at its side, ears neutral" | Lux: slightly more open/relaxed posture. Nox: lower, more compact, tighter tail curl. |
| **Sleep** `[Both]` | "the cat curled into a tight low ball, head tucked down, tail wrapped fully around its body, ears flattened back" | Nox curls tighter/lower than Lux. |
| **Wake** `[Both]` | "the cat mid-stretch just after waking, head lifting up, front paws still low, ears rising from flat to upright, eyes just opening" | |
| **Walk** `[Both]` | "the cat mid-stride walking pose, one front paw forward and one back paw forward (opposite pairs), tail extended out for balance, side profile view" | Nox: lower, more deliberate stride. Lux: slightly bouncier stride. |
| **Look Around** `[Lux]` | "the cat sitting upright with its head turned sharply to one side as if looking at something off-frame, one ear rotated toward the turn, curious posture" | |
| **Think** `[Lux]` | "the cat sitting with its head tilted down and slightly forward, one ear rotated back, tail tip curled thoughtfully, contemplative pose" | |
| **Observe** `[Both]` | "the cat sitting very still, body angled slightly forward, both ears pointed fully forward, wide alert eye, watching intently" | Nox: lower/more grounded stance than Lux's version. |
| **Guide** `[Lux]` | "the cat leaning forward with one front paw extended outward as if gesturing or pointing, head tilted warmly, inviting posture" | |
| **Celebrate** `[Lux]` | "the cat mid small hop with its back slightly arched, both ears perked fully upright, tail flicked upward, joyful brief motion pose" | |
| **Wait** `[Lux]` | "the cat sitting upright with its chin lifted slightly, eyes at half-close as if patiently waiting, very still posture" | |
| **Sit** `[Both]` | "the cat in a simple grounded seated base pose, front paws together, tail resting alongside its body, neutral calm expression" | This is the base/rest pose other poses return to — keep it extremely simple. |
| **Stretch** `[Both]` | "the cat mid-stretch, body elongated forward low to the ground, back arched upward behind it, front paws extended far forward" | Nox: shallower/more restrained arch than Lux. |
| **Protect** `[Nox]` | "the cat in a low squared defensive stance, chest forward, both ears flattened slightly forward (alert not aggressive), tail low and still, guarding posture" | |
| **Approve** `[Nox]` | "the cat giving a single small forward nod of its head, calm neutral body, eyes briefly soft-closing, quiet confirming gesture" | |
| **Verify** `[Nox]` | "the cat with its head lowered slightly and turned as if scanning left to right, one ear rotated as if listening closely, focused posture" | |
| **Guard** `[Nox]` | "the cat in a squared grounded stance facing forward, chest out slightly, both ears forward, low still tail, standing watch" | |
| **Alert** `[Nox]` | "the cat with sharpened posture, weight shifted forward, both ears snapped fully forward, wide fixed eyes, tail stiff with only the tip twitching — composed and firm, NOT scared or cowering" | Critical: never frightened-looking — a guard bracing, not a startled animal. |
| **Stamp** `[Nox]` | "the cat mid motion pressing one front paw decisively downward as if stamping or sealing something, head level, neutral firm expression" | |
| **Return To Logo** `[Both]` | "the cat folding inward into the exact circular yin-yang silhouette pose from the reference image, transitional half-formed shape between a full cat and the interlocking circle mark" | Hardest one — likely needs the designer to hand-tween this in Rive rather than generate directly; use the reference image as the end-of-animation key pose instead. |

---

## 3. Workflow after generation

1. Generate all `[Both]` poses once (shared body), then `[Lux]`-only and `[Nox]`-only poses.
2. Pick the cleanest seed per pose — reject anything with broken silhouette or stray pixels.
3. Hand the batch to the designer with `docs/design/MASCOT_MOTION_BIBLE.md` — the animation
   catalogue there (body/ears/eyes/tail/breathing per state) is the spec these drafts should be
   cleaned up against, not just vibes.
4. Designer vectorizes/traces each draft into the actual rig (bones for `body`, `ear_L`, `ear_R`,
   `eye_L`, `eye_R`, `tail` — see the Rive Architecture section of the bible), builds the
   in-between frames Rive needs for smooth playback, and wires the `SM_Lux` / `SM_Nox` state
   machines with the `stateIndex` / `reducedMotion` inputs already expected by
   `lib/core/mascot/mascot_controller.dart`.
5. Export as `lux.riv`, `nox.riv`, `duo.riv` into `assets/mascot/` — the app picks them up with
   no code changes (see `assets/mascot/README.md`).
