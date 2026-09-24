import Navbar from "@/components/Navbar";
import Hero from "@/components/Hero";
import ThreeDoors from "@/components/ThreeDoors";
import WorkflowTimeline from "@/components/WorkflowTimeline";
import BurnTool from "@/components/BurnTool";
import ComparisonSection from "@/components/ComparisonSection";
import Pillars from "@/components/Pillars";
import TrustMetrics from "@/components/TrustMetrics";
import FeaturesGrid from "@/components/FeaturesGrid";
import LivePreview from "@/components/LivePreview";
import DeviceScreenshots from "@/components/DeviceScreenshots";
import LuxNoxSection from "@/components/LuxNoxSection";
import SecurityEditorial from "@/components/SecurityEditorial";
import Testimonials from "@/components/Testimonials";
import DevSection from "@/components/DevSection";
import DeveloperSection from "@/components/DeveloperSection";
import FaqAccordion from "@/components/FaqAccordion";
import Footer from "@/components/Footer";

export default function Home() {
  return (
    <>
      <Navbar />

      <main className="flex-1 w-full bg-background text-foreground">
        <Hero />
        <ThreeDoors />
        <WorkflowTimeline />
        <BurnTool />
        <ComparisonSection />
        <Pillars />
        <TrustMetrics />
        <FeaturesGrid />
        <LivePreview />
        <DeviceScreenshots />
        <LuxNoxSection />
        <SecurityEditorial />
        <Testimonials />
        <DevSection />
        <DeveloperSection />
        <FaqAccordion />
      </main>

      <Footer />
    </>
  );
}
