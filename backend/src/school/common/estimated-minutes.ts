// Bola ilovasi uchun taxminiy vaqt: bitta savolga o'rtacha 15 soniya.
// `max(1, ceil(savollar * 15 / 60))` daqiqa (so'rovnoma va psixologik testlar uchun bir xil).

export const SECONDS_PER_QUESTION = 15;

export const estimatedMinutes = (questionCount: number): number => Math.max(1, Math.ceil((questionCount * SECONDS_PER_QUESTION) / 60));
