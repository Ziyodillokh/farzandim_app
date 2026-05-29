import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsInt, IsOptional, IsString, Matches, Max, MaxLength, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class ListAppUsageDto {
  @ApiPropertyOptional({ example: '2025-05-01' })
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  @IsOptional()
  from?: string;

  @ApiPropertyOptional({ example: '2025-05-28' })
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  @IsOptional()
  to?: string;

  @ApiPropertyOptional()
  @IsString()
  @MaxLength(255)
  @IsOptional()
  packageName?: string;

  @ApiPropertyOptional({ default: 500 })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(1000)
  @IsOptional()
  limit?: number = 500;
}
