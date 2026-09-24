import { MetadataRoute } from "next";

// Required for `output: "export"` — metadata routes must opt into static.
export const dynamic = "force-static";

// Indexable URLs only. Legal pages are copied from web/ at deploy, so this
// build has no honest mtime for them. Homepage lastModified is omitted too:
// inventing freshness (or using new Date() every build) would be false.
// /go and /to are utility pages with robots noindex — keep them out.
export default function sitemap(): MetadataRoute.Sitemap {
  return [
    {
      url: "https://nosus.foo/",
      changeFrequency: "weekly",
      priority: 1,
    },
    { url: "https://nosus.foo/privacy.html" },
    { url: "https://nosus.foo/terms.html" },
    { url: "https://nosus.foo/account-deletion.html" },
  ];
}
