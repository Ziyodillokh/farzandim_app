'use client';

import type { ReactNode } from 'react';
import { Lock } from 'lucide-react';
import { LOCKED_FIELD_LABELS } from '@/lib/constants/kelajak';
import type { KelajakQuestion } from '@/types/api.types';

/** Javob berilgan savol — nimalar o'zgarmasligini tushuntiradi (§6). */
export function LockNotice({ answerCount }: { answerCount: number }) {
  return (
    <div className="flex gap-3 rounded-lg border border-warning/30 bg-warning/10 px-3 py-2.5 text-sm">
      <Lock className="mt-0.5 h-4 w-4 shrink-0 text-warning" />
      <p className="text-foreground">
        Bu savolga <span className="font-semibold tabular-nums">{answerCount}</span> marta javob
        berilgan. Natijalar buzilmasligi uchun {LOCKED_FIELD_LABELS.join(', ')} o&apos;zgarmaydi.
        Matn, izohlar, majburiylik va faollikni o&apos;zgartirish mumkin. Boshqa o&apos;zgarish
        kerak bo&apos;lsa, savolni nofaol qilib yangisini qo&apos;shing.
      </p>
    </div>
  );
}

/** Faqat o'qish uchun: manba, javoblar soni, ball hisoblash va sanalar. */
export function QuestionMeta({ question: q }: { question: KelajakQuestion }) {
  return (
    <section className="space-y-3">
      <h3 className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
        Manba va statistika
      </h3>
      <dl className="grid grid-cols-1 gap-x-4 gap-y-2 rounded-lg border border-border bg-muted/20 p-3 text-sm sm:grid-cols-2">
        <MetaItem label="Tashqi ID"><span className="font-mono">{q.externalId}</span></MetaItem>
        <MetaItem label="Javoblar soni"><span className="tabular-nums">{q.answerCount}</span></MetaItem>
        <MetaItem label="Manba turi">{q.sourceType}</MetaItem>
        <MetaItem label="Manba">{q.sourceName}</MetaItem>
        <MetaItem label="Manba versiyasi">{q.sourceVersion}</MetaItem>
        <MetaItem label="Ball hisoblash">{formatScoring(q.scoring)}</MetaItem>
        <MetaItem label="Yaratilgan">{formatDateTime(q.createdAt)}</MetaItem>
        <MetaItem label="Yangilangan">{formatDateTime(q.updatedAt)}</MetaItem>
      </dl>
    </section>
  );
}

function MetaItem({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="min-w-0">
      <dt className="text-2xs font-medium uppercase tracking-wider text-muted-foreground">{label}</dt>
      <dd className="break-words">{children}</dd>
    </div>
  );
}

function formatScoring(scoring: Record<string, unknown> | null): string {
  if (!scoring) return '—';
  const entries = Object.entries(scoring);
  if (entries.length === 0) return '—';
  return entries
    .map(([key, value]) => `${key}: ${typeof value === 'object' ? JSON.stringify(value) : String(value)}`)
    .join(' · ');
}

function formatDateTime(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '—';
  return new Intl.DateTimeFormat('uz-UZ', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(d);
}
