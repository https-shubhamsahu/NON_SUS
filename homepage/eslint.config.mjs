import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
  // Override default ignores of eslint-config-next.
  globalIgnores([
    // Default ignores of eslint-config-next:
    ".next/**",
    "out/**",
    "build/**",
    "next-env.d.ts",
    // The Eureka pitch ships a third-party minified browser bundle unchanged.
    "public/eureka-pitch/vendor/**",
    // Claude Design sync: previews import the synced bundle as "homepage", and
    // the staged converter and its output are local-only (.design-sync/NOTES.md).
    ".design-sync/**",
    ".ds-sync/**",
    "ds-bundle/**",
  ]),
]);

export default eslintConfig;
