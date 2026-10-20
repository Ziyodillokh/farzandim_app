import type { NextConfig } from 'next';

/**
 * Parvoz School — statik eksport, `https://farzandimedu.uz/school/` ostida.
 *
 * Statik eksport cheklovlari (ataylab): middleware, server actions, `headers()`,
 * `[id]` dinamik yo'llar YO'Q. Deploy skripti har faylni curl bilan tekshiradi —
 * yo'lda `[ ]` bo'lsa curl uni glob deb tushunadi va deploy orqaga qaytadi.
 * Tafsilot sahifalari `.../view/?id=...` ko'rinishida.
 */
// Haqiqiy (http) rejim paneli demo bilan bir domenda boshqa yo'lda turishi
// mumkin: `PANEL_BASE_PATH=/maktab npm run build` (standart — demo yo'li).
const BASE_PATH = process.env.PANEL_BASE_PATH ?? '/school';

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
