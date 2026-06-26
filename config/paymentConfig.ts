import Config from 'react-native-config';
import type { PaymentsConfig, PaymentsEnvironment } from './paymentTypes';

const readConfigValue = (key: string) => {
  if (typeof Config !== 'undefined' && Config[key] !== undefined) {
    return Config[key] as string;
  }

  return '';
};

export const getDefaultPaymentsEnvironment = (): PaymentsEnvironment => {
  const value = readConfigValue('PAYMENTS_ENVIRONMENT').toLowerCase();

  return value === 'production' ? 'production' : 'development';
};

export const createDefaultPaymentsConfig = (
  overrides: Partial<PaymentsConfig> = {},
): PaymentsConfig => ({
  environment: getDefaultPaymentsEnvironment(),
  revenueCatKeys: {
    development: {
      ios: readConfigValue('REVENUE_TEST_CAT_KEY'),
      android: readConfigValue('REVENUE_TEST_CAT_KEY_ANDROID') || readConfigValue('REVENUE_TEST_CAT_KEY'),
    },
    production: {
      ios: readConfigValue('REVENUE_CAT_KEY'),
      android: readConfigValue('REVENUE_CAT_KEY_ANDROID') || readConfigValue('REVENUE_CAT_KEY'),
    },
  },
  features: ['premium'],
  entitlements: {
    premium: readConfigValue('REVENUE_CAT_PREMIUM_ENTITLEMENT') || 'premium',
  },
  debugLogs: getDefaultPaymentsEnvironment() === 'development',
  ...overrides,
});
