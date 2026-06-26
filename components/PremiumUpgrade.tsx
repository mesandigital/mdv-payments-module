import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { usePayments } from '../hooks/usePayments';
import { PaymentOptionList } from './PaymentOptionList';

export const PremiumUpgrade = () => {
  const { config, packages, loading, purchasePackage } = usePayments();
  const content = config.content?.premium;

  return (
    <View style={styles.container}>
      {content?.features?.length ? (
        <View style={styles.features}>
          {content.features.map((feature) => (
            <Text key={feature} style={styles.feature}>
              {feature}
            </Text>
          ))}
        </View>
      ) : null}

      <PaymentOptionList
        title={content?.title ?? 'Upgrade to Premium'}
        subtitle={content?.subtitle}
        packages={packages}
        loading={loading}
        ctaLabel={content?.ctaLabel ?? 'Upgrade'}
        onPurchase={purchasePackage}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    gap: 16,
  },
  features: {
    gap: 8,
  },
  feature: {
    fontSize: 14,
    color: '#111827',
  },
});
