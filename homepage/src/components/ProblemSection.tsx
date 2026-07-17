export default function ProblemSection() {
  return (
    <section className="py-24 bg-brand-black border-b border-brand-gray/80 relative">
      <div className="mx-auto max-w-3xl px-6 md:px-8 text-center">
        <h2 className="text-3xl md:text-5xl font-black uppercase tracking-tight text-white leading-tight">
          A Leaked Draft Costs the Deal<span className="text-brand-gray-light">.</span>{" "}
          <br className="hidden md:block" />
          <span className="text-brand-gray-light">A Leaked Note Costs Your Name</span>
          <span className="text-white">.</span>
        </h2>
        <p className="text-sm md:text-base text-brand-gray-light mt-6 leading-relaxed max-w-2xl mx-auto font-medium">
          Cloud storage assumes every recipient keeps their word<span className="text-white">.</span>{" "}
          NO SUS is built for when they don&apos;t, with a way to find out who broke it, or a way to make
          sure there&apos;s nothing left to leak at all<span className="text-white">.</span>
        </p>
      </div>
    </section>
  );
}
