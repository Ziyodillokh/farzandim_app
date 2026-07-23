import { ApiProperty } from '@nestjs/swagger';
import { IsEnum, IsOptional, IsString, MinLength } from 'class-validator';

export enum PaymentProviderEnum {
  payme = 'payme',
  click = 'click',
  uzum = 'uzum',
}

export enum BillingPeriodEnum {
  monthly = 'monthly',
  yearly = 'yearly',
}

export class CheckoutDto {
  @ApiProperty({ description: 'Plan ID to purchase' })
  @IsString()
  @MinLength(1)
  planId: string;

  @ApiProperty({ enum: PaymentProviderEnum })
  @IsEnum(PaymentProviderEnum)
  provider: PaymentProviderEnum;

  /**
   * Billing period: 'monthly' (default) yoki 'yearly'. Yillik = oylik narx ×10
   * (2 oy tekin). Oylik plan tanlansa ham yillik sotib olish mumkin.
   */
  @ApiProperty({ enum: BillingPeriodEnum, required: false, default: 'monthly' })
  @IsOptional()
  @IsEnum(BillingPeriodEnum)
  billingPeriod?: BillingPeriodEnum;
}
