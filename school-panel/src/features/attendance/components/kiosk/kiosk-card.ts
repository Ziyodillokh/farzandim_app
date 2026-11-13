import type { CardTapView } from '@/data/contracts';
import type { ToneKind } from '@/features/cards/tone';
import type { KioskOutcome } from './kiosk-result';

/** Karta tegishi natijasi → kiosk kartochkasi (kirdi / takror / chiqdi / rad etildi). */
export function outcomeFromTap(view: CardTapView): KioskOutcome {
  const name = view.student ? `${view.student.lastName} ${view.student.firstName}` : null;
  switch (view.result) {
    case 'IN':
    case 'NONE':
      if (name && view.status) {
        return { kind: 'success', name, className: view.className, status: view.status, time: view.time, already: view.result === 'NONE', suspicious: view.suspicious };
      }
      return { kind: 'card', result: 'UNKNOWN', name };
    case 'OUT':
      return { kind: 'left', name: name ?? '', className: view.className, time: view.time };
    default:
      return { kind: 'card', result: view.result, name };
  }
}

/** Ovoz: kirdi / chiqdi — bitta ton; shubhali yoki navbatda — ogohlantirish; rad — past ton. */
export function toneFor(outcome: KioskOutcome): ToneKind {
  if (outcome.kind === 'success') return outcome.suspicious ? 'warn' : 'ok';
  if (outcome.kind === 'left') return 'ok';
  if (outcome.kind === 'queued') return 'warn';
  return 'fail';
}
