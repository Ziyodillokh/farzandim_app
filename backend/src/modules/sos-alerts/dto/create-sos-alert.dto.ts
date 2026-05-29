import { ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsNumber,
  IsOptional,
  IsObject,
  Min,
  Max,
} from 'class-validator';

export class CreateSosAlertDto {
  @ApiPropertyOptional({ example: 41.2995 })
  @IsNumber()
  @Min(-90)
  @Max(90)
  @IsOptional()
  latitude?: number;

  @ApiPropertyOptional({ example: 69.2401 })
  @IsNumber()
  @Min(-180)
  @Max(180)
  @IsOptional()
  longitude?: number;

  @ApiPropertyOptional({ example: 10.5 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  accuracy?: number;

  @ApiPropertyOptional()
  @IsObject()
  @IsOptional()
  deviceInfo?: Record<string, unknown>;
}
