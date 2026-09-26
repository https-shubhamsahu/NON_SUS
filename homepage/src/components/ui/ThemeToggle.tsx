"use client";

import { useEffect, useSyncExternalStore } from "react";
import { Moon, Sun } from "lucide-react";

const STORAGE_KEY = "nosus-theme";

type Theme = "light" | "dark";

const listeners = new Set<() => void>();

function emitThemeChange() {
  listeners.forEach((listener) => listener());
}

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

function subscribeTheme(onStoreChange: () => void) {
  listeners.add(onStoreChange);
  const onStorage = (event: StorageEvent) => {
    if (event.key === STORAGE_KEY || event.key === null) onStoreChange();
  };
  window.addEventListener("storage", onStorage);
  const mq = window.matchMedia("(prefers-color-scheme: light)");
  mq.addEventListener("change", onStoreChange);
  return () => {
    listeners.delete(onStoreChange);
    window.removeEventListener("storage", onStorage);
    mq.removeEventListener("change", onStoreChange);
  };
}

function getThemeSnapshot(): Theme {
  return readStoredTheme() ?? systemTheme();
}

function getServerThemeSnapshot(): Theme {
  return "dark";
}

/**
 * Light/dark control. Persists to localStorage (`nosus-theme`).
 * If nothing is stored, leaves `data-theme` unset so CSS media query owns the look.
 */
export function ThemeToggle({ className }: { className?: string }) {
  const theme = useSyncExternalStore(
    subscribeTheme,
    getThemeSnapshot,
    getServerThemeSnapshot,
  );

  useEffect(() => {
    const stored = readStoredTheme();
    if (stored) {
      document.documentElement.dataset.theme = stored;
    } else {
      delete document.documentElement.dataset.theme;
    }
  }, [theme]);

  function toggle() {
    const next: Theme = theme === "dark" ? "light" : "dark";
    document.documentElement.dataset.theme = next;
    try {
      localStorage.setItem(STORAGE_KEY, next);
    } catch {
      /* ignore */
    }
    emitThemeChange();
  }

  return (
    <button
      type="button"
      aria-label="Switch color theme"
      aria-pressed={theme === "dark"}
      onClick={toggle}
      className={`btn btn-ghost inline-flex h-11 w-11 shrink-0 items-center justify-center p-0 cursor-pointer ${className ?? ""}`}
    >
      {theme === "dark" ? (
        <Sun className="h-5 w-5" aria-hidden="true" />
      ) : (
        <Moon className="h-5 w-5" aria-hidden="true" />
      )}
    </button>
  );
}
