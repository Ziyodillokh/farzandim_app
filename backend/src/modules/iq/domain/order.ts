// Sessiya savollari tartibi (docs/IQ-REJA.md §8). Har tur ichida qiyinlik
// o'sadi, turlar test bo'ylab bir tekis taqsimlanadi — bola bir xil turdagi
// savollardan zerikmaydi: rasm, son, rasm, so'z, rasm, mantiq...
// Bitta turli (rasmli A/B) forma uchun natija oddiy `b` o'sishi bilan bir xil.

import { IQ_ITEM_KINDS, IqItemKind } from './bank';

export interface OrderableItem {
  id: string;
  externalId: string;
  kind: IqItemKind;
  b: number;
}

/** Tur fazasi: matnli turlar bir-biriga yopishmasin (so'z oldinroq, mantiq keyinroq). */
const PHASE: Readonly<Record<IqItemKind, number>> = { FIGURAL: 0.5, NUMERIC: 0.5, VERBAL: 0.25, LOGIC: 0.75 };

const byDifficulty = (a: OrderableItem, b: OrderableItem) => a.b - b.b || a.externalId.localeCompare(b.externalId);

export function orderSessionItems(items: readonly OrderableItem[]): string[] {
  const placed = IQ_ITEM_KINDS.flatMap((kind, kindIndex) => {
    const own = items.filter((it) => it.kind === kind).sort(byDifficulty);
    return own.map((it, i) => ({ it, at: (i + PHASE[kind]) / own.length, kindIndex }));
  });
  return placed
    .sort((x, y) => x.at - y.at || x.kindIndex - y.kindIndex || byDifficulty(x.it, y.it))
    .map(({ it }) => it.id);
}
