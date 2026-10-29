import Link from 'next/link';

import { ParvozWordmark } from '@/components/layout/parvoz-wordmark';

export default function NotFound() {
  return (
    <div className="relative isolate flex min-h-screen flex-col items-center justify-center gap-5 p-6 text-center">
      <div aria-hidden className="aurora-bg" />
      <ParvozWordmark size="lg" sub="Monitoring" />
      <p className="font-display text-7xl font-semibold tracking-[-0.03em] text-primary">404</p>
      <p className="text-muted-foreground">Sahifa topilmadi · Страница не найдена</p>
      <Link href="/dashboard" className="rounded-xl bg-brand-gradient px-5 py-2.5 text-sm font-semibold text-white shadow-primary-glow hover:brightness-110">
        Bosh sahifa · Главная
      </Link>
    </div>
  );
}
