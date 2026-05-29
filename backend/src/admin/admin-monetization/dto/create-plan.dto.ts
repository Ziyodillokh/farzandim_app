import { ApiProperty } from '@nestjs/swagger';
import {
  IsArray,
  IsBoolean,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

const PLAN_PERIODS = ['monthly', 'yearly', 'lifetime'] as const;
const ENTITLEMENT_TIERS = ['free', 'standard', 'premium', 'vip'] as const;

export class CreatePlanDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  name: string;

  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  @MaxLength(64)
  @Matches(/^[a-z0-9-]+$/)
  slug: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string | null;

  @ApiProperty({ default: 0 })
  @IsInt()
  @Min(0)
  priceUzs: number;

  @ApiProperty({ enum: PLAN_PERIODS, default: 'monthly' })
  @IsEnum(PLAN_PERIODS)
  period: (typeof PLAN_PERIODS)[number];

  @ApiProperty({ enum: ENTITLEMENT_TIERS, default: 'standard' })
  @IsEnum(ENTITLEMENT_TIERS)
  entitlementTier: (typeof ENTITLEMENT_TIERS)[number];

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  badge?: string | null;

  @ApiProperty({ required: false, type: [String] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  features?: string[];

  @ApiProperty({ required: false })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsInt()
  sortOrder?: number;
}
