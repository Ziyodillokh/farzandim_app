import type { DeepString } from '../types';
import type { insights as uz } from '../uz/insights';

export const insights: DeepString<typeof uz> = {
  title: 'Автоматические выводы',
  subtitle: 'Сигналы, найденные в показателях автоматически',
  empty: 'Пока особых сигналов нет',
  masteryLeader: '{area} — лидер по успеваемости: {value}%, на {diff} п.п. выше среднего.',
  masteryLow: '{area}: успеваемость {value}%, на {diff} п.п. ниже среднего. Рекомендуется дополнительная методическая помощь.',
  masteryGrowth: '{area}: успеваемость выросла на {delta} п.п. к тому же периоду прошлого года — максимальный рост.',
  weakSubject: 'Самый слабый предмет — {subject}: {value}% (на {gap} п.п. ниже общего среднего).',
  interestGap: 'Предмет «{subject}» выбирают многие ({share}%), но успеваемость {mastery}% — ресурсы и помощь учителей могут быть эффективны.',
  bullyingHotspot: '{area}: сигнал буллинга {value}% — в {ratio} раза выше среднего. Рекомендуются профилактические программы.',
  wellbeingUp: 'Индекс благополучия {value} — улучшился на {delta} балла к прошлому году.',
  wellbeingDown: 'Индекс благополучия {value} — снизился на {delta} балла к прошлому году.',
  attendanceLeader: '{area} — лидер по посещаемости: {value}%.',
  chronicHigh: '{area}: хронические пропуски {value}% — нужно наблюдение.',
  nightOlder: 'В 10–11 классах {night}% экранного времени приходится на ночь; {sleep}% говорят, что не высыпаются.',
  iqParticipationLow: '{area}: охват Parvoz IQ {value}% — самый низкий; рекомендуется назначение в школах.',
  coverageGrowth: 'Охват мониторинга {value}% — расширился на {delta} п.п. к прошлому году.',
};
