import { ApiProperty } from '@nestjs/swagger';
import {
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { Transform } from 'class-transformer';

const PROMOCODE_STATUSES = ['active', 'inactive', 'archived'] as const;

export class CreatePromocodeDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  @MinLength(2)
  @MaxLength(40)
  @Transform(({ value }) => value?.toUpperCase())
  code: string;

  @ApiProperty()
  @IsInt()
  @Min(1)
  @Max(100)
  discountPct: number;

  @ApiProperty({ default: 0 })
  @IsOptional()
  @IsInt()
  @Min(0)
  usageLimit?: number;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  expiresAt?: string | null;

  @ApiProperty({ required: false, enum: PROMOCODE_STATUSES })
  @IsOptional()
  @IsEnum(PROMOCODE_STATUSES)
  status?: (typeof PROMOCODE_STATUSES)[number];

  @ApiProperty({ required: false })
  @IsOptional()
  @IsUUID()
  planId?: string | null;
}
