import * as FileSystem from 'expo-file-system';

const recognitionUrl = process.env.EXPO_PUBLIC_SONG_RECOGNITION_URL;
const recognitionToken = process.env.EXPO_PUBLIC_SONG_RECOGNITION_API_KEY;

export interface RecognizedTrack {
  trackId: string;
  trackName: string;
  artistName: string;
  albumName?: string | null;
  albumArtUrl?: string | null;
  streamingLinks?: {
    spotify?: string | null;
    appleMusic?: string | null;
  };
  confidence?: number | null;
  source?: string;
}

export class SongRecognitionService {
  static async identifyTrackFromFile(uri: string): Promise<RecognizedTrack> {
    if (!uri) {
      throw new Error('Recording file missing');
    }

    const fileExtension = SongRecognitionService.getExtension(uri);
    const base64Audio = await FileSystem.readAsStringAsync(uri, {
      encoding: FileSystem.EncodingType.Base64,
    });

    if (!recognitionUrl) {
      await SongRecognitionService.delay(1500);
      return {
        trackId: `demo-${Date.now()}`,
        trackName: 'Levitating',
        artistName: 'Dua Lipa',
        albumName: 'Future Nostalgia',
        albumArtUrl: 'https://images.unsplash.com/photo-1485579149621-3123dd979885?w=600',
        streamingLinks: {
          spotify: 'https://open.spotify.com/track/463CkQjx2Zk1yXoBuierM9',
          appleMusic: 'https://music.apple.com/us/album/levitating/1506051509?i=1506051807',
        },
        confidence: 0.42,
        source: 'mock',
      };
    }

    const response = await fetch(recognitionUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(recognitionToken ? { Authorization: `Bearer ${recognitionToken}` } : {}),
      },
      body: JSON.stringify({
        audio_base64: base64Audio,
        file_extension: fileExtension,
      }),
    });

    if (!response.ok) {
      const message = await SongRecognitionService.safeParseError(response);
      throw new Error(message);
    }

    const payload = await response.json();
    const normalized = SongRecognitionService.normalizeResponse(payload);

    if (!normalized) {
      throw new Error('We could not identify that track. Try again in a quieter space.');
    }

    return normalized;
  }

  static async cleanupRecording(uri: string) {
    if (!uri) return;
    try {
      await FileSystem.deleteAsync(uri, { idempotent: true });
    } catch (error) {
      console.warn('[SongRecognition] cleanup failed', error);
    }
  }

  private static normalizeResponse(payload: any): RecognizedTrack | null {
    if (!payload) return null;

    const trackPayload =
      payload.track ||
      payload.result ||
      payload.data?.track ||
      payload.data ||
      payload;

    if (!trackPayload) {
      return null;
    }

    const trackName =
      trackPayload.trackName ||
      trackPayload.title ||
      trackPayload.name ||
      trackPayload.song_name;

    const artistName =
      trackPayload.artistName ||
      trackPayload.artist ||
      trackPayload.subtitle ||
      trackPayload.artist_name ||
      trackPayload.artists?.[0]?.name;

    if (!trackName || !artistName) {
      return null;
    }

    const normalizedTrack: RecognizedTrack = {
      trackId:
        trackPayload.trackId ||
        trackPayload.id ||
        trackPayload.track_id ||
        trackPayload.apple_music?.id ||
        trackPayload.spotify?.id ||
        `${trackName}-${artistName}`.replace(/\s+/g, '-').toLowerCase(),
      trackName,
      artistName,
      albumName:
        trackPayload.albumName ||
        trackPayload.album ||
        trackPayload.album_name ||
        trackPayload.collectionName ||
        null,
      albumArtUrl:
        trackPayload.albumArtUrl ||
        trackPayload.album_art_url ||
        trackPayload.artwork?.url ||
        trackPayload.images?.coverart ||
        trackPayload.apple_music?.artwork?.url ||
        trackPayload.spotify?.album?.images?.[0]?.url ||
        null,
      streamingLinks: {
        spotify:
          trackPayload.spotify?.external_urls?.spotify ||
          trackPayload.spotify?.url ||
          trackPayload.links?.spotify ||
          null,
        appleMusic:
          trackPayload.apple_music?.url ||
          trackPayload.appleMusicUrl ||
          trackPayload.apple_music_url ||
          null,
      },
      confidence:
        trackPayload.confidence ||
        trackPayload.score ||
        payload.confidence ||
        trackPayload.result_score ||
        null,
      source:
        payload.source ||
        trackPayload.source ||
        (payload.result ? 'audd' : recognitionUrl ? 'custom' : 'mock'),
    };

    return normalizedTrack;
  }

  private static getExtension(uri: string) {
    const parts = uri.split('.');
    return parts.length > 1 ? parts.pop() : 'm4a';
  }

  private static async safeParseError(response: Response) {
    try {
      const errorPayload = await response.json();
      return (
        errorPayload?.message ||
        errorPayload?.error ||
        `Recognition failed with status ${response.status}`
      );
    } catch {
      return `Recognition failed with status ${response.status}`;
    }
  }

  private static delay(ms: number) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
