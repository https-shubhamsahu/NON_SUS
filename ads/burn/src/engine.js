/* Minimal composition engine for the Burn ad recorder/previewer.
   Motion helpers match vendor/animations-v3.jsx so choreography in piece.jsx
   stays keyed to authored time T. */

export const Easing = {
  linear: (t) => t,
  easeInQuad: (t) => t * t,
  easeOutQuad: (t) => t * (2 - t),
  easeInOutQuad: (t) => (t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t),
  easeInCubic: (t) => t * t * t,
  easeOutCubic: (t) => (--t) * t * t + 1,
  easeInOutCubic: (t) => (t < 0.5 ? 4 * t * t * t : (t - 1) * (2 * t - 2) * (2 * t - 2) + 1),
  easeInQuart: (t) => t * t * t * t,
  easeOutQuart: (t) => 1 - (--t) * t * t * t,
  easeInOutQuart: (t) => (t < 0.5 ? 8 * t * t * t * t : 1 - 8 * (--t) * t * t * t),
};

export const clamp = (v, min, max) => Math.max(min, Math.min(max, v));

export function interpolate(input, output, ease = Easing.linear) {
  return (t) => {
    if (t <= input[0]) return output[0];
    if (t >= input[input.length - 1]) return output[output.length - 1];
    for (let i = 0; i < input.length - 1; i++) {
      if (t >= input[i] && t <= input[i + 1]) {
        const span = input[i + 1] - input[i];
        const local = span === 0 ? 0 : (t - input[i]) / span;
        const easeFn = Array.isArray(ease) ? (ease[i] || Easing.linear) : ease;
        return output[i] + (output[i + 1] - output[i]) * easeFn(local);
      }
    }
    return output[output.length - 1];
  };
}

export function animate({ from = 0, to = 1, start = 0, end = 1, ease = Easing.easeInOutCubic }) {
  return (t) => {
    if (t <= start) return from;
    if (t >= end) return to;
    const local = (t - start) / (end - start);
    return from + (to - from) * ease(local);
  };
}

export function parseScenes(raw) {
  const parsed = typeof raw === "string" ? JSON.parse(raw) : raw;
  const sections = [];
  const table = Object.create(null);
  let playStart = 0;
  let authStart = 0;
  for (const s of parsed) {
    const nat = typeof s.nat === "number" && isFinite(s.nat) && s.nat > 0 ? s.nat : s.dur;
    sections.push({ name: s.name, playStart, dur: s.dur, authStart, nat });
    if (!Object.prototype.hasOwnProperty.call(table, s.name)) {
      table[s.name] = Math.round(authStart * 1000) / 1000;
    }
    playStart += s.dur;
    authStart += nat;
  }
  return {
    sections,
    table,
    total: Math.round(playStart * 1000) / 1000,
    authoredTotal: Math.round(authStart * 1000) / 1000,
  };
}

export function warpTime(derived, t) {
  const ss = derived.sections;
  if (!ss.length) return 0;
  let idx = ss.length - 1;
  for (let i = 0; i < ss.length; i++) {
    if (t < ss[i].playStart + ss[i].dur) {
      idx = i;
      break;
    }
  }
  const s = ss[idx];
  const local = Math.min(Math.max(t - s.playStart, 0), s.dur);
  const T = s.authStart + (s.dur > 0 ? local * (s.nat / s.dur) : 0);
  return Math.min(T, derived.authoredTotal);
}

export const SCENES = [
  { name: "Type", dur: 3, desc: "A cursor types the note in Geist Mono on black." },
  { name: "Reveal", dur: 3, desc: "The camera pulls back to the Burn circle and the BURN NOTE pill is pressed." },
  { name: "Encrypt", dur: 4, desc: "The circle clears; a dashed ring spins around a lock while it encrypts." },
  { name: "Ready", dur: 5, desc: "The circle morphs into the ready card with the code, the QR and Copy Link." },
  { name: "Open", dur: 6, desc: "The link travels to a phone; the note shows once, then erases." },
  { name: "Gone", dur: 3, desc: "The same link is tapped again and nothing opens." },
  { name: "File", dur: 3, desc: "Hard cut to the File tab; a file drops in and is sealed." },
  { name: "End", dur: 3, desc: "End card with the NO SUS wordmark." },
];

export const DERIVED = parseScenes(SCENES);
export const DURATION = DERIVED.total;
