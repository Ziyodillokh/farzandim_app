'use client';

import { Mail, Phone, UserRoundX } from 'lucide-react';

import { EmptyState } from '@/components/common/empty-state';
import { SectionCard } from '@/components/common/section-card';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import type { ClassHomeroom } from '@/data/mock/services/classes';
import { useI18n } from '@/i18n';
import { initials } from '@/lib/utils';

export function HomeroomCard({ homeroom }: { homeroom: ClassHomeroom | null }) {
  const { t } = useI18n();
  return (
    <SectionCard title={t('classes.view.homeroomTitle')}>
      {homeroom ? (
        <div className="space-y-4">
          <div className="flex items-center gap-3">
            <Avatar className="h-12 w-12">
              <AvatarFallback className="bg-gradient-to-br from-primary to-primary-glow text-sm font-semibold text-primary-foreground">
                {initials(homeroom.fullName)}
              </AvatarFallback>
            </Avatar>
            <div className="min-w-0">
              <p className="flex flex-wrap items-center gap-2 font-semibold">
                <span className="truncate">{homeroom.fullName}</span>
                {!homeroom.active && <Badge variant="secondary" size="sm">{t('classes.view.inactive')}</Badge>}
              </p>
              <p className="truncate text-sm text-muted-foreground">{homeroom.position}</p>
            </div>
          </div>
          <div className="grid gap-2">
            <Button asChild variant="outline" className="justify-start">
              <a href={`tel:${homeroom.phone.replace(/\s/g, '')}`} aria-label={t('classes.view.call')}>
                <Phone />
                <span className="tabular-nums">{homeroom.phone}</span>
              </a>
            </Button>
            {homeroom.email && (
              <Button asChild variant="outline" className="justify-start">
                <a href={`mailto:${homeroom.email}`} aria-label={t('classes.view.write')}>
                  <Mail />
                  <span className="truncate">{homeroom.email}</span>
                </a>
              </Button>
            )}
          </div>
        </div>
      ) : (
        <EmptyState icon={<UserRoundX />} title={t('classes.card.noHomeroom')} className="py-6" />
      )}
    </SectionCard>
  );
}
