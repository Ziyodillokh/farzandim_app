-- CreateTable: bolaning kunlik qadam soni (Parvoz pedometer).
CREATE TABLE "child_step_daily" (
    "id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "date" DATE NOT NULL,
    "steps" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "child_step_daily_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "child_step_daily_child_id_date_key" ON "child_step_daily"("child_id", "date");

-- CreateIndex
CREATE INDEX "child_step_daily_child_id_date_idx" ON "child_step_daily"("child_id", "date");

-- AddForeignKey
ALTER TABLE "child_step_daily" ADD CONSTRAINT "child_step_daily_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;
