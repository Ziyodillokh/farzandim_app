-- Growth Daily Learning: yangi enum qiymatlari. Alohida migratsiyada —
-- Postgres yangi qiymatni qo'shilgan tranzaksiyada ishlatishga ruxsat bermaydi.

-- AlterEnum
ALTER TYPE "NotificationType" ADD VALUE 'LEARNING_REPORT';

-- AlterEnum
ALTER TYPE "XpEventType" ADD VALUE 'DAILY_LEARNING';
