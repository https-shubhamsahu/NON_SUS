import { Upload, Shield, Share2, Users, Eye, Ban } from "lucide-react";

export default function WorkflowTimeline() {
  const steps = [
    {
      icon: Upload,
      num: "01",
      title: "Upload",
      desc: "Drag or select your document. Files are encrypted client-side using AES-256 before reaching the server.",
    },
    {
      icon: Shield,
      num: "02",
      title: "Protect",
      desc: "Apply dynamic email watermarks, toggle touch-to-reveal blur, and enable root-detection filters.",
    },
    {
      icon: Share2,
      num: "03",
      title: "Share",
      desc: "Mint secure access URLs. Control links with automatic revocation bounds, view counts, and expiration limits.",
    },
    {
      icon: Users,
      num: "04",
      title: "Collaborate",
      desc: "Roster students or researchers into secure groups. Keep notes sync'd in real-time, online or offline.",
    },
    {
      icon: Eye,
      num: "05",
      title: "Track",
      desc: "Monitor opens, durations, and suspicious actions like right-clicks or screenshot attempts on a chained log.",
    },
    {
      icon: Ban,
      num: "06",
      title: "Control",
      desc: "Instantly revoke share permissions or self-destruct documents, wiping them from cache and storage.",
    },
  ];

  return (
    <section id="how-it-works" className="relative py-24 bg-brand-black">
      <div className="flex flex-col justify-center">
        
        <div className="mx-auto max-w-7xl w-full px-6 md:px-8 mb-12">
          <h2 className="text-3xl md:text-5xl font-black uppercase tracking-tight text-white leading-none">
            End-to-End Governance
          </h2>
        </div>

        {/* Native responsive layout: every step is reachable without scroll JS. */}
        <div className="mx-auto max-w-7xl w-full px-6 md:px-8">
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-8">
            {steps.map((step, idx) => (
              <div
                key={idx}
                className="border border-brand-gray bg-brand-gray-dark/50 p-8 rounded flex flex-col justify-between min-h-[300px] relative"
              >
                <div className="flex justify-between items-start">
                  <div className="w-12 h-12 border border-brand-gray flex items-center justify-center bg-brand-black rounded">
                    <step.icon className="h-5 w-5 text-white stroke-[1.5]" />
                  </div>
                  <span className="font-mono text-3xl font-black text-brand-gray/30">
                    {step.num}
                  </span>
                </div>

                <div className="mt-8">
                  <h3 className="text-base font-bold uppercase tracking-wider text-white">
                    {step.title}
                  </h3>
                  <p className="text-xs text-brand-gray-light leading-relaxed mt-2 font-medium">
                    {step.desc}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </div>

      </div>
    </section>
  );
}
