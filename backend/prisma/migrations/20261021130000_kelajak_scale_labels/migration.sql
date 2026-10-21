-- Parvoz Kelajak: shkala yorliqlari o'zbekchaga moslandi (savollar "-mi?"
-- shaklida — "To'g'ri / To'g'ri emas" javobi mos emas edi). Faqat ko'rinadigan
-- matn o'zgaradi: qiymatlar (1..5, 1..4), ball va oldingi javoblar o'zgarmaydi.
-- Faqat standart yorliqli qatorlar yangilanadi (admin tahriri saqlanadi).

UPDATE "kelajak_questions"
SET "options" = '[{"value":1,"label":{"uz":"Yo‘q"}},{"value":2,"label":{"uz":"Ko‘proq yo‘q"}},{"value":3,"label":{"uz":"Ba’zan"}},{"value":4,"label":{"uz":"Ko‘proq ha"}},{"value":5,"label":{"uz":"Ha"}}]'::jsonb,
    "updated_at" = CURRENT_TIMESTAMP
WHERE "answer_type" = 'likert_5'
  AND "options" = '[{"value":1,"label":{"uz":"Umuman to‘g‘ri emas"}},{"value":2,"label":{"uz":"Ko‘proq to‘g‘ri emas"}},{"value":3,"label":{"uz":"Ba’zan / qisman"}},{"value":4,"label":{"uz":"Ko‘proq to‘g‘ri"}},{"value":5,"label":{"uz":"To‘liq to‘g‘ri"}}]'::jsonb;

UPDATE "kelajak_questions"
SET "options" = '[{"value":1,"label":{"uz":"Yo‘q"}},{"value":2,"label":{"uz":"Unchalik emas"}},{"value":3,"label":{"uz":"Ha"}},{"value":4,"label":{"uz":"Ha, juda"}}]'::jsonb,
    "updated_at" = CURRENT_TIMESTAMP
WHERE "answer_type" = 'interest_4'
  AND "options" = '[{"value":1,"label":{"uz":"Umuman yoqmaydi"}},{"value":2,"label":{"uz":"Unchalik yoqmaydi"}},{"value":3,"label":{"uz":"Yoqadi"}},{"value":4,"label":{"uz":"Juda yoqadi"}}]'::jsonb;
