import type { Metadata, Viewport } from 'next';
import { Inter, Unbounded } from 'next/font/google';
import type { ReactNode } from 'react';

import { AppProviders } from '@/providers/app-providers';
import './globals.css';

const inter = Inter({ subsets: ['latin', 'cyrillic'], variable: '--font-inter', display: 'swap' });
const unbounded = Unbounded({ subsets: ['latin', 'cyrillic'], variable: '--font-unbounded', display: 'swap', weight: ['500', '600', '700'] });

export const metadata: Metadata = {
  title: { default: 'Parvoz School', template: '%s · Parvoz School' },
  description: 'Parvoz School — maktab, ota-ona va o\'quvchini birlashtiruvchi raqamli ekotizim (demo).',
  robots: { index: false, follow: false },
  icons: { icon: `${process.env.NEXT_PUBLIC_BASE_PATH ?? ''}/icon.svg` },
};

export const viewport: Viewport = {
  themeColor: '#060B16',
  width: 'device-width',
  initialScale: 1,
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="uz" suppressHydrationWarning className={`${inter.variable} ${unbounded.variable}`}>
      <body className="min-h-screen font-sans">
        <AppProviders>{children}</AppProviders>
      </body>
    </html>
  );
}
