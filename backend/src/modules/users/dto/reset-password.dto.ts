import { ApiProperty } from '@nestjs/swagger';
import { IsString, Length, MinLength, MaxLength } from 'class-validator';

export class ResetPasswordDto {
  @ApiProperty({
    example: '123456',
    description: '6-digit OTP code (joriy telefonga yuborilgan)',
  })
  @IsString()
  @Length(6, 6)
  code!: string;

  @ApiProperty({
    example: 'newPass123',
    description: 'Yangi parol (6-72 belgi)',
  })
  @IsString()
  @MinLength(6)
  @MaxLength(72)
  newPassword!: string;
}
