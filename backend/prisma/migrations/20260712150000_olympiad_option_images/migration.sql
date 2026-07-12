-- AlterTable: konkurs savol VARIANTLARIGA ixtiyoriy rasm (options bilan parallel)
ALTER TABLE "olympiad_questions" ADD COLUMN "option_images" TEXT[] DEFAULT ARRAY[]::TEXT[];
