// Import polyfills for general compatibility
import 'react-native-get-random-values';
import 'react-native-gesture-handler';
import 'text-encoding-polyfill';

import React from 'react';
import { AuthProvider } from './src/hooks/useAuth';
import { AppNavigator } from './src/navigation/AppNavigator';

export default function App() {
  return (
    <AuthProvider>
      <AppNavigator />
    </AuthProvider>
  );
}
