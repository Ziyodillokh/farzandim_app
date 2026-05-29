import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsDateString,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';

export class AppUsageEntryDto {
  @ApiProperty({ example: 'com.youtube' })
  @IsString()
  @MinLength(1)
  @MaxLength(255)
  packageName: string;

  @ApiProperty({ example: '2025-05-28', description: 'YYYY-MM-DD' })
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'date must be YYYY-MM-DD' })
  date: string;

  @ApiProperty({ example: 3600000 })
  @IsInt()
  @Min(0)
  foregroundMs: number;

  @ApiPropertyOptional()
  @IsDateString()
  @IsOptional()
  lastUsedAt?: string;

  @ApiPropertyOptional({ default: 0 })
  @IsInt()
  @Min(0)
  @IsOptional()
  openCount?: number = 0;
}

export class BatchUpsertUsageDto {
  @ApiProperty({ type: [AppUsageEntryDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(500)
  @ValidateNested({ each: true })
  @Type(() => AppUsageEntryDto)
  entries: AppUsageEntryDto[];
}
