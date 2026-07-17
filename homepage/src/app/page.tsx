import Navbar from "@/components/Navbar";
import Hero from "@/components/Hero";
import ProblemSection from "@/components/ProblemSection";
import Pillars from "@/components/Pillars";
import TrustMetrics from "@/components/TrustMetrics";
import LivePreview from "@/components/LivePreview";
import FeaturesGrid from "@/components/FeaturesGrid";
import WorkflowTimeline from "@/components/WorkflowTimeline";
import LuxNoxSection from "@/components/LuxNoxSection";
import SecurityEditorial from "@/components/SecurityEditorial";
import DeviceScreenshots from "@/components/DeviceScreenshots";
import Testimonials from "@/components/Testimonials";
import ComparisonSection from "@/components/ComparisonSection";
import DeveloperSection from "@/components/DeveloperSection";
import FaqAccordion from "@/components/FaqAccordion";
import DevSection from "@/components/DevSection";
import Footer from "@/components/Footer";

export default function Home() {
  return (
    <>
      <Navbar />

      <main className="flex-1 w-full bg-brand-black">
        {/* Hero with the REAL burn note / burn file tool (LimeWire-style:
            the product itself above the fold, not a mockup) */}
        <Hero />

        {/* Problem: the stakes of a leak, before the solution */}
        <ProblemSection />

        {/* Solution: three pillars (Prevent / Detect / Prove) instead of a
            wall of individual features */}
        <Pillars />

        {/* Live dashboard preview simulation */}
        <LivePreview />

        {/* Workflow scrolling timeline */}
        <WorkflowTimeline />

        {/* Use cases: where a leak actually costs something */}
        <Testimonials />

        {/* Lux & Nox — the lab mascots, surfaced earlier so the brand
            personality lands well before the technical sections */}
        <LuxNoxSection />

        {/* Why not just use Google Drive? */}
        <ComparisonSection />

        {/* Protocol facts and trust pillars */}
        <TrustMetrics />

        {/* Capabilities Grid — the detailed list, now that Pillars leads */}
        <FeaturesGrid />

        {/* Device responsive mocks */}
        <DeviceScreenshots />

        {/* Security statements and technical specifications */}
        <SecurityEditorial />

        {/* Under the Hood: real link anatomy, claim semantics, audit chain */}
        <DevSection />

        {/* About the developer */}
        <DeveloperSection />

        {/* FAQ */}
        <FaqAccordion />
      </main>

      <Footer />
    </>
  );
}
