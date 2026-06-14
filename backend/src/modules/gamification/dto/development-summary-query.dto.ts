import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional, IsString } from 'class-validator';

/** Rivojlanish ko'rsatkichi vaqt oralig'i (#63). */
export class DevelopmentSummaryQueryDto {
  @ApiPropertyOptional({ enum: ['weekly', 'monthly'], default: 'weekly' })
  @IsOptional()
  @IsString()
  @IsIn(['weekly', 'monthly'])
  range?: 'weekly' | 'monthly';
}
