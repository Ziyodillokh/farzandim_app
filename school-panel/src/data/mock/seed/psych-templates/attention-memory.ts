/**
 * Original demo content written for Parvoz. Not derived from any published instrument. Demo norms are synthetic.
 *
 * "Diqqat va xotira": 7 ta diqqat + 7 ta xotira savoli (bitta javobli).
 * Xotira savollarida avval stimul bir necha soniya ko'rsatiladi.
 */
import { L, options, same, single, type TemplateContent } from './build';

const A = 'attention';
const M = 'memory';

const attention = [
  single('at1', A, ['Qatorda nechta «K» harfi bor?  K M K T K L M K', 'Сколько букв «К» в строке?  K M K T K L M K'], same([3, 4, 5, 6]), 'b'),
  single('at2', A, ['Qaysi juftlikda ikkala son bir xil?', 'В какой паре оба числа одинаковые?'], same(['3927 — 3972', '6014 — 6104', '4815 — 4815', '5538 — 5583']), 'c'),
  single('at3', A, ['Qaysi son 6 bilan boshlanib, 3 bilan tugaydi?', 'Какое число начинается с 6 и заканчивается на 3?'], same([6038, 3016, 6093, 9063]), 'c'),
  single('at4', A, ['Qatorda nechta juft son bor?  3 8 5 2 7 6 9 4', 'Сколько чётных чисел в строке?  3 8 5 2 7 6 9 4'], same([4, 3, 5, 2]), 'a'),
  single(
    'at5',
    A,
    ['Qaysi so\'z xato yozilgan?', 'Какое слово написано с ошибкой?'],
    options([
      ['maktab', 'школа'],
      ['daftr', 'тетрдь'],
      ['kitob', 'книга'],
      ['qalam', 'ручка'],
    ]),
    'b',
  ),
  single('at6', A, ['Nechta strelka chapga qaragan?  → → ← → → → ←', 'Сколько стрелок смотрят влево?  → → ← → → → ←'], same([2, 3, 4, 1]), 'a'),
  single(
    'at7',
    A,
    ['Nechta «3» to\'g\'ridan-to\'g\'ri «7» dan keyin turibdi?  7 3 1 3 7 3 3 7 1 3', 'Сколько раз «3» стоит сразу после «7»?  7 3 1 3 7 3 3 7 1 3'],
    same([3, 4, 2, 5]),
    'c',
  ),
];

const memory = [
  single(
    'me1',
    M,
    ['Qaysi so\'z ro\'yxatda bor edi?', 'Какое слово было в списке?'],
    options([
      ['mashina', 'машина'],
      ['quyosh', 'солнце'],
      ['gul', 'цветок'],
      ['stol', 'стол'],
    ]),
    'b',
    { text: ['olma · kitob · quyosh · ruchka · daraxt', 'яблоко · книга · солнце · ручка · дерево'], showSec: 8 },
  ),
  single('me2', M, ['Sonlar qaysi tartibda edi?', 'В каком порядке были числа?'], same(['7 2 9 4', '7 9 2 4', '2 7 9 4', '7 2 4 9']), 'a', {
    text: ['7 2 9 4', '7 2 9 4'],
    showSec: 6,
  }),
  single(
    'me3',
    M,
    ['Doira qanday rangda edi?', 'Какого цвета был круг?'],
    options([
      ['qizil', 'красный'],
      ['yashil', 'зелёный'],
      ['ko\'k', 'синий'],
      ['sariq', 'жёлтый'],
    ]),
    'c',
    { text: ['qizil uchburchak · ko\'k doira · yashil kvadrat', 'красный треугольник · синий круг · зелёный квадрат'], showSec: 8 },
  ),
  single('me4', M, ['Ali nechta non oldi?', 'Сколько лепёшек купил Али?'], same([2, 5, 4, 3]), 'd', {
    text: ['Ali bozorga borib, 3 ta non va 2 ta sut oldi.', 'Али пошёл на рынок и купил 3 лепёшки и 2 пакета молока.'],
    showSec: 8,
  }),
  single('me5', M, ['Uchinchi son qaysi edi?', 'Какое число было третьим?'], same([1, 6, 3, 8]), 'b', { text: ['8 1 6 3 5', '8 1 6 3 5'], showSec: 7 }),
  single(
    'me6',
    M,
    ['Qaysi so\'z ro\'yxatda YO\'Q edi?', 'Какого слова НЕ было в списке?'],
    options([
      ['daryo', 'река'],
      ['kalit', 'ключ'],
      ['oyna', 'зеркало'],
      ['lola', 'тюльпан'],
    ]),
    'c',
    { text: ['mushuk · daryo · soat · bulut · kalit · lola', 'кошка · река · часы · облако · ключ · тюльпан'], showSec: 10 },
  ),
  single(
    'me7',
    M,
    ['Sonlarni teskari tartibda tanla', 'Выбери числа в обратном порядке'],
    same(['7 8 4 2 9 5', '5 9 2 8 4 7', '7 4 2 8 9 5', '7 4 8 2 9 5']),
    'd',
    { text: ['5 9 2 8 4 7', '5 9 2 8 4 7'], showSec: 8 },
  ),
];

export const ATTENTION_MEMORY: TemplateContent = {
  description: L(
    'Tafsilotlarni payqash va qisqa muddatli xotirani ko\'rsatuvchi o\'yin shaklidagi topshiriqlar.',
    'Задания в игровой форме на внимательность к деталям и кратковременную память.',
  ),
  instructions: L(
    'Ba\'zi savollarda avval so\'zlar yoki sonlar bir necha soniya ko\'rsatiladi — ularni eslab qol. Keyin bitta javobni tanla.',
    'В некоторых заданиях сначала на несколько секунд покажут слова или числа — запомни их. Затем выбери один ответ.',
  ),
  items: [...attention, ...memory],
};
