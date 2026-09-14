import React from "react";
import { flushSync } from "react-dom";
import { clamp, parseScenes, warpTime, SCENES, DERIVED } from "./engine.js";

export const CompositionContext = React.createContext(null);

export function useComposition() {
  const ctx = React.useContext(CompositionContext);
  if (!ctx) throw new Error("useComposition() must be called inside a stage");
  return ctx;
}

export function Shot({ from, to, children }) {
  const c = useComposition();
  const start = +from;
  const end = to == null ? Infinity : +to;
  const on = isFinite(start) && c.T >= start && c.T < end;
  return (
    <div style={{ position: "absolute", inset: 0, visibility: on ? "visible" : "hidden" }}>
      {children}
    </div>
  );
}

const CAPTION_FADE = 0.18;
export function Captions({ items, style }) {
  const c = useComposition();
  const t = c.T;
  const list = (items || [])
    .filter((it) => it && isFinite(+it.at))
    .sort((a, b) => a.at - b.at);
  let active = null;
  let end = Infinity;
  for (let i = 0; i < list.length; i++) {
    if (t < list[i].at) break;
    active = list[i];
    end = typeof active.until === "number" && isFinite(active.until)
      ? active.until
      : (i + 1 < list.length ? list[i + 1].at : Infinity);
  }
  if (!active || t >= end) return null;
  let o = Math.min(1, (t - active.at) / CAPTION_FADE);
  if (isFinite(end)) o = Math.min(o, (end - t) / CAPTION_FADE);
  o = Math.max(0, Math.min(1, o));
  return (
    <div
      data-om-caption=""
      style={Object.assign({
        position: "absolute",
        left: "8%",
        right: "8%",
        bottom: "7%",
        textAlign: "center",
        opacity: o,
        pointerEvents: "none",
        font: "500 30px Geist, system-ui, sans-serif",
        color: "#f6f4ef",
      }, style)}
    >
      {active.text}
    </div>
  );
}

function useDerived(scenes) {
  return React.useMemo(() => {
    if (!scenes) return DERIVED;
    return parseScenes(scenes);
  }, [scenes]);
}

export function RecordStage({ width, height, scenes, bg = "#080808", children }) {
  const derived = useDerived(scenes);
  const [time, setTime] = React.useState(0);
  React.useLayoutEffect(() => {
    window.__burnSeek = (t) => {
      const next = clamp(+t, 0, derived.total);
      flushSync(() => setTime(next));
    };
    window.__burnDuration = derived.total;
    window.__burnReady = true;
    document.documentElement.setAttribute("data-burn-ready", "1");
  }, [derived.total]);

  const T = warpTime(derived, time);
  const value = React.useMemo(() => ({
    T,
    CUES: derived.table,
    time,
    duration: derived.total,
    authoredTotal: derived.authoredTotal,
    playing: false,
  }), [T, derived, time]);

  return (
    <div
      data-burn-stage="record"
      style={{
        width,
        height,
        background: bg,
        position: "relative",
        overflow: "hidden",
      }}
    >
      <CompositionContext.Provider value={value}>
        {children}
      </CompositionContext.Provider>
    </div>
  );
}

export function PreviewStage({ width, height, scenes, bg = "#080808", children }) {
  const derived = useDerived(scenes);
  const [time, setTime] = React.useState(0);
  const [playing, setPlaying] = React.useState(true);
  const lastTs = React.useRef(null);

  React.useEffect(() => {
    if (!playing) {
      lastTs.current = null;
      return;
    }
    let raf;
    const step = (ts) => {
      if (lastTs.current == null) lastTs.current = ts;
      const dt = (ts - lastTs.current) / 1000;
      lastTs.current = ts;
      setTime((t) => {
        let next = t + dt;
        if (next >= derived.total) {
          next = derived.total;
          setPlaying(false);
        }
        return next;
      });
      raf = requestAnimationFrame(step);
    };
    raf = requestAnimationFrame(step);
    return () => cancelAnimationFrame(raf);
  }, [playing, derived.total]);

  React.useEffect(() => {
    const onKey = (e) => {
      if (e.code === "Space") {
        e.preventDefault();
        setPlaying((p) => !p);
      } else if (e.code === "Home" || e.key === "0") {
        setTime(0);
        setPlaying(true);
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  const T = warpTime(derived, time);
  const value = React.useMemo(() => ({
    T,
    CUES: derived.table,
    time,
    duration: derived.total,
    authoredTotal: derived.authoredTotal,
    playing,
  }), [T, derived, time, playing]);

  const pct = derived.total > 0 ? (time / derived.total) * 100 : 0;
  const fmt = (t) => {
    const s = Math.max(0, t);
    const m = Math.floor(s / 60);
    const sec = Math.floor(s % 60);
    const cs = Math.floor((s * 100) % 100);
    return `${m}:${String(sec).padStart(2, "0")}.${String(cs).padStart(2, "0")}`;
  };

  return (
    <div style={{
      position: "absolute",
      inset: 0,
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      background: "#0a0a0a",
    }}>
      <div style={{
        flex: 1,
        width: "100%",
        minHeight: 0,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        overflow: "hidden",
      }}>
        <div
          data-burn-stage="preview"
          style={{
            width,
            height,
            background: bg,
            position: "relative",
            overflow: "hidden",
            transform: `scale(${Math.min(
              (typeof window !== "undefined" ? window.innerWidth : width) / width,
              ((typeof window !== "undefined" ? window.innerHeight : height) - 52) / height,
            )})`,
            transformOrigin: "center",
            flexShrink: 0,
          }}
        >
          <CompositionContext.Provider value={value}>
            {children}
          </CompositionContext.Provider>
        </div>
      </div>
      <div style={{
        display: "flex",
        alignItems: "center",
        gap: 10,
        padding: "8px 14px",
        width: "min(720px, 100%)",
        color: "#f6f4ef",
        fontFamily: "Geist, system-ui, sans-serif",
        fontSize: 12,
      }}>
        <button
          type="button"
          onClick={() => setPlaying((p) => !p)}
          style={btnStyle}
        >
          {playing ? "Pause" : "Play"}
        </button>
        <button
          type="button"
          onClick={() => { setTime(0); setPlaying(true); }}
          style={btnStyle}
        >
          Restart
        </button>
        <span style={{ fontVariantNumeric: "tabular-nums", width: 64, textAlign: "right" }}>{fmt(time)}</span>
        <input
          type="range"
          min={0}
          max={derived.total}
          step={0.01}
          value={time}
          onChange={(e) => { setPlaying(false); setTime(+e.target.value); }}
          style={{ flex: 1 }}
        />
        <span style={{ fontVariantNumeric: "tabular-nums", width: 64, opacity: 0.55 }}>{fmt(derived.total)}</span>
        <span style={{ opacity: 0.4, width: 36 }}>{Math.round(pct)}%</span>
      </div>
    </div>
  );
}

const btnStyle = {
  background: "rgba(255,255,255,0.08)",
  border: "1px solid rgba(255,255,255,0.12)",
  color: "#f6f4ef",
  borderRadius: 5,
  padding: "4px 10px",
  cursor: "pointer",
};

export { SCENES };
