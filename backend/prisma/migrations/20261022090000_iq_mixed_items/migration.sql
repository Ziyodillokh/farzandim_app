-- Parvoz IQ aralash formalar (docs/IQ-REJA.md §8): matnli savollar uchun tur va
-- shart matni. Mavjud savollar FIGURAL bo'lib qoladi; grid_svg faqat rasmli
-- savolda majburiy (cheklov yumshatildi, ma'lumot o'zgarmaydi).

-- CreateEnum
CREATE TYPE "IqItemKind" AS ENUM ('FIGURAL', 'NUMERIC', 'VERBAL', 'LOGIC');

-- AlterTable
ALTER TABLE "iq_items" ADD COLUMN "kind" "IqItemKind" NOT NULL DEFAULT 'FIGURAL',
ADD COLUMN "stem" JSONB,
ALTER COLUMN "grid_svg" DROP NOT NULL;
