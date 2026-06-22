import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  // Admin panel asosiy domen subpath'ida: farzandimedu.uz/admin (root '/' — landing).
  // Next.js barcha route/asset'larni /admin ostiga prefiks qiladi; API chaqiruvlari
  // NEXT_PUBLIC_API_URL (absolyut) bo'lgani uchun basePath ularga ta'sir qilmaydi.
  basePath: '/admin',
  reactStrictMode: true,
  experimental: {
    optimizePackageImports: ['lucide-react', '@tabler/icons-react', 'recharts'],
  },
  images: {
    remotePatterns: [
      { protocol: 'http', hostname: 'localhost' },
      { protocol: 'http', hostname: '127.0.0.1' },
      { protocol: 'https', hostname: 'farzandimedu.uz' },
      { protocol: 'https', hostname: '**.farzandimedu.uz' },
    ],
  },
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          { key: 'X-Frame-Options', value: 'DENY' },
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
        ],
      },
    ];
  },
};

export default nextConfig;
