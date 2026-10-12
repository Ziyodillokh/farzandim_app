import { Bell } from 'lucide-react';
import type { ReactNode } from 'react';

import { ParvozLogo } from '@/components/layout/parvoz-logo';
import { cn } from '@/lib/utils';

/**
 * Parvoz Parents ilovasi ko'rinishi (telefon maketi) — xabar/eslatma ota-onaga
 * qanday yetib borishini oldindan ko'rsatish uchun.
 */
export function PhoneMockup({ children, className, time = '09:41' }: { children: ReactNode; className?: string; time?: string }) {
  return (
    <div className={cn('mx-auto w-[290px] rounded-[2.6rem] border-[10px] border-neutral-900 bg-neutral-900 shadow-soft-xl', className)}>
      <div className="relative overflow-hidden rounded-[2rem] bg-[#060B16] text-white">
        <div className="flex items-center justify-between px-6 pt-3 text-[11px] font-semibold">
          <span>{time}</span>
          <span className="h-5 w-20 rounded-full bg-black" />
          <span>100%</span>
        </div>
        <div className="flex items-center gap-2 px-4 pb-3 pt-4">
          <ParvozLogo className="h-7 w-7 rounded-lg" />
          <span className="font-display text-sm font-semibold">Parvoz</span>
          <Bell className="ml-auto h-4 w-4 opacity-70" />
        </div>
        <div className="min-h-[430px] space-y-3 bg-gradient-to-b from-[#0B1428] to-[#060B16] px-3 pb-6 pt-2">{children}</div>
      </div>
    </div>
  );
}

/** Telefon ichidagi bildirishnoma kartochkasi. */
export function PhoneNotification({ title, body, meta, important }: { title: string; body: string; meta: string; important?: boolean }) {
  return (
    <div className={cn('rounded-2xl border border-white/10 bg-white/[0.07] p-3.5 backdrop-blur', important && 'border-amber-300/40 bg-amber-300/10')}>
      <div className="flex items-center gap-2 text-[10px] uppercase tracking-wider text-white/60">
        <span className="h-1.5 w-1.5 rounded-full bg-[#3C82FF]" />
        {meta}
      </div>
      <p className="mt-1.5 text-[13px] font-semibold leading-snug">{title}</p>
      <p className="mt-1 whitespace-pre-line text-[12px] leading-relaxed text-white/75">{body}</p>
    </div>
  );
}
