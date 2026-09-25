import Navbar from "@/components/Navbar";
import Hero from "@/components/Hero";
import ThreeDoors from "@/components/ThreeDoors";
import WorkflowTimeline from "@/components/WorkflowTimeline";
import ComparisonSection from "@/components/ComparisonSection";
import LivePreview from "@/components/LivePreview";
import SecurityEditorial from "@/components/SecurityEditorial";
import DevSection from "@/components/DevSection";
import LuxNoxSection from "@/components/LuxNoxSection";
import DeveloperSection from "@/components/DeveloperSection";
import FaqAccordion from "@/components/FaqAccordion";
import Footer from "@/components/Footer";

export default function Home() {
  return (
    <>
      <Navbar />

      <main className="flex-1 w-full bg-background text-foreground">
        <Hero />
        <LivePreview />
        <ThreeDoors />
        <WorkflowTimeline />
        <ComparisonSection />
        <SecurityEditorial />
        <DevSection />
        <LuxNoxSection />
        <DeveloperSection />
        <FaqAccordion />
      </main>

      <Footer />
    </>
  );
}
