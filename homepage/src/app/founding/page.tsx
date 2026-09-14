import type { Metadata } from "next";
import Link from "next/link";

import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import FoundingTeamForm from "@/components/FoundingTeamForm";
import { DEVELOPER } from "@/lib/links";

export const metadata: Metadata = {
  title: "Founding Team — NO SUS",
  description:
    "NO SUS is still designed, built, and operated by one developer. This form opens an email draft if you want to help as founding team — nothing is posted to our servers.",
  alternates: { canonical: "/founding" },
  openGraph: {
    title: "Founding Team — NO SUS",
    description:
      "Interest form for people who want to help build NO SUS. Applications go by email; they are not stored in our database.",
    url: "https://nosus.foo/founding",
  },
};

export default function FoundingPage() {
  return (
    <>
      <Navbar />
      <main className="flex-1 w-full bg-brand-black">
        <section className="pt-32 pb-24 border-b border-brand-gray/80">
          <div className="mx-auto max-w-3xl px-6 md:px-8">
            <span className="text-[10px] font-bold tracking-widest text-brand-gray-light uppercase mb-3 block">
              Founding team
            </span>
            <h1 className="text-3xl md:text-5xl font-black uppercase tracking-tight text-white leading-none">
              Looking for people to build this with.
            </h1>
            <div className="mt-6 flex flex-col gap-4 text-sm text-brand-gray-light leading-relaxed font-medium max-w-2xl">
              <p>
                NO SUS is designed, built, and operated end-to-end by one
                developer — {DEVELOPER.name}. That is still true. There is no
                company hiring page, no salary band, and no equity offer
                attached to this form.
              </p>
              <p>
                If you want to help as founding team anyway — engineering,
                design, growth, or operations on a tiny encrypted-docs product —
                say so. The form prepares an email draft to {DEVELOPER.email}.
                Send it from your mail app; we do not keep a copy on our
                servers.
              </p>
              <p>
                Curious about the product first?{" "}
                <Link href="/" className="text-white underline">
                  Try Burn Notes and Burn Files on the homepage
                </Link>
                , or read{" "}
                <Link href="/#developer" className="text-white underline">
                  about the developer
                </Link>
                .
              </p>
            </div>

            <div className="mt-12">
              <FoundingTeamForm />
            </div>
          </div>
        </section>
      </main>
      <Footer />
    </>
  );
}
