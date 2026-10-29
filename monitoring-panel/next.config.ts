import type { NextConfig } from 'next';

/**
 * Parvoz Monitoring — statik eksport, `https://farzandimedu.uz/monitoring/` ostida.
 *
 * Statik eksport cheklovlari (ataylab): middleware, server actions, `headers()`,
 * `[id]` dinamik yo'llar YO'Q. Deploy skripti har faylni curl bilan tekshiradi —
 * yo'lda `[ ]` bo'lsa curl uni glob deb tushunadi va deploy orqaga qaytadi.
 * Tafsilot sahifalari `.../view/?id=...` ko'rinishida.
 */
// Yo'l `PANEL_BASE_PATH` bilan o'zgartirilishi mumkin (standart — /monitoring).
const BASE_PATH = process.env.PANEL_BASE_PATH ?? '/monitoring';

const nextConfig: NextConfig = {
  output: 'export',
  basePath: BASE_PATH,
  trailingSlash: true,
  reactStrictMode: true,
  poweredByHeader: false,
  images: { unoptimized: true },
  env: {
    NEXT_PUBLIC_BASE_PATH: BASE_PATH,
  },
  experimental: {
    optimizePackageImports: ['lucide-react', 'recharts', 'date-fns'],
  },
};

export default nextConfig;
