import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  cacheComponents: true,
  partialPrefetching: true,
  // The README points people at http://127.0.0.1:5174; without this Next treats that origin as
  // cross-origin, blocks /_next dev resources and serves a page that never hydrates.
  allowedDevOrigins: ['127.0.0.1'],
  // The media panel uploads lesson clips and pictures; the default 1 MB action body would refuse a
  // dialogue longer than a couple of sentences. The action re-checks each file (8 MB audio, 4 MB image).
  experimental: {
    serverActions: {
      bodySizeLimit: '10mb',
    },
  },
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default nextConfig;
