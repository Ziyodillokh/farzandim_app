'use client';

import { PhoneMockup, PhoneNotification } from '@/components/common/phone-mockup';
import { useSchool } from '@/features/school/hooks';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

/**
 * Parvoz Parents telefon maketida oldindan ko'rish: bildirishnoma kartochkasi
 * va (ixtiyoriy) qo'shimcha kontekst — ota-ona aynan nimani ko'rishini bildiradi.
 */
export function MessagePhonePreview({
  title,
  body,
  important,
  meta,
  className,
  time,
}: {
  title: string;
  body: string;
  important?: boolean;
  /** Bildirishnoma ustidagi kichik yozuv (standart: maktab nomi · hozir). */
  meta?: string;
  className?: string;
  time?: string;
}) {
  const { t } = useI18n();
  const school = useSchool();
  const schoolName = school.data?.school.shortName ?? school.data?.school.name ?? 'Parvoz School';
  const trimmedTitle = title.trim();
  const trimmedBody = body.trim();

  return (
    <PhoneMockup className={cn('animate-fade-in', className)} time={time}>
      <p className="px-1 pt-1 text-[10px] font-semibold uppercase tracking-[0.18em] text-white/40">{t('messages.preview.lockTitle')}</p>
      <PhoneNotification
        title={trimmedTitle || t('messages.preview.placeholderTitle')}
        body={trimmedBody || t('messages.preview.placeholderBody')}
        meta={meta ?? `${schoolName} · ${t('messages.preview.now')}`}
        important={important}
      />
      <div className="space-y-2 pt-2 opacity-40" aria-hidden>
        <div className="h-14 rounded-2xl bg-white/[0.05]" />
        <div className="h-10 rounded-2xl bg-white/[0.04]" />
      </div>
    </PhoneMockup>
  );
}
