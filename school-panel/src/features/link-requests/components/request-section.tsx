'use client';

import type { ReactNode } from 'react';

import { Badge } from '@/components/ui/badge';
import { Card } from '@/components/ui/card';
import type { LinkRequest } from '@/data/contracts';
import { useI18n } from '@/i18n';
import type { LinkDecision } from '../hooks';
import { RequestCard } from './request-card';

/** Sarlavhali bo'lim (tekshiruv kutayotganlar / tuzatish so'rovlari) va uning so'rovlari. */
export function RequestSection({
  id,
  icon,
  title,
  description,
  requests,
  onDecide,
}: {
  id: string;
  icon: ReactNode;
  title: string;
  description: string;
  requests: LinkRequest[];
  onDecide: (request: LinkRequest, decision: LinkDecision) => void;
}) {
  const { formatNumber } = useI18n();
  return (
    <section aria-labelledby={id}>
      <Card className="overflow-hidden">
        <div className="flex items-start gap-3 border-b border-border/50 px-5 py-4 dark:border-white/[0.06]">
          <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary ring-1 ring-inset ring-primary/15 [&_svg]:size-[18px]">{icon}</span>
          <div className="min-w-0">
            <h2 id={id} className="text-[0.95rem] font-semibold tracking-[-0.005em]">
              {title}
              <Badge variant="default" size="sm" className="ml-2 align-middle tabular-nums">
                {formatNumber(requests.length)}
              </Badge>
            </h2>
            <p className="mt-0.5 text-sm text-muted-foreground">{description}</p>
          </div>
        </div>
        <ul className="space-y-2 p-4">
          {requests.map((request) => (
            <RequestCard key={request.id} request={request} onDecide={onDecide} />
          ))}
        </ul>
      </Card>
    </section>
  );
}
