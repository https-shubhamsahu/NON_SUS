import { MetadataRoute } from "next";

// Required for `output: "export"` — metadata routes must opt into static.
export const dynamic = "force-static";

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    {
      url: "https://nosus.foo",
      lastModified: new Date(),
      changeFrequency: "weekly",
      priority: 1,
    },
  ];
}
