import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsDate, IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';
import { KELAJAK_TEST_TYPES, TEXT_ANSWER_MAX_LENGTH } from '../domain/catalog';

/** Test turi nomidan uzun satr — albatta noma'lum (servis 400 UNKNOWN_TYPE qaytaradi). */
const TYPE_MAX_LENGTH = 40;
/** Shkala qiymati chegarasi (bank variantlari 1..5; aniq tekshiruv — variantlar bo'yicha). */
const ANSWER_VALUE_MIN = -1000;
const ANSWER_VALUE_MAX = 1000;
export const DEFAULT_RESULTS_LIMIT = 30;
const MAX_RESULTS_LIMIT = 100;

export class StartKelajakSessionDto {
  // Ro'yxatdan tashqari tur — servisda 400 `UNKNOWN_TYPE` (kontrakt kodi bilan).
  @ApiProperty({ enum: KELAJAK_TEST_TYPES, example: 'daily' })
  @IsString()
  @MaxLength(TYPE_MAX_LENGTH)
  type!: string;
}

/**
 * Javob: shkala savoliga `value` (variant qiymati), ochiq savolga `text`
 * (`""` — javobni o'chiradi). Aynan bittasi beriladi.
 */
export class KelajakAnswerDto {
  @ApiPropertyOptional({ type: Number, example: 4 })
  @IsOptional()
  @IsInt()
  @Min(ANSWER_VALUE_MIN)
  @Max(ANSWER_VALUE_MAX)
  value?: number;

  @ApiPropertyOptional({ maxLength: TEXT_ANSWER_MAX_LENGTH })
  @IsOptional()
  @IsString()
  @MaxLength(TEXT_ANSWER_MAX_LENGTH)
  text?: string;
}

export class KelajakResultsQueryDto {
  @ApiPropertyOptional({ minimum: 1, maximum: MAX_RESULTS_LIMIT, default: DEFAULT_RESULTS_LIMIT })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(MAX_RESULTS_LIMIT)
  limit?: number;

  @ApiPropertyOptional({ description: 'Shu vaqtdan oldin yakunlanganlar (kursor, ISO 8601)' })
  @IsOptional()
  @Type(() => Date)
  @IsDate()
  before?: Date;
}
