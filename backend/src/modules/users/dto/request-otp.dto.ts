import { ApiProperty } from '@nestjs/swagger';
import { IsString, Matches } from 'class-validator';

export class RequestOtpDto {
  @ApiProperty({
    example: '+998901234567',
    description: 'Phone in format +998XXXXXXXXX',
  })
  @IsString()
  @Matches(/^\+998\d{9}$/, {
    message: 'Phone must be in format +998XXXXXXXXX',
  })
  phone!: string;
}
