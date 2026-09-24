import type { Metadata } from "next";
import GoDesk from "@/components/go/GoDesk";

export const metadata: Metadata = {
  title: "Open Saved — NO SUS",
  description:
    "Open your Saved chat on this computer by scanning a QR with the NO SUS phone app. Utility page — not indexed.",
  alternates: { canonical: "/go" },
  robots: { index: false, follow: false },
  referrer: "no-referrer",
  // Override layout openGraph/twitter so shares of /go do not claim the homepage URL.
  openGraph: {
    title: "Open Saved — NO SUS",
    description:
      "Open your Saved chat on this computer by scanning a QR with the NO SUS phone app.",
    url: "/go",
  },
  twitter: {
    title: "Open Saved — NO SUS",
    description:
      "Open your Saved chat on this computer by scanning a QR with the NO SUS phone app.",
  },
};

export default function GoPage() {
  return <GoDesk />;
}
