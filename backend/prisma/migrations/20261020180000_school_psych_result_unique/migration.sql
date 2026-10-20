-- Ilova orqali bitta tayinlashga o'quvchidan bitta natija: takroriy yuborishga qarshi
-- DB kafolati (servisdagi qulf bilan birga). CSV importdagi tayinlashsiz natijalar
-- (assignment_id NULL) cheklanmaydi — PostgreSQL'da NULL qiymatlar o'zaro teng emas.
-- Jadval shu tarmoqda yaratilgan (S7b) — prod'da hali yo'q, takrorlar yo'q.

-- CreateIndex
CREATE UNIQUE INDEX "school_psych_results_assignment_id_student_id_key" ON "school_psych_results"("assignment_id", "student_id");
