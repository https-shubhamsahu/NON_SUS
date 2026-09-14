import type { ReactNode } from "react";
import { NoSusLogo } from "homepage";

// NO SUS components are white-on-black; the site renders them on bg-brand-black.
const Stage = ({ children }: { children: ReactNode }) => (
  <div className="bg-brand-black p-8 text-white">{children}</div>
);

/** Navbar and footer size, as the site uses it. */
export const Navbar = () => (
  <Stage>
    <NoSusLogo sizeClass="text-lg md:text-xl" />
  </Stage>
);

/** The wordmark scales with its font size; the gray square is 0.21em. */
export const Sizes = () => (
  <Stage>
    <div className="flex flex-col items-start gap-4">
      <NoSusLogo sizeClass="text-lg" />
      <NoSusLogo sizeClass="text-3xl" />
      <NoSusLogo sizeClass="text-6xl" />
    </div>
  </Stage>
);

/** Centered end card. */
export const EndCard = () => (
  <Stage>
    <div className="flex flex-col items-center gap-3 px-10 py-12">
      <NoSusLogo sizeClass="text-5xl" />
      <span className="font-mono text-[11px] uppercase tracking-widest text-brand-gray-light">
        Try it at nosus.foo
      </span>
    </div>
  </Stage>
);
