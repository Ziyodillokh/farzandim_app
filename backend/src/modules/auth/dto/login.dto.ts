import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString } from 'class-validator';

/**
 * Email yoki telefon + parol bilan kirish.
 * `identifier` — email manzili yoki +998 telefon raqami (service aniqlaydi).
 */
export class LoginDto {
  @ApiProperty({
    example: 'ota@example.com',
    description: 'Email manzili yoki +998 telefon raqami',
  })
  @IsString()
  @IsNotEmpty({ message: "Email yoki telefon raqamni kiriting" })
  identifier!: string;

  @ApiProperty({ example: 'Parol123' })
  @IsString()
  @IsNotEmpty({ message: "Parolni kiriting" })
  password!: string;
}
