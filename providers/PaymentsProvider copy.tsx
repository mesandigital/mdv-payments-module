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

const PaymentsContext = createContext<PaymentsContextValue | null>(null);

type PaymentsProviderProps = PropsWithChildren<{
  config: PaymentsConfig;
}>;

const initialState: PaymentsState = {
  isConfigured: false,
  loading: false,
  error: null,
  offering: null,
  packages: [],
  customerInfo: null,
  isPremium: false,
};

export const PaymentsProvider = ({ config, children }: PaymentsProviderProps) => {
  const [state, setState] = useState<PaymentsState>(initialState);

  const refresh = useCallback(async () => {
    setState((current) => ({ ...current, loading: false, error: null }));
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  const purchasePackage = useCallback(
    async (_pkg: PurchasesPackage): Promise<PurchaseResult | null> => {
      setState((current) => ({ ...current, loading: false, error: null }));
      return null;
    },
    [],
  );

  const getPackageForCreditProduct = useCallback(
    (productKey: string) => {
      const product = config.creditProducts?.find((item) => item.key === productKey);

      if (!product) {
        return undefined;
      }

      return state.packages.find((pkg) => {
        const productInfo = pkg.product;

        return (
          pkg.identifier === product.revenueCatIdentifier ||
          productInfo.identifier === product.revenueCatIdentifier
        );
      });
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
    const error = new Error('RevenueCat is disabled.');
    setState((current) => ({ ...current, loading: false, error }));
    throw error;
  }, []);

  const hasEntitlement = useCallback(
    (_entitlementId: string) => false,
    [],
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
