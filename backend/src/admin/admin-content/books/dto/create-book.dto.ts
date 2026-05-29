import { ApiProperty } from '@nestjs/swagger';
import {
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

const CONTENT_STATUSES = ['hidden', 'pending', 'approved', 'rejected'] as const;
const PLAN_REQUIRED = ['free', 'standard', 'premium', 'vip'] as const;

export class CreateBookDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  title: string;

  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  @MaxLength(150)
  author: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(4000)
  description?: string | null;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  pdfUrl?: string | null;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  coverUrl?: string | null;

  @ApiProperty({ default: 0 })
  @IsOptional()
  @IsInt()
  @Min(0)
  pages?: number;

  @ApiProperty({ default: 0 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(25)
  ageFrom?: number;

  @ApiProperty({ default: 18 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(25)
  ageTo?: number;

  @ApiProperty({ default: 'school' })
  @IsOptional()
  @IsString()
  category?: string;

  @ApiProperty({ enum: PLAN_REQUIRED, default: 'free' })
  @IsOptional()
  @IsEnum(PLAN_REQUIRED)
  planRequired?: (typeof PLAN_REQUIRED)[number];

  @ApiProperty({ enum: CONTENT_STATUSES, default: 'hidden' })
  @IsOptional()
  @IsEnum(CONTENT_STATUSES)
  status?: (typeof CONTENT_STATUSES)[number];
}

export class UpdateBookDto {
  @IsOptional() @IsString() @MaxLength(200) title?: string;
  @IsOptional() @IsString() @MaxLength(150) author?: string;
  @IsOptional() @IsString() @MaxLength(4000) description?: string | null;
  @IsOptional() @IsString() pdfUrl?: string | null;
  @IsOptional() @IsString() coverUrl?: string | null;
  @IsOptional() @IsInt() @Min(0) pages?: number;
  @IsOptional() @IsInt() @Min(0) @Max(25) ageFrom?: number;
  @IsOptional() @IsInt() @Min(0) @Max(25) ageTo?: number;
  @IsOptional() @IsString() category?: string;
  @IsOptional() @IsEnum(['free', 'standard', 'premium', 'vip']) planRequired?: string;
  @IsOptional() @IsEnum(['hidden', 'pending', 'approved', 'rejected']) status?: string;
}
