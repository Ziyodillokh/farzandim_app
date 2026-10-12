/**
 * "Aurora glass" dizayni uchun aloqa modullari (xabarlar, eslatmalar, ota-onalar)
 * umumiy klasslari. Tailwind to'liq satrlarni ko'radi — dinamik yig'ilmaydi.
 */

/** Shisha karta ichidagi plitka. */
export const INNER_TILE = 'rounded-xl bg-white/50 ring-1 ring-inset ring-border/60 dark:bg-white/[0.03]';

/** Bosiladigan plitka (tanlanmagan holat). */
export const TILE_BUTTON = `${INNER_TILE} transition-all hover:ring-primary/40 hover:bg-white/70 dark:hover:bg-white/[0.06]`;

/** Tanlangan chip / variant — kichik matnda ham kontrast yetarli (qattiq bg-primary emas). */
export const SELECTED_SOFT = 'bg-primary/15 text-primary ring-1 ring-inset ring-primary/30';

/** Tanlangan katta plitka (auditoriya turi, eslatma turi). */
export const SELECTED_TILE = 'rounded-xl bg-primary/[0.08] ring-1 ring-inset ring-primary/40 dark:bg-primary/[0.12]';

/** Segmentli tanlov konteyneri — `TabsList` bilan bir xil. */
export const SEGMENT_TRACK = 'inline-flex rounded-xl bg-primary/[0.06] p-1 ring-1 ring-inset ring-border/50 dark:bg-white/[0.04]';

/** Ikonka plitkasi ohanglari (faqat ko'k / osmon / feruza + ma'noli holatlar). */
export const ICON_TONES = {
  primary: 'bg-primary/10 text-primary ring-1 ring-inset ring-primary/20',
  sky: 'bg-sky-500/10 text-sky-600 ring-1 ring-inset ring-sky-500/20 dark:text-sky-400',
  cyan: 'bg-cyan-500/10 text-cyan-700 ring-1 ring-inset ring-cyan-500/20 dark:text-cyan-400',
  success: 'bg-success/10 text-success ring-1 ring-inset ring-success/20',
  warning: 'bg-warning/15 text-warning ring-1 ring-inset ring-warning/25',
  muted: 'bg-muted text-muted-foreground ring-1 ring-inset ring-border',
} as const;

export type IconTone = keyof typeof ICON_TONES;

/** Muhim / ochiq yozuvlar uchun burchakdagi yumshoq iliq nur (chap chegara o'rniga). */
export const WARM_GLOW = 'pointer-events-none absolute inset-0 bg-[radial-gradient(120%_70%_at_0%_0%,hsl(var(--warning)/0.13),transparent_55%)]';

/** Brend nuri (callout, preview paneli). */
export const BRAND_GLOW = 'pointer-events-none absolute inset-0 bg-[radial-gradient(90%_120%_at_0%_0%,hsl(var(--primary)/0.12),transparent_60%)]';
