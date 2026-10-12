'use client';

import { Check, CheckCircle2, Clock, Eye, RotateCcw } from 'lucide-react';
import { useEffect, useState } from 'react';

import type { PsychItem, PsychTest } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

type Stage = 'intro' | 'stimulus' | 'question' | 'done';
type Answer = string | number | number[] | null;
const LIKERT = [1, 2, 3, 4, 5] as const;

const OPTION = 'flex w-full items-center gap-2.5 rounded-xl border px-3 py-2.5 text-left text-[13px] leading-snug transition-colors';
const OPTION_OFF = 'border-white/10 bg-white/[0.06] hover:bg-white/[0.1]';
const OPTION_ON = 'border-sky-400/70 bg-sky-400/20';

function hasStimulus(item: PsychItem | undefined): item is Extract<PsychItem, { type: 'SINGLE' }> & { stimulus: NonNullable<Extract<PsychItem, { type: 'SINGLE' }>['stimulus']> } {
  return item?.type === 'SINGLE' && Boolean(item.stimulus);
}

function Choices({ item, answer, onAnswer }: { item: PsychItem; answer: Answer; onAnswer: (a: Answer) => void }) {
  const { t, locale } = useI18n();
  if (item.type === 'LIKERT') {
    return (
      <div className="space-y-1.5">
        {LIKERT.map((v) => (
          <button key={v} type="button" onClick={() => onAnswer(v)} className={cn(OPTION, answer === v ? OPTION_ON : OPTION_OFF)}>
            <span className="flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-white/10 text-[11px] font-semibold">{v}</span>
            {t(`assessments.likert.${v}`)}
          </button>
        ))}
      </div>
    );
  }
  const multi = item.type === 'MULTI';
  const picked = Array.isArray(answer) ? answer : [];
  return (
    <div className="space-y-1.5">
      {multi && <p className="text-[11px] text-white/55">{t('assessments.preview.multiHint')}</p>}
      {item.options.map((o, idx) => {
        const on = multi ? picked.includes(idx) : answer === o.key;
        const toggle = () => onAnswer(multi ? (on ? picked.filter((x) => x !== idx) : [...picked, idx]) : o.key);
        return (
          <button key={o.key} type="button" onClick={toggle} className={cn(OPTION, on ? OPTION_ON : OPTION_OFF)} aria-pressed={on}>
            <span className={cn('flex h-5 w-5 shrink-0 items-center justify-center border border-white/30', multi ? 'rounded-md' : 'rounded-full', on && 'border-sky-300 bg-sky-400/80')}>
              {on && <Check className="h-3 w-3" />}
            </span>
            {o.text[locale]}
          </button>
        );
      })}
    </div>
  );
}

/** Telefondagi interaktiv test (demo — hech narsa saqlanmaydi). */
export function PhoneRunner({ test }: { test: PsychTest }) {
  const { t, tc, locale } = useI18n();
  const [stage, setStage] = useState<Stage>('intro');
  const [index, setIndex] = useState(0);
  const [answers, setAnswers] = useState<Answer[]>([]);
  const [left, setLeft] = useState(0);
  const item = test.items[index];
  const total = test.items.length;

  const open = (i: number) => {
    const next = test.items[i];
    setIndex(i);
    if (hasStimulus(next)) {
      setLeft(next.stimulus.showSec);
      setStage('stimulus');
    } else {
      setStage('question');
    }
  };

  useEffect(() => {
    if (stage !== 'stimulus') return;
    if (left <= 0) {
      setStage('question');
      return;
    }
    const id = setTimeout(() => setLeft((s) => s - 1), 1000);
    return () => clearTimeout(id);
  }, [stage, left]);

  const restart = () => {
    setAnswers([]);
    setIndex(0);
    setStage('intro');
  };
  const next = () => (index + 1 < total ? open(index + 1) : setStage('done'));

  if (total === 0) return <p className="px-3 py-24 text-center text-sm text-white/60">{t('assessments.preview.empty')}</p>;

  if (stage === 'intro') {
    return (
      <div className="space-y-4 px-1 pt-2">
        <div className="rounded-2xl border border-white/10 bg-white/[0.06] p-4">
          <p className="text-[10px] font-semibold uppercase tracking-wider text-sky-300">{t(`enums.psychKind.${test.kind}`)}</p>
          <p className="mt-1.5 font-display text-lg font-semibold leading-snug">{test.title[locale]}</p>
          <div className="mt-3 flex gap-3 text-[11px] text-white/65">
            <span>{tc('assessments.itemsCount', total)}</span>
            {test.timeLimitMin && (
              <span className="flex items-center gap-1">
                <Clock className="h-3 w-3" />
                {t('assessments.minutes', { count: test.timeLimitMin })}
              </span>
            )}
          </div>
        </div>
        {test.instructions[locale] && <p className="px-1 text-[13px] leading-relaxed text-white/80">{test.instructions[locale]}</p>}
        <button type="button" onClick={() => open(0)} className="w-full rounded-xl bg-brand-gradient py-3 text-sm font-semibold text-white" data-testid="preview-start">
          {t('assessments.preview.start')}
        </button>
      </div>
    );
  }

  if (stage === 'done') {
    return (
      <div className="flex flex-col items-center gap-3 px-3 pt-16 text-center">
        <span className="flex h-16 w-16 items-center justify-center rounded-full bg-sky-400/15 text-sky-300">
          <CheckCircle2 className="h-9 w-9" />
        </span>
        <p className="font-display text-xl font-semibold">{t('assessments.preview.doneTitle')}</p>
        <p className="text-[13px] text-white/75">{t('assessments.preview.doneText')}</p>
        <p className="rounded-full bg-white/[0.08] px-3 py-1 text-[11px] text-white/60">{t('assessments.preview.demoNote')}</p>
        <button type="button" onClick={restart} className="mt-4 flex items-center gap-2 rounded-xl border border-white/15 px-4 py-2 text-sm font-medium">
          <RotateCcw className="h-4 w-4" />
          {t('assessments.preview.restart')}
        </button>
      </div>
    );
  }

  const answer = answers[index] ?? null;
  const progress = Math.round(((index + (stage === 'question' ? 1 : 0.5)) / total) * 100);
  return (
    <div className="space-y-3 px-1">
      <div>
        <div className="flex justify-between text-[11px] text-white/60">
          <span className="truncate pr-2">{test.title[locale]}</span>
          <span className="tabular-nums">{t('assessments.preview.progress', { n: index + 1, total })}</span>
        </div>
        <div className="mt-1.5 h-1.5 overflow-hidden rounded-full bg-white/10">
          <div className="h-full rounded-full bg-gradient-to-r from-sky-400 to-blue-500 transition-all" style={{ width: `${progress}%` }} />
        </div>
      </div>
      {stage === 'stimulus' && hasStimulus(item) ? (
        <div className="space-y-4 pt-6 text-center">
          <p className="flex items-center justify-center gap-1.5 text-xs font-semibold uppercase tracking-wider text-sky-300">
            <Eye className="h-3.5 w-3.5" />
            {t('assessments.preview.remember')}
          </p>
          <p className="rounded-2xl border border-sky-400/30 bg-sky-400/10 px-3 py-6 font-display text-xl font-semibold leading-relaxed">{item.stimulus.text[locale]}</p>
          <p className="text-sm tabular-nums text-white/70">{t('assessments.preview.seconds', { sec: left })}</p>
          <button type="button" onClick={() => setStage('question')} className="text-xs text-white/55 underline-offset-2 hover:underline">
            {t('assessments.preview.next')}
          </button>
        </div>
      ) : (
        item && (
          <>
            <p className="pt-1 text-[15px] font-semibold leading-snug">{item.text[locale]}</p>
            <Choices item={item} answer={answer} onAnswer={(a) => setAnswers((prev) => Object.assign([...prev], { [index]: a }))} />
            <button
              type="button"
              onClick={next}
              disabled={answer === null && item.type !== 'MULTI'}
              className="w-full rounded-xl bg-brand-gradient py-3 text-sm font-semibold text-white transition-opacity disabled:opacity-40"
              data-testid="preview-next"
            >
              {index + 1 < total ? t('assessments.preview.next') : t('assessments.preview.finish')}
            </button>
          </>
        )
      )}
    </div>
  );
}
