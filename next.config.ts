import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  experimental: {
    // Keep visited segments warm so tab switches inside the Android shell feel
    // instant instead of re-fetching on every tap.
    staleTimes: {
      dynamic: 30,
      static: 180,
    },
    optimizePackageImports: ['lucide-react', 'recharts'],
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
