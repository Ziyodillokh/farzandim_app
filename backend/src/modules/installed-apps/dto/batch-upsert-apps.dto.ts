import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
  ValidateNested,
} from 'class-validator';

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
