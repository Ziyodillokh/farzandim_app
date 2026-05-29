-- CreateEnum
CREATE TYPE "RoutineType" AS ENUM ('SLEEP', 'SCHOOL', 'HOMEWORK', 'SPORT', 'OTHER');

-- CreateTable
CREATE TABLE "routines" (
    "id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "type" "RoutineType" NOT NULL,
    "start_hour" INTEGER NOT NULL,
    "start_minute" INTEGER NOT NULL,
    "end_hour" INTEGER NOT NULL,
    "end_minute" INTEGER NOT NULL,
    "weekdays" INTEGER[],
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "routines_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "routines_child_id_is_active_idx" ON "routines"("child_id", "is_active");

-- AddForeignKey
ALTER TABLE "routines" ADD CONSTRAINT "routines_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;
