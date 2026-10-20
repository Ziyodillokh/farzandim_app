'use client';

import { useRouter } from 'next/navigation';
import { useEffect } from 'react';

import { getSession } from '@/auth/session';
import { LoginCard } from '@/features/auth/components/login-card';
import { LoginHero } from '@/features/auth/components/login-hero';
import { useI18n, type Locale } from '@/i18n';
import { cn } from '@/lib/utils';

export default function LoginPage() {
  const { locale, setLocale, t } = useI18n();
  const router = useRouter();

  useEffect(() => {
    if (getSession()) router.replace('/dashboard');
  }, [router]);

  return (
    // Login doim kosmik qorong'i: `dark` — ichidagi tokenlar (shisha, input) to'q variantda.
    <div className="dark relative min-h-screen text-foreground">
      <div className="absolute right-4 top-4 z-20 flex items-center rounded-xl bg-white/10 p-1 ring-1 ring-inset ring-white/15 sm:right-6 sm:top-6" role="group" aria-label={t('shell.language')}>
        {(['uz', 'ru'] as Locale[]).map((l) => (
          <button
            key={l}
            type="button"
            aria-pressed={locale === l}
            onClick={() => setLocale(l)}
            className={cn('h-8 rounded-lg px-3 text-xs font-semibold uppercase text-white/70 transition-all', locale === l && 'bg-white text-brand-950')}
          >
            {l === 'uz' ? 'UZ' : 'RU'}
          </button>
        ))}
      </div>
      <div className="relative z-10 mx-auto grid min-h-screen w-full max-w-[1320px] grid-cols-1 content-center items-center gap-8 px-4 py-16 sm:px-8 lg:grid-cols-[1fr_440px] lg:gap-16 lg:px-14">
        <LoginHero />
        <div className="mx-auto w-full max-w-[440px]">
          <LoginCard />
        </div>
      </div>
    </div>
  );
}
