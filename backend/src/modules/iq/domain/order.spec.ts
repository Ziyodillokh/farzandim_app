import { IqItemKind } from './bank';
import { OrderableItem, orderSessionItems } from './order';

const make = (kind: IqItemKind, n: number, b0: number): OrderableItem[] =>
  Array.from({ length: n }, (_, i) => ({ id: `${kind[0]}${i}`, externalId: `x-${kind}-${i}`, kind, b: b0 + (n - i) * 0.1 }));

describe('IQ sessiya tartibi', () => {
  it("bitta turli forma — oddiy b o'sishi (teng b — externalId)", () => {
    const items = [...make('FIGURAL', 5, 0), { id: 'tie', externalId: 'a-first', kind: 'FIGURAL' as const, b: 0.5 }];
    const order = orderSessionItems(items);
    const bs = order.map((id) => items.find((i) => i.id === id)!.b);
    expect([...bs].sort((a, b) => a - b)).toEqual(bs);
    expect(order.indexOf('tie')).toBe(order.indexOf('F0') - 1);
  });

  it("aralash forma: turlar bir tekis, har tur ichida osondan qiyinga", () => {
    const items = [...make('LOGIC', 3, 0), ...make('NUMERIC', 4, 0), ...make('FIGURAL', 10, -1), ...make('VERBAL', 3, 0)];
    const order = orderSessionItems(items);
    const byId = new Map(items.map((i) => [i.id, i]));
    expect(order.map((id) => byId.get(id)!.kind[0]).join('')).toBe('FVNFFLFNVFFLNFFVFNLF');
    for (const kind of ['FIGURAL', 'NUMERIC', 'VERBAL', 'LOGIC']) {
      const bs = order.filter((id) => byId.get(id)!.kind === kind).map((id) => byId.get(id)!.b);
      expect([...bs].sort((a, b) => a - b)).toEqual(bs);
    }
    expect(orderSessionItems([...items].reverse())).toEqual(order);
  });
});
