import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
  ValidateNested,
} from 'class-validator';

import { APP_CATEGORIES, AppCategory } from '../app-category.util';

export class InstalledAppDto {
  @ApiProperty()
  @IsString()
  @MinLength(1)
  @MaxLength(255)
  packageName: string;

  @ApiProperty()
  @IsString()
  @MinLength(1)
  @MaxLength(255)
  appName: string;

  @ApiPropertyOptional()
  @IsString()
  @MaxLength(50)
  @IsOptional()
  versionName?: string;

  @ApiPropertyOptional()
  @IsInt()
  @IsOptional()
  versionCode?: number;

  @ApiPropertyOptional()
  @IsString()
  @MaxLength(50)
  @IsOptional()
  installSource?: string;

  @ApiPropertyOptional()
  @IsString()
  @MaxLength(500)
  @IsOptional()
  iconPath?: string;

  @ApiPropertyOptional({ description: 'Base64-encoded icon (max ~50KB binary)' })
  @IsString()
  @MaxLength(80_000)
  @IsOptional()
  iconBase64?: string;

  @ApiPropertyOptional({ default: false })
  @IsBoolean()
  @IsOptional()
  isSystem?: boolean = false;

  // Bola qurilmasi ApplicationInfo'dan aniqlagan haqiqiy kategoriya
  // (GAME/SOCIAL/VIDEO). Bo'lsa backend paket-nomi taxminidan ustun qo'yadi.
  @ApiPropertyOptional({
    enum: APP_CATEGORIES,
    description: "Qurilma aniqlagan haqiqiy kategoriya (GAME/SOCIAL/VIDEO)",
  })
  @IsString()
  @IsIn(APP_CATEGORIES)
  @IsOptional()
  category?: AppCategory;
}

export class BatchUpsertAppsDto {
  @ApiProperty({ type: [InstalledAppDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(500)
  @ValidateNested({ each: true })
  @Type(() => InstalledAppDto)
  apps: InstalledAppDto[];
}
