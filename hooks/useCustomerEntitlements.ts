import { useMemo } from 'react';
import { usePayments } from './usePayments';

export const useCustomerEntitlements = () => {
  const { customerInfo, hasEntitlement, loading, refresh } = usePayments();

  const activeEntitlementIds = useMemo(
    () => Object.keys(customerInfo?.entitlements.active ?? {}),
    [customerInfo],
  );

  return {
    customerInfo,
    activeEntitlementIds,
    hasEntitlement,
    loading,
    refresh,
  };
};
