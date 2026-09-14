/* NO SUS Burn — 30s motion ad. Continuous composition; all choreography keyed to T.
   Ported from vendor/burn-ad.jsx so the recorded video matches the authored beats. */
import React from "react";
import { Easing, animate, interpolate, clamp } from "./engine.js";
import { useComposition, Shot, Captions } from "./stage.jsx";

const SANS = 'var(--font-sans), Geist, system-ui, sans-serif';
const MONO = 'var(--font-mono), "Geist Mono", ui-monospace, monospace';
const BLACK = '#080808';
const GRAY = '#888888';
export const NOTE = 'gate code 4471. delete this.';
export const LINK = 'https://app.nosus.foo/#/burn/7f3a9c2e';
export const LINK_SHORT = 'app.nosus.foo/#/burn/7f3a9c2e';

const MOTION = {
  enter: (from, to, start, dur) => animate({ from, to, start, end: start + (dur || 0.22), ease: Easing.easeOutCubic }),
  draw: (start, dur) => animate({ from: 0, to: 1, start, end: start + (dur || 0.4), ease: Easing.easeOutQuart }),
  pop: (start, dur) => animate({ from: 0, to: 1, start, end: start + (dur || 0.18), ease: Easing.easeOutQuad }),
};

const ico = (s) => ({ width: s, height: s, viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', strokeWidth: 2, strokeLinecap: 'round', strokeLinejoin: 'round', style: { display: 'block' } });
const Lock = ({ s = 16 }) => (
  <svg {...ico(s)}><rect x="3" y="11" width="18" height="11" rx="2" /><path d="M7 11V7a5 5 0 0 1 10 0v4" /></svg>
);
const FileUp = ({ s = 28 }) => (
  <svg {...ico(s)}><path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z" /><path d="M14 2v5h6" /><path d="M12 18v-6" /><path d="m9 15 3-3 3 3" /></svg>
);
const Copy = ({ s = 12 }) => (
  <svg {...ico(s)}><rect x="9" y="9" width="13" height="13" rx="2" /><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" /></svg>
);
const Check = ({ s = 12 }) => (<svg {...ico(s)}><path d="M20 6 9 17l-5-5" /></svg>);
const RotateCcw = ({ s = 12 }) => (
  <svg {...ico(s)}><path d="M3 12a9 9 0 1 0 9-9 9 9 0 0 0-6.36 2.64L3 8" /><path d="M3 3v5h5" /></svg>
);
const Cursor = ({ s = 22, o = 1 }) => (
  <svg width={s} height={s * 1.32} viewBox="0 0 17 22" style={{ display: 'block', opacity: o }}>
    <path d="M1 1 L1 17.5 L5.4 13.6 L8.3 20.6 L11.2 19.3 L8.3 12.5 L14 12.1 Z" fill="#fff" stroke="#080808" strokeWidth="1" />
  </svg>
);

const LABEL = { font: `700 10px ${SANS}`, letterSpacing: '0.16em', textTransform: 'uppercase' };
const TINY = { font: `700 9px ${SANS}`, letterSpacing: '0.14em', textTransform: 'uppercase', whiteSpace: 'nowrap' };
const center = { position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' };

function NoSusLogo({ size = 60 }) {
  return (
    <span
      data-nosus-logo=""
      style={{
        font: `900 ${size}px ${SANS}`,
        letterSpacing: '-0.045em',
        color: '#fff',
        display: 'inline-flex',
        alignItems: 'baseline',
        whiteSpace: 'nowrap',
        userSelect: 'none',
      }}
    >
      NO SUS
      <span
        style={{
          display: 'inline-block',
          width: '0.21em',
          height: '0.21em',
          background: '#808080',
          marginLeft: '0.08em',
          marginBottom: '0.02em',
        }}
      />
    </span>
  );
}

function Tabs({ active, chrome = 1 }) {
  const tab = (name) => {
    const on = active === name;
    return (
      <div key={name} style={{
        padding: '6px 16px', ...TINY, letterSpacing: '0.1em',
        background: on ? '#fff' : 'transparent', color: on ? '#000' : GRAY,
      }}>{name}</div>
    );
  };
  return (
    <div style={{
      display: 'flex', border: `1px solid rgba(255,255,255,${0.2 * chrome})`, background: BLACK,
      borderRadius: 999, overflow: 'hidden', marginBottom: 20, opacity: chrome,
    }}>{['Note', 'File', 'Redeem'].map(tab)}</div>
  );
}

function NoteIdle({ T, C }) {
  const chrome = MOTION.enter(0, 1, C.Reveal - 0.1, 0.55)(T);
  const n = Math.round(animate({ from: 0, to: NOTE.length, start: 0.45, end: 2.35, ease: Easing.linear })(T));
  const typed = NOTE.slice(0, n);
  const done = n >= NOTE.length;
  const caretOn = !done || (T * 2) % 1 < 0.55;
  const press = clamp((T - (C.Reveal + 1.95)) / 0.12, 0, 1) * clamp(((C.Reveal + 2.35) - T) / 0.12, 0, 1);
  const armed = n > 0;
  return (
    <div style={center}>
      <Tabs active="Note" chrome={chrome} />
      <div style={{
        width: 374, height: 120, background: 'rgba(8,8,8,0.5)', borderRadius: 12, padding: 14,
        border: `1px solid rgba(255,255,255,${0.1 * chrome})`,
        display: 'flex', alignItems: 'flex-start', justifyContent: 'center',
      }}>
        <div data-typed-note="" style={{ font: `400 10px ${MONO}`, lineHeight: 1.5, color: '#fff', textAlign: 'center' }}>
          {typed}<span style={{
            display: 'inline-block', width: 1, height: '1.1em', background: '#fff',
            verticalAlign: '-0.18em', marginLeft: 1, opacity: caretOn ? 1 : 0,
          }} />
        </div>
      </div>
      <div style={{
        display: 'flex', justifyContent: 'space-between', width: 352, marginTop: 12,
        font: `400 8px ${MONO}`, color: GRAY, opacity: chrome,
      }}>
        <span>{n}/500</span>
        <span style={{ border: '1px solid rgba(255,255,255,0.1)', borderRadius: 3, padding: '1px 5px', color: '#fff', whiteSpace: 'nowrap' }}>24 HOURS</span>
      </div>
      <div data-burn-note-btn="" style={{
        marginTop: 20, padding: '10px 24px', ...TINY, letterSpacing: '0.16em', borderRadius: 999,
        border: `1px solid ${armed ? '#fff' : 'rgba(255,255,255,0.1)'}`,
        background: armed ? '#fff' : 'transparent', color: armed ? '#000' : 'rgba(255,255,255,0.3)',
        opacity: chrome, transform: `scale(${1 - 0.05 * press})`,
      }}>Burn Note</div>
    </div>
  );
}

function Working({ T, C, from }) {
  const label = T < from + 0.7 ? 'ENCRYPTING IN BROWSER…' : T < from + 1.4 ? 'UPLOADING CIPHERTEXT…' : 'SEALING…';
  const single = from === C.Encrypt;
  const pulse = 0.55 + 0.45 * (0.5 + 0.5 * Math.sin(T * 4.2));
  const inn = MOTION.pop(from, 0.25)(T);
  return (
    <div data-working="" style={{ ...center, gap: 16, opacity: inn, transform: `scale(${0.94 + 0.06 * inn})` }}>
      <div style={{ position: 'relative', width: 64, height: 64 }}>
        <div style={{
          position: 'absolute', inset: 0, border: '2px dashed #fff', borderRadius: '50%',
          transform: `rotate(${T * 260}deg)`,
        }} />
        <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff' }}>
          <Lock s={20} />
        </div>
      </div>
      <div data-working-label="" style={{
        font: `400 10px ${MONO}`, letterSpacing: '0.16em', color: GRAY, textTransform: 'uppercase',
        maxWidth: 200, textAlign: 'center', opacity: pulse,
      }}>{single ? 'ENCRYPTING IN BROWSER…' : label}</div>
    </div>
  );
}

function DoneCard({ T, C }) {
  const R = C.Ready;
  const head = MOTION.pop(R + 0.2, 0.22)(T);
  const lab = MOTION.pop(R + 0.55, 0.2)(T);
  const num = MOTION.pop(R + 0.75, 0.24)(T);
  const qr = MOTION.draw(R + 1.15, 0.55)(T);
  const pill = MOTION.pop(R + 1.8, 0.22)(T);
  const again = MOTION.pop(R + 2.2, 0.22)(T);
  const flip = clamp((T - (R + 3.1)) / 0.22, 0, 1);
  const copied = T >= R + 3.21;
  return (
    <div data-done-card="" style={{ ...center, gap: 8, padding: '0 12px' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, color: '#fff', opacity: head, transform: `translateY(${(1 - head) * -8}px)` }}>
        <Lock s={16} />
        <span style={{ ...LABEL, letterSpacing: '0.18em' }}>Ready to share</span>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', marginTop: 4 }}>
        <span style={{ font: `700 9px ${SANS}`, letterSpacing: '0.28em', textTransform: 'uppercase', color: GRAY, opacity: lab }}>Their code</span>
        <span data-pair-code="" style={{
          font: `900 60px ${SANS}`, lineHeight: 1, letterSpacing: '0.18em', color: '#fff',
          fontVariantNumeric: 'tabular-nums', opacity: num, transform: `scale(${0.9 + 0.1 * num})`, marginTop: 2, marginRight: '-0.18em',
        }}>77</span>
        <span style={{ font: `400 8px ${SANS}`, color: GRAY, marginTop: 4, opacity: lab }}>Tell them these digits.</span>
      </div>
      <div style={{ padding: 6, background: '#fff', borderRadius: 8, marginTop: 4, opacity: qr, clipPath: `inset(0 0 ${(1 - qr) * 100}% 0)`, transform: `scale(${0.94 + 0.06 * qr})` }}>
        <div style={{ width: 108, height: 108 }}>
          <img src="assets/qr.png" width={108} height={108} alt="" style={{ display: 'block', borderRadius: 6, imageRendering: 'pixelated' }} />
        </div>
      </div>
      <div data-copy-link="" style={{
        marginTop: 6, background: '#fff', color: '#000', padding: '8px 24px', borderRadius: 999,
        display: 'flex', alignItems: 'center', gap: 8, ...TINY, letterSpacing: '0.16em',
        opacity: pill, transform: `rotateX(${Math.sin(flip * Math.PI) * 88}deg) scale(${0.96 + 0.04 * pill})`,
      }}>
        {copied ? <Check /> : <Copy />}{copied ? 'Copied' : 'Copy Link'}
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, ...TINY, letterSpacing: '0.16em', color: GRAY, marginTop: 8, opacity: again }}>
        <RotateCcw />Burn another
      </div>
    </div>
  );
}

function FileIdle({ T, C }) {
  const F = C.File;
  const inn = MOTION.pop(F + 0.02, 0.2)(T);
  const drop = MOTION.enter(0, 1, F + 0.6, 0.32)(T);
  const held = T >= F + 0.7;
  return (
    <div data-file-idle="" style={{ ...center, opacity: inn }}>
      <Tabs active="File" />
      <div style={{
        width: 374, height: 140, borderRadius: 16, border: `2px dashed rgba(255,255,255,${0.2 + 0.8 * drop})`,
        background: drop > 0.4 ? 'rgba(255,255,255,0.05)' : 'transparent',
        display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
        position: 'relative', overflow: 'hidden',
      }}>
        <div style={{ color: '#fff', marginBottom: 8, opacity: 1 - drop }}><FileUp s={28} /></div>
        <div style={{ font: `700 9px ${MONO}`, color: '#fff', textTransform: 'uppercase', opacity: 1 - drop }}>CLICK OR DRAG FILE HERE</div>
        <div style={{ font: `400 7px ${MONO}`, color: GRAY, textTransform: 'uppercase', marginTop: 6, opacity: 1 - drop }}>Up to 25MB</div>
        <div style={{
          position: 'absolute', display: 'flex', alignItems: 'center', gap: 8,
          border: '1px solid rgba(255,255,255,0.2)', borderRadius: 8, padding: '8px 12px', background: BLACK,
          transform: `translateY(${(1 - drop) * -130}px)`, opacity: held ? 1 : drop,
        }}>
          <span style={{ color: '#fff' }}><FileUp s={16} /></span>
          <span style={{ font: `400 9px ${MONO}`, color: '#fff' }}>handoff.pdf</span>
        </div>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, marginTop: 16 }}>
        <span style={{ font: `400 7.5px ${MONO}`, color: GRAY, letterSpacing: '0.08em', textTransform: 'uppercase', whiteSpace: 'nowrap' }}>Expires in:</span>
        {['1 HOUR', '24 HOURS', '7 DAYS'].map((c) => {
          const on = c === '24 HOURS';
          return (
            <span key={c} style={{
              padding: '2px 8px', font: `700 8px ${SANS}`, letterSpacing: '0.16em', borderRadius: 3,
              border: `1px solid ${on ? '#fff' : 'rgba(255,255,255,0.1)'}`,
              background: on ? 'rgba(255,255,255,0.1)' : 'transparent', color: on ? '#fff' : GRAY, whiteSpace: 'nowrap',
            }}>{c}</span>
          );
        })}
      </div>
    </div>
  );
}

function PhoneBeat({ T, C, L }) {
  const O = C.Open;
  const travel = MOTION.enter(0, 1, O + 0.15, 1.1)(T);
  const landed = T >= O + 1.25;
  const reveal = MOTION.pop(O + 1.45, 0.28)(T);
  const eraseFrom = O + 3.7, eraseTo = O + 5.15;
  const kept = Math.round(animate({ from: NOTE.length, to: 0, start: eraseFrom, end: eraseTo, ease: Easing.linear })(T));
  const phoneIn = MOTION.enter(0, 1, O + 0.05, 0.3)(T);
  return (
    <div data-phone-beat="" style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <div style={{ transform: `scale(${L.phone * (1 + 0.03 * clamp((T - O) / 6, 0, 1))})`, position: 'relative' }}>
        <div style={{
          width: 300, height: 600, borderRadius: 44, border: '4px solid rgba(255,255,255,0.8)',
          background: BLACK, display: 'flex', alignItems: 'center', justifyContent: 'center',
          padding: 32, opacity: phoneIn, transform: `scale(${0.97 + 0.03 * phoneIn})`,
        }}>
          <div data-phone-note="" style={{
            font: `400 ${L.note}px ${MONO}`, lineHeight: 1.7, color: '#fff', textAlign: 'center', textWrap: 'balance',
            opacity: landed ? reveal : 0,
          }}>{NOTE.slice(0, kept)}</div>
        </div>
        <div data-travel-link="" style={{
          position: 'absolute', left: '50%', top: -L.travel * 3.4,
          transform: `translate(-50%, 0) translateX(${(1 - travel) * -820}px)`,
          opacity: landed ? clamp(1 - (T - (O + 1.25)) / 0.25, 0, 1) : 1,
          font: `400 ${L.travel}px ${MONO}`, color: GRAY, whiteSpace: 'nowrap',
        }}>{LINK_SHORT}</div>
      </div>
    </div>
  );
}

function GoneBeat({ T, C, L }) {
  const G = C.Gone;
  const inn = MOTION.pop(G + 0.05, 0.2)(T);
  const tap = clamp((T - (G + 0.85)) / 0.35, 0, 1);
  const cur = MOTION.enter(0, 1, G + 0.25, 0.6)(T);
  const fade = clamp(1 - (T - (G + 1.35)) / 0.8, 0, 1);
  return (
    <div data-gone-beat="" style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <div style={{ position: 'relative', transform: `scale(${1 + 0.035 * clamp((T - G) / 3, 0, 1)})` }}>
        <div data-gone-link="" style={{
          font: `400 ${L.link}px ${MONO}`, color: GRAY, whiteSpace: 'nowrap',
          opacity: inn * fade, textDecoration: 'underline', textDecorationColor: 'rgba(136,136,136,0.4)', textUnderlineOffset: 8,
        }}>{LINK_SHORT}</div>
        <div style={{
          position: 'absolute', left: '50%', top: '50%', width: 18, height: 18, marginLeft: -9, marginTop: -9,
          border: '2px solid #fff', borderRadius: '50%',
          transform: `scale(${0.4 + tap * 3.2})`, opacity: (1 - tap) * 0.9,
        }} />
        <div style={{ position: 'absolute', left: '50%', top: '100%', marginTop: 6, transform: `translateY(${(1 - cur) * 70}px)`, opacity: cur * fade }}>
          <Cursor s={L.cursor} />
        </div>
      </div>
    </div>
  );
}

function EndCard({ T, C, L, total }) {
  const E = C.End;
  const logo = MOTION.pop(E + 0.15, 0.3)(T);
  const line = MOTION.pop(E + 0.7, 0.3)(T);
  const out = clamp((total - 0.1 - T) / 0.45, 0, 1);
  return (
    <div data-end-card="" style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', opacity: out }}>
      <div style={{ transform: `scale(${L.end})`, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 18 }}>
        <div style={{ opacity: logo, transform: `translateY(${(1 - logo) * 10}px)`, whiteSpace: 'nowrap' }}>
          <NoSusLogo size={60} />
        </div>
        <div data-end-url="" style={{
          font: `400 13px ${MONO}`, letterSpacing: '0.22em', textTransform: 'uppercase', color: GRAY,
          opacity: line, whiteSpace: 'nowrap',
        }}>Try it at nosus.foo</div>
      </div>
    </div>
  );
}

export function layoutFor(width, height) {
  const vert = height > width;
  return vert
    ? { base: 2.0, z1: 5.6, phone: 2.05, note: 14, travel: 16, end: 2.6, link: 40, cursor: 30, super: 62, superMax: '82%', superLeft: '8%', superRight: '8%', superAlign: 'center', superBottom: '9%', worldTop: '43%' }
    : { base: 1.35, z1: 4.6, phone: 1.25, note: 17, travel: 13, end: 1.9, link: 34, cursor: 26, super: 54, superMax: '62%', superLeft: '6%', superRight: '6%', superAlign: 'center', superBottom: '9%', worldTop: '50%' };
}

export function Piece({ L, supers = true }) {
  const { T, CUES: C, authoredTotal } = useComposition();
  const rev = MOTION.enter(0, 1, C.Reveal - 0.05, 0.9)(T);
  const drift = T >= C.File
    ? animate({ from: 0, to: 0.055, start: C.File, end: C.End, ease: Easing.linear })(T)
    : animate({ from: 0, to: 0.055, start: C.Encrypt, end: C.Open, ease: Easing.linear })(T);
  const s = (L.z1 + (L.base - L.z1) * rev) * (1 + drift);
  const ty = 54 * (1 - rev);

  const cardR = T >= C.File ? 220 : interpolate([C.Ready, C.Ready + 0.45], [220, 56], Easing.easeOutCubic)(T);
  const showWorld = (T < C.Open) || (T >= C.File && T < C.End);

  const pressCursor = MOTION.enter(0, 1, C.Reveal + 0.85, 1.0)(T);
  const cursorGone = clamp(1 - (T - (C.Reveal + 2.5)) / 0.3, 0, 1);

  return (
    <div data-screen-label={`t=${Math.floor(T)}s`} style={{ position: 'absolute', inset: 0, background: BLACK, overflow: 'hidden' }}>
      <div style={{
        position: 'absolute', left: '50%', top: L.worldTop, width: 440, height: 440,
        marginLeft: -220, marginTop: -220, transformOrigin: 'center',
        transform: `scale(${s}) translate(0px, ${ty}px)`,
        border: `4px solid rgba(255,255,255,${0.8 * rev})`, background: 'rgba(8,8,8,0.95)',
        borderRadius: cardR, boxShadow: `8px 8px 0px 0px rgba(255,255,255,${0.05 * rev})`,
        visibility: showWorld ? 'visible' : 'hidden',
      }}>
        <Shot from={0} to={C.Encrypt}><NoteIdle T={T} C={C} /></Shot>
        <Shot from={C.Encrypt} to={C.Ready}><Working T={T} C={C} from={C.Encrypt} /></Shot>
        <Shot from={C.Ready} to={C.Open}><DoneCard T={T} C={C} /></Shot>
        <Shot from={C.File} to={C.File + 1.55}><FileIdle T={T} C={C} /></Shot>
        <Shot from={C.File + 1.55} to={C.End}><Working T={T} C={C} from={C.File + 1.55} /></Shot>
        <div style={{
          position: 'absolute', left: interpolate([0, 1], [246, 232])(pressCursor),
          top: interpolate([0, 1], [196, 328])(pressCursor),
          opacity: (T >= C.Reveal + 0.8 ? 1 : 0) * cursorGone, pointerEvents: 'none',
        }}>
          <Cursor s={16} />
        </div>
      </div>

      <Shot from={C.Open} to={C.Gone}><PhoneBeat T={T} C={C} L={L} /></Shot>
      <Shot from={C.Gone} to={C.File}><GoneBeat T={T} C={C} L={L} /></Shot>
      <Shot from={C.End} to={authoredTotal + 1}><EndCard T={T} C={C} L={L} total={authoredTotal} /></Shot>

      {supers && (
        <Captions
          items={[
            { at: C.Encrypt + 0.55, until: C.Encrypt + 3.5, text: 'Encrypts in your browser.' },
            { at: C.Ready + 0.9, until: C.Ready + 4.5, text: 'The key lives in the link.' },
            { at: C.Open + 0.5, until: C.Open + 5.6, text: "One open. Then it's gone." },
            { at: C.File + 0.4, until: C.File + 2.9, text: 'Notes or one file. No account.' },
          ]}
          style={{
            left: L.superLeft, right: L.superRight, bottom: L.superBottom, textAlign: L.superAlign,
            margin: L.superAlign === 'center' ? '0 auto' : undefined,
            maxWidth: L.superMax, font: `900 ${L.super}px ${SANS}`, letterSpacing: '-0.03em',
            lineHeight: 1.05, color: '#fff', textShadow: 'none',
          }}
        />
      )}
    </div>
  );
}
