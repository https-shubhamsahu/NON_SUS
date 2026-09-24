"use client";

import { useEffect, useState } from "react";
import { Moon, Sun } from "lucide-react";
import { cn } from "@/lib/utils";

const STORAGE_KEY = "nosus-theme";

type Theme = "light" | "dark";

function readStoredTheme(): Theme | null {
  try {
    const value = localStorage.getItem(STORAGE_KEY);
    if (value === "light" || value === "dark") return value;
  } catch {
    /* private mode / blocked storage */
  }
  return null;
}

function systemTheme(): Theme {
  return window.matchMedia("(prefers-color-scheme: light)").matches
    ? "light"
    : "dark";
}

/**
 * Light/dark control. Persists to localStorage (`nosus-theme`).
 * If nothing is stored, leaves `data-theme` unset so CSS media query owns the look.
 */
export function ThemeToggle({ className }: { className?: string }) {
  // Dark-first SSR default; sync from storage / system after mount.
  const [theme, setTheme] = useState<Theme>("dark");

  useEffect(() => {
    const stored = readStoredTheme();
    if (stored) {
      document.documentElement.dataset.theme = stored;
      setTheme(stored);
    } else {
      delete document.documentElement.dataset.theme;
      setTheme(systemTheme());
    }
  }, []);

  function toggle() {
    const next: Theme = theme === "dark" ? "light" : "dark";
    document.documentElement.dataset.theme = next;
    try {
      localStorage.setItem(STORAGE_KEY, next);
    } catch {
      /* ignore */
    }
    setTheme(next);
  }

  return (
    <button
      type="button"
      aria-label="Switch color theme"
      aria-pressed={theme === "dark"}
      onClick={toggle}
      className={cn(
        "btn btn-ghost inline-flex h-11 w-11 shrink-0 items-center justify-center p-0 cursor-pointer",
        className,
      )}
    >
      {theme === "dark" ? (
        <Sun className="h-5 w-5" aria-hidden="true" />
      ) : (
        <Moon className="h-5 w-5" aria-hidden="true" />
      )}
    </button>
  );
}
