import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsIn,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

const CONTENT_STATUSES = ['hidden', 'pending', 'approved', 'rejected'] as const;

export class CreateArticleDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  title: string;

  @ApiProperty({ description: 'Markdown matn' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(40000)
  body: string;

  @ApiPropertyOptional({ description: 'Muqova MinIO storage key' })
  @IsOptional()
  @IsString()
  coverPath?: string | null;

  @ApiPropertyOptional({ default: 0 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(25)
  ageFrom?: number;

  @ApiPropertyOptional({ default: 18 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(25)
  ageTo?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(100)
  category?: string | null;

  @ApiPropertyOptional({ enum: CONTENT_STATUSES, default: 'approved' })
  @IsOptional()
  @IsString()
  @IsIn(CONTENT_STATUSES)
  status?: string;
}

export class UpdateArticleDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(200)
  title?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(40000)
  body?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  coverPath?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(25)
  ageFrom?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(25)
  ageTo?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(100)
  category?: string | null;

  @ApiPropertyOptional({ enum: CONTENT_STATUSES })
  @IsOptional()
  @IsString()
  @IsIn(CONTENT_STATUSES)
  status?: string;
}
