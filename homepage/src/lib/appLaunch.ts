// Zoom-style "open in app" launch flow for Android visitors.
//
// A mobile browser cannot ask "is io.nosus.app installed?" — that's blocked
// by design for privacy. What Zoom (and everyone else) actually does is
// ATTEMPT the launch and handle the miss:
//
//   Chromium browsers (Chrome/Edge/Samsung Internet): an intent:// URL.
//     The browser itself resolves it — opens the app when installed, and
//     navigates to `browser_fallback_url` (our APK download) when not.
//
//   Everything else (Firefox etc.): navigate to the custom scheme and use
//     the visibility heuristic — if the tab is still visible ~1.6s later,
//     nothing handled the scheme, so the app is almost certainly missing.
//
// The matching intent filter (io.nosus.app://open) lives in
// android/app/src/main/AndroidManifest.xml.
import { RELEASES_URL } from "./links";

export const ANDROID_PACKAGE_ID = "io.nosus.app";

export function isAndroid(): boolean {
  return (
    typeof navigator !== "undefined" && /android/i.test(navigator.userAgent)
  );
}

/**
 * Attempts to open the installed Android app.
 * `onProbablyNotInstalled` fires only on the non-Chromium path — Chromium
 * handles the fallback itself by navigating to the APK download page.
 */
export function launchAndroidApp(onProbablyNotInstalled: () => void): void {
  const ua = navigator.userAgent;
  const isChromium = /chrome|chromium|crios|samsungbrowser|edga?/i.test(ua) && !/firefox|fxios/i.test(ua);

  if (isChromium) {
    window.location.href =
      `intent://open#Intent;scheme=${ANDROID_PACKAGE_ID};package=${ANDROID_PACKAGE_ID};` +
      `S.browser_fallback_url=${encodeURIComponent(RELEASES_URL)};end`;
    return;
  }

  const timer = window.setTimeout(() => {
    // Tab still visible → the scheme navigation went nowhere → no app.
    if (document.visibilityState === "visible") onProbablyNotInstalled();
  }, 1600);
  window.addEventListener(
    "visibilitychange",
    () => {
      // App took over the screen → it is installed; cancel the miss timer.
      if (document.visibilityState === "hidden") window.clearTimeout(timer);
    },
    { once: true },
  );
  window.location.href = `${ANDROID_PACKAGE_ID}://open`;
}
