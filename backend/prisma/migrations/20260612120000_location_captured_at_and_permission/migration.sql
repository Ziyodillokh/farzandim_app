-- Lokatsiya: kliyent fix vaqti (offline flush'da server vaqti noto'g'ri bo'ladi)
ALTER TABLE "locations" ADD COLUMN "captured_at" TIMESTAMP(3);

-- Mavjud yozuvlar uchun server vaqti bilan to'ldiramiz (null qolmasin —
-- tarix saralash/filtrlash shu ustunga o'tadi)
UPDATE "locations" SET "captured_at" = "created_at" WHERE "captured_at" IS NULL;

CREATE INDEX "locations_child_id_captured_at_idx" ON "locations"("child_id", "captured_at" DESC);
