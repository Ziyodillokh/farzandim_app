-- Kirish K2: maktab o'quvchi kodi (6 raqam, ikki o'rin: bola + ota-ona), bolaning "maktab/sinf noto'g'ri" so'rovi va
-- ishonchsiz ota-onaning vasiylik so'rovi (xodim tasdig'i).
-- FAQAT qo'shuvchi: 3 ta yangi jadval (school_student_invites, school_link_corrections, school_guardian_reviews) va ularning
-- indekslari / begona kalitlari. Mavjud jadvallar, ustunlar va qatorlarga tegilmaydi (UPDATE / DELETE yo'q). 8 belgili
-- ota-ona taklif kodlari (school_guardians.invite_code) o'zgarmaydi.

-- CreateTable
CREATE TABLE "school_student_invites" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "student_id" TEXT NOT NULL,
    "code" CHAR(6) NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "student_child_id" TEXT,
    "student_used_at" TIMESTAMP(3),
    "student_confirmed_at" TIMESTAMP(3),
    "parent_user_id" TEXT,
    "parent_used_at" TIMESTAMP(3),
    "created_by_staff_id" TEXT NOT NULL,
    "closed_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "school_student_invites_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_link_corrections" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "student_id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "note" TEXT NOT NULL DEFAULT '',
    "client_request_id" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'OPEN',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolved_at" TIMESTAMP(3),
    "resolved_by_staff_id" TEXT,

    CONSTRAINT "school_link_corrections_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_guardian_reviews" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "student_id" TEXT NOT NULL,
    "invite_id" TEXT,
    "user_id" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'OPEN',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolved_at" TIMESTAMP(3),
    "resolved_by_staff_id" TEXT,

    CONSTRAINT "school_guardian_reviews_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "school_student_invites_school_id_student_id_idx" ON "school_student_invites"("school_id", "student_id");

-- CreateIndex
CREATE INDEX "school_student_invites_student_child_id_idx" ON "school_student_invites"("student_child_id");

-- CreateIndex
CREATE INDEX "school_student_invites_parent_user_id_idx" ON "school_student_invites"("parent_user_id");

-- CreateIndex
CREATE INDEX "school_link_corrections_school_id_status_idx" ON "school_link_corrections"("school_id", "status");

-- CreateIndex
CREATE INDEX "school_link_corrections_child_id_status_idx" ON "school_link_corrections"("child_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "school_link_corrections_child_id_client_request_id_key" ON "school_link_corrections"("child_id", "client_request_id");

-- CreateIndex
CREATE INDEX "school_guardian_reviews_school_id_status_idx" ON "school_guardian_reviews"("school_id", "status");

-- CreateIndex
CREATE INDEX "school_guardian_reviews_user_id_status_idx" ON "school_guardian_reviews"("user_id", "status");

-- CreateIndex
CREATE INDEX "school_guardian_reviews_student_id_status_idx" ON "school_guardian_reviews"("student_id", "status");

-- CreateIndex
CREATE INDEX "school_guardian_reviews_invite_id_idx" ON "school_guardian_reviews"("invite_id");

-- AddForeignKey
ALTER TABLE "school_student_invites" ADD CONSTRAINT "school_student_invites_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_student_invites" ADD CONSTRAINT "school_student_invites_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "school_students"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_student_invites" ADD CONSTRAINT "school_student_invites_student_child_id_fkey" FOREIGN KEY ("student_child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_student_invites" ADD CONSTRAINT "school_student_invites_parent_user_id_fkey" FOREIGN KEY ("parent_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_link_corrections" ADD CONSTRAINT "school_link_corrections_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_link_corrections" ADD CONSTRAINT "school_link_corrections_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "school_students"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_link_corrections" ADD CONSTRAINT "school_link_corrections_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_guardian_reviews" ADD CONSTRAINT "school_guardian_reviews_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_guardian_reviews" ADD CONSTRAINT "school_guardian_reviews_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "school_students"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_guardian_reviews" ADD CONSTRAINT "school_guardian_reviews_invite_id_fkey" FOREIGN KEY ("invite_id") REFERENCES "school_student_invites"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_guardian_reviews" ADD CONSTRAINT "school_guardian_reviews_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Qisman unique indekslar va CHECK'lar (Prisma sxemasi ifodalay olmaydi; `migrate diff` ularni drift deb hisoblamaydi).

-- Kod faol (yopilmagan) kodlar orasida yagona. Muddati o'tgan, lekin yopilmagan qator ham kodni band qiladi — servis
-- yangi kod berishdan oldin uni yopadi.
CREATE UNIQUE INDEX "school_student_invites_code_open_key" ON "school_student_invites"("code") WHERE "closed_at" IS NULL;

-- Bitta o'quvchida bitta yopilmagan kod.
CREATE UNIQUE INDEX "school_student_invites_student_open_key" ON "school_student_invites"("student_id") WHERE "closed_at" IS NULL;

-- Bola o'quvchi o'rnini tasdiqlanmagan (UNDER_REVIEW) holatda faqat bitta kodda band qila oladi.
CREATE UNIQUE INDEX "school_student_invites_child_review_key" ON "school_student_invites"("student_child_id") WHERE "student_child_id" IS NOT NULL AND "student_confirmed_at" IS NULL;

-- Bolada bitta ochiq tuzatish so'rovi.
CREATE UNIQUE INDEX "school_link_corrections_child_open_key" ON "school_link_corrections"("child_id") WHERE "status" = 'OPEN';

-- Ota-onada bitta o'quvchi uchun bitta ochiq vasiylik so'rovi.
CREATE UNIQUE INDEX "school_guardian_reviews_user_student_open_key" ON "school_guardian_reviews"("user_id", "student_id") WHERE "status" = 'OPEN';

ALTER TABLE "school_student_invites" ADD CONSTRAINT "school_student_invites_code_digits_chk" CHECK ("code" ~ '^[0-9]{6}$');
ALTER TABLE "school_link_corrections" ADD CONSTRAINT "school_link_corrections_status_chk" CHECK ("status" IN ('OPEN', 'CONFIRMED', 'REJECTED', 'CANCELLED'));
ALTER TABLE "school_guardian_reviews" ADD CONSTRAINT "school_guardian_reviews_status_chk" CHECK ("status" IN ('OPEN', 'CONFIRMED', 'REJECTED'));
