import { DONUT_COLORS } from '@/components/charts/donut';

/**
 * Hayot sahifalari uchun umumiy toifaviy ranglar (dataviz validatori bilan
 * tekshirilgan: qo'shni juftliklar rang ko'rligida ham ajraladi). Qizil yo'q.
 * Jins ranglari boshqa yo'nalish sahifalari (o'zlashtirish, IQ) bilan bir xil.
 */
export const GENDER_COLORS = { M: DONUT_COLORS[0], F: DONUT_COLORS[1] } as const;
