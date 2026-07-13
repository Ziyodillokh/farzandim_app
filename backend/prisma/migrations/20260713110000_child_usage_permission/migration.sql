-- Child: PACKAGE_USAGE_STATS ("Foydalanish ma'lumotlari") ruxsat holati.
-- null = noma'lum, true = berilgan, false = yo'q. Ota-onaga ekran vaqti
-- bo'sh sababini aniq ko'rsatish uchun (ulanish emas, ruxsat).
ALTER TABLE "children" ADD COLUMN "usage_permission" BOOLEAN;
