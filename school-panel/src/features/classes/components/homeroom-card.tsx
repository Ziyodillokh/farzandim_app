'use client';

import { ChevronRight, Mail, Phone, UserRoundCheck, UserRoundX } from 'lucide-react';
import type { ReactNode } from 'react';

import { EmptyState } from '@/components/common/empty-state';
import { SectionCard } from '@/components/common/section-card';
import { StaffAvatar } from '@/components/common/staff-avatar';
import { Badge } from '@/components/ui/badge';
import type { ClassHomeroom } from '@/data/mock/services/classes';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { INNER_TILE } from '../styles';

function ContactRow({ href, icon, label, value }: { href: string; icon: ReactNode; label: string; value: string }) {
  return (
    <a
      href={href}
      aria-label={label}
      className={cn(
        'group flex items-center gap-3 px-3 py-2.5 text-sm transition-colors hover:ring-primary/40 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring',
        INNER_TILE,
      )}
    >
      <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-primary [&_svg]:h-4 [&_svg]:w-4">{icon}</span>
      <span className="min-w-0 flex-1 truncate tabular-nums">{value}</span>
      <ChevronRight className="h-4 w-4 text-muted-foreground transition-transform group-hover:translate-x-0.5" />
    </a>
  );
}

export function HomeroomCard({ homeroom }: { homeroom: ClassHomeroom | null }) {
  const { t } = useI18n();
  return (
    <SectionCard icon={<UserRoundCheck />} title={t('classes.view.homeroomTitle')}>
      {homeroom ? (
        <div className="space-y-4">
          <div className="flex items-center gap-3.5">
            <StaffAvatar staffId={homeroom.id} name={homeroom.fullName} size="lg" className="ring-2 ring-primary/15 ring-offset-2 ring-offset-background" />
            <div className="min-w-0">
              <div className="flex flex-wrap items-center gap-2">
                <span className="truncate font-semibold">{homeroom.fullName}</span>
                {!homeroom.active && (
                  <Badge variant="secondary" size="sm">
                    {t('classes.view.inactive')}
                  </Badge>
                )}
              </div>
              <p className="truncate text-sm text-muted-foreground">{homeroom.position}</p>
            </div>
          </div>
          <div className="grid gap-2">
            <ContactRow href={`tel:${homeroom.phone.replace(/\s/g, '')}`} icon={<Phone />} label={t('classes.view.call')} value={homeroom.phone} />
            {homeroom.email && <ContactRow href={`mailto:${homeroom.email}`} icon={<Mail />} label={t('classes.view.write')} value={homeroom.email} />}
          </div>
        </div>
      ) : (
        <EmptyState icon={<UserRoundX />} title={t('classes.card.noHomeroom')} className="py-6" />
      )}
    </SectionCard>
  );
}
