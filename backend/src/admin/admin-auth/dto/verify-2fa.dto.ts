import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, MaxLength, MinLength } from 'class-validator';

export class Verify2faDto {
  @ApiProperty({ description: 'Challenge token from login response' })
  @IsString()
  @IsNotEmpty()
  challengeId: string;

  @ApiProperty({ description: '6-digit TOTP code or 8-char backup code' })
  @IsString()
  @MinLength(6)
  @MaxLength(10)
  code: string;
}
