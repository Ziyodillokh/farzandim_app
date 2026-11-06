import { Injectable } from '@nestjs/common';

/**
 * Bola kirishi soati. Alohida provider — testlar blok / oyna muddatlarini haqiqiy kutmasdan
 * `clock.now = () => …` bilan almashtiradi (davomat modulidagi `AttendanceClock` kabi).
 * JWT muddati (setupToken `exp`) va throttler haqiqiy soatda qoladi.
 */
@Injectable()
export class ChildAuthClock {
  now(): Date {
    return new Date();
  }
}
