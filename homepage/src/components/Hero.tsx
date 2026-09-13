import BurnTool from "./BurnTool";

export default function Hero() {
  return (
    <section className="relative min-h-screen flex flex-col justify-center items-center pt-32 pb-20 overflow-hidden swiss-grid">
      <div aria-hidden="true" className="absolute inset-0 pointer-events-none bg-[radial-gradient(ellipse_at_top,rgba(255,255,255,0.09),transparent_65%)]" />
      {/* Fade the static glow into the next section. */}
      <div className="absolute inset-x-0 bottom-0 z-[1] h-56 md:h-72 bg-gradient-to-b from-transparent to-brand-black pointer-events-none" />
      <div className="relative z-10 w-full max-w-7xl px-6 md:px-8 flex flex-col items-center justify-center">
        {/* 1. Header (Centered Headline & Subtitle) */}
        <div className="flex flex-col items-center text-center max-w-4xl gap-6">
          <span
            className="text-[10px] font-bold tracking-widest text-brand-gray-light uppercase"
          >
            Document Leak Attribution
          </span>

          <h1
            className="text-4xl sm:text-5xl md:text-6xl font-black tracking-tighter uppercase leading-[0.95] text-white select-none"
          >
            If It Leaks<span className="text-brand-gray-light">,</span> <br />
            <span className="text-brand-gray-light">You&apos;ll Know Exactly Who</span><span className="text-white">.</span>
          </h1>

          <p
            className="text-sm sm:text-base md:text-lg text-brand-gray-light font-medium leading-relaxed max-w-2xl"
          >
            Every document you share is watermarked to whoever opens it<span className="text-white">.</span> Every note you burn
            disappears before anyone else can<span className="text-white">.</span> Try it right here; no account needed<span className="text-white">.</span>
          </p>
        </div>

        {/* The working tool is visible in the initial HTML. */}
        <div
          className="w-full max-w-2xl mt-12 relative z-10"
        >
          <BurnTool />
        </div>


      </div>
    </section>
  );
}
