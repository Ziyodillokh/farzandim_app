-- Bolaning TUG'ILGAN SANASI. Avval faqat `age` saqlanardi va ilovalar
-- yoshdan soxta "01.01.YYYY" yasab ko'rsatardi (foydalanuvchi shikoyati).
--
-- DATE (DateTime emas): sana-only, aks holda Toshkent UTC+5 da bir kun
-- siljiydi. Nullable — mavjud bolalarda ma'lumot yo'q, UI bo'sh ko'rsatadi.
-- `age` ustuni O'CHIRILMAYDI: u kontent/olimpiada/push filtrlarida ishlatiladi.

ALTER TABLE "children" ADD COLUMN "birth_date" DATE;
