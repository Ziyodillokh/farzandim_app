-- AppUsage.hourlyMs — kunlik soatlik taqsimot [24] ms. Schema'da (hourly_ms)
-- e'lon qilingan va backend har upsert'da yozadi, LEKIN uni yaratadigan
-- migratsiya yo'q edi → prod DB'da ustun mavjud emas → har app_usage upsert
-- $transaction'i "column hourly_ms does not exist" bilan fail bo'lardi →
-- bola ekran vaqti UMUMAN saqlanmasdi (ota-onada "ma'lumotlar yig'ilmoqda"da
-- abadiy qotib qolardi). IF NOT EXISTS — dev'da (db push bilan qo'shilgan
-- bo'lsa) ham xavfsiz idempotent.
ALTER TABLE "app_usage" ADD COLUMN IF NOT EXISTS "hourly_ms" JSONB NOT NULL DEFAULT '[]';
