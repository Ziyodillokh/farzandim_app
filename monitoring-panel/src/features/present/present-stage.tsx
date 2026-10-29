'use client';

import { ChevronLeft, ChevronRight, Maximize2, Minimize2, Pause, Play, X } from 'lucide-react';
import { useRouter } from 'next/navigation';
import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react';

import { ParvozWordmark } from '@/components/layout/parvoz-wordmark';
import type { MetricKey, Scope } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { InsightsSlide, IqInterestsSlide, KpisSlide, MapSlide, ProblemsSlide, SubjectsSlide, TitleSlide } from './slides';

/** Bitta slayd ekranda turish vaqti. */
const SLIDE_MS = 12_000;
const MAP_TOUR: readonly MetricKey[] = ['mastery', 'wellbeing', 'bullying', 'attendance'];

function useSlides(scope: Scope): ReactNode[] {
  return useMemo(
    () => [
      <TitleSlide key="title" scope={scope} />,
      <KpisSlide key="kpis" scope={scope} />,
      ...MAP_TOUR.map((m) => <MapSlide key={`map-${m}`} scope={scope} metric={m} />),
      <SubjectsSlide key="subjects" scope={scope} />,
      <IqInterestsSlide key="iq" scope={scope} />,
      <ProblemsSlide key="problems" scope={scope} />,
      <InsightsSlide key="insights" scope={scope} />,
    ],
    [scope],
  );
}

function ControlButton({ label, onClick, children }: { label: string; onClick: () => void; children: ReactNode }) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={label}
      title={label}
      className="flex h-9 w-9 items-center justify-center rounded-xl text-white/75 ring-1 ring-inset ring-white/15 transition-colors hover:bg-white/10 hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan-300"
    >
      {children}
    </button>
  );
}

/**
 * Taqdimot sahnasi: har doim qorong'i, slaydlar avtomatik almashadi (12 s),
 * klaviatura: ← → / PageUp PageDown — o'tish, Probel — pauza, F — to'liq ekran.
 */
export function PresentStage({ scope, exitHref }: { scope: Scope; exitHref: string }) {
  const { t } = useI18n();
  const router = useRouter();
  const slides = useSlides(scope);
  const total = slides.length;
  const [index, setIndex] = useState(0);
  const [playing, setPlaying] = useState(true);
  const [fullscreen, setFullscreen] = useState(false);

  const go = useCallback((delta: number) => setIndex((i) => (i + delta + total) % total), [total]);
  const toggleFullscreen = useCallback(() => {
    if (document.fullscreenElement) void document.exitFullscreen?.();
    else void document.documentElement.requestFullscreen?.().catch(() => undefined);
  }, []);

  useEffect(() => {
    if (!playing) return;
    const id = window.setTimeout(() => go(1), SLIDE_MS);
    return () => window.clearTimeout(id);
  }, [index, playing, go]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.metaKey || e.ctrlKey || e.altKey) return;
      if (e.key === 'ArrowRight' || e.key === 'PageDown') go(1);
      else if (e.key === 'ArrowLeft' || e.key === 'PageUp') go(-1);
      else if (e.key === ' ') setPlaying((p) => !p);
      else if (e.key === 'f' || e.key === 'F') toggleFullscreen();
      else return;
      e.preventDefault();
    };
    const onFs = () => setFullscreen(Boolean(document.fullscreenElement));
    window.addEventListener('keydown', onKey);
    document.addEventListener('fullscreenchange', onFs);
    return () => {
      window.removeEventListener('keydown', onKey);
      document.removeEventListener('fullscreenchange', onFs);
    };
  }, [go, toggleFullscreen]);

  return (
    <div className="dark fixed inset-0 z-50 flex flex-col overflow-hidden bg-[#040a17] text-white">
      <div aria-hidden className="pointer-events-none absolute inset-0 bg-[radial-gradient(70%_60%_at_80%_0%,rgba(37,99,235,0.28),transparent),radial-gradient(50%_50%_at_0%_100%,rgba(6,182,212,0.16),transparent)]" />
      <header className="relative flex items-center justify-between gap-3 px-5 pt-4 md:px-10">
        <ParvozWordmark size="sm" sub="MONITORING" tone="onDark" />
        <div className="flex items-center gap-1.5">
          <span className="mr-2 hidden text-xs text-white/40 lg:inline">{t('present.controls.hint')}</span>
          <ControlButton label={t('present.controls.prev')} onClick={() => go(-1)}>
            <ChevronLeft className="h-4 w-4" />
          </ControlButton>
          <ControlButton label={playing ? t('present.controls.pause') : t('present.controls.play')} onClick={() => setPlaying((p) => !p)}>
            {playing ? <Pause className="h-4 w-4" /> : <Play className="h-4 w-4" />}
          </ControlButton>
          <ControlButton label={t('present.controls.next')} onClick={() => go(1)}>
            <ChevronRight className="h-4 w-4" />
          </ControlButton>
          <span className="mx-1.5 min-w-[3.5rem] text-center font-display text-sm tabular-nums text-white/70" aria-live="polite">
            {t('present.controls.counter', { n: index + 1, total })}
          </span>
          <ControlButton label={fullscreen ? t('present.controls.exitFullscreen') : t('present.controls.fullscreen')} onClick={toggleFullscreen}>
            {fullscreen ? <Minimize2 className="h-4 w-4" /> : <Maximize2 className="h-4 w-4" />}
          </ControlButton>
          <ControlButton
            label={t('present.controls.exit')}
            onClick={() => {
              if (document.fullscreenElement) void document.exitFullscreen?.();
              router.push(exitHref);
            }}
          >
            <X className="h-4 w-4" />
          </ControlButton>
        </div>
      </header>
      <main className="relative min-h-0 flex-1 px-5 pb-6 pt-5 md:px-10 md:pb-8">
        <h1 className="sr-only">{t('present.title')}</h1>
        <div key={index} className="h-full animate-fade-in overflow-y-auto">
          {slides[index]}
        </div>
      </main>
      <footer className="relative flex items-center gap-1.5 px-5 pb-4 md:px-10" aria-label={t('present.title')}>
        {slides.map((_, i) => (
          <button
            key={i}
            type="button"
            aria-label={t('present.controls.goTo', { n: i + 1 })}
            aria-current={i === index}
            onClick={() => setIndex(i)}
            className="group relative h-1.5 flex-1 overflow-hidden rounded-full bg-white/12"
          >
            <span
              className={cn('absolute inset-y-0 left-0 rounded-full bg-cyan-300', i < index ? 'w-full' : i > index ? 'w-0' : playing ? 'present-progress' : 'w-1/2')}
              style={i === index && playing ? { animationDuration: `${SLIDE_MS}ms` } : undefined}
            />
          </button>
        ))}
      </footer>
    </div>
  );
}
