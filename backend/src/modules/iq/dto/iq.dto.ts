import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsInt, IsOptional, Max, Min } from 'class-validator';
import { OPTION_KEYS } from '../domain/levels';

/** Bitta savolga sarflangan vaqt chegarasi (1 soat) — undan ko'pi xato. */
const MAX_DURATION_MS = 60 * 60 * 1000;

export class IqAnswerDto {
  @ApiProperty({ enum: OPTION_KEYS, example: 'C' })
  @IsIn(OPTION_KEYS)
  choice!: string;

  @ApiPropertyOptional({
    type: Number,
    example: 18_500,
    description: 'Savolga sarflangan vaqt (ms)',
  })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(MAX_DURATION_MS)
  durationMs?: number;
}
