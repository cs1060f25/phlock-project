import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  Image,
  TouchableOpacity,
  Alert,
  StatusBar,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import * as ImagePicker from 'expo-image-picker';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RootStackParamList } from '../../navigation/types';
import { Button, Input } from '../../components/shared';
import { useAuth } from '../../hooks/useAuth';
import { AuthService } from '../../services/auth';

type ProfileSetupScreenProps = {
  navigation: NativeStackNavigationProp<RootStackParamList, 'ProfileSetup'>;
};

export function ProfileSetupScreen({ navigation }: ProfileSetupScreenProps) {
  const [displayName, setDisplayName] = useState('');
  const [bio, setBio] = useState('');
  const [photoUri, setPhotoUri] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const { supabaseUser, refreshProfile } = useAuth();

  const pickImage = async () => {
    // Request permission
    const { status } = await ImagePicker.requestMediaLibraryPermissionsAsync();

    if (status !== 'granted') {
      Alert.alert(
        'Permission Required',
        'Please allow access to your photos to upload a profile picture.'
      );
      return;
    }

    // Pick image
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsEditing: true,
      aspect: [1, 1],
      quality: 0.8,
    });

    if (!result.canceled && result.assets[0]) {
      setPhotoUri(result.assets[0].uri);
    }
  };

  const handleComplete = async () => {
    if (!displayName.trim()) {
      Alert.alert('Required', 'Please enter your name');
      return;
    }

    if (!supabaseUser) {
      Alert.alert('Error', 'No user session found');
      return;
    }

    setLoading(true);

    try {
      let photoUrl: string | undefined;

      // Upload photo if selected
      if (photoUri) {
        photoUrl = await AuthService.uploadProfilePhoto(supabaseUser.id, photoUri);
      }

      // Create user profile
      await AuthService.createUserProfile(supabaseUser.id, {
        display_name: displayName.trim(),
        bio: bio.trim() || null,
        profile_photo_url: photoUrl || null,
        email: supabaseUser.email || null,
        phone: supabaseUser.phone || null,
      });

      // Refresh profile in auth context
      await refreshProfile();

      // Navigate to main app
      navigation.navigate('MainApp');
    } catch (err: any) {
      console.error('Profile setup error:', err);
      Alert.alert(
        'Error',
        'Failed to create profile. Please try again.'
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
        <ScrollView
          style={styles.scrollView}
          contentContainerStyle={styles.content}
          keyboardShouldPersistTaps="handled"
        >
          <View style={styles.header}>
            <Text style={styles.title}>Set up your profile</Text>
            <Text style={styles.subtitle}>
              Let your friends know who you are
            </Text>
          </View>

          {/* Photo Upload */}
          <TouchableOpacity
            style={styles.photoContainer}
            onPress={pickImage}
            activeOpacity={0.7}
          >
            {photoUri ? (
              <Image source={{ uri: photoUri }} style={styles.photo} />
            ) : (
              <View style={styles.photoPlaceholder}>
                <Text style={styles.photoPlaceholderIcon}>📷</Text>
                <Text style={styles.photoPlaceholderText}>Add Photo</Text>
              </View>
            )}
          </TouchableOpacity>

          {/* Form */}
          <View style={styles.form}>
            <Input
              label="Display Name"
              placeholder="Your name"
              value={displayName}
              onChangeText={setDisplayName}
              autoCapitalize="words"
              showClearButton
              onClear={() => setDisplayName('')}
            />

            <Input
              label="Bio (Optional)"
              placeholder="Tell friends about your music taste..."
              value={bio}
              onChangeText={setBio}
              multiline
              numberOfLines={3}
              showClearButton
              onClear={() => setBio('')}
            />
          </View>

          <Button
            title="Complete Setup"
            onPress={handleComplete}
            variant="primary"
            size="large"
            fullWidth
            loading={loading}
          />
        </ScrollView>
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
  scrollView: {
    flex: 1,
  },
  content: {
    paddingHorizontal: 24,
    paddingTop: 40,
    paddingBottom: 40,
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
  photoContainer: {
    alignSelf: 'center',
    marginBottom: 40,
  },
  photo: {
    width: 120,
    height: 120,
    borderRadius: 60,
  },
  photoPlaceholder: {
    width: 120,
    height: 120,
    borderRadius: 60,
    backgroundColor: '#f5f5f5',
    borderWidth: 2,
    borderColor: '#e0e0e0',
    borderStyle: 'dashed',
    alignItems: 'center',
    justifyContent: 'center',
  },
  photoPlaceholderIcon: {
    fontSize: 32,
    marginBottom: 4,
  },
  photoPlaceholderText: {
    fontSize: 13,
    color: '#999',
    fontWeight: '600',
  },
  form: {
    marginBottom: 32,
  },
});
