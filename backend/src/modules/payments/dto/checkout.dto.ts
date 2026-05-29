import { ApiProperty } from '@nestjs/swagger';
import { IsEnum, IsString, MinLength } from 'class-validator';

export enum PaymentProviderEnum {
  payme = 'payme',
  click = 'click',
  uzum = 'uzum',
}

export class CheckoutDto {
  @ApiProperty({ description: 'Plan ID to purchase' })
  @IsString()
  @MinLength(1)
  planId: string;

  @ApiProperty({ enum: PaymentProviderEnum })
  @IsEnum(PaymentProviderEnum)
  provider: PaymentProviderEnum;
}
