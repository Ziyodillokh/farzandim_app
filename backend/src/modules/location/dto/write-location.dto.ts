import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsString,
  IsNumber,
  IsOptional,
  IsUUID,
  IsBoolean,
  IsInt,
  Min,
  Max,
  MaxLength,
} from 'class-validator';

export class WriteLocationDto {
  @ApiProperty({ description: 'Child ID (UUID)', example: 'uuid-here' })
  @IsUUID()
  childId!: string;

  @ApiProperty({ example: 41.2995, minimum: -90, maximum: 90 })
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude!: number;

  @ApiProperty({ example: 69.2401, minimum: -180, maximum: 180 })
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude!: number;

  @ApiPropertyOptional({ example: 12.5, description: 'GPS accuracy in meters' })
  @IsOptional()
  @IsNumber()
  accuracy?: number;

  @ApiPropertyOptional({ example: 2.3, description: 'Speed in m/s' })
  @IsOptional()
  @IsNumber()
  speed?: number;

  @ApiPropertyOptional({ example: 85, minimum: 0, maximum: 100 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100)
  batteryLevel?: number;

  @ApiPropertyOptional({ example: false })
  @IsOptional()
  @IsBoolean()
  isCharging?: boolean;

  @ApiPropertyOptional({ example: 'Samsung Galaxy A52', maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  deviceModel?: string;

  @ApiPropertyOptional({ example: 'Android 13', maxLength: 50 })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  androidVersion?: string;

  @ApiPropertyOptional({ example: '1.2.0', maxLength: 50 })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  appVersion?: string;

  @ApiPropertyOptional({ example: 'Home_WiFi', maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  wifiName?: string;
}
