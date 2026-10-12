'use client';

import { useCallback, useEffect, useMemo, useRef } from 'react';
import { toast } from 'sonner';

import { useSession } from '@/auth/use-session';
import { getClockState, restartMorning, scenarioEnded } from '@/data/mock/clock';
import { getTables } from '@/data/mock/db';
import { useI18n } from '@/i18n';
import type { ArrivalViewer } from './arrivals';
import { runEngineTick } from './tick';
import { useArrivalToasts } from './use-arrival-toasts';

const TICK_MS = 1000;
const DAY_ENDED_TOAST_ID = 'demo-day-ended';

/** 19:00 da bir marta — doimiy toast "Demo kuni yakunlandi" + "Qayta boshlash". */
function useDayEndedNotice(): () => void {
  const i18n = useI18n();
  const i18nRef = useRef(i18n);
  useEffect(() => {
    i18nRef.current = i18n;
  }, [i18n]);
  const shownForEpoch = useRef<number | null>(null);

  return useCallback(() => {
    const { epoch } = getClockState();
    if (!scenarioEnded()) {
      if (shownForEpoch.current !== null) toast.dismiss(DAY_ENDED_TOAST_ID);
      shownForEpoch.current = null;
      return;
    }
    if (shownForEpoch.current === epoch) return;
    shownForEpoch.current = epoch;
    const { t } = i18nRef.current;
    toast.info(t('demo.dayEnded'), {
      id: DAY_ENDED_TOAST_ID,
      description: t('demo.dayEndedHint'),
      duration: Number.POSITIVE_INFINITY,
      action: { label: t('demo.restart'), onClick: () => restartMorning() },
    });
  }, []);
}

/**
 * Jonli simulyator: har soniyada demo vaqtini tekshiradi, yangi daqiqa bo'lsa
 * kirish/chiqishlar, test natijalari va so'rovnoma javoblarini bazaga yozadi.
 * Birinchi "yetib olish"da (sahifa 10:00 da ochilsa, ertalab qayta boshlansa)
 * toast ko'rsatilmaydi; kelish toast'lari rol va doiraga mos.
 */
export function DemoEngine() {
  const session = useSession();
  const viewer = useMemo<ArrivalViewer | null>(() => {
    if (!session) return null;
    const staff = getTables().staff.find((s) => s.id === session.staffId);
    return { role: session.role, classIds: staff?.classIds ?? [] };
  }, [session]);
  const announceArrivals = useArrivalToasts(viewer);
  const checkDayEnded = useDayEndedNotice();

  useEffect(() => {
    if (!session) return;
    const lastKey = { current: '' };
    let warmedUp = false;
    const tick = () => {
      checkDayEnded();
      const result = runEngineTick(lastKey);
      if (!result) return;
      if (!warmedUp || result.catchingUp) {
        warmedUp = true;
        return;
      }
      announceArrivals(result.events);
    };
    tick();
    const id = setInterval(tick, TICK_MS);
    return () => clearInterval(id);
  }, [session, announceArrivals, checkDayEnded]);

  return null;
}
