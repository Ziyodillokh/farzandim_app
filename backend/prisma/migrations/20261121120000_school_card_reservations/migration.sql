-- Karta partiyasi: chop etishdan oldin o'quvchiga ajratilgan raqamlar (faqat qo'shiluvchi).
-- CreateTable
CREATE TABLE "school_card_reservations" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "student_id" TEXT NOT NULL,
    "number" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "school_card_reservations_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "school_card_reservations_student_id_key" ON "school_card_reservations"("student_id");

-- CreateIndex
CREATE UNIQUE INDEX "school_card_reservations_number_key" ON "school_card_reservations"("number");

-- CreateIndex
CREATE INDEX "school_card_reservations_school_id_idx" ON "school_card_reservations"("school_id");

-- AddForeignKey
ALTER TABLE "school_card_reservations" ADD CONSTRAINT "school_card_reservations_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_card_reservations" ADD CONSTRAINT "school_card_reservations_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "school_students"("id") ON DELETE CASCADE ON UPDATE CASCADE;

