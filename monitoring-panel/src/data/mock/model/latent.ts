/**
 * Demo modelning yashirin omillari. Har hudud uchun qo'lda sozlangan (0..1):
 *  - urban — shaharlashuv (rasmiy ulushga yaqin);
 *  - resource — maktab resurslari va o'qituvchilar malakasi (proksi);
 *  - digital — internet va qurilmalar;
 *  - climate — maktab muhiti (farovonlik);
 *  - coverage — Parvoz monitoringi qamrovi (namoyish uchun kelajak ko'rinishi);
 *  - agro — qishloq xo'jaligi ulushi (kasbiy qiziqishlarga ta'sir).
 * Tumanlar uchun hudud qiymati atrofida kichik, nolga markazlangan og'ishlar.
 * Farqlar ataylab o'rtacha: bu namoyish, hech bir hudud haqida xulosa emas.
 */
import { DISTRICTS_WITHOUT_GEOMETRY, UZ_DISTRICT_SHAPES } from '@/data/geo/uz-districts';
import { REGION_IDS, type RegionId } from '@/data/reference/regions';
import { unitHash } from '@/lib/rng';

export type Latent = {
  urban: number;
  resource: number;
  digital: number;
  climate: number;
  coverage: number;
  agro: number;
};

export const REGION_LATENT: Readonly<Record<RegionId, Latent>> = {
  'UZ-QR': { urban: 0.49, resource: 0.44, digital: 0.5, climate: 0.61, coverage: 0.54, agro: 0.6 },
  'UZ-AN': { urban: 0.53, resource: 0.6, digital: 0.6, climate: 0.7, coverage: 0.66, agro: 0.6 },
  'UZ-BU': { urban: 0.37, resource: 0.6, digital: 0.58, climate: 0.72, coverage: 0.63, agro: 0.56 },
  'UZ-JI': { urban: 0.47, resource: 0.49, digital: 0.53, climate: 0.64, coverage: 0.57, agro: 0.66 },
  'UZ-QA': { urban: 0.43, resource: 0.46, digital: 0.51, climate: 0.61, coverage: 0.55, agro: 0.63 },
  'UZ-NW': { urban: 0.5, resource: 0.65, digital: 0.66, climate: 0.69, coverage: 0.68, agro: 0.46 },
  'UZ-NG': { urban: 0.6, resource: 0.55, digital: 0.6, climate: 0.65, coverage: 0.62, agro: 0.55 },
  'UZ-SA': { urban: 0.37, resource: 0.56, digital: 0.57, climate: 0.67, coverage: 0.64, agro: 0.6 },
  'UZ-SU': { urban: 0.36, resource: 0.44, digital: 0.48, climate: 0.6, coverage: 0.52, agro: 0.68 },
  'UZ-SI': { urban: 0.44, resource: 0.5, digital: 0.54, climate: 0.63, coverage: 0.57, agro: 0.7 },
  'UZ-TO': { urban: 0.55, resource: 0.62, digital: 0.7, climate: 0.66, coverage: 0.71, agro: 0.46 },
  'UZ-FA': { urban: 0.57, resource: 0.58, digital: 0.62, climate: 0.68, coverage: 0.67, agro: 0.55 },
  'UZ-XO': { urban: 0.34, resource: 0.57, digital: 0.55, climate: 0.74, coverage: 0.61, agro: 0.62 },
  'UZ-TK': { urban: 1, resource: 0.95, digital: 0.95, climate: 0.6, coverage: 0.82, agro: 0.04 },
};

export type DistrictRef = {
  id: string;
  name: string;
  regionId: RegionId;
  /** Hudud o'quvchilaridagi ulushi (yig'indisi 1). */
  weight: number;
  /** Xaritada chegarasi bormi (2020 yildan keyin tuzilganlarda yo'q). */
  hasShape: boolean;
  latent: Latent;
};

const clamp01 = (v: number) => Math.min(1, Math.max(0, v));
/** [-1, 1) barqaror shovqin. */
export const signedNoise = (...parts: Array<string | number>) => unitHash(...parts) * 2 - 1;

function buildDistricts(regionId: RegionId): DistrictRef[] {
  const shapes = UZ_DISTRICT_SHAPES[regionId]?.districts ?? [];
  const missing = DISTRICTS_WITHOUT_GEOMETRY[regionId] ?? [];
  const raw = [
    ...shapes.map((d) => ({ id: d.id, name: d.name, hasShape: true })),
    ...missing.map((name, i) => ({ id: `${regionId}-new-${i + 1}`, name, hasShape: false })),
  ];
  const base = REGION_LATENT[regionId];
  const weights = raw.map((d) => {
    const city = /shahri/i.test(d.name) ? 1.3 : 1;
    return (0.55 + unitHash('w', d.id) * 0.9) * city;
  });
  const total = weights.reduce((a, b) => a + b, 0) || 1;
  // Og'ishlar: avval tasodifiy, keyin hudud bo'yicha vaznli o'rtachasi nolga keltiriladi.
  const keys = ['urban', 'resource', 'digital', 'climate', 'coverage', 'agro'] as const;
  const offsets = raw.map((d) => {
    const city = /shahri/i.test(d.name);
    return Object.fromEntries(
      keys.map((k) => {
        let o = signedNoise('lat', k, d.id) * 0.06;
        if (city && (k === 'urban' || k === 'digital' || k === 'resource')) o += 0.05;
        if (city && k === 'agro') o -= 0.08;
        return [k, o];
      }),
    ) as Record<(typeof keys)[number], number>;
  });
  const mean = Object.fromEntries(
    keys.map((k) => [k, offsets.reduce((s, o, i) => s + o[k] * (weights[i] as number), 0) / total]),
  ) as Record<(typeof keys)[number], number>;
  return raw.map((d, i) => ({
    ...d,
    regionId,
    weight: (weights[i] as number) / total,
    latent: Object.fromEntries(keys.map((k) => [k, clamp01(base[k] + (offsets[i] as Record<string, number>)[k]! - mean[k])])) as Latent,
  }));
}

const DISTRICTS: Readonly<Record<RegionId, readonly DistrictRef[]>> = Object.fromEntries(
  REGION_IDS.map((id) => [id, buildDistricts(id)]),
) as unknown as Record<RegionId, readonly DistrictRef[]>;

export function districtsOf(regionId: RegionId): readonly DistrictRef[] {
  return DISTRICTS[regionId];
}

export function findDistrict(id: string): DistrictRef | undefined {
  for (const regionId of REGION_IDS) {
    const d = DISTRICTS[regionId].find((x) => x.id === id);
    if (d) return d;
  }
  return undefined;
}
