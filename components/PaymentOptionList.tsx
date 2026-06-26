import React from 'react';
import {
  ActivityIndicator,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import type { PurchasesPackage } from '../config/paymentTypes';

type PaymentOptionListProps = {
  title?: string;
  subtitle?: string;
  packages: PurchasesPackage[];
  loading?: boolean;
  ctaLabel?: string;
  onPurchase: (pkg: PurchasesPackage) => void;
};

export const PaymentOptionList = ({
  title,
  subtitle,
  packages,
  loading,
  ctaLabel = 'Continue',
  onPurchase,
}: PaymentOptionListProps) => {
  return (
    <View style={styles.container}>
      {title ? <Text style={styles.title}>{title}</Text> : null}
      {subtitle ? <Text style={styles.subtitle}>{subtitle}</Text> : null}

      {loading ? <ActivityIndicator /> : null}

      {packages.map((pkg) => (
        <View key={pkg.identifier} style={styles.option}>
          <View style={styles.optionText}>
            <Text style={styles.optionTitle}>{pkg.product.title}</Text>
            <Text style={styles.optionDescription}>{pkg.product.description}</Text>
            <Text style={styles.price}>{pkg.product.priceString}</Text>
          </View>
          <Pressable
            accessibilityRole="button"
            style={styles.button}
            onPress={() => onPurchase(pkg)}
            disabled={loading}
          >
            <Text style={styles.buttonText}>{ctaLabel}</Text>
          </Pressable>
        </View>
      ))}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    gap: 12,
  },
  title: {
    fontSize: 24,
    fontWeight: '700',
    color: '#111827',
  },
  subtitle: {
    fontSize: 15,
    color: '#4B5563',
    lineHeight: 21,
  },
  option: {
    borderWidth: 1,
    borderColor: '#E5E7EB',
    borderRadius: 8,
    padding: 14,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  optionText: {
    flex: 1,
    gap: 4,
  },
  optionTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: '#111827',
  },
  optionDescription: {
    fontSize: 13,
    color: '#6B7280',
  },
  price: {
    fontSize: 14,
    fontWeight: '700',
    color: '#111827',
  },
  button: {
    backgroundColor: '#111827',
    borderRadius: 8,
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  buttonText: {
    color: '#FFFFFF',
    fontWeight: '700',
  },
});
