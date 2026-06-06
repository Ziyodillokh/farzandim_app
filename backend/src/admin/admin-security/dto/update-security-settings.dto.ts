import { ApiProperty } from '@nestjs/swagger';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

export class UpdateSecuritySettingsDto {
  @ApiProperty({ required: false })
  @IsOptional()
  @IsBoolean()
  ipAllowlistEnabled?: boolean;

  @ApiProperty({ required: false, type: [String] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(200)
  @IsString({ each: true })
  @MaxLength(45, { each: true })
  ipAllowlist?: string[];
}
