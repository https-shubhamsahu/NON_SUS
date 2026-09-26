"use client";

import { ReactNode } from "react";

import { APP_URL } from "@/lib/links";

/**
 * Link to the web app. On Android, https://app.nosus.foo is a verified App
 * Link, so a normal tap opens the installed app. Cancelling the click to show
 * a chooser kept the browser in front of that tap.
 */
export default function AppLink({
  children,
  className = "",
  onNavigate,
}: {
  children: ReactNode;
  className?: string;
  onNavigate?: () => void;
}) {
  return (
    <a href={APP_URL} className={className} onClick={() => onNavigate?.()}>
      {children}
    </a>
  );
}
