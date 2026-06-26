import { useMemo } from 'react';
import { usePayments } from './usePayments';

export const useCredits = () => {
  const { config, packages, purchaseCreditProduct, getPackageForCreditProduct, loading } = usePayments();

  const creditProducts = useMemo(
    () =>
      (config.creditProducts ?? []).map((product) => ({
        ...product,
        package: getPackageForCreditProduct(product.key),
      })),
    [config.creditProducts, getPackageForCreditProduct],
  );

  return {
    loading,
    packages,
    creditProducts,
    purchaseCreditProduct,
  };
};
