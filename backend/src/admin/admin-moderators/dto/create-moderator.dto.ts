import { ApiProperty } from '@nestjs/swagger';
import {
  IsArray,
  IsEmail,
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';
import { Transform } from 'class-transformer';

const ROLE_KEYS = ['super_admin', 'finance', 'content_maker', 'support', 'custom'] as const;

export class CreateModeratorDto {
  @ApiProperty({ example: 'Sardor Aliyev' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  name: string;

  @ApiProperty({ example: 'sardor@farzandim.uz' })
  @IsEmail()
  @Transform(({ value }) => value?.trim().toLowerCase())
  @MaxLength(180)
  email: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  phone?: string | null;

  @ApiProperty({ enum: ROLE_KEYS })
  @IsEnum(ROLE_KEYS)
  moderatorRoleKey: (typeof ROLE_KEYS)[number];

  @ApiProperty({ required: false, type: [String] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  permissions?: string[];

  @ApiProperty({ example: 'StrongPass123' })
  @IsString()
  @MinLength(8)
  @MaxLength(120)
  password: string;
}
