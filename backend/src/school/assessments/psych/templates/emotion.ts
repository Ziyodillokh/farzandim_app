/**
 * Original demo content written for Parvoz. Not derived from any published instrument. Demo norms are synthetic.
 *
 * "Hissiy holat skriningi": 12 ta Likert savoli — 7 ta hayajon (`worry`),
 * 5 ta kayfiyat (`mood`, 2 tasi teskari). Javoblar 1–5: hech qachon … doim.
 */
import { L, likert, type TemplateContent } from './build';

const W = 'worry';
const M = 'mood';

export const EMOTION: TemplateContent = {
  description: L(
    'O\'quvchi so\'nggi haftalardagi his-tuyg\'ulari — hayajon va kayfiyati haqida o\'zi javob beradi.',
    'Ученик сам рассказывает о своих чувствах за последние недели — о волнении и настроении.',
  ),
  instructions: L(
    'Bu yerda to\'g\'ri yoki noto\'g\'ri javob yo\'q. Har bir gapni o\'qi va so\'nggi ikki haftada bu sen bilan qanchalik tez-tez bo\'lganini tanla.',
    'Здесь нет правильных и неправильных ответов. Прочитай каждое утверждение и выбери, как часто это было с тобой за последние две недели.',
  ),
  items: [
    likert('em1', W, ['Nazorat ishi oldidan uzoq vaqt hayajonlanaman.', 'Перед контрольной я долго волнуюсь.']),
    likert('mo1', M, ['Kunim ko\'pincha yaxshi kayfiyatda o\'tadi.', 'Мой день обычно проходит в хорошем настроении.']),
    likert('em2', W, ['Biror ish rejadagidek bo\'lmay qolishidan xavotir olaman.', 'Я переживаю, что что-то пойдёт не по плану.']),
    likert('em3', W, ['Uxlashdan oldin kun davomida bo\'lgan voqealar haqida ko\'p o\'ylayman.', 'Перед сном я долго думаю о том, что было за день.']),
    likert('mo2', M, ['Do\'stlarim bilan vaqt o\'tkazish menga quvonch beradi.', 'Время с друзьями приносит мне радость.']),
    likert('em4', W, ['Doska oldida javob berishdan oldin yuragim tez ura boshlaydi.', 'Перед ответом у доски у меня часто бьётся сердце.']),
    likert('mo3', M, ['Hech narsa qilgim kelmaydigan kunlar bo\'ladi.', 'Бывают дни, когда мне ничего не хочется делать.'], true),
    likert('em5', W, ['Yangi joyga yoki notanish odamlar orasiga borishdan oldin bezovtalanaman.', 'Я беспокоюсь, когда иду в новое место или к незнакомым людям.']),
    likert('em6', W, ['Xato qilib qo\'yishdan qo\'rqaman.', 'Я боюсь сделать ошибку.']),
    likert('mo4', M, ['Ertangi kunni qiziqish bilan kutaman.', 'Я с интересом жду завтрашнего дня.']),
    likert('em7', W, ['Kichik qiyinchiliklar ham xayolimdan uzoq ketmaydi.', 'Даже небольшие трудности долго не выходят у меня из головы.']),
    likert('mo5', M, ['O\'zimda charchoq va zerikish his qilaman.', 'Я чувствую усталость и скуку.'], true),
  ],
};
