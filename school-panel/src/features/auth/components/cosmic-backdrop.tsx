import { withBase } from '@/lib/base-path';

/** Yulduzlar — bitta qatlam, animatsiyasiz (sekin noutbuklarda ham yengil). */
const STARS = [
  '8% 12%', '17% 31%', '26% 8%', '33% 46%', '41% 19%', '52% 6%', '61% 28%', '9% 58%', '22% 72%', '38% 64%', '47% 88%', '14% 90%',
]
  .map((at, i) => `radial-gradient(${i % 3 === 0 ? 1.5 : 1}px ${i % 3 === 0 ? 1.5 : 1}px at ${at}, rgba(255,255,255,${i % 2 ? 0.55 : 0.85}), transparent)`)
  .join(',');

/**
 * Login foni: kosmos (#060A15 — suratdagi osmon bilan bir xil), yulduzlar va orbitadan
 * Yer (Parvoz saytidagi surat). Statik HTML'ga tushadi — gidratatsiyadan oldin ko'rinadi.
 */
export function CosmicBackdrop() {
  return (
    <div aria-hidden className="pointer-events-none fixed inset-0 -z-10 overflow-hidden bg-brand-950">
      <div className="absolute inset-0" style={{ backgroundImage: STARS }} />
      {/* eslint-disable-next-line @next/next/no-img-element -- basePath'li statik surat */}
      <img
        src={withBase('/brand/earth-orbit.jpg')}
        alt=""
        decoding="async"
        fetchPriority="high"
        className="absolute inset-x-0 bottom-0 h-[78%] w-full object-cover object-[50%_45%] opacity-95 [mask-image:linear-gradient(180deg,transparent,black_35%)] lg:inset-y-0 lg:left-auto lg:right-0 lg:h-full lg:w-[62%] lg:object-[50%_62%] lg:[mask-image:linear-gradient(90deg,transparent,black_30%)]"
      />
      <div className="absolute -left-40 -top-40 h-[34rem] w-[34rem] rounded-full bg-[radial-gradient(closest-side,rgba(60,130,255,0.22),transparent)]" />
      <div className="absolute bottom-0 right-0 h-[60%] w-[70%] bg-[radial-gradient(60%_60%_at_70%_70%,rgba(80,138,255,0.18),transparent)]" />
      <div className="absolute inset-x-0 bottom-0 h-40 bg-gradient-to-t from-brand-950/80 to-transparent" />
    </div>
  );
}
