import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

/** Bola Faro'ga yuboradigan xabar. */
export class ChatDto {
  @ApiProperty({ example: 'Salom Faro! Kosmos haqida gapirib ber' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(1000)
  message: string;
}
