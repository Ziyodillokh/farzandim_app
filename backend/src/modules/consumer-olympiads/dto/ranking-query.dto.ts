import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';
import { Type } from 'class-transformer';

/** `region=me` — joriy bolaning O'Z viloyati bo'yicha filtr. */
export const RANKING_REGION_ME = 'me';

export enum RankingRange {
  all = 'all',
  daily = 'daily',
  weekly = 'weekly',
  monthly = 'monthly',
}

export class RankingQueryDto {
  @ApiPropertyOptional({ enum: RankingRange, default: 'all' })
  @IsEnum(RankingRange)
  @IsOptional()
  range?: RankingRange = RankingRange.all;

  @ApiPropertyOptional({ default: 50 })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  @IsOptional()
  limit?: number = 50;

  /**
   * Viloyat filtri (`Child.region`). Berilmasa — global reyting.
   *
   * MUHIM: filtr SERVER tomonda qo'llanadi. Avval klient global top-N ni olib
   * o'zi filtrlardi — boshqa viloyat bolasi top-N ga kirmasa ro'yxat bo'sh
   * chiqib, "viloyat filtri ishlamayapti" degan holat kelib chiqardi.
   *
   * `region=me` — joriy bolaning o'z viloyati (klient o'z viloyatini
   * mustaqil bilmaydi — u faqat reyting javobidan keladi).
   */
  @ApiPropertyOptional({ description: "Viloyat nomi yoki 'me'" })
  @IsString()
  @MaxLength(64)
  @IsOptional()
  region?: string;
}
