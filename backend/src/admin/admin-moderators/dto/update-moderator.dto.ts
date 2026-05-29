import { ApiProperty } from '@nestjs/swagger';
import {
  IsArray,
  IsEnum,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

const ROLE_KEYS = ['super_admin', 'finance', 'content_maker', 'support', 'custom'] as const;

export class UpdateModeratorDto {
  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  name?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  phone?: string | null;

  @ApiProperty({ required: false, enum: ROLE_KEYS })
  @IsOptional()
  @IsEnum(ROLE_KEYS)
  moderatorRoleKey?: (typeof ROLE_KEYS)[number];

  @ApiProperty({ required: false, type: [String] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  permissions?: string[];

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MinLength(8)
  @MaxLength(120)
  password?: string;
}
