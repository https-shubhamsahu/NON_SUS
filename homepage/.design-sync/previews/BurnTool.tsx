import { useEffect, useRef, type ReactNode } from "react";
import { BurnTool } from "homepage";

// NO SUS components are white-on-black; the site renders them on bg-brand-black.
const Stage = ({ children }: { children: ReactNode }) => (
  <div className="bg-brand-black p-8 text-white">{children}</div>
);

// BurnTool keeps its tab and text in internal state, so these stories drive
// the real component the way a visitor would: click a tab, type a note.
function Driven({ tab, note, children }: { tab?: string; note?: string; children: ReactNode }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const root = ref.current;
    if (!root) return;
    if (tab) {
      [...root.querySelectorAll("button")].find((b) => b.textContent?.trim() === tab)?.click();
    }
    if (note) {
      requestAnimationFrame(() => {
        const area = root.querySelector("textarea");
        if (!area) return;
        const setter = Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, "value")?.set;
        setter?.call(area, note);
        area.dispatchEvent(new Event("input", { bubbles: true }));
      });
    }
  }, [tab, note]);
  return <div ref={ref}>{children}</div>;
}

/** The hero circle as a visitor first sees it: File tab, drop zone, expiry. */
export const File = () => (
  <Stage>
    <BurnTool />
  </Stage>
);

/** Note tab with a secret typed in, Burn Note enabled. */
export const Note = () => (
  <Stage>
    <Driven tab="Note" note="gate code 4471. delete this.">
      <BurnTool />
    </Driven>
  </Stage>
);

/** Redeem tab: paste the link, then the 2-digit code. */
export const Redeem = () => (
  <Stage>
    <Driven tab="Redeem">
      <BurnTool />
    </Driven>
  </Stage>
);
