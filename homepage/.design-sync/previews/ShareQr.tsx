import type { ReactNode } from "react";
import { ShareQr } from "homepage";

// NO SUS components are white-on-black; the site renders them on bg-brand-black.
const Stage = ({ children }: { children: ReactNode }) => (
  <div className="bg-brand-black p-8 text-white">{children}</div>
);

const LINK =
  "https://app.nosus.foo/#/burn/5f0c2a9e-7d41-4b8a-9a3e-2c61d8f4b0a7?k=9c1e4f7a2b8d3c6e5f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0b1c2d3e4f5a6&v=0f1e2d3c4b5a69788796a5b4c3d2e1f0";

/** As BurnTool shows it on READY TO SHARE: 108px inside a white frame. */
export const InBurnTool = () => (
  <Stage>
    <div className="inline-flex p-1.5 bg-white rounded-lg">
      <ShareQr value={LINK} size={108} />
    </div>
  </Stage>
);

/** Larger, for a poster or an ad frame. */
export const Large = () => (
  <Stage>
    <div className="inline-flex p-2 bg-white rounded-lg">
      <ShareQr value={LINK} size={200} />
    </div>
  </Stage>
);
