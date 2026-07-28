import React, {
  createContext,
  PropsWithChildren,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from 'react';
import type {
  CustomerInfo,
  PaymentsConfig,
  PaymentsContextValue,
  PaymentsState,
  PurchaseResult,
  PurchasesPackage,
} from '../config/paymentTypes';
import {
  configureRevenueCat,
  findPackageByIdentifier,
  getCurrentOffering,
  getCustomerInfo,
  hasEntitlement as hasRevenueCatEntitlement,
  isPremiumCustomer,
  purchaseRevenueCatPackage,
  restoreRevenueCatPurchases,
} from '../services/revenueCatClient';

const PaymentsContext = createContext<PaymentsContextValue | null>(null);

type PaymentsProviderProps = PropsWithChildren<{
  config: PaymentsConfig;
}>;

const initialState: PaymentsState = {
  isConfigured: false,
  loading: true,
  error: null,
  offering: null,
  packages: [],
  customerInfo: null,
  isPremium: false,
};

const toError = (value: unknown) => (
  value instanceof Error ? value : new Error(String(value))
);

export const PaymentsProvider = ({ config, children }: PaymentsProviderProps) => {
  const [state, setState] = useState<PaymentsState>(initialState);

  const refresh = useCallback(async () => {
    setState((current) => ({ ...current, loading: true, error: null }));

    try {
      await configureRevenueCat(config);

      const customerInfo = await getCustomerInfo();
      let offering = null;
      let offeringError: Error | null = null;

      try {
        offering = await getCurrentOffering();
      } catch (caughtError) {
        offeringError = toError(caughtError);
        console.warn('[PaymentsProvider] RevenueCat offerings unavailable:', offeringError.message);
      }

      setState({
        isConfigured: true,
        loading: false,
        error: offeringError,
        offering,
        packages: offering?.availablePackages ?? [],
        customerInfo,
        isPremium: isPremiumCustomer(customerInfo, config),
      });
    } catch (caughtError) {
      const normalizedError = toError(caughtError);
      setState((current) => ({
        ...current,
        loading: false,
        error: normalizedError,
      }));
    }
  }, [config]);

  useEffect(() => {
    refresh();
  }, [refresh]);

  const purchasePackage = useCallback(
    async (pkg: PurchasesPackage): Promise<PurchaseResult | null> => {
      setState((current) => ({ ...current, loading: true, error: null }));

      try {
        const result = await purchaseRevenueCatPackage(pkg, config);

        setState((current) => ({
          ...current,
          loading: false,
          customerInfo: result.customerInfo,
          isPremium: result.isPremium,
        }));

        return result;
      } catch (caughtError: any) {
        if (!caughtError?.userCancelled) {
          const normalizedError = toError(caughtError);
          setState((current) => ({
            ...current,
            loading: false,
            error: normalizedError,
          }));
        } else {
          setState((current) => ({ ...current, loading: false }));
        }

        return null;
      }
    },
    [config],
  );

  const getPackageForCreditProduct = useCallback(
    (productKey: string) => {
      const product = config.creditProducts?.find((item) => item.key === productKey);

      if (!product) {
        return undefined;
      }

      return findPackageByIdentifier(state.packages, product.revenueCatIdentifier);
    },
    [config.creditProducts, state.packages],
  );

  const purchaseCreditProduct = useCallback(
    async (productKey: string): Promise<PurchaseResult | null> => {
      const product = config.creditProducts?.find((item) => item.key === productKey);

      if (!product) {
        throw new Error(`Unknown credit product: ${productKey}`);
      }

      const pkg = getPackageForCreditProduct(productKey);

      if (!pkg) {
        throw new Error(`RevenueCat package not found for credit product: ${productKey}`);
      }

      const result = await purchasePackage(pkg);

      if (!result) {
        return null;
      }

      await config.creditGrantAdapter?.({
        product,
        package: pkg,
        customerInfo: result.customerInfo,
      });

      return {
        ...result,
        grantedCredits: product.credits,
      };
    },
    [config, getPackageForCreditProduct, purchasePackage],
  );

  const restorePurchases = useCallback(async (): Promise<CustomerInfo> => {
    setState((current) => ({ ...current, loading: true, error: null }));

    try {
      const customerInfo = await restoreRevenueCatPurchases();

      setState((current) => ({
        ...current,
        loading: false,
        customerInfo,
        isPremium: isPremiumCustomer(customerInfo, config),
      }));

      return customerInfo;
    } catch (caughtError) {
      const normalizedError = toError(caughtError);
      setState((current) => ({
        ...current,
        loading: false,
        error: normalizedError,
      }));
      throw caughtError;
    }
  }, [config]);

  const hasEntitlement = useCallback(
    (entitlementId: string) => hasRevenueCatEntitlement(state.customerInfo, entitlementId),
    [state.customerInfo],
  );

  const value = useMemo<PaymentsContextValue>(
    () => ({
      ...state,
      config,
      refresh,
      purchasePackage,
      purchaseCreditProduct,
      restorePurchases,
      hasEntitlement,
      getPackageForCreditProduct,
    }),
    [
      state,
      config,
      refresh,
      purchasePackage,
      purchaseCreditProduct,
      restorePurchases,
      hasEntitlement,
      getPackageForCreditProduct,
    ],
  );

  return (
    <PaymentsContext.Provider value={value}>
      {children}
    </PaymentsContext.Provider>
  );
};

export const usePaymentsContext = () => {
  const context = useContext(PaymentsContext);

  if (!context) {
    throw new Error('usePayments must be used within a PaymentsProvider.');
  }

  return context;
};
