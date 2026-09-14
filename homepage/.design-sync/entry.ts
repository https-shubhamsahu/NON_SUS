// Entry for the Claude Design sync (Burn ad kit scope). The homepage is a
// Next.js app with no library build, and its components are default exports,
// which the converter's synthesized `export *` entry would drop. Re-export the
// synced components by name here instead.
export { default as NoSusLogo } from "../src/components/ui/Logo";
export { default as BurnTool } from "../src/components/BurnTool";
export { default as ShareQr } from "../src/components/ShareQr";
export { default as AppLink } from "../src/components/AppLink";
