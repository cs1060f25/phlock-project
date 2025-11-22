import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Button } from '../components/shared';
import { SongRecognitionFab } from '../components/song-recognition/SongRecognitionFab';
import { useAuth } from '../hooks/useAuth';

export function MainAppScreen() {
  const { user, signOut } = useAuth();

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.content}>
        <Text style={styles.title}>Welcome to Phlock!</Text>
        <Text style={styles.subtitle}>
          You're signed in as {user?.display_name || 'User'}
        </Text>

        <View style={styles.placeholder}>
          <Text style={styles.placeholderText}>
            🎵 Main app coming soon...
          </Text>
          <Text style={styles.placeholderSubtext}>
            This is where the music sharing, friend discovery, and Crate will live!
          </Text>
        </View>

        <Button
          title="Sign Out"
          onPress={signOut}
          variant="secondary"
          size="medium"
        />
      </View>

      <SongRecognitionFab />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
  content: {
    flex: 1,
    padding: 24,
    justifyContent: 'center',
    alignItems: 'center',
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
    marginBottom: 48,
  },
  placeholder: {
    padding: 32,
    backgroundColor: '#f9f9f9',
    borderRadius: 20,
    marginBottom: 48,
    alignItems: 'center',
  },
  placeholderText: {
    fontSize: 24,
    marginBottom: 12,
  },
  placeholderSubtext: {
    fontSize: 15,
    color: '#666',
    textAlign: 'center',
    lineHeight: 21,
  },
});
