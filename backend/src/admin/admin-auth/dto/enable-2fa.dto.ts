import { ApiProperty } from '@nestjs/swagger';
import { IsString, MaxLength, MinLength } from 'class-validator';

export class Enable2faDto {
  @ApiProperty({ description: '6-digit TOTP verification code from authenticator app' })
  @IsString()
  @MinLength(6)
  @MaxLength(8)
  code: string;
}
