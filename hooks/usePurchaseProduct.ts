import { usePayments } from './usePayments';

export const usePurchaseProduct = () => {
  const {
    loading,
    purchasePackage,
    purchaseCreditProduct,
    restorePurchases,
    getPackageForCreditProduct,
  } = usePayments();

  return {
    loading,
    purchasePackage,
    purchaseCreditProduct,
    restorePurchases,
    getPackageForCreditProduct,
  };
};
