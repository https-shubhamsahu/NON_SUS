import Navbar from "@/components/Navbar";
import Hero from "@/components/Hero";
import TrustMetrics from "@/components/TrustMetrics";
import LivePreview from "@/components/LivePreview";
import FeaturesGrid from "@/components/FeaturesGrid";
import WorkflowTimeline from "@/components/WorkflowTimeline";
import LuxNoxSection from "@/components/LuxNoxSection";
import SecurityEditorial from "@/components/SecurityEditorial";
import DeviceScreenshots from "@/components/DeviceScreenshots";
import Testimonials from "@/components/Testimonials";
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

        {/* Live dashboard preview simulation */}
        <LivePreview />

        {/* Workflow scrolling timeline */}
        <WorkflowTimeline />

        {/* Protocol facts and trust pillars */}
        <TrustMetrics />

        {/* Capabilities Grid */}
        <FeaturesGrid />

        {/* Lux & Nox — the lab mascots */}
        <LuxNoxSection />

        {/* Device responsive mocks */}
        <DeviceScreenshots />

        {/* Security statements and technical specifications */}
        <SecurityEditorial />

        {/* Under the Hood: real link anatomy, claim semantics, audit chain */}
        <DevSection />

        {/* Use-case scenarios */}
        <Testimonials />

        {/* About the developer */}
        <DeveloperSection />

        {/* FAQ */}
        <FaqAccordion />
      </main>

      <Footer />
    </>
  );
}
