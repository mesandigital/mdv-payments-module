import { usePayments } from './usePayments';

export const usePremiumStatus = () => {
  const { isPremium, loading, refresh, customerInfo, hasEntitlement, config } = usePayments();

  return {
    isPremium,
    loading,
    refresh,
    customerInfo,
    hasPremiumEntitlement: () => hasEntitlement(config.entitlements?.premium ?? 'premium'),
  };
};
