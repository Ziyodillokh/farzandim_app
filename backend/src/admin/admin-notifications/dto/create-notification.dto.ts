import { ApiProperty } from '@nestjs/swagger';
import {
  IsEnum,
  IsNotEmpty,
  IsObject,
  IsOptional,
  IsString,
  IsUrl,
  MaxLength,
  MinLength,
} from 'class-validator';

const TARGET_TYPES = ['all', 'parents', 'children', 'premium', 'age_group'] as const;

export class CreateNotificationDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  title: string;

  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  message: string;

  @ApiProperty({ enum: TARGET_TYPES })
  @IsEnum(TARGET_TYPES)
  targetType: (typeof TARGET_TYPES)[number];

  @ApiProperty({ required: false })
  @IsOptional()
  @IsObject()
  filters?: {
    activeOnly?: boolean;
    premiumOnly?: boolean;
    ageFrom?: number;
    ageTo?: number;
  };

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  imageUrl?: string | null;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  deepLink?: string | null;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  scheduledAt?: string | null;
}
