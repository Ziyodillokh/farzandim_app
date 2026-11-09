-- CreateTable
CREATE TABLE "school_parent_threads" (
    "id" TEXT NOT NULL,
    "school_id" TEXT NOT NULL,
    "staff_id" TEXT NOT NULL,
    "student_id" TEXT NOT NULL,
    "guardian_id" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'OPEN',
    "last_author" TEXT NOT NULL DEFAULT 'PARENT',
    "last_message_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "parent_unread" INTEGER NOT NULL DEFAULT 0,
    "staff_unread" INTEGER NOT NULL DEFAULT 0,
    "parent_read_at" TIMESTAMP(3),
    "staff_read_at" TIMESTAMP(3),
    "resolved_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "school_parent_threads_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "school_parent_messages" (
    "id" TEXT NOT NULL,
    "thread_id" TEXT NOT NULL,
    "author" TEXT NOT NULL,
    "staff_id" TEXT,
    "topic" TEXT,
    "body_enc" TEXT NOT NULL,
    "client_message_id" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "school_parent_messages_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "school_parent_threads_school_id_staff_id_last_message_at_idx" ON "school_parent_threads"("school_id", "staff_id", "last_message_at" DESC);

-- CreateIndex
CREATE INDEX "school_parent_threads_guardian_id_last_message_at_idx" ON "school_parent_threads"("guardian_id", "last_message_at" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "school_parent_threads_guardian_id_staff_id_student_id_key" ON "school_parent_threads"("guardian_id", "staff_id", "student_id");

-- CreateIndex
CREATE INDEX "school_parent_messages_thread_id_created_at_idx" ON "school_parent_messages"("thread_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "school_parent_messages_thread_id_client_message_id_key" ON "school_parent_messages"("thread_id", "client_message_id");

-- AddForeignKey
ALTER TABLE "school_parent_threads" ADD CONSTRAINT "school_parent_threads_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_parent_threads" ADD CONSTRAINT "school_parent_threads_staff_id_fkey" FOREIGN KEY ("staff_id") REFERENCES "school_staff"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_parent_threads" ADD CONSTRAINT "school_parent_threads_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "school_students"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_parent_threads" ADD CONSTRAINT "school_parent_threads_guardian_id_fkey" FOREIGN KEY ("guardian_id") REFERENCES "school_guardians"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_parent_messages" ADD CONSTRAINT "school_parent_messages_thread_id_fkey" FOREIGN KEY ("thread_id") REFERENCES "school_parent_threads"("id") ON DELETE CASCADE ON UPDATE CASCADE;

