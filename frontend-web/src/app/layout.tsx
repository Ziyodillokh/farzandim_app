import type { Metadata, Viewport } from 'next';
import { Toaster } from 'sonner';
import { QueryProvider } from '@/providers/query-provider';
import { ThemeProvider } from '@/providers/theme-provider';
import './globals.css';

// Eslatma: ilgari `next/font/google` (Inter) ishlatilardi, lekin u build/dev
// vaqtida shriftni Google CDN'dan (undici fetch) yuklab oladi — bu muhitda
// `fonts.gstatic.com` bilan ulanish uzilib qoladi (ECONNRESET) va sahifa 500
// beradi. Tarmoqqa bog'liqlikni olib tashlash uchun `--font-inter` o'zgaruvchisi
// tizim UI shrift stack'iga o'rnatildi (vizual jihatdan Inter'ga juda yaqin).
const interFontStack =
  "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, " +
  "'Helvetica Neue', Arial, sans-serif";

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
    <html
      lang="uz"
      suppressHydrationWarning
      style={{ ['--font-inter' as string]: interFontStack }}
    >
      <body className="font-sans">
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
