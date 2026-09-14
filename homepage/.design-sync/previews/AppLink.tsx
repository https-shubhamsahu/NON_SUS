import type { ReactNode } from "react";
import { AppLink } from "homepage";
import { ArrowUpRight } from "lucide-react";

// NO SUS components are white-on-black; the site renders them on bg-brand-black.
const Stage = ({ children }: { children: ReactNode }) => (
  <div className="bg-brand-black p-8 text-white">{children}</div>
);

/** The navbar call to action. */
export const NavbarCta = () => (
  <Stage>
    <AppLink className="relative inline-flex items-center justify-center overflow-hidden border border-white bg-white px-5 py-2.5 text-xs font-bold tracking-wider uppercase text-black transition-all hover:bg-black hover:text-white group">
      <span className="relative z-10 flex items-center gap-1.5">
        Open the App <ArrowUpRight className="h-3.5 w-3.5" />
      </span>
    </AppLink>
  </Stage>
);

/** The footer call to action. */
export const FooterCta = () => (
  <Stage>
    <AppLink className="inline-flex items-center gap-2 bg-white text-black px-10 py-4 text-xs font-bold uppercase tracking-wider hover:bg-black hover:text-white border border-white transition-all rounded-sm group">
      Get Started Free <ArrowUpRight className="h-4 w-4" />
    </AppLink>
  </Stage>
);

/** Full-width button from the mobile menu. */
export const MobileMenu = () => (
  <Stage>
    <div className="w-72">
      <AppLink className="flex items-center justify-center bg-white py-3 text-sm font-bold tracking-wider uppercase text-black">
        Open the App
      </AppLink>
    </div>
  </Stage>
);
