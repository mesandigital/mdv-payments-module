import React from 'react';
import {
  ActivityIndicator,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useCredits } from '../hooks/useCredits';

type CreditPacksProps = {
  title?: string;
  subtitle?: string;
};

export const CreditPacks = ({ title, subtitle }: CreditPacksProps) => {
  const { creditProducts, loading, purchaseCreditProduct } = useCredits();

  return (
    <View style={styles.container}>
      {title ? <Text style={styles.title}>{title}</Text> : null}
      {subtitle ? <Text style={styles.subtitle}>{subtitle}</Text> : null}
      {loading ? <ActivityIndicator /> : null}

      {creditProducts.map((product) => (
        <View key={product.key} style={styles.pack}>
          <View style={styles.packText}>
            <Text style={styles.packTitle}>{product.title ?? `${product.credits} Credits`}</Text>
            <Text style={styles.packDescription}>
              {product.description ?? product.package?.product.description}
            </Text>
            {product.package ? (
              <Text style={styles.price}>{product.package.product.priceString}</Text>
            ) : (
              <Text style={styles.unavailable}>Unavailable</Text>
            )}
          </View>
          <Pressable
            accessibilityRole="button"
            style={[styles.button, !product.package && styles.buttonDisabled]}
            disabled={loading || !product.package}
            onPress={() => purchaseCreditProduct(product.key)}
          >
            <Text style={styles.buttonText}>Buy</Text>
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
  pack: {
    borderWidth: 1,
    borderColor: '#E5E7EB',
    borderRadius: 8,
    padding: 14,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  packText: {
    flex: 1,
    gap: 4,
  },
  packTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: '#111827',
  },
  packDescription: {
    fontSize: 13,
    color: '#6B7280',
  },
  price: {
    fontSize: 14,
    fontWeight: '700',
    color: '#111827',
  },
  unavailable: {
    fontSize: 13,
    color: '#9CA3AF',
  },
  button: {
    backgroundColor: '#111827',
    borderRadius: 8,
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  buttonDisabled: {
    backgroundColor: '#9CA3AF',
  },
  buttonText: {
    color: '#FFFFFF',
    fontWeight: '700',
  },
});
