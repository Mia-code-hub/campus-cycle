import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // better-sqlite3 是原生模块，交给 Node 直接 require，别让打包器处理
  serverExternalPackages: ["better-sqlite3"],
  cacheComponents: true,
  partialPrefetching: true,
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
