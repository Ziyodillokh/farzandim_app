/**
 * Original demo content written for Parvoz. Not derived from any published instrument. Demo norms are synthetic.
 *
 * "Ijtimoiy ko'nikmalar": 10 ta Likert savoli (shkala `social`, 2 tasi teskari).
 */
import { L, likert, type TemplateContent } from './build';

const S = 'social';

export const SOCIAL: TemplateContent = {
  description: L(
    'Muloqot, hamkorlik va do\'stlik ko\'nikmalarini o\'quvchining o\'z bahosi bo\'yicha ko\'rsatadi.',
    'Показывает навыки общения, сотрудничества и дружбы по самооценке ученика.',
  ),
  instructions: L(
    'Har bir gapni o\'qi va bu sen bilan qanchalik tez-tez bo\'lishini tanla. To\'g\'ri yoki noto\'g\'ri javob yo\'q.',
    'Прочитай каждое утверждение и выбери, как часто это бывает с тобой. Правильных и неправильных ответов нет.',
  ),
  items: [
    likert('so1', S, ['Yangi bolalar bilan oson tanishaman.', 'Я легко знакомлюсь с новыми ребятами.']),
    likert('so2', S, ['Do\'stimning kayfiyati yo\'qligini sezaman.', 'Я замечаю, когда у друга плохое настроение.']),
    likert('so3', S, ['Jamoada ishlaganda boshqalarning fikrini tinglayman.', 'В команде я выслушиваю мнение других.']),
    likert('so4', S, ['Bahslashganda tez jahlim chiqadi.', 'В споре я быстро начинаю сердиться.'], true),
    likert('so5', S, ['Kerak bo\'lsa, yordam so\'ray olaman.', 'Если нужно, я могу попросить о помощи.']),
    likert('so6', S, ['Navbatimni sabr bilan kuta olaman.', 'Мне хватает терпения дождаться своей очереди.']),
    likert('so7', S, ['Kelishmovchilik bo\'lsa, murosaga kelishga harakat qilaman.', 'Если возник спор, я стараюсь договориться.']),
    likert('so8', S, ['Guruh ishida chetda turishni afzal ko\'raman.', 'В групповой работе я предпочитаю оставаться в стороне.'], true),
    likert('so9', S, ['Boshqalarni maqtash va minnatdorchilik bildirishni yaxshi ko\'raman.', 'Мне нравится хвалить других и благодарить.']),
    likert('so10', S, ['Do\'stlarim menga ishonishadi.', 'Друзья мне доверяют.']),
  ],
};
