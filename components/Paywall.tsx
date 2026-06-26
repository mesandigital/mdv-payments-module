import React from 'react';
import { View } from 'react-native';
import { usePayments } from '../hooks/usePayments';
import { CreditPacks } from './CreditPacks';
import { PremiumUpgrade } from './PremiumUpgrade';

export const Paywall = () => {
  const { config } = usePayments();
  const features = config.features ?? ['premium'];

  return (
    <View>
      {features.includes('premium') ? <PremiumUpgrade /> : null}
      {features.includes('credits') ? (
        <CreditPacks
          title={config.content?.credits?.title ?? 'Buy Credits'}
          subtitle={config.content?.credits?.subtitle}
        />
      ) : null}
    </View>
  );
};
