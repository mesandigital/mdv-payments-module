import type {
  CustomerInfo,
  PurchasesOffering,
  PurchasesPackage,
} from '@revenuecat/purchases-typescript-internal';

export type PaymentsEnvironment = 'development' | 'production';

export type PaymentsFeature = 'credits' | 'premium' | 'oneTimeUnlock';

export type PaymentsPlatformKeys = {
  ios?: string;
  android?: string;
};

export type PaymentsRevenueCatKeys = {
  development: PaymentsPlatformKeys;
  production: PaymentsPlatformKeys;
};

export type CreditProductConfig = {
  key: string;
  revenueCatIdentifier: string;
  credits: number;
  title?: string;
  description?: string;
};

export type EntitlementConfig = {
  premium?: string;
  [key: string]: string | undefined;
};

export type PremiumContentConfig = {
  title?: string;
  subtitle?: string;
  features?: string[];
  ctaLabel?: string;
};

export type CreditsContentConfig = {
  title?: string;
  subtitle?: string;
  creditLabel?: string;
  ctaLabel?: string;
};

export type PaymentsContentConfig = {
  premium?: PremiumContentConfig;
  credits?: CreditsContentConfig;
};

export type CreditGrantContext = {
  product: CreditProductConfig;
  package: PurchasesPackage;
  customerInfo: CustomerInfo;
};

export type CreditGrantAdapter = (context: CreditGrantContext) => Promise<void> | void;

export type PaymentsConfig = {
  environment: PaymentsEnvironment;
  revenueCatKeys: PaymentsRevenueCatKeys;
  appUserId?: string | null;
  features?: PaymentsFeature[];
  entitlements?: EntitlementConfig;
  creditProducts?: CreditProductConfig[];
  content?: PaymentsContentConfig;
  debugLogs?: boolean;
  creditGrantAdapter?: CreditGrantAdapter;
};

export type PurchaseResult = {
  customerInfo: CustomerInfo;
  productIdentifier?: string;
  grantedCredits?: number;
  isPremium: boolean;
};

export type PaymentsState = {
  isConfigured: boolean;
  loading: boolean;
  error: Error | null;
  offering: PurchasesOffering | null;
  packages: PurchasesPackage[];
  customerInfo: CustomerInfo | null;
  isPremium: boolean;
};

export type PaymentsContextValue = PaymentsState & {
  config: PaymentsConfig;
  refresh: () => Promise<void>;
  purchasePackage: (pkg: PurchasesPackage) => Promise<PurchaseResult | null>;
  purchaseCreditProduct: (productKey: string) => Promise<PurchaseResult | null>;
  restorePurchases: () => Promise<CustomerInfo>;
  hasEntitlement: (entitlementId: string) => boolean;
  getPackageForCreditProduct: (productKey: string) => PurchasesPackage | undefined;
};

export type {
  CustomerInfo,
  PurchasesOffering,
  PurchasesPackage,
};
