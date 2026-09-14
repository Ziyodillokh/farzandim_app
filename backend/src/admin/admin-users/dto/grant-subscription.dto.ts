import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

/**
 * Admin sovg'asi — ota-onaga tanlangan tarifni N kun BEPUL berish (demo).
 * Foydalanuvchilar ro'yxatidagi "…" menyusidan.
 */
export class GrantSubscriptionDto {
  @ApiProperty({ description: 'Sovg\'a qilinadigan tarif (Plan.id)' })
  @IsUUID()
  planId: string;

  @ApiProperty({ example: 7, description: 'Necha kun (1–365)' })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(365)
  days: number;

  @ApiProperty({ required: false, description: 'Ichki izoh (audit log uchun)' })
  @IsOptional()
  @IsString()
  @MaxLength(300)
  note?: string;
}
