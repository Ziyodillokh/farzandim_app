// IQ normalarini noldan qayta hisoblash (docs/IQ-REJA.md §3.6): savollar `b`si
// kalibrovka qilinganda yoki normada shubha bo'lsa. Faqat birinchi yakunlangan
// sessiyalar; har guruh uchun Welford (aralash formalar — alohida "mix:<guruh>").
// Standart: quruq ishga tushirish.
//
//   npx tsx scripts/iq/rebuild-norms.ts          # faqat hisobot
//   npx tsx scripts/iq/rebuild-norms.ts --write  # iq_norms jadvalini almashtirish

import { IqSessionStatus, PrismaClient } from '@prisma/client';
import { normKey } from '../../src/modules/iq/domain/levels';
import { eapAbility, normStats, WelfordRow, welfordAdd } from '../../src/modules/iq/domain/scoring';
import { designCenter, parseStoredResult } from '../../src/modules/iq/iq.views';

async function main(): Promise<void> {
  const write = process.argv.includes('--write');
  const prisma = new PrismaClient();
  try {
    const sessions = await prisma.iqSession.findMany({
      where: {
        status: IqSessionStatus.COMPLETED,
        firstAttempt: true,
        normGroup: { not: null },
      },
      select: { itemIds: true, form: true, normGroup: true, result: true },
    });
    const items = await prisma.iqItem.findMany({
      select: { id: true, b: true },
    });
    const bById = new Map(items.map((i) => [i.id, i.b]));
    const rows = new Map<string, WelfordRow>();
    for (const s of sessions) {
      const stored = parseStoredResult(s.result);
      if (!stored || !s.normGroup) continue;
      const bs = s.itemIds.map((id) => bById.get(id) ?? 0);
      const { theta } = eapAbility(
        stored.responses.map((r, i) => ({ b: bs[i], correct: r === 1 })),
        designCenter(bs),
      );
      const key = normKey(s.form, s.normGroup);
      rows.set(key, welfordAdd(rows.get(key) ?? { n: 0, mean: 0, m2: 0 }, theta));
    }
    for (const [group, row] of [...rows].sort()) {
      const { n, mean, sd } = normStats(row);
      console.log(`${group.padEnd(10)} n=${n} mean=${mean.toFixed(3)} sd=${sd.toFixed(3)}`);
    }
    if (!write) return console.log('Quruq ishga tushirish — yozish uchun --write');
    await prisma.$transaction([
      prisma.iqNorm.deleteMany({}),
      prisma.iqNorm.createMany({
        data: [...rows].map(([group, row]) => ({ group, ...row })),
      }),
    ]);
    console.log(`iq_norms yangilandi: ${rows.size} guruh`);
  } finally {
    await prisma.$disconnect();
  }
}

void main();
