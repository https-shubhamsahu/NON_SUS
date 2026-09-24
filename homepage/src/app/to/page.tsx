import type { Metadata } from "next";
import DropDoor from "@/components/drop/DropDoor";

export const metadata: Metadata = {
  title: "Send a file",
  robots: { index: false, follow: false },
  referrer: "no-referrer",
};

export default function DropPage() {
  return <DropDoor />;
}
