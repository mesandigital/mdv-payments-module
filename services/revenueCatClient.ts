import { Platform } from 'react-native';
import Purchases, { LOG_LEVEL } from 'react-native-purchases';
import type {
  CustomerInfo,
  PaymentsConfig,
  PurchaseResult,
  PurchasesOffering,
  PurchasesPackage,
} from '../config/paymentTypes';

let configuredKey: string | null = null;
let configuredUserId: string | null | undefined;

const getApiKey = (config: PaymentsConfig) => {
  const platformKeys = config.revenueCatKeys[config.environment];
  const apiKey = Platform.OS === 'ios' ? platformKeys.ios : platformKeys.android;

  if (!apiKey) {
    throw new Error(
      `Missing RevenueCat ${Platform.OS} API key for ${config.environment} payments environment.`,
    );
  }

  return apiKey;
};

export const configureRevenueCat = async (config: PaymentsConfig) => {
  const apiKey = getApiKey(config);
  const appUserId = config.appUserId ?? null;

  if (configuredKey === apiKey && configuredUserId === appUserId) {
    return;
  }

  Purchases.setLogLevel(config.debugLogs ? LOG_LEVEL.VERBOSE : LOG_LEVEL.WARN);
  await Purchases.configure({
    apiKey,
    appUserID: appUserId,
  });

  configuredKey = apiKey;
  configuredUserId = appUserId;
};

export const getCurrentOffering = async (): Promise<PurchasesOffering | null> => {
  const offerings = await Purchases.getOfferings();

  return offerings.current ?? null;
};

export const getCustomerInfo = async (): Promise<CustomerInfo> => {
  return Purchases.getCustomerInfo();
};

export const hasEntitlement = (
  customerInfo: CustomerInfo | null | undefined,
  entitlementId = 'premium',
) => {
  return Boolean(customerInfo?.entitlements.active[entitlementId]);
};

export const isPremiumCustomer = (
  customerInfo: CustomerInfo | null | undefined,
  config: PaymentsConfig,
) => {
  return hasEntitlement(customerInfo, config.entitlements?.premium ?? 'premium');
};

export const purchaseRevenueCatPackage = async (
  pkg: PurchasesPackage,
  config: PaymentsConfig,
): Promise<PurchaseResult> => {
  const { customerInfo, productIdentifier } = await Purchases.purchasePackage(pkg);

  return {
    customerInfo,
    productIdentifier,
    isPremium: isPremiumCustomer(customerInfo, config),
  };
};

export const restoreRevenueCatPurchases = async (): Promise<CustomerInfo> => {
  return Purchases.restorePurchases();
};

export const findPackageByIdentifier = (
  packages: PurchasesPackage[],
  revenueCatIdentifier: string,
) => {
  return packages.find((pkg) => {
    const product = pkg.product;

    return (
      pkg.identifier === revenueCatIdentifier ||
      product.identifier === revenueCatIdentifier
    );
  });
};
