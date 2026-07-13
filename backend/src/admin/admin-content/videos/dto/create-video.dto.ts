import { ApiProperty } from '@nestjs/swagger';
import {
  IsBoolean,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUrl,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

const CONTENT_STATUSES = ['hidden', 'pending', 'approved', 'rejected'] as const;
const PLAN_REQUIRED = ['free', 'standard', 'premium', 'vip'] as const;
const VIDEO_LEVELS = ['beginner', 'intermediate', 'advanced'] as const;

export class CreateVideoDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  title: string;

  @ApiProperty()
  @IsUrl()
  url: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  thumbnail?: string | null;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(4000)
  description?: string | null;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsInt()
  @Min(0)
  durationSec?: number;

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

  @ApiProperty({ required: false })
  @IsOptional()
  @IsUUID()
  categoryId?: string | null;

  @ApiProperty({ enum: PLAN_REQUIRED, default: 'free' })
  @IsOptional()
  @IsEnum(PLAN_REQUIRED)
  planRequired?: (typeof PLAN_REQUIRED)[number];

  @ApiProperty({ required: false, enum: VIDEO_LEVELS })
  @IsOptional()
  @IsEnum(VIDEO_LEVELS)
  level?: (typeof VIDEO_LEVELS)[number];

  @ApiProperty({ enum: CONTENT_STATUSES, default: 'hidden' })
  @IsOptional()
  @IsEnum(CONTENT_STATUSES)
  status?: (typeof CONTENT_STATUSES)[number];

  @ApiProperty({ required: false })
  @IsOptional()
  @IsBoolean()
  featured?: boolean;

  @ApiProperty({ default: 0, description: 'DON mukofoti (bola to\'liq ko\'rgach)' })
  @IsOptional()
  @IsInt()
  @Min(0)
  xpReward?: number;
}

export class UpdateVideoDto {
  @IsOptional() @IsString() @MaxLength(200) title?: string;
  @IsOptional() @IsString() @MaxLength(4000) description?: string | null;
  @IsOptional() @IsString() thumbnail?: string | null;
  @IsOptional() @IsInt() @Min(0) durationSec?: number;
  @IsOptional() @IsInt() @Min(0) @Max(25) ageFrom?: number;
  @IsOptional() @IsInt() @Min(0) @Max(25) ageTo?: number;
  @IsOptional() @IsUUID() categoryId?: string | null;
  @IsOptional() @IsEnum(['free', 'standard', 'premium', 'vip']) planRequired?: string;
  @IsOptional() @IsEnum(['beginner', 'intermediate', 'advanced']) level?: string | null;
  @IsOptional() @IsEnum(['hidden', 'pending', 'approved', 'rejected']) status?: string;
  @IsOptional() @IsBoolean() featured?: boolean;
  @IsOptional() @IsInt() @Min(0) xpReward?: number;
}
