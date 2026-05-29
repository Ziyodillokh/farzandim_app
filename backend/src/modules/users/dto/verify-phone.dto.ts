import { ApiProperty } from '@nestjs/swagger';
import { IsString, Matches, Length } from 'class-validator';

export class VerifyPhoneDto {
  @ApiProperty({
    example: '+998901234567',
    description: 'Phone in format +998XXXXXXXXX',
  })
  @IsString()
  @Matches(/^\+998\d{9}$/, {
    message: 'Phone must be in format +998XXXXXXXXX',
  })
  phone!: string;

  @ApiProperty({ example: '123456', description: '6-digit OTP code' })
  @IsString()
  @Length(6, 6)
  code!: string;
}
