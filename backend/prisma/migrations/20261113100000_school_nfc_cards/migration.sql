-- NFC kartalar bilan kirish: karta ro'yxati, tegishlar jurnali, karta kalitlari uchun
-- bosh kalit va School Mode «kirgandan boshlab bloklash». Faqat qo'shimcha (additive).
ALTER TYPE "AttendanceSource" ADD VALUE 'CARD';

CREATE TYPE "SchoolCardKind" AS ENUM ('UID', 'SUN');
CREATE TYPE "SchoolCardStatus" AS ENUM ('ACTIVE', 'LOST', 'BLOCKED');
CREATE TYPE "SchoolCardTapResult" AS ENUM ('IN', 'OUT', 'NONE', 'UNKNOWN', 'BLOCKED', 'INVALID', 'OUTSIDE');

ALTER TABLE "schools" ADD COLUMN "card_key" TEXT;

ALTER TABLE "school_mode_policies" ADD COLUMN "block_from_arrival" BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE "school_cards" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "student_id" TEXT NOT NULL,
    "uid" TEXT NOT NULL,
    "kind" "SchoolCardKind" NOT NULL,
    "number" TEXT NOT NULL,
    "status" "SchoolCardStatus" NOT NULL DEFAULT 'ACTIVE',
    "last_counter" INTEGER,
    "last_tap_at" TIMESTAMP(3),
    "issued_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "blocked_at" TIMESTAMP(3),
    "blocked_reason" TEXT,

    CONSTRAINT "school_cards_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "school_card_taps" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "tapped_at" TIMESTAMP(3) NOT NULL,
    "card_id" TEXT,
    "student_id" TEXT,
    "uid" TEXT,
    "result" "SchoolCardTapResult" NOT NULL,
    "suspicious" BOOLEAN NOT NULL DEFAULT false,
    "kiosk_id" TEXT,
    "staff_id" TEXT,

    CONSTRAINT "school_card_taps_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "school_cards_student_id_idx" ON "school_cards"("student_id");

CREATE UNIQUE INDEX "school_cards_school_id_uid_key" ON "school_cards"("school_id", "uid");

CREATE UNIQUE INDEX "school_cards_school_id_number_key" ON "school_cards"("school_id", "number");

CREATE INDEX "school_card_taps_school_id_at_idx" ON "school_card_taps"("school_id", "at" DESC);

CREATE INDEX "school_card_taps_school_id_suspicious_idx" ON "school_card_taps"("school_id", "suspicious");

ALTER TABLE "school_cards" ADD CONSTRAINT "school_cards_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "school_cards" ADD CONSTRAINT "school_cards_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "school_students"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "school_card_taps" ADD CONSTRAINT "school_card_taps_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;
