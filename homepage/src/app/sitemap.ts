import { MetadataRoute } from "next";

// Required for `output: "export"` — metadata routes must opt into static.
export const dynamic = "force-static";

// The legal pages are copied in from web/ by .github/workflows/gh-pages.yml,
// so this build cannot see when they change. They carry no lastModified
// because a date that moves on every deploy would be false.
export default function sitemap(): MetadataRoute.Sitemap {
  return [
    {
      url: "https://nosus.foo/",
      lastModified: new Date(),
      changeFrequency: "weekly",
      priority: 1,
    },
    { url: "https://nosus.foo/privacy.html" },
    { url: "https://nosus.foo/terms.html" },
    { url: "https://nosus.foo/account-deletion.html" },
  ];
}
