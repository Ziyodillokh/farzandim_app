import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsInt, IsOptional, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';

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
}
