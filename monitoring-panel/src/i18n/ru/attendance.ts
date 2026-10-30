import type { DeepString } from '../types';
import type { attendance as uz } from '../uz/attendance';

export const attendance: DeepString<typeof uz> = {
  title: 'Посещаемость',
  subtitle: 'Явка, опоздания и хронические пропуски',
  nav: {
    label: 'Разделы страницы',
    overview: 'Показатели',
    map: 'Карта',
    breakdowns: 'Срезы',
    areas: 'Таблица',
  },
  overview: {
    earlyExits: 'Ранний уход',
    earlyExitsDesc: 'Случаи раннего ухода с уроков — доля от отмеченных ученико-дней.',
    missedDays: 'Пропущенные дни: {value}',
  },
  statuses: {
    title: 'Статусы посещаемости',
    came: 'Присутствовали',
    missed: 'Отсутствовали',
    mainDeviation: 'Основное отклонение — {status}: {value}',
    excusedShare: 'Из пропущенных дней {value} — по уважительной причине',
  },
  breakdowns: {
    title: 'Срезы',
    subtitle: 'Посещаемость по месяцам, дням недели, классам и типам школ',
    byMonth: 'По месяцам',
    byWeekday: 'По дням недели',
    byGrade: 'По классам',
    bySchoolType: 'По типу школы',
    columnsNote: 'Пунктир — общая посещаемость; янтарные столбцы — группа с самой низкой посещаемостью. В типах школ вертикальная метка — общая посещаемость, число — разница с ней.',
    axisNote: 'Ось начинается не с нуля',
    overall: 'Общая посещаемость: {value}',
    weekday: {
      d1: 'Понедельник',
      d2: 'Вторник',
      d3: 'Среда',
      d4: 'Четверг',
      d5: 'Пятница',
      d6: 'Суббота',
    },
  },
  areas: {
    title: 'Таблица регионов',
    titleDistrict: 'Таблица районов',
    csvFile: 'poseshchaemost',
  },
};
