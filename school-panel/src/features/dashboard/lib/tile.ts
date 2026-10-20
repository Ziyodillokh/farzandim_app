/**
 * "Aurora glass" ichki plitkalari — glass karta ichidagi qator va bloklar uchun.
 * Bosh sahifa, Bola ovozi va Growth Learning bir xil uslubdan foydalanadi.
 */
export const TILE = 'rounded-xl bg-white/50 ring-1 ring-inset ring-border/60 dark:bg-white/[0.03]';

/** Bosiladigan plitka (havola, tugma) — yumshoq hover. */
export const TILE_INTERACTIVE = `${TILE} transition-colors hover:bg-white/80 hover:ring-primary/30 dark:hover:bg-white/[0.06]`;

/** Kichik ikonka "chip"i (ro'yxat qatorlari boshida). */
export const ICON_CHIP = 'flex shrink-0 items-center justify-center rounded-xl ring-1 ring-inset';
