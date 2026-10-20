/** Uydirma, lekin tabiiy o'zbekcha ismlar (demo). */
export const MALE_NAMES = [
  'Abdulloh', 'Akmal', 'Alisher', 'Amir', 'Asadbek', 'Aziz', 'Bekzod', 'Bobur', 'Diyorbek', 'Doniyor',
  'Elbek', 'Farrux', 'Hasan', 'Husan', 'Ibrohim', 'Islom', 'Jahongir', 'Javohir', 'Jasur', 'Kamron',
  'Lazizbek', 'Mirjalol', 'Muhammadali', 'Muhammadyusuf', 'Nodirbek', 'Otabek', 'Ozodbek', 'Rustam',
  'Sardor', 'Sanjar', 'Shahzod', 'Shohruh', 'Sherzod', 'Sunnat', 'Temur', 'Ulug\'bek', 'Umar', 'Usmon',
  'Xurshid', 'Yahyo', 'Yusuf', 'Zafar', 'Ziyodulla', 'Asilbek', 'Behruz', 'Dilshod', 'Firdavs', 'G\'ayrat',
];

export const FEMALE_NAMES = [
  'Aziza', 'Barno', 'Dilnoza', 'Dilfuza', 'Durdona', 'Feruza', 'Gulnoza', 'Hilola', 'Iroda', 'Kamola',
  'Laylo', 'Lola', 'Madina', 'Malika', 'Marjona', 'Mohinur', 'Munisa', 'Mushtariy', 'Nargiza', 'Nigora',
  'Nilufar', 'Nodira', 'Odina', 'Oysha', 'Robiya', 'Ruxshona', 'Sabina', 'Sarvinoz', 'Sevara', 'Shahzoda',
  'Shirin', 'Soliha', 'Sug\'diyona', 'Umida', 'Xadicha', 'Yasmina', 'Zarina', 'Zilola', 'Zuhra', 'Asal',
  'Charos', 'E\'zoza', 'Fotima', 'Gulshan', 'Imona', 'Jasmina', 'Komila',
];

/** Familiya o'zagi: erkak — +ov/+yev, ayol — +ova/+yeva. */
export const SURNAME_STEMS = [
  'Karim', 'Rahim', 'Yusup', 'Toshmat', 'Ergash', 'Abdulla', 'Usmon', 'Sobir', 'Nazar', 'Qodir',
  'Rasul', 'Hamid', 'Aliy', 'Umar', 'Ismoil', 'Xolmat', 'Sultan', 'Mahmud', 'Jo\'ra', 'Murod',
  'Azim', 'Baxrom', 'Davlat', 'Fayzull', 'G\'afur', 'Hakim', 'Ibrohim', 'Jalol', 'Kamol', 'Latip',
  'Mirzay', 'Normat', 'Olim', 'Po\'lat', 'Rustam', 'Safar', 'Tursun', 'Valiy', 'Xasan', 'Yo\'ldosh',
];

export function surname(stem: string, female: boolean): string {
  const vowelEnd = /[aeiouy']$/i.test(stem) && !stem.endsWith('iy');
  if (stem.endsWith('iy')) return `${stem.slice(0, -1)}yev${female ? 'a' : ''}`;
  const base = vowelEnd ? `${stem}yev` : `${stem}ov`;
  return female ? `${base}a` : base;
}

export function patronymic(fatherName: string, female: boolean): string {
  return `${fatherName} ${female ? 'qizi' : 'o\'g\'li'}`;
}

/** Fanlar bo'yicha o'qituvchi lavozimlari. */
export const TEACHER_POSITIONS = [
  'Matematika o\'qituvchisi',
  'Ona tili va adabiyot o\'qituvchisi',
  'Ingliz tili o\'qituvchisi',
  'Rus tili o\'qituvchisi',
  'Tarix o\'qituvchisi',
  'Fizika o\'qituvchisi',
  'Kimyo o\'qituvchisi',
  'Biologiya o\'qituvchisi',
  'Geografiya o\'qituvchisi',
  'Informatika o\'qituvchisi',
  'Jismoniy tarbiya o\'qituvchisi',
  'Boshlang\'ich sinf o\'qituvchisi',
  'Musiqa o\'qituvchisi',
  'Tasviriy san\'at o\'qituvchisi',
];
