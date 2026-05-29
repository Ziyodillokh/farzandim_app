import type { Metadata, Viewport } from 'next';
import { Inter } from 'next/font/google';
import { Toaster } from 'sonner';
import { QueryProvider } from '@/providers/query-provider';
import { ThemeProvider } from '@/providers/theme-provider';
import './globals.css';

const inter = Inter({
  subsets: ['latin', 'cyrillic'],
  variable: '--font-inter',
  display: 'swap',
});

export const metadata: Metadata = {
  title: {
    default: 'Farzandim — Ota-onalar uchun xavfsiz nazorat',
    template: '%s · Farzandim',
  },
  description:
    "Bolalar uchun rivojlanish platformasi va ota-onalar uchun xavfsiz nazorat paneli.",
  manifest: '/manifest.json',
};

export const viewport: Viewport = {
  themeColor: '#0A0A12',
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="uz" suppressHydrationWarning>
      <body className={`${inter.variable} font-sans`}>
        <ThemeProvider>
          <QueryProvider>
            {children}
            <Toaster
              richColors
              position="top-right"
              theme="dark"
              toastOptions={{
                style: { background: 'hsl(var(--card))', border: '1px solid hsl(var(--border))' },
              }}
            />
          </QueryProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}
