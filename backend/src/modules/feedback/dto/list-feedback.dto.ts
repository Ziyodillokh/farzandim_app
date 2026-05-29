import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsIn, IsInt, Min, Max } from 'class-validator';
import { Type } from 'class-transformer';

export class ListFeedbackDto {
  @ApiPropertyOptional({ enum: ['true', 'false'], description: 'Filter by read status' })
  @IsOptional()
  @IsIn(['true', 'false'])
  isRead?: 'true' | 'false';

  @ApiPropertyOptional({ default: 100, minimum: 1, maximum: 200 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  limit?: number;
}
