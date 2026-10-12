/** Ruscha lug'at o'zbekcha bilan AYNAN bir xil tuzilishda bo'lishi shart. */
export type DeepString<T> = {
  [K in keyof T]: T[K] extends string ? string : DeepString<T[K]>;
};

/** Ko'plik shakli (rus tili uchun; o'zbekchada uchalasi bir xil bo'lishi mumkin). */
export type PluralForms = { one: string; few: string; many: string };

type IsPlural<T> = T extends PluralForms ? (keyof T extends keyof PluralForms ? true : false) : false;

/** "students.title" kabi matn kalitlari. */
export type TextKey<T, P extends string = ''> = {
  [K in keyof T & string]: T[K] extends string
    ? `${P}${K}`
    : IsPlural<T[K]> extends true
      ? never
      : TextKey<T[K], `${P}${K}.`>;
}[keyof T & string];

/** "common.studentsCount" kabi ko'plik kalitlari. */
export type PluralKey<T, P extends string = ''> = {
  [K in keyof T & string]: T[K] extends string
    ? never
    : IsPlural<T[K]> extends true
      ? `${P}${K}`
      : PluralKey<T[K], `${P}${K}.`>;
}[keyof T & string];

export type Vars = Record<string, string | number>;
