import { FileText, Lock, Shield, Eye } from "lucide-react";

export default function DeviceScreenshots() {
  return (
    <section
      className="py-32 bg-background border-b border-border relative overflow-hidden flex flex-col items-center"
    >
      <div className="mx-auto max-w-7xl px-6 md:px-8 w-full">
        <div className="text-center max-w-2xl mx-auto mb-20">
          <span className="text-xs font-bold tracking-widest text-muted-foreground uppercase mb-2 block">
            Across devices
          </span>
          <h2 className="text-[32px] md:text-5xl font-black uppercase tracking-tight text-foreground leading-none">
            Web and native
          </h2>
          <p className="text-base text-muted-foreground mt-4 leading-relaxed">
            Use NO SUS in the browser or as a native app on tablets, laptops, and phones.
          </p>
        </div>

        <div className="relative h-[480px] w-full max-w-4xl mx-auto flex items-center justify-center">
          {/* Laptop frame */}
          <div className="absolute z-10 w-[550px] h-[320px] paper-card overflow-hidden hidden md:block">
            <div className="h-6 bg-muted border-b border-border flex items-center px-4 justify-between">
              <div className="flex gap-1.5">
                <span className="w-2.5 h-2.5 rounded-full bg-border" />
                <span className="w-2.5 h-2.5 rounded-full bg-border" />
                <span className="w-2.5 h-2.5 rounded-full bg-border" />
              </div>
              <span className="text-[10px] font-mono text-muted-foreground">nosus.foo/vault</span>
              <div className="w-8" />
            </div>

            <div className="p-5 grid grid-cols-12 gap-4 h-full bg-card">
              <div className="col-span-3 border-r border-border flex flex-col gap-2 pr-2">
                <div className="w-full h-4 bg-muted rounded-[12px]" />
                <div className="w-5/6 h-3 bg-muted rounded-[12px]" />
                <div className="w-3/4 h-3 bg-muted rounded-[12px]" />
              </div>
              <div className="col-span-9 flex flex-col gap-4">
                <div className="flex justify-between items-center border-b border-border pb-2">
                  <span className="text-xs font-bold text-foreground uppercase tracking-wider">
                    Vault files
                  </span>
                  <div className="w-16 h-4 bg-muted rounded-[12px]" />
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <div className="border border-border p-3 rounded-[12px] bg-background flex flex-col gap-2">
                    <FileText className="h-5 w-5 text-foreground" />
                    <span className="text-xs font-mono text-foreground font-bold">sys_specs.pdf</span>
                  </div>
                  <div className="border border-border p-3 rounded-[12px] bg-background flex flex-col gap-2">
                    <Lock className="h-5 w-5 text-foreground" />
                    <span className="text-xs font-mono text-foreground font-bold">keys_metadata.csv</span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Tablet frame */}
          <div
            style={{ transform: "translate(-150px, 50px)" }}
            className="absolute z-20 w-[280px] h-[380px] paper-card overflow-hidden hidden sm:block border-4 border-foreground"
          >
            <div className="h-4 bg-muted flex items-center px-4 justify-between border-b border-border">
              <span className="w-1.5 h-1.5 rounded-full bg-border" />
            </div>

            <div className="p-4 flex flex-col gap-4 h-full justify-between pb-8 bg-card">
              <div className="flex justify-between items-center pb-2 border-b border-border">
                <span className="text-xs font-bold text-foreground uppercase tracking-wider">
                  Study desk
                </span>
                <span className="text-xs font-mono text-muted-foreground">Active</span>
              </div>

              <div className="flex flex-col gap-2">
                {Array.from({ length: 4 }).map((_, i) => (
                  <div
                    key={i}
                    className="flex justify-between items-center border border-border p-2 rounded-[12px] bg-background"
                  >
                    <div className="flex items-center gap-2">
                      <FileText className="h-3.5 w-3.5 text-foreground" />
                      <span className="text-xs font-mono text-foreground">doc_{i + 1}.pdf</span>
                    </div>
                    <span className="w-2 h-2 rounded-full bg-foreground" />
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Phone frame */}
          <div className="absolute z-30 w-[170px] h-[320px] paper-card overflow-hidden border-[6px] border-foreground sm:translate-x-[200px] sm:translate-y-[80px]">
            <div className="absolute top-2 left-1/2 -translate-x-1/2 w-14 h-3 bg-foreground rounded-full z-40" />

            <div className="p-3 pt-8 flex flex-col gap-4 justify-between h-full pb-6 bg-card">
              <div className="flex flex-col gap-1 items-center">
                <Shield className="h-6 w-6 text-foreground" />
                <span className="text-xs font-bold text-foreground uppercase tracking-widest mt-1">
                  NO SUS app
                </span>
              </div>

              <div className="flex-1 flex flex-col justify-center items-center gap-2">
                <div className="w-24 h-24 rounded-full border border-dashed border-border flex items-center justify-center bg-background">
                  <Eye className="h-5 w-5 text-muted-foreground" />
                </div>
                <span className="text-xs font-mono text-muted-foreground text-center leading-normal">
                  Touch to reveal content
                </span>
              </div>

              <div className="btn btn-primary text-xs h-9 min-h-[36px] pointer-events-none">
                Open desk
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
