import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsString,
  Length,
  IsOptional,
  ValidateNested,
  IsBoolean,
  IsInt,
  Min,
  Max,
  MaxLength,
} from 'class-validator';
import { Type } from 'class-transformer';

export class DeviceInfoDto {
  @ApiPropertyOptional({ example: 'Samsung Galaxy A52' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  model?: string;

  @ApiPropertyOptional({ example: 'Android 13' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  os?: string;

  @ApiPropertyOptional({ example: 85 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100)
  batteryLevel?: number;

  @ApiPropertyOptional({ example: false })
  @IsOptional()
  @IsBoolean()
  isCharging?: boolean;
}

export class ChildPairDto {
  @ApiProperty({
    example: '12345',
    description: 'Family code (5 digits)',
    minLength: 5,
    maxLength: 5,
  })
  @IsString()
  @Length(5, 5)
  familyCode!: string;

  @ApiPropertyOptional({ type: DeviceInfoDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => DeviceInfoDto)
  deviceInfo?: DeviceInfoDto;
}
