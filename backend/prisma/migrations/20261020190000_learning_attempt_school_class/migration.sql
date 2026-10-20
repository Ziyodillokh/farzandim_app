-- Growth urinishi yakunlanganda bola bog'langan maktab sinfi (snapshot). Maktab
-- hisobotlari (sinf faolligi, K=5 kataklar) shu ustun bo'yicha guruhlanadi:
-- o'quvchini boshqa sinfga ko'chirish yoki ota-onani uzish o'tgan haftalarni
-- o'zgartirmaydi (ayirib bitta bola natijasini tiklab bo'lmaydi). Qo'shuvchi:
-- nullable ustun + indeks; eski urinishlar NULL (maktabga ko'rinmaydi).

-- AlterTable
ALTER TABLE "learning_attempts" ADD COLUMN "school_class_id" TEXT;

-- CreateIndex
CREATE INDEX "learning_attempts_school_class_id_day_idx" ON "learning_attempts"("school_class_id", "day");
