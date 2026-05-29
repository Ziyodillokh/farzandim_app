import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

export class CreateAppLimitDto {
  @ApiProperty({ example: 'com.youtube' })
  @IsString()
  @MinLength(1)
  @MaxLength(255)
  packageName: string;

  @ApiProperty({
    description: 'Daily limit in milliseconds (number or numeric string)',
    example: 900000,
  })
  dailyLimitMs: number | string;

  @ApiPropertyOptional({
    description: 'Weekly limit in milliseconds (number or numeric string)',
    example: 3600000,
  })
  @IsOptional()
  weeklyLimitMs?: number | string;

  @ApiPropertyOptional({ default: true })
  @IsBoolean()
  @IsOptional()
  isActive?: boolean = true;
}
