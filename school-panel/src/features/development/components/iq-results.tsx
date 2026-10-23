'use client';

// Parvoz IQ natijalari (docs/IQ-REJA.md §7): sinf bo'yicha joriy natijalar
// (oxirgi 180 kun, umumiy tarix). Psixolog / o'z sinfi rahbari — ism bilan;
// direktor / admin — faqat daraja taqsimoti, 5 nafardan kam bo'lsa yashirin.
// Faqat haqiqiy (http) panelda — demo rejimda ma'lumot yo'q.

import { useQuery } from '@tanstack/react-query';
import { useEffect, useMemo, useState } from 'react';

import { Card, CardContent } from '@/components/ui/card';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Skeleton } from '@/components/ui/skeleton';
import { http } from '@/data/http/client';
import { isHttpMode } from '@/data/source';
import { useClassOptions } from '@/features/students/hooks';
import { useI18n } from '@/i18n';

const BANDS = ['VERY_HIGH', 'HIGH', 'ABOVE_AVERAGE', 'AVERAGE', 'BELOW_AVERAGE', 'LOW', 'VERY_LOW'] as const;
type Band = (typeof BANDS)[number];

type IqDomain = 'FIGURAL' | 'NUMERIC' | 'VERBAL' | 'LOGIC';

interface IqResult {
  correct: number;
  total: number;
  status: 'PROVISIONAL' | 'NORMED';
  percentile: number | null;
  band: Band;
  standardScore: number | null;
  ci95: [number, number] | null;
  completedAt: string;
  /** Aralash formada tur bo'yicha xom natija (rasm / son / so'z / mantiq). */
  domains?: Array<{ kind: IqDomain; right: number; total: number }>;
}

interface IqClassResults {
  className: string;
  mode: 'INDIVIDUAL' | 'AGGREGATE';
  students: number;
  linked: number;
  completed: number;
  bands: Record<Band, number> | null;
  suppressed: boolean;
  rows: Array<{ studentId: string; name: string; linked: boolean; result: IqResult | null }>;
}

/** LOW / VERY_LOW — bitta yumshoq yorliq ("Rivojlanish zonasi"). */
const bandKey = (b: Band) => (b === 'LOW' || b === 'VERY_LOW' ? 'growthZone' : b);

export function IqResults() {
  const { t, locale } = useI18n();
  const classes = useClassOptions();
  const [classId, setClassId] = useState<string>();
  const options = useMemo(() => (classes.data ?? []) as Array<{ id: string; name: string }>, [classes.data]);

  useEffect(() => {
    if (!classId && options.length > 0) setClassId(options[0].id);
  }, [classId, options]);

  const results = useQuery({
    queryKey: ['iq-results', classId],
    enabled: isHttpMode && !!classId,
    queryFn: () => http<IqClassResults>('GET', '/school/assessments/iq/results', { query: { classId: classId! } }),
  });

  if (!isHttpMode) {
    return <p className="text-sm text-muted-foreground">{t('development.iqSchool.demoOnly')}</p>;
  }
  const data = results.data;
  const day = (iso: string) => new Date(iso).toLocaleDateString(locale === 'ru' ? 'ru-RU' : 'uz-UZ');

  return (
    <div className="space-y-4" data-testid="iq-results">
      <div className="flex flex-wrap items-center gap-3">
        <h2 className="text-lg font-semibold">{t('development.iqSchool.title')}</h2>
        <Select value={classId} onValueChange={setClassId}>
          <SelectTrigger className="w-40" aria-label={t('development.iqSchool.class')}>
            <SelectValue placeholder={t('development.iqSchool.class')} />
          </SelectTrigger>
          <SelectContent>
            {options.map((c) => (
              <SelectItem key={c.id} value={c.id}>{c.name}</SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>
      <p className="text-sm text-muted-foreground">{t('development.iqSchool.hint')}</p>

      {results.isLoading ? (
        <Skeleton className="h-40 w-full rounded-2xl" />
      ) : results.isError ? (
        <p className="text-sm text-destructive">{t('development.iqSchool.error')}</p>
      ) : !data ? null : (
        <Card>
          <CardContent className="space-y-4 p-4 sm:p-6">
            <p className="text-sm">
              {t('development.iqSchool.summary', { completed: data.completed, linked: data.linked, students: data.students })}
            </p>
            {data.suppressed ? (
              <p className="text-sm text-muted-foreground">{t('development.iqSchool.suppressed')}</p>
            ) : data.bands ? (
              <ul className="grid gap-1.5 sm:grid-cols-2">
                {BANDS.filter((b) => b !== 'VERY_LOW').map((b) => {
                  const n = b === 'LOW' ? data.bands!.LOW + data.bands!.VERY_LOW : data.bands![b];
                  return (
                    <li key={b} className="flex justify-between rounded-lg bg-muted/40 px-3 py-1.5 text-sm">
                      <span>{t(`development.iqSchool.band.${bandKey(b)}`)}</span>
                      <span className="font-semibold tabular-nums">{n}</span>
                    </li>
                  );
                })}
              </ul>
            ) : null}
            {data.mode === 'INDIVIDUAL' && data.rows.length > 0 && (
              <div className="overflow-x-auto">
                <table className="w-full min-w-[520px] text-sm">
                  <thead className="text-left text-xs uppercase text-muted-foreground">
                    <tr>
                      <th className="py-2 pr-3">{t('development.iqSchool.col.student')}</th>
                      <th className="py-2 pr-3">{t('development.iqSchool.col.band')}</th>
                      <th className="py-2 pr-3">{t('development.iqSchool.col.percentile')}</th>
                      <th className="py-2 pr-3">{t('development.iqSchool.col.score')}</th>
                      <th className="py-2">{t('development.iqSchool.col.date')}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {data.rows.map((r) => (
                      <tr key={r.studentId} className="border-t border-border/60">
                        <td className="py-2 pr-3 font-medium">{r.name}</td>
                        {r.result ? (
                          <>
                            <td className="py-2 pr-3">
                              {t(`development.iqSchool.band.${bandKey(r.result.band)}`)}
                              {r.result.domains && (
                                <span className="block text-xs text-muted-foreground tabular-nums">
                                  {r.result.domains
                                    .map((d) => `${t(`development.iqSchool.domain.${d.kind}`)} ${d.right}/${d.total}`)
                                    .join(' · ')}
                                </span>
                              )}
                            </td>
                            <td className="py-2 pr-3 tabular-nums">{r.result.percentile ?? '—'}</td>
                            <td className="py-2 pr-3 tabular-nums">
                              {r.result.status === 'NORMED' && r.result.standardScore !== null
                                ? `${r.result.standardScore}${r.result.ci95 ? ` (${r.result.ci95[0]}–${r.result.ci95[1]})` : ''}`
                                : t('development.iqSchool.provisional')}
                            </td>
                            <td className="py-2 tabular-nums">{day(r.result.completedAt)}</td>
                          </>
                        ) : (
                          <td className="py-2 text-muted-foreground" colSpan={4}>
                            {r.linked ? t('development.iqSchool.notTaken') : t('development.iqSchool.notLinked')}
                          </td>
                        )}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </CardContent>
        </Card>
      )}
    </div>
  );
}
