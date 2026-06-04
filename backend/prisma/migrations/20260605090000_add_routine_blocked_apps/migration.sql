-- "Ilova cheklovlar" — jadval (routine) oynasida bloklanadigan ilova paketlari.
-- AlterTable
ALTER TABLE "routines" ADD COLUMN "blocked_apps" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];
