import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

/** Foydalanuvchiga ogohlantirish (push) yuborish. */
export class WarnUserDto {
  @ApiProperty({ example: "Qoidalarni buzganingiz uchun ogohlantirish." })
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  message: string;
}
