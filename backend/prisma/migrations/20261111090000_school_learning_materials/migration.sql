-- Maktabning o'z o'quv materiallari va "O'qidim" belgilari. FAQAT qo'shuvchi: 2 yangi jadval, indekslar, FK.

-- CreateTable
CREATE TABLE "school_learning_materials" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "subject" TEXT NOT NULL,
    "grades" INTEGER[],
    "body" TEXT NOT NULL,
    "link_url" TEXT,
    "estimated_minutes" INTEGER NOT NULL,
    "by_staff_id" TEXT NOT NULL,
    "archived" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "school_learning_materials_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_material_reads" (
    "assignment_id" TEXT NOT NULL,
    "student_id" TEXT NOT NULL,
    "read_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "school_material_reads_pkey" PRIMARY KEY ("assignment_id","student_id")
);

-- CreateIndex
CREATE INDEX "school_learning_materials_school_id_archived_idx" ON "school_learning_materials"("school_id", "archived");

-- CreateIndex
CREATE INDEX "school_material_reads_student_id_idx" ON "school_material_reads"("student_id");

-- AddForeignKey
ALTER TABLE "school_learning_materials" ADD CONSTRAINT "school_learning_materials_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_material_reads" ADD CONSTRAINT "school_material_reads_assignment_id_fkey" FOREIGN KEY ("assignment_id") REFERENCES "school_learning_assignments"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_material_reads" ADD CONSTRAINT "school_material_reads_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "school_students"("id") ON DELETE CASCADE ON UPDATE CASCADE;

