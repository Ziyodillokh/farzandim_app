/**
 * Original demo content written for Parvoz. Not derived from any published instrument. Demo norms are synthetic.
 *
 * "O'zimga ishonch": 10 ta Likert savoli (shkala `self`, 4 tasi teskari).
 */
import { L, likert, type TemplateContent } from './build';

const S = 'self';

export const SELF_ESTEEM: TemplateContent = {
  description: L(
    'O\'ziga ishonch va o\'zini qadrlashni o\'quvchining o\'z javoblari asosida ko\'rsatadi.',
    'Показывает уверенность в себе и самоуважение по ответам самого ученика.',
  ),
  instructions: L(
    'Har bir gap sen haqingda qanchalik to\'g\'ri ekanini belgila. Javoblaringni faqat maktab psixologi ko\'radi.',
    'Отметь, насколько каждое утверждение верно про тебя. Твои ответы видит только школьный психолог.',
  ),
  items: [
    likert('se1', S, ['Mening kuchli tomonlarim borligini bilaman.', 'Я знаю, что у меня есть сильные стороны.']),
    likert('se2', S, ['Yangi ishni boshlaganimda uddalay olishimga ishonaman.', 'Когда я берусь за новое дело, я верю, что справлюсь.']),
    likert('se3', S, ['Ko\'pincha o\'zimni boshqalardan yomonroq deb o\'ylayman.', 'Я часто думаю, что я хуже других.'], true),
    likert('se4', S, ['Fikrimni sinfda bemalol ayta olaman.', 'Я спокойно высказываю своё мнение в классе.']),
    likert('se5', S, ['Xato qilsam, o\'zimni uzoq vaqt koyiyman.', 'Если я ошибаюсь, я долго ругаю себя.'], true),
    likert('se6', S, ['Men o\'zimni qadrlayman.', 'Я ценю себя.']),
    likert('se7', S, ['Tanqiddan cho\'chib, ko\'p ishga qo\'l urmayman.', 'Я часто не берусь за дело, потому что боюсь критики.'], true),
    likert('se8', S, ['Qiyin vazifani bajarganimda o\'zim bilan faxrlanaman.', 'Я горжусь собой, когда справляюсь с трудным заданием.']),
    likert('se9', S, ['O\'zimda o\'zgartirishni xohlaydigan narsalar juda ko\'p.', 'Мне хочется изменить в себе очень многое.'], true),
    likert('se10', S, ['Meni yaxshi ko\'radigan va qo\'llab-quvvatlaydigan odamlar bor.', 'Есть люди, которые любят и поддерживают меня.']),
  ],
};
