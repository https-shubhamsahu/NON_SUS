import type { Metadata } from "next";
import GoDesk from "@/components/go/GoDesk";

export const metadata: Metadata = {
  title: "Open Saved",
  robots: { index: false, follow: false },
  referrer: "no-referrer",
};

export default function GoPage() {
  return <GoDesk />;
}
