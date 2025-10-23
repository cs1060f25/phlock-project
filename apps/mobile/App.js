// Import polyfills for general compatibility
import 'react-native-get-random-values';
import 'text-encoding-polyfill';

import React, { useState, useRef, useEffect } from 'react';
import {
  StyleSheet,
  View,
  Text,
  TextInput,
  TouchableOpacity,
  ScrollView,
  Linking,
  Alert,
  Animated,
  Platform,
  SafeAreaView,
  Modal,
} from 'react-native';
import * as Clipboard from 'expo-clipboard';
import MusicConverter from './services/music-converter';

// Import SVG logos
import SpotifyLogo from './assets/logos/Spotify_icon.svg';
import AppleMusicLogo from './assets/logos/Apple_Music_icon.svg';
import YouTubeLogo from './assets/logos/YouTube_icon.svg';
import YouTubeMusicLogo from './assets/logos/YouTube_Music_icon.svg';
import AmazonMusicLogo from './assets/logos/Amazon_Music_icon.svg';
import TidalLogo from './assets/logos/Tidal_icon.svg';

const PLATFORM_LOGOS = {
  spotify: SpotifyLogo,
  apple: AppleMusicLogo,
  youtube: YouTubeLogo,
  youtubeMusic: YouTubeMusicLogo,
  amazon: AmazonMusicLogo,
  tidal: TidalLogo,
  soundcloud: null, // SoundCloud logo not available, using emoji fallback
};

const PLATFORM_ICONS = {
  spotify: '🎵',
  apple: '🍎',
  youtube: '▶️',
  youtubeMusic: '🎶',
  amazon: '📦',
  tidal: '🌊',
  soundcloud: '☁️',
};

const PLATFORM_NAMES = {
  spotify: 'Spotify',
  apple: 'Apple Music',
  youtube: 'YouTube',
  youtubeMusic: 'YouTube Music',
  amazon: 'Amazon Music',
  tidal: 'Tidal',
  soundcloud: 'SoundCloud',
};

export default function App() {
  const [leftPlatform, setLeftPlatform] = useState('spotify');
  const [rightPlatform, setRightPlatform] = useState('apple');
  const [direction, setDirection] = useState('right'); // 'right' = left→right, 'left' = right→left
  const [musicUrl, setMusicUrl] = useState('');
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState(null);
  const [error, setError] = useState(null);
  const [showSourceMenu, setShowSourceMenu] = useState(false);
  const [showTargetMenu, setShowTargetMenu] = useState(false);
  const [copied, setCopied] = useState(false);

  const converter = useRef(new MusicConverter()).current;
  const spinValue = useRef(new Animated.Value(0)).current;
  const copyOpacity = useRef(new Animated.Value(1)).current;
  const checkOpacity = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    if (loading) {
      // Start spinning animation
      spinValue.setValue(0);
      Animated.loop(
        Animated.timing(spinValue, {
          toValue: 1,
          duration: 1000,
          useNativeDriver: true,
        })
      ).start();
    } else {
      // Stop animation
      spinValue.stopAnimation();
    }
  }, [loading]);

  const spin = spinValue.interpolate({
    inputRange: [0, 1],
    outputRange: ['0deg', '360deg'],
  });

  const platforms = ['spotify', 'apple', 'youtube', 'youtubeMusic', 'amazon', 'tidal', 'soundcloud'];

  const handleConvert = async () => {
    if (!musicUrl.trim()) {
      Alert.alert('Error', 'Please enter a link, dummy');
      return;
    }

    // Determine source and target based on direction
    const sourcePlatform = direction === 'right' ? leftPlatform : rightPlatform;
    const targetPlatform = direction === 'right' ? rightPlatform : leftPlatform;

    setLoading(true);
    setResult(null);
    setError(null);

    try {
      const convertResult = await converter.convert(musicUrl, targetPlatform);

      if (convertResult.success) {
        setResult(convertResult);
      } else {
        setError(convertResult.error || 'Failed to convert link');
      }
    } catch (err) {
      console.error('Conversion error:', err);
      setError('Network error. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleCopyToClipboard = async () => {
    if (result?.convertedUrl) {
      await Clipboard.setStringAsync(result.convertedUrl);

      // Animate from copy icon to checkmark
      setCopied(true);
      Animated.parallel([
        Animated.timing(copyOpacity, {
          toValue: 0,
          duration: 200,
          useNativeDriver: true,
        }),
        Animated.timing(checkOpacity, {
          toValue: 1,
          duration: 200,
          useNativeDriver: true,
        }),
      ]).start();

      // Reset after 2 seconds
      setTimeout(() => {
        Animated.parallel([
          Animated.timing(copyOpacity, {
            toValue: 1,
            duration: 200,
            useNativeDriver: true,
          }),
          Animated.timing(checkOpacity, {
            toValue: 0,
            duration: 200,
            useNativeDriver: true,
          }),
        ]).start(() => setCopied(false));
      }, 2000);
    }
  };

  const handleOpenLink = async () => {
    if (result?.convertedUrl) {
      const supported = await Linking.canOpenURL(result.convertedUrl);
      if (supported) {
        await Linking.openURL(result.convertedUrl);
      } else {
        Alert.alert('Error', 'Cannot open this link');
      }
    }
  };

  const toggleDirection = () => {
    setDirection(direction === 'right' ? 'left' : 'right');
    setResult(null);
    setError(null);
  };

  const selectSourcePlatform = (platform) => {
    setLeftPlatform(platform);
    setShowSourceMenu(false);
    setResult(null);
    setError(null);
  };

  const selectTargetPlatform = (platform) => {
    setRightPlatform(platform);
    setShowTargetMenu(false);
    setResult(null);
    setError(null);
  };

  const PlatformSelector = ({ platform, onPress }) => {
    const Logo = PLATFORM_LOGOS[platform];
    return (
      <TouchableOpacity style={styles.platformBox} onPress={onPress}>
        {Logo ? (
          <Logo width={48} height={48} />
        ) : (
          <Text style={styles.platformIcon}>{PLATFORM_ICONS[platform]}</Text>
        )}
      </TouchableOpacity>
    );
  };

  const PlatformMenu = ({ visible, onClose, onSelect, selectedPlatform }) => (
    <Modal
      visible={visible}
      transparent={true}
      animationType="fade"
      onRequestClose={onClose}
    >
      <TouchableOpacity
        style={styles.modalOverlay}
        activeOpacity={1}
        onPress={onClose}
      >
        <View style={styles.menuContainer}>
          <ScrollView contentContainerStyle={styles.menuScroll}>
            {platforms.map((platform) => {
              const Logo = PLATFORM_LOGOS[platform];
              return (
                <TouchableOpacity
                  key={platform}
                  style={[
                    styles.menuOption,
                    platform === selectedPlatform && styles.menuOptionSelected
                  ]}
                  onPress={() => onSelect(platform)}
                >
                  {Logo ? (
                    <Logo width={24} height={24} />
                  ) : (
                    <Text style={styles.menuOptionIcon}>{PLATFORM_ICONS[platform]}</Text>
                  )}
                  <Text style={styles.menuOptionText}>{PLATFORM_NAMES[platform]}</Text>
                </TouchableOpacity>
              );
            })}
          </ScrollView>
        </View>
      </TouchableOpacity>
    </Modal>
  );

  return (
    <SafeAreaView style={styles.safeArea}>
      <ScrollView contentContainerStyle={styles.container}>
        <Text style={styles.title}>musiclinkr</Text>

        {/* Platform Selector */}
        <View style={styles.platformSelector}>
          <PlatformSelector
            platform={leftPlatform}
            onPress={() => setShowSourceMenu(true)}
          />

          <TouchableOpacity style={styles.arrowContainer} onPress={toggleDirection}>
            <Text style={[styles.arrow, direction === 'right' && styles.arrowActive]}>
              →
            </Text>
            <Text style={[styles.arrow, direction === 'left' && styles.arrowActive]}>
              ←
            </Text>
          </TouchableOpacity>

          <PlatformSelector
            platform={rightPlatform}
            onPress={() => setShowTargetMenu(true)}
          />
        </View>

        {/* Input Section */}
        <View style={styles.inputSection}>
          <View style={styles.inputWrapper}>
            <TextInput
              style={styles.input}
              placeholder="Paste link here..."
              placeholderTextColor="#aaa"
              value={musicUrl}
              onChangeText={setMusicUrl}
              autoCapitalize="none"
              autoCorrect={false}
              keyboardType="url"
            />
            {musicUrl.length > 0 && (
              <TouchableOpacity
                style={styles.clearBtn}
                onPress={() => {
                  setMusicUrl('');
                  setResult(null);
                  setError(null);
                }}
              >
                <Text style={styles.clearBtnText}>×</Text>
              </TouchableOpacity>
            )}
          </View>

          <TouchableOpacity
            style={styles.convertBtn}
            onPress={handleConvert}
            disabled={loading}
          >
            <Animated.Text
              style={[
                styles.convertBtnIcon,
                { transform: [{ rotate: spin }] }
              ]}
            >
              ✿
            </Animated.Text>
          </TouchableOpacity>
        </View>

        {/* Result Section */}
        {result && (
          <View style={styles.resultContainer}>
            <Text style={styles.resultTrackInfo}>
              {result.track?.title} - {result.track?.artist}
            </Text>
            <View style={styles.linkRow}>
              <TouchableOpacity onPress={handleOpenLink} style={styles.linkWrapper}>
                <Text style={styles.resultLink} numberOfLines={1}>
                  {result.convertedUrl}
                </Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={styles.copyIconBtn}
                onPress={handleCopyToClipboard}
                activeOpacity={0.6}
              >
                <View style={styles.copyIconContainer}>
                  <Animated.View style={[styles.copyIcon, { opacity: copyOpacity }]}>
                    <View style={styles.copySquareBack} />
                    <View style={styles.copySquareFront} />
                  </Animated.View>
                  <Animated.View style={[styles.checkIcon, { opacity: checkOpacity }]}>
                    <Text style={styles.checkmark}>✓</Text>
                  </Animated.View>
                </View>
              </TouchableOpacity>
            </View>
          </View>
        )}

        {/* Error Section */}
        {error && (
          <View style={styles.errorContainer}>
            <Text style={styles.errorText}>✗ {error}</Text>
          </View>
        )}

        {/* Platform Menus */}
        <PlatformMenu
          visible={showSourceMenu}
          onClose={() => setShowSourceMenu(false)}
          onSelect={selectSourcePlatform}
          selectedPlatform={leftPlatform}
        />
        <PlatformMenu
          visible={showTargetMenu}
          onClose={() => setShowTargetMenu(false)}
          onSelect={selectTargetPlatform}
          selectedPlatform={rightPlatform}
        />
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#fff',
  },
  container: {
    flexGrow: 1,
    padding: 20,
    alignItems: 'center',
    justifyContent: 'center',
  },
  title: {
    fontSize: 28,
    fontWeight: '700',
    marginBottom: 40,
    color: '#000',
  },
  platformSelector: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 20,
    marginBottom: 40,
  },
  platformBox: {
    width: 90,
    height: 90,
    borderRadius: 20,
    borderWidth: 1,
    borderColor: '#f5f5f5',
    backgroundColor: '#fff',
    alignItems: 'center',
    justifyContent: 'center',
  },
  platformIcon: {
    fontSize: 48,
  },
  arrowContainer: {
    backgroundColor: '#fff',
    borderRadius: 16,
    padding: 8,
    paddingHorizontal: 12,
    borderWidth: 1,
    borderColor: '#f5f5f5',
    gap: 2,
  },
  arrow: {
    fontSize: 20,
    color: '#d0d0d0',
  },
  arrowActive: {
    color: '#000',
    fontWeight: 'bold',
  },
  inputSection: {
    width: '100%',
    maxWidth: 420,
    marginBottom: 24,
  },
  inputWrapper: {
    position: 'relative',
    marginBottom: 16,
  },
  input: {
    width: '100%',
    padding: 18,
    paddingRight: 50,
    borderWidth: 1,
    borderColor: '#e0e0e0',
    borderRadius: 20,
    fontSize: 15,
    backgroundColor: '#fafafa',
    color: '#000',
  },
  clearBtn: {
    position: 'absolute',
    right: 16,
    top: '50%',
    transform: [{ translateY: -12 }],
    padding: 4,
  },
  clearBtnText: {
    fontSize: 24,
    color: '#999',
  },
  convertBtn: {
    width: '100%',
    padding: 24,
    backgroundColor: '#000',
    borderRadius: 20,
    alignItems: 'center',
    justifyContent: 'center',
  },
  convertBtnIcon: {
    fontSize: 28,
    color: '#fff',
  },
  resultContainer: {
    marginTop: 20,
    width: '100%',
    maxWidth: 420,
    padding: 20,
    backgroundColor: '#f9f9f9',
    borderRadius: 16,
  },
  resultTrackInfo: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 16,
    color: '#000',
    textAlign: 'center',
  },
  linkRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  linkWrapper: {
    flex: 1,
  },
  resultLink: {
    fontSize: 13,
    color: '#007AFF',
    textDecorationLine: 'underline',
  },
  copyIconBtn: {
    padding: 8,
  },
  copyIconContainer: {
    width: 24,
    height: 24,
    position: 'relative',
  },
  copyIcon: {
    position: 'absolute',
    top: 0,
    left: 0,
    width: 24,
    height: 24,
  },
  copySquareBack: {
    position: 'absolute',
    top: 0,
    left: 4,
    width: 14,
    height: 14,
    borderWidth: 2,
    borderColor: '#666',
    borderRadius: 3,
    backgroundColor: '#fff',
  },
  copySquareFront: {
    position: 'absolute',
    top: 6,
    left: 0,
    width: 14,
    height: 14,
    borderWidth: 2,
    borderColor: '#000',
    borderRadius: 3,
    backgroundColor: '#fff',
  },
  checkIcon: {
    position: 'absolute',
    top: 0,
    left: 0,
    width: 24,
    height: 24,
    justifyContent: 'center',
    alignItems: 'center',
  },
  checkmark: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#000',
  },
  errorContainer: {
    marginTop: 20,
    padding: 16,
    width: '100%',
    maxWidth: 420,
  },
  errorText: {
    color: '#666',
    fontSize: 14,
    textAlign: 'center',
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  menuContainer: {
    backgroundColor: '#fff',
    borderRadius: 20,
    padding: 16,
    maxWidth: 300,
    maxHeight: '80%',
  },
  menuScroll: {
    gap: 8,
  },
  menuOption: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    borderRadius: 12,
    backgroundColor: '#f9f9f9',
    gap: 12,
  },
  menuOptionSelected: {
    backgroundColor: '#e0e0e0',
  },
  menuOptionIcon: {
    fontSize: 24,
  },
  menuOptionText: {
    fontSize: 16,
    color: '#000',
  },
});
