/**
 * Original demo content written for Parvoz. Not derived from any published instrument. Demo norms are synthetic.
 *
 * "Mantiqiy fikrlash": 16 ta bitta javobli savol (shkala `total`) —
 * 5 sonli qator, 4 o'xshatish, 4 "ortiqchasini top", 3 mantiqiy masala.
 */
import { L, options, same, single, type TemplateContent } from './build';

const S = 'total';

const series = [
  single('lg1', S, ['Sonlar qatorini davom ettir: 2, 4, 6, 8, …', 'Продолжи ряд чисел: 2, 4, 6, 8, …'], same([9, 10, 12, 16]), 'b'),
  single('lg2', S, ['Keyingi son qaysi: 3, 6, 12, 24, …', 'Какое число следующее: 3, 6, 12, 24, …'], same([30, 36, 48, 42]), 'c'),
  single('lg3', S, ['Keyingi son qaysi: 50, 45, 40, 35, …', 'Какое число следующее: 50, 45, 40, 35, …'], same([30, 25, 33, 32]), 'a'),
  single('lg4', S, ['Keyingi son qaysi: 1, 4, 9, 16, …', 'Какое число следующее: 1, 4, 9, 16, …'], same([20, 24, 25, 32]), 'c'),
  single('lg5', S, ['Keyingi son qaysi: 2, 3, 5, 8, 12, …', 'Какое число следующее: 2, 3, 5, 8, 12, …'], same([14, 15, 16, 17]), 'd'),
];

const analogies = [
  single(
    'lg6',
    S,
    ['Kitob — o\'qish uchun, qoshiq — … uchun', 'Книга — чтобы читать, ложка — чтобы …'],
    options([
      ['oshxona', 'кухня'],
      ['ovqat yeyish', 'есть'],
      ['likopcha', 'тарелка'],
      ['metall', 'металл'],
    ]),
    'b',
  ),
  single(
    'lg7',
    S,
    ['Issiq — sovuq, baland — …', 'Горячий — холодный, высокий — …'],
    options([
      ['keng', 'широкий'],
      ['og\'ir', 'тяжёлый'],
      ['past', 'низкий'],
      ['uzun', 'длинный'],
    ]),
    'c',
  ),
  single(
    'lg8',
    S,
    ['Shifokor — shifoxona, o\'qituvchi — …', 'Врач — больница, учитель — …'],
    options([
      ['maktab', 'школа'],
      ['kitob', 'книга'],
      ['dars', 'урок'],
      ['o\'quvchi', 'ученик'],
    ]),
    'a',
  ),
  single('lg9', S, ['Uchburchak — 3, kvadrat — …', 'Треугольник — 3, квадрат — …'], same([2, 5, 6, 4]), 'd'),
];

const oddOneOut = [
  single(
    'lg10',
    S,
    ['Qaysi biri ortiqcha?', 'Что здесь лишнее?'],
    options([
      ['olma', 'яблоко'],
      ['nok', 'груша'],
      ['sabzi', 'морковь'],
      ['o\'rik', 'абрикос'],
    ]),
    'c',
  ),
  single('lg11', S, ['Qaysi son ortiqcha?', 'Какое число лишнее?'], same([10, 3, 7, 11]), 'a'),
  single(
    'lg12',
    S,
    ['Qaysi shakl ortiqcha?', 'Какая фигура лишняя?'],
    options([
      ['kvadrat', 'квадрат'],
      ['doira', 'круг'],
      ['uchburchak', 'треугольник'],
      ['kub', 'куб'],
    ]),
    'd',
  ),
  single('lg13', S, ['Qaysi son ortiqcha?', 'Какое число лишнее?'], same([21, 54, 35, 49]), 'b'),
];

const reasoning = [
  single(
    'lg14',
    S,
    ['Aziz Bekdan baland, Bek Doniyordan baland. Kim eng past?', 'Азиз выше Бека, Бек выше Даниёра. Кто ниже всех?'],
    options([
      ['Aziz', 'Азиз'],
      ['Bek', 'Бек'],
      ['Doniyor', 'Даниёр'],
      ['Aniqlab bo\'lmaydi', 'Нельзя определить'],
    ]),
    'c',
  ),
  single(
    'lg15',
    S,
    ['Barcha mushuklar — hayvon. Mosh — mushuk. Demak…', 'Все кошки — животные. Мурка — кошка. Значит…'],
    options([
      ['Mosh — hayvon', 'Мурка — животное'],
      ['Barcha hayvonlar — mushuk', 'Все животные — кошки'],
      ['Mosh — it', 'Мурка — собака'],
      ['Hech narsa deb bo\'lmaydi', 'Ничего сказать нельзя'],
    ]),
    'a',
  ),
  single(
    'lg16',
    S,
    ['Bugun chorshanba. 10 kundan keyin haftaning qaysi kuni bo\'ladi?', 'Сегодня среда. Какой день недели будет через 10 дней?'],
    options([
      ['juma', 'пятница'],
      ['shanba', 'суббота'],
      ['yakshanba', 'воскресенье'],
      ['payshanba', 'четверг'],
    ]),
    'b',
  ),
];

export const LOGIC: TemplateContent = {
  description: L(
    'Sonli qatorlar, o\'xshatishlar, ortiqchasini topish va mantiqiy masalalar orqali fikrlash uslubini ko\'rsatadi.',
    'Показывает особенности мышления через числовые ряды, аналогии, поиск лишнего и логические задачи.',
  ),
  instructions: L(
    'Har bir savolni diqqat bilan o\'qi va bitta javobni tanla. Shoshilma: bilmasang, keyingi savolga o\'taver.',
    'Внимательно прочитай каждый вопрос и выбери один ответ. Не торопись: если не знаешь, переходи к следующему.',
  ),
  items: [...series, ...analogies, ...oddOneOut, ...reasoning],
};
