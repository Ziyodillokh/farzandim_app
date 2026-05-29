import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsNotEmpty,
  IsString,
  MaxLength,
  MinLength,
  IsNumber,
  IsInt,
  Min,
  Max,
  IsBoolean,
  IsOptional,
} from 'class-validator';

export class CreateGeoZoneDto {
  @ApiProperty({ example: 'Uy', maxLength: 100 })
  @IsNotEmpty()
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  name: string;

  @ApiProperty({ example: 41.2995, description: 'Latitude of center' })
  @IsNumber()
  @Min(-90)
  @Max(90)
  centerLat: number;

  @ApiProperty({ example: 69.2401, description: 'Longitude of center' })
  @IsNumber()
  @Min(-180)
  @Max(180)
  centerLng: number;

  @ApiProperty({ example: 200, description: 'Radius in meters (10 - 50000)', minimum: 10, maximum: 50000 })
  @IsInt()
  @Min(10)
  @Max(50000)
  radiusMeters: number;

  @ApiPropertyOptional({ default: false, description: 'Alert parent when child enters zone' })
  @IsOptional()
  @IsBoolean()
  alertOnEnter?: boolean;

  @ApiPropertyOptional({ default: false, description: 'Alert parent when child exits zone' })
  @IsOptional()
  @IsBoolean()
  alertOnExit?: boolean;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
