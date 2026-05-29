import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class Disable2faDto {
  @ApiProperty({ description: 'Current password for verification' })
  @IsString()
  @IsNotEmpty()
  password: string;

  @ApiProperty({ description: '6-digit TOTP code (required if 2FA is enabled)', required: false })
  @IsOptional()
  @IsString()
  @MinLength(6)
  @MaxLength(10)
  code?: string;
}
