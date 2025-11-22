import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  Animated,
  Image,
  Modal,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useSongRecognition } from '../../hooks/useSongRecognition';
import { useFriends } from '../../hooks/useFriends';
import { useAuth } from '../../hooks/useAuth';
import { Button } from '../shared';
import { FriendWithProfile } from '../../services/friends';
import { SharesService } from '../../services/shares';

export function SongRecognitionFab() {
  const [isModalVisible, setModalVisible] = useState(false);
  const [shareMessage, setShareMessage] = useState('');
  const [shareError, setShareError] = useState<string | null>(null);
  const [sendingTo, setSendingTo] = useState<string | null>(null);
  const pulseAnim = useRef(new Animated.Value(1)).current;

  const {
    status,
    error,
    recognizedTrack,
    startListening,
    stopAndIdentify,
    cancelListening,
    reset,
  } = useSongRecognition();
  const { friends, loading: friendsLoading } = useFriends();
  const { supabaseUser } = useAuth();

  useEffect(() => {
    const animation = Animated.loop(
      Animated.sequence([
        Animated.timing(pulseAnim, {
          toValue: 1.08,
          duration: 1400,
          useNativeDriver: true,
        }),
        Animated.timing(pulseAnim, {
          toValue: 1,
          duration: 1400,
          useNativeDriver: true,
        }),
      ])
    );

    animation.start();
    return () => animation.stop();
  }, [pulseAnim]);

  useEffect(() => {
    if (!recognizedTrack) {
      setShareMessage('');
    }
  }, [recognizedTrack]);

  const listenButtonLabel = useMemo(() => {
    switch (status) {
      case 'listening':
        return 'Tap to ID';
      case 'identifying':
        return 'Identifying...';
      case 'success':
        return 'Listen Again';
      default:
        return 'Listen for 8s';
    }
  }, [status]);

  const statusDescription = useMemo(() => {
    switch (status) {
      case 'listening':
        return 'Hold your phone near the audio. We\'ll auto-capture ~8s.';
      case 'identifying':
        return 'Sending the sample to our recognition service...';
      case 'success':
        return 'Verified! Send this find to someone in Phlock.';
      case 'error':
        return error || 'We hit a snag — try again.';
      default:
        return 'Tap Listen to use your mic like a Shazam-style scout.';
    }
  }, [status, error]);

  const handleFabPress = () => {
    reset();
    setShareError(null);
    setModalVisible(true);
  };

  const handleCloseModal = async () => {
    setModalVisible(false);
    setShareError(null);
    await cancelListening();
  };

  const handleListenPress = async () => {
    setShareError(null);
    if (status === 'listening') {
      await stopAndIdentify();
      return;
    }
    await startListening();
  };

  const handleShare = async (friend: FriendWithProfile) => {
    if (!recognizedTrack || !supabaseUser) return;
    setShareError(null);
    setSendingTo(friend.friend.id);

    try {
      await SharesService.sendRecognizedShare({
        senderId: supabaseUser.id,
        recipientId: friend.friend.id,
        track: recognizedTrack,
        message: shareMessage.trim() || undefined,
      });

      Alert.alert(
        'Sent!',
        `Shared ${recognizedTrack.trackName} with ${friend.friend.display_name}.`
      );
      setShareMessage('');
    } catch (err) {
      setShareError(err instanceof Error ? err.message : 'Failed to share track.');
    } finally {
      setSendingTo(null);
    }
  };

  const confidencePercent = useMemo(() => {
    if (!recognizedTrack?.confidence) return null;
    const value = recognizedTrack.confidence;
    return value > 1 ? Math.round(value) : Math.round(value * 100);
  }, [recognizedTrack?.confidence]);

  const showShareSection = recognizedTrack && status === 'success';

  return (
    <>
      <Animated.View style={[styles.fabContainer, { transform: [{ scale: pulseAnim }] }]}>
        <TouchableOpacity style={styles.fab} onPress={handleFabPress} activeOpacity={0.9}>
          <Ionicons name="ear-outline" size={26} color="#fff" />
        </TouchableOpacity>
      </Animated.View>

      <Modal
        visible={isModalVisible}
        animationType="slide"
        transparent
        onRequestClose={handleCloseModal}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalCard}>
            <View style={styles.dragIndicator} />
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Identify & Send</Text>
              <TouchableOpacity onPress={handleCloseModal} hitSlop={{ top: 12, right: 12, bottom: 12, left: 12 }}>
                <Ionicons name="close" size={24} color="#000" />
              </TouchableOpacity>
            </View>

            <ScrollView
              style={styles.modalScroll}
              contentContainerStyle={{ paddingBottom: 24 }}
              showsVerticalScrollIndicator={false}
            >
              <View style={styles.statusCard}>
                <Text style={styles.statusLabel}>{status.toUpperCase()}</Text>
                <Text style={styles.statusDescription}>{statusDescription}</Text>

                <TouchableOpacity
                  style={[
                    styles.listenButton,
                    status === 'listening' && styles.listenButtonActive,
                    status === 'identifying' && styles.listenButtonDisabled,
                  ]}
                  onPress={handleListenPress}
                  disabled={status === 'identifying'}
                >
                  <Ionicons
                    name={status === 'listening' ? 'stop-circle' : 'ear'}
                    size={22}
                    color="#fff"
                    style={{ marginRight: 8 }}
                  />
                  <Text style={styles.listenButtonText}>{listenButtonLabel}</Text>
                </TouchableOpacity>
              </View>

              {recognizedTrack && (
                <View style={styles.trackCard}>
                  {recognizedTrack.albumArtUrl ? (
                    <Image
                      source={{ uri: recognizedTrack.albumArtUrl }}
                      style={styles.albumArt}
                    />
                  ) : (
                    <View style={[styles.albumArt, styles.albumArtFallback]}>
                      <Ionicons name="musical-notes-outline" size={28} color="#666" />
                    </View>
                  )}

                  <View style={styles.trackInfo}>
                    <Text style={styles.trackName}>{recognizedTrack.trackName}</Text>
                    <Text style={styles.trackArtist}>{recognizedTrack.artistName}</Text>
                    {recognizedTrack.albumName ? (
                      <Text style={styles.trackAlbum}>{recognizedTrack.albumName}</Text>
                    ) : null}
                    {confidencePercent ? (
                      <View style={styles.confidencePill}>
                        <Ionicons name="sparkles-outline" size={14} color="#2f6b2f" />
                        <Text style={styles.confidenceText}>
                          {confidencePercent}% confident
                        </Text>
                      </View>
                    ) : null}
                  </View>
                </View>
              )}

              {showShareSection && (
                <View style={styles.shareSection}>
                  <Text style={styles.sectionTitle}>Send Within Phlock</Text>
                  <Text style={styles.sectionSubtitle}>
                    Pick a friend to send this song instantly.
                  </Text>

                  <TextInput
                    style={styles.messageInput}
                    placeholder="Add a quick note (optional)"
                    placeholderTextColor="#999"
                    value={shareMessage}
                    onChangeText={setShareMessage}
                    maxLength={120}
                    multiline
                  />

                  {friendsLoading ? (
                    <ActivityIndicator style={{ marginVertical: 24 }} />
                  ) : friends.length === 0 ? (
                    <Text style={styles.emptyState}>
                      You haven’t added any friends yet. Head to the Friends tab to start building
                      your squad.
                    </Text>
                  ) : (
                    friends.map((friend) => (
                      <TouchableOpacity
                        key={friend.friend.id}
                        style={styles.friendRow}
                        onPress={() => handleShare(friend)}
                        disabled={Boolean(sendingTo) && sendingTo !== friend.friend.id}
                      >
                        <View style={styles.avatar}>
                          <Text style={styles.avatarText}>
                            {(friend.friend.display_name || '?').charAt(0).toUpperCase()}
                          </Text>
                        </View>
                        <View style={styles.friendDetails}>
                          <Text style={styles.friendName}>{friend.friend.display_name}</Text>
                          {friend.friend.bio ? (
                            <Text numberOfLines={1} style={styles.friendSubtext}>
                              {friend.friend.bio}
                            </Text>
                          ) : null}
                        </View>
                        {sendingTo === friend.friend.id ? (
                          <ActivityIndicator color="#000" />
                        ) : (
                          <Ionicons name="paper-plane-outline" size={20} color="#000" />
                        )}
                      </TouchableOpacity>
                    ))
                  )}

                  {shareError ? <Text style={styles.errorText}>{shareError}</Text> : null}

                  <View style={styles.shareActions}>
                    <Button
                      title="Reset Sample"
                      variant="ghost"
                      onPress={reset}
                      style={{ flex: 1, marginRight: 12 }}
                    />
                    <Button title="Close" variant="secondary" onPress={handleCloseModal} style={{ flex: 1 }} />
                  </View>
                </View>
              )}
            </ScrollView>
          </View>
        </View>
      </Modal>
    </>
  );
}

const styles = StyleSheet.create({
  fabContainer: {
    position: 'absolute',
    bottom: 28,
    right: 24,
  },
  fab: {
    width: 64,
    height: 64,
    borderRadius: 32,
    backgroundColor: '#111',
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#111',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.25,
    shadowRadius: 20,
    elevation: 10,
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.35)',
    justifyContent: 'flex-end',
  },
  modalCard: {
    backgroundColor: '#fff',
    borderTopLeftRadius: 28,
    borderTopRightRadius: 28,
    paddingHorizontal: 24,
    paddingTop: 12,
    maxHeight: '88%',
  },
  dragIndicator: {
    width: 48,
    height: 4,
    borderRadius: 2,
    backgroundColor: '#ddd',
    alignSelf: 'center',
    marginBottom: 12,
  },
  modalHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 12,
  },
  modalTitle: {
    fontSize: 20,
    fontWeight: '700',
    color: '#000',
  },
  modalScroll: {
    maxHeight: '100%',
  },
  statusCard: {
    backgroundColor: '#f5f6fb',
    borderRadius: 20,
    padding: 20,
    marginBottom: 20,
  },
  statusLabel: {
    fontSize: 12,
    fontWeight: '700',
    color: '#6574ff',
    marginBottom: 6,
  },
  statusDescription: {
    fontSize: 15,
    lineHeight: 20,
    color: '#333',
    marginBottom: 16,
  },
  listenButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#111',
    borderRadius: 16,
    paddingVertical: 14,
  },
  listenButtonActive: {
    backgroundColor: '#e43f5a',
  },
  listenButtonDisabled: {
    opacity: 0.6,
  },
  listenButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  trackCard: {
    flexDirection: 'row',
    backgroundColor: '#fdfdfd',
    borderRadius: 20,
    padding: 16,
    borderWidth: 1,
    borderColor: '#f1f1f1',
    marginBottom: 24,
  },
  albumArt: {
    width: 84,
    height: 84,
    borderRadius: 12,
    marginRight: 16,
  },
  albumArtFallback: {
    backgroundColor: '#f1f1f1',
    alignItems: 'center',
    justifyContent: 'center',
  },
  trackInfo: {
    flex: 1,
  },
  trackName: {
    fontSize: 18,
    fontWeight: '700',
    color: '#111',
  },
  trackArtist: {
    fontSize: 15,
    color: '#555',
    marginTop: 4,
  },
  trackAlbum: {
    fontSize: 13,
    color: '#888',
    marginTop: 2,
  },
  confidencePill: {
    marginTop: 12,
    paddingHorizontal: 10,
    paddingVertical: 6,
    backgroundColor: '#e6f4e6',
    alignSelf: 'flex-start',
    borderRadius: 999,
    flexDirection: 'row',
    alignItems: 'center',
  },
  confidenceText: {
    color: '#2f6b2f',
    fontWeight: '600',
    fontSize: 12,
    marginLeft: 6,
  },
  shareSection: {
    marginBottom: 16,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '700',
    color: '#000',
    marginBottom: 4,
  },
  sectionSubtitle: {
    fontSize: 14,
    color: '#555',
    marginBottom: 16,
  },
  messageInput: {
    borderRadius: 16,
    borderWidth: 1,
    borderColor: '#eee',
    padding: 16,
    fontSize: 15,
    color: '#111',
    minHeight: 72,
    textAlignVertical: 'top',
    marginBottom: 16,
  },
  friendRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#f2f2f2',
  },
  avatar: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: '#111',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
  },
  avatarText: {
    color: '#fff',
    fontWeight: '700',
  },
  friendDetails: {
    flex: 1,
  },
  friendName: {
    fontSize: 15,
    fontWeight: '600',
    color: '#000',
  },
  friendSubtext: {
    fontSize: 13,
    color: '#666',
  },
  emptyState: {
    fontSize: 15,
    color: '#666',
    marginVertical: 20,
  },
  shareActions: {
    flexDirection: 'row',
    marginTop: 20,
  },
  errorText: {
    color: '#c62828',
    marginTop: 12,
    fontSize: 14,
  },
});
