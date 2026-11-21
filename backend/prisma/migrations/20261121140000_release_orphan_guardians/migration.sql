-- Ma'lumotni tuzatish (sxema o'zgarmaydi): ota-ona akkaunti o'chirilganda `user_id` NULL bo'lgan,
-- lekin `link_status = LINKED` qolib ketgan vasiy yozuvlari «taklif qilinmagan» holatga qaytariladi.
-- Faqat buzuq (akkauntsiz «ulangan») qatorlar o'zgaradi; haqiqiy ulanishlarga tegilmaydi.
UPDATE "school_guardians"
SET "link_status" = 'NOT_INVITED', "linked_at" = NULL, "invite_code" = NULL, "invite_expires_at" = NULL
WHERE "user_id" IS NULL AND "link_status" = 'LINKED';
