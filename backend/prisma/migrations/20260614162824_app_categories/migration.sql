-- AlterTable
ALTER TABLE "installed_apps" ADD COLUMN     "category" TEXT;

-- CreateTable
CREATE TABLE "category_blocks" (
    "id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "category_blocks_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "category_blocks_child_id_idx" ON "category_blocks"("child_id");

-- CreateIndex
CREATE UNIQUE INDEX "category_blocks_child_id_category_key" ON "category_blocks"("child_id", "category");

-- AddForeignKey
ALTER TABLE "category_blocks" ADD CONSTRAINT "category_blocks_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;
