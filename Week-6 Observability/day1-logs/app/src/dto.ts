/**
 * Request shapes. The decorators do double duty:
 *   class-validator  -> rejects bad input with a 400 before it reaches us
 *   @nestjs/swagger  -> generates the request body schema on /docs
 * One definition, two consumers. That is the reason to bother with DTOs.
 */
import { ApiProperty } from '@nestjs/swagger';
import { IsInt, Max, Min } from 'class-validator';

export class CreateOrderDto {
  @ApiProperty({ example: 1, description: 'id of the tea being ordered' })
  @IsInt()
  @Min(1)
  teaId: number;

  @ApiProperty({ example: 2, minimum: 1, maximum: 10, description: 'number of cups' })
  @IsInt()
  @Min(1)
  @Max(10)
  quantity: number;
}
