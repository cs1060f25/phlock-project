import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
  Alert,
  StatusBar,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RootStackParamList } from '../../navigation/types';
import { Button, Input } from '../../components/shared';
import { useAuth } from '../../hooks/useAuth';

type AuthScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'Auth'>;
};

export function AuthScreen({ navigation }: AuthScreenProps) {
  const [authMethod, setAuthMethod] = useState<'email' | 'phone'>('email');
  const [value, setValue] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const { signInWithEmail, signInWithPhone } = useAuth();

  const validateEmail = (email: string) => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  };

  const validatePhone = (phone: string) => {
    // Simple validation: 10+ digits
    const phoneRegex = /^\+?[\d\s-]{10,}$/;
    return phoneRegex.test(phone);
  };

  const handleContinue = async () => {
    setError('');

    // Validation
    if (!value.trim()) {
      setError(`Please enter your ${authMethod}`);
      return;
    }

    if (authMethod === 'email' && !validateEmail(value)) {
      setError('Please enter a valid email address');
      return;
    }

    if (authMethod === 'phone' && !validatePhone(value)) {
      setError('Please enter a valid phone number');
      return;
    }

    setLoading(true);

    try {
      if (authMethod === 'email') {
        await signInWithEmail(value);
        navigation.navigate('OTPVerification', { email: value });
      } else {
        await signInWithPhone(value);
        navigation.navigate('OTPVerification', { phone: value });
      }
    } catch (err: any) {
      console.error('Auth error:', err);
      Alert.alert(
        'Error',
        err.message || 'Failed to send verification code. Please try again.'
      );
    } finally {
      setLoading(false);
    }
  };

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <StatusBar barStyle="dark-content" />

      <KeyboardAvoidingView
        style={styles.keyboardView}
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      >
        <View style={styles.content}>
          <View style={styles.header}>
            <Text style={styles.title}>Welcome to Phlock</Text>
            <Text style={styles.subtitle}>
              Enter your {authMethod} to get started
            </Text>
          </View>

          {/* Auth Method Toggle */}
          <View style={styles.toggleContainer}>
            <Button
              title="Email"
              onPress={() => {
                setAuthMethod('email');
                setValue('');
                setError('');
              }}
              variant={authMethod === 'email' ? 'primary' : 'secondary'}
              size="medium"
              style={styles.toggleButton}
            />
            <Button
              title="Phone"
              onPress={() => {
                setAuthMethod('phone');
                setValue('');
                setError('');
              }}
              variant={authMethod === 'phone' ? 'primary' : 'secondary'}
              size="medium"
              style={styles.toggleButton}
            />
          </View>

          {/* Input Field */}
          <View style={styles.inputContainer}>
            <Input
              label={authMethod === 'email' ? 'Email Address' : 'Phone Number'}
              placeholder={
                authMethod === 'email'
                  ? 'your@email.com'
                  : '+1 (555) 000-0000'
              }
              value={value}
              onChangeText={(text) => {
                setValue(text);
                setError('');
              }}
              keyboardType={authMethod === 'email' ? 'email-address' : 'phone-pad'}
              autoCapitalize="none"
              autoCorrect={false}
              error={error}
              showClearButton
              onClear={() => setValue('')}
            />
          </View>

          <Button
            title="Continue"
            onPress={handleContinue}
            variant="primary"
            size="large"
            fullWidth
            loading={loading}
          />

          <Text style={styles.info}>
            We'll send you a verification code to confirm your {authMethod}
          </Text>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
  keyboardView: {
    flex: 1,
  },
  content: {
    flex: 1,
    paddingHorizontal: 24,
    paddingTop: 40,
  },
  header: {
    marginBottom: 40,
  },
  title: {
    fontSize: 32,
    fontWeight: '700',
    color: '#000',
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 17,
    color: '#666',
  },
  toggleContainer: {
    flexDirection: 'row',
    gap: 12,
    marginBottom: 32,
  },
  toggleButton: {
    flex: 1,
  },
  inputContainer: {
    marginBottom: 24,
  },
  info: {
    fontSize: 14,
    color: '#999',
    textAlign: 'center',
    marginTop: 16,
    lineHeight: 20,
  },
});
