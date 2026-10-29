import type { Metadata, Viewport } from 'next';
import { Onest, Unbounded } from 'next/font/google';
import type { ReactNode } from 'react';

import { AppProviders } from '@/providers/app-providers';
import './globals.css';

const onest = Onest({ subsets: ['latin', 'cyrillic'], variable: '--font-onest', display: 'swap' });
const unbounded = Unbounded({ subsets: ['latin', 'cyrillic'], variable: '--font-unbounded', display: 'swap', weight: ['500', '600', '700'] });

export const metadata: Metadata = {
  title: { default: 'Parvoz Monitoring', template: '%s · Parvoz Monitoring' },
  description: 'Parvoz Monitoring — bolalar ta\'limi va farovonligi monitoringi (demo).',
  robots: { index: false, follow: false },
  icons: { icon: `${process.env.NEXT_PUBLIC_BASE_PATH ?? ''}/icon.svg` },
};

export const viewport: Viewport = {
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: '#060A15' },
    { media: '(prefers-color-scheme: dark)', color: '#060A15' },
  ],
  width: 'device-width',
  initialScale: 1,
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="uz" suppressHydrationWarning className={`${onest.variable} ${unbounded.variable}`}>
      <body className="min-h-screen font-sans">
        <AppProviders>{children}</AppProviders>
      </body>
    </html>
  );
}
