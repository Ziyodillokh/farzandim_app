import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export enum LeaderboardPeriod {
  weekly = 'weekly',
  monthly = 'monthly',
  all = 'all',
}

/**
 * XP reyting so'rovi. Har maydonda class-validator dekoratori SHART (global
 * ValidationPipe whitelist + forbidNonWhitelisted), aks holda "property X
 * should not exist" 400.
 */
export class LeaderboardQueryDto {
  @ApiPropertyOptional({ enum: LeaderboardPeriod, default: LeaderboardPeriod.all })
  @IsOptional()
  @IsEnum(LeaderboardPeriod)
  period?: LeaderboardPeriod = LeaderboardPeriod.all;

  @ApiPropertyOptional({ example: 'Qashqadaryo', description: 'Viloyat filtri' })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  region?: string;

  @ApiPropertyOptional({ default: 1, minimum: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @ApiPropertyOptional({ default: 15, minimum: 1, maximum: 50 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number = 15;

  @ApiPropertyOptional({ description: 'Joriy bola id — "Siz" reytingi uchun' })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  childId?: string;
}
