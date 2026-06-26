import type { CreditGrantAdapter } from '../config/paymentTypes';

export const createCreditGrantAdapter = (
  grantCredits: (userId: string | null | undefined, credits: number) => Promise<void> | void,
  userId?: string | null,
): CreditGrantAdapter => {
  return async ({ product }) => {
    await grantCredits(userId, product.credits);
  };
};
