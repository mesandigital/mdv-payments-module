# mdv-payments-module

Reusable RevenueCat payment module for premium upgrades, credit packs, and app-specific paywalls.

The module owns RevenueCat setup, offering loading, purchases, restores, entitlement checks, and default payment UI. The host app owns product configuration, user identity, app copy, feature gating, and credit persistence.

## What It Supports

- Premium subscriptions through RevenueCat entitlements.
- Credit pack purchases mapped to RevenueCat packages/products.
- Development and production key switching.
- Default UI for premium upgrades and credit packs.
- Hook-only usage when an app needs custom UI.
- Backwards compatibility for the existing `src/services/revenuecat` wrapper.

## Install

For local development inside this repo:

```json
{
  "dependencies": {
    "mdv-payments-module": "file:src/modules/payments"
  }
}
```

For another app after publishing:

```sh
npm install mdv-payments-module react-native-purchases react-native-config
```

## Files

```txt
src/modules/payments/
  adapters/
    createCreditGrantAdapter.ts
  components/
    CreditPacks.tsx
    PaymentOptionList.tsx
    Paywall.tsx
    PremiumUpgrade.tsx
  config/
    paymentConfig.ts
    paymentTypes.ts
  hooks/
    useCredits.ts
    useCustomerEntitlements.ts
    usePayments.ts
    usePremiumStatus.ts
    usePurchaseProduct.ts
  providers/
    PaymentsProvider.tsx
  services/
    revenueCatClient.ts
  index.ts
```

## Environment Variables

`createDefaultPaymentsConfig()` reads these values from `react-native-config`:

```txt
PAYMENTS_ENVIRONMENT=development

REVENUE_TEST_CAT_KEY=
REVENUE_TEST_CAT_KEY_ANDROID=

REVENUE_CAT_KEY=
REVENUE_CAT_KEY_ANDROID=

REVENUE_CAT_PREMIUM_ENTITLEMENT=premium
```

If the Android-specific keys are empty, the module falls back to the shared iOS/test key names.

## Store And RevenueCat Setup

The module does not create App Store Connect or RevenueCat products for you. Create those first, then pass the identifiers into `PaymentsProvider`.

### Identifier Planning

Use stable product identifiers because they are referenced by Apple, RevenueCat, and this module.

Recommended examples:

```txt
Premium subscription entitlement:
premium

Apple subscription product IDs:
premium_monthly
premium_yearly

Apple consumable credit product IDs:
credits_10
credits_50
credits_100

RevenueCat offering identifier:
default
```

In this module:

- `entitlements.premium` must match the RevenueCat entitlement identifier.
- `creditProducts[].revenueCatIdentifier` must match either the RevenueCat package identifier or the underlying store product identifier.
- The default paywall reads RevenueCat package prices from the current/default offering.

## Apple App Store Connect Setup

Use App Store Connect for real iOS products. RevenueCat's Test Store is enough for early development, but production iOS purchases need App Store Connect products.

Apple docs:

- Consumable/non-consumable In-App Purchases: https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/create-consumable-or-non-consumable-in-app-purchases
- Auto-renewable subscriptions: https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions
- Sandbox testing: https://developer.apple.com/help/app-store-connect/test-in-app-purchases/overview-of-testing-in-sandbox

### Premium Subscription Products

Use auto-renewable subscriptions for Premium/Pro access.

1. Open App Store Connect.
2. Select the app.
3. Go to `Monetization` -> `Subscriptions`.
4. Create a subscription group, for example `Premium`.
5. Add subscription products inside the group:
   - `premium_monthly`
   - `premium_yearly`
6. For each subscription product, set:
   - Reference name.
   - Product ID.
   - Duration.
   - Price.
   - Availability.
   - Localization/display name.
   - Review information.
7. If you have multiple tiers, assign subscription levels so Apple knows upgrade/downgrade order.

For most apps, keep monthly and yearly Premium plans in the same subscription group. Apple allows one active subscription per group, which prevents users from buying duplicate plans for the same service.

### Credit Pack Products

Use consumable In-App Purchases for credits.

1. Open App Store Connect.
2. Select the app.
3. Go to `Monetization` -> `In-App Purchases`.
4. Click `+`.
5. Choose `Consumable`.
6. Create products such as:
   - `credits_10`
   - `credits_50`
   - `credits_100`
7. Set price, availability, localization, and review information.

Credits should be granted by your backend or app database after RevenueCat confirms the purchase. Do not use RevenueCat entitlements as the user's credit balance.

### Apple Checklist

Before testing real Apple products, confirm:

- Paid Apps Agreement, banking, and tax details are complete in App Store Connect.
- The app bundle ID matches the app configured in RevenueCat.
- The product IDs in App Store Connect exactly match the IDs imported into RevenueCat.
- Products have price, availability, and localization.
- A sandbox tester exists for device testing.
- Product metadata changes may take time to appear in sandbox.

## RevenueCat Dashboard Setup

RevenueCat docs:

- SDK quickstart: https://www.revenuecat.com/docs/getting-started/quickstart
- Configuring products: https://www.revenuecat.com/docs/projects/configuring-products
- Entitlements: https://www.revenuecat.com/docs/getting-started/entitlements
- Offerings: https://www.revenuecat.com/docs/offerings/overview

### Development Setup With RevenueCat Test Store

Use this first when building the UI and purchase flow.

1. Create a RevenueCat project.
2. Add an iOS app and Android app if needed.
3. Copy each public SDK API key.
4. In `Product catalog` -> `Products`, use the `Test Store` tab.
5. Create test products:
   - `premium_monthly`
   - `premium_yearly`
   - `credits_10`
6. Create an entitlement:
   - `premium`
7. Attach premium subscription products to the `premium` entitlement.
8. Do not attach consumable credit packs to the `premium` entitlement.
9. Create an offering:
   - Identifier: `default`
10. Add packages to the offering:
   - Monthly package -> `premium_monthly`
   - Annual package -> `premium_yearly`
   - Custom credit package -> `credits_10`, if using credit UI in the same paywall.

### Production Setup With Apple Products

After products exist in App Store Connect:

1. In RevenueCat, open the project.
2. Connect the iOS app/store configuration.
3. Import or manually add the Apple product IDs from App Store Connect.
4. Create or reuse the `premium` entitlement.
5. Attach Apple subscription products to the `premium` entitlement.
6. Leave consumable credit products unattached unless they unlock permanent access.
7. Create or update the `default` offering.
8. Add packages for the products you want the app to show.
9. Mark the offering as default.
10. Copy the RevenueCat public Apple SDK key into `REVENUE_CAT_KEY`.

### Module Config Example

```tsx
import {
  PaymentsProvider,
  createDefaultPaymentsConfig,
} from 'mdv-payments-module';

const paymentsConfig = createDefaultPaymentsConfig({
  environment: 'production',
  appUserId: user.id,
  features: ['premium', 'credits'],
  entitlements: {
    premium: 'premium',
  },
  creditProducts: [
    {
      key: 'credits_10',
      revenueCatIdentifier: 'credits_10',
      credits: 10,
      title: '10 Credits',
    },
  ],
  creditGrantAdapter: async ({ product, customerInfo }) => {
    await grantCreditsToUser({
      userId: user.id,
      credits: product.credits,
      revenueCatUserId: customerInfo.originalAppUserId,
    });
  },
});

export function AppPaymentsProvider({ children }: { children: React.ReactNode }) {
  return (
    <PaymentsProvider config={paymentsConfig}>
      {children}
    </PaymentsProvider>
  );
}
```

### Environment Mapping

Use development keys while building and switch to production keys for App Store/TestFlight builds.

```txt
# Development / RevenueCat Test Store
PAYMENTS_ENVIRONMENT=development
REVENUE_TEST_CAT_KEY=appl_test_or_revenuecat_dev_key
REVENUE_TEST_CAT_KEY_ANDROID=goog_test_or_revenuecat_dev_key

# Production / real stores
PAYMENTS_ENVIRONMENT=production
REVENUE_CAT_KEY=appl_public_sdk_key
REVENUE_CAT_KEY_ANDROID=goog_public_sdk_key

REVENUE_CAT_PREMIUM_ENTITLEMENT=premium
```

`PaymentsProvider` configures RevenueCat once and selects the correct key for `Platform.OS`.

## Testing Checklist

Development:

1. Use RevenueCat Test Store products first.
2. Confirm `<Paywall />` loads packages from the current offering.
3. Buy a test premium product.
4. Confirm `usePremiumStatus().isPremium` becomes `true`.
5. Restore purchases and confirm access remains active.
6. Buy a credit product and confirm `creditGrantAdapter` runs.

iOS sandbox/TestFlight:

1. Use a sandbox Apple account.
2. Install through Xcode, TestFlight, or an appropriate sandbox build.
3. Confirm App Store Connect products are available in RevenueCat.
4. Confirm product identifiers match exactly.
5. Confirm RevenueCat customer history shows the purchase.
6. Confirm the app unlocks Premium from the `premium` entitlement.
7. Confirm consumable credits are granted once per successful purchase in your app/backend.

## Basic Setup

Wrap the part of the app that needs payments:

```tsx
import React from 'react';
import {
  PaymentsProvider,
  createDefaultPaymentsConfig,
} from 'mdv-payments-module';

const paymentsConfig = createDefaultPaymentsConfig({
  environment: 'development',
  appUserId: user?.id,
  features: ['premium'],
  entitlements: {
    premium: 'premium',
  },
});

export const AppPaymentsProvider = ({ children }: { children: React.ReactNode }) => {
  return (
    <PaymentsProvider config={paymentsConfig}>
      {children}
    </PaymentsProvider>
  );
};
```

## Premium Upgrade Flow

Use the default UI:

```tsx
import { Paywall } from 'mdv-payments-module';

export const UpgradeScreen = () => {
  return <Paywall />;
};
```

Or use the hook and build custom UI:

```tsx
import { usePayments } from 'mdv-payments-module';

export const CustomUpgradeScreen = () => {
  const { packages, purchasePackage, loading, isPremium } = usePayments();

  return (
    <>
      {packages.map((pkg) => (
        <Button
          key={pkg.identifier}
          title={`${pkg.product.title} - ${pkg.product.priceString}`}
          disabled={loading}
          onPress={() => purchasePackage(pkg)}
        />
      ))}
    </>
  );
};
```

Check premium status:

```tsx
import { usePremiumStatus } from 'mdv-payments-module';

const { isPremium, loading, refresh } = usePremiumStatus();
```

## Credit Pack Flow

Configure the app's credit products:

```tsx
import {
  PaymentsProvider,
  createDefaultPaymentsConfig,
} from 'mdv-payments-module';

const paymentsConfig = createDefaultPaymentsConfig({
  environment: 'development',
  appUserId: user?.id,
  features: ['credits'],
  creditProducts: [
    {
      key: 'credits_small',
      revenueCatIdentifier: 'credits_10',
      credits: 10,
      title: '10 Credits',
    },
    {
      key: 'credits_large',
      revenueCatIdentifier: 'credits_50',
      credits: 50,
      title: '50 Credits',
    },
  ],
  creditGrantAdapter: async ({ product, customerInfo }) => {
    await grantCreditsToUser({
      userId: user?.id,
      credits: product.credits,
      revenueCatUserId: customerInfo.originalAppUserId,
    });
  },
});
```

Use the default credit UI:

```tsx
import { CreditPacks } from 'mdv-payments-module';

export const CreditsScreen = () => {
  return (
    <CreditPacks
      title="Buy Credits"
      subtitle="Use credits to unlock app actions."
    />
  );
};
```

Or purchase a credit product manually:

```tsx
import { useCredits } from 'mdv-payments-module';

const { creditProducts, purchaseCreditProduct, loading } = useCredits();

await purchaseCreditProduct('credits_small');
```

## Important Credit Rule

RevenueCat should confirm that a purchase happened. It should not be the only place that tracks a user's credit balance.

For credits with real value, the recommended flow is:

```txt
1. User buys a RevenueCat package.
2. RevenueCat returns successful customer info.
3. creditGrantAdapter calls the app backend or database.
4. Backend/database grants the credit balance.
5. UI reads the balance from app-owned storage.
```

Avoid storing credit balances only in local React state or only on the device.

## Premium And Credits Together

Use both features when an app needs subscriptions and consumables:

```tsx
const paymentsConfig = createDefaultPaymentsConfig({
  environment: 'production',
  appUserId: user?.id,
  features: ['premium', 'credits'],
  entitlements: {
    premium: 'pro',
  },
  creditProducts: [
    {
      key: 'credits_small',
      revenueCatIdentifier: 'credits_10',
      credits: 10,
    },
  ],
});
```

`<Paywall />` will render the premium upgrade UI and the credit pack UI when both features are enabled.

## Custom Copy

Pass display content through config:

```tsx
const paymentsConfig = createDefaultPaymentsConfig({
  content: {
    premium: {
      title: 'Upgrade to Pro',
      subtitle: 'Unlock unlimited tracking and advanced analytics.',
      features: [
        'Unlimited history',
        'Advanced insights',
        'Cloud sync',
      ],
      ctaLabel: 'Upgrade',
    },
    credits: {
      title: 'Buy Credits',
      subtitle: 'Use credits for one-time actions.',
      creditLabel: 'Credits',
      ctaLabel: 'Buy',
    },
  },
});
```

Prices should still come from RevenueCat package data, not hardcoded copy.

## Restore Purchases

```tsx
import { usePurchaseProduct } from 'mdv-payments-module';

const { restorePurchases } = usePurchaseProduct();

await restorePurchases();
```

## Entitlements

Check a named entitlement:

```tsx
import { useCustomerEntitlements } from 'mdv-payments-module';

const { hasEntitlement, activeEntitlementIds } = useCustomerEntitlements();

const hasPro = hasEntitlement('pro');
```

## Legacy Wrapper

Existing imports from `src/services/revenuecat` still work. That wrapper now delegates to this module:

```ts
RevenueCat.init(userId);
RevenueCat.getOfferings();
RevenueCat.purchasePackage(pkg);
RevenueCat.getCustomerInfo();
RevenueCat.restorePurchases();
RevenueCat.isPremium(customerInfo);
```

Prefer new code importing from `mdv-payments-module`. Keep the legacy wrapper only for old screens that have not been migrated yet.

## Local Extraction To Another App

To reuse this module in another app before publishing:

1. Copy `src/modules/payments`.
2. Add `"mdv-payments-module": "file:path/to/payments"` to the app's `package.json`.
3. Install `react-native-config` or replace `createDefaultPaymentsConfig()` with app-specific config loading.
4. Add the RevenueCat API keys.
5. Configure the app's entitlement IDs and credit products.
6. Provide a `creditGrantAdapter` if credits are enabled.

## Recommended Boundary

This module should handle:

- RevenueCat configure/init.
- RevenueCat offerings and packages.
- Purchase and restore calls.
- Customer info and entitlement checks.
- Generic premium and credit UI.

The app should handle:

- The logged-in user ID.
- Backend/database credit grants.
- What premium unlocks.
- App-specific analytics.
- App-specific paywall design when the default UI is not enough.
