-- AlterTable: "O'chirishni taqiqlash" (Device Admin — uninstall bloklash)
ALTER TABLE "children" ADD COLUMN "block_uninstall" BOOLEAN NOT NULL DEFAULT false;
