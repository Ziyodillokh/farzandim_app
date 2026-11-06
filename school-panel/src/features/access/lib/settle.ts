/** Yangilanishni kutishning yuqori chegarasi: tarmoq osilib qolsa ham bir martalik parol ko'rsatilishi shart. */
export const REFRESH_WAIT_MS = 2000;

/** `promise` tugaguncha (muvaffaqiyat yoki xato — ikkalasi ham yutiladi) yoki `ms` o'tguncha kutadi. */
export function settleWithin(promise: Promise<unknown>, ms: number): Promise<void> {
  return new Promise<void>((resolve) => {
    const timer = setTimeout(resolve, ms);
    const finish = () => {
      clearTimeout(timer);
      resolve();
    };
    void promise.then(finish, finish);
  });
}
