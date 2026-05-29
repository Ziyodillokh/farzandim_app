import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsString,
  IsOptional,
  MinLength,
  MaxLength,
  IsEnum,
} from 'class-validator';

export enum DeviceType {
  ANDROID = 'android',
  IOS = 'ios',
}

export class RegisterTokenDto {
  @ApiProperty({
    description: 'FCM registration token',
    minLength: 20,
    maxLength: 4096,
  })
  @IsString()
  @MinLength(20)
  @MaxLength(4096)
  token!: string;

  @ApiPropertyOptional({ enum: DeviceType, example: 'android' })
  @IsOptional()
  @IsEnum(DeviceType)
  deviceType?: DeviceType;

  @ApiPropertyOptional({
    example: 'device-unique-id-123',
    maxLength: 200,
  })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  deviceId?: string;
}
