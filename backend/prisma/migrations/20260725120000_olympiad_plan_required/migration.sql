-- Olympiad (test/konkurs) tarif-gating: video/audiobook/book bilan bir xil
-- `plan_required` ustuni. `free` = hamma ko'radi ("Barchasi"). Mavjud testlar
-- default 'free' oladi → xatti-harakat o'zgarmaydi (orqaga to'liq mos).

ALTER TABLE "olympiads" ADD COLUMN "plan_required" TEXT NOT NULL DEFAULT 'free';

-- consumer-olympiads feed'i planRequired bo'yicha filtrlaydi (rank tizimi).
CREATE INDEX "olympiads_plan_required_idx" ON "olympiads"("plan_required");
