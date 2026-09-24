import type { Metadata } from "next";
import DropDoor from "@/components/drop/DropDoor";

export const metadata: Metadata = {
  title: "Send a file — NO SUS",
  description:
    "Send a file through a NO SUS drop door on this computer. Utility page — not indexed.",
  alternates: { canonical: "/to" },
  robots: { index: false, follow: false },
  referrer: "no-referrer",
  // Override layout openGraph/twitter so shares of /to do not claim the homepage URL.
  openGraph: {
    title: "Send a file — NO SUS",
    description:
      "Send a file through a NO SUS drop door on this computer.",
    url: "/to",
  },
  twitter: {
    title: "Send a file — NO SUS",
    description:
      "Send a file through a NO SUS drop door on this computer.",
  },
};

export default function DropPage() {
  return <DropDoor />;
}
