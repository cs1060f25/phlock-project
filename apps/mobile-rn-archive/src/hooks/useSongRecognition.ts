import { useCallback, useRef, useState } from 'react';
import { Audio, InterruptionModeAndroid, InterruptionModeIOS } from 'expo-av';
import { SongRecognitionService, RecognizedTrack } from '../services/songRecognition';

export type SongRecognitionStatus = 'idle' | 'listening' | 'identifying' | 'success' | 'error';
export type PermissionState = 'unknown' | 'granted' | 'denied';

const AUTO_CAPTURE_DURATION_MS = 8000;

export function useSongRecognition() {
  const [status, setStatus] = useState<SongRecognitionStatus>('idle');
  const [recognizedTrack, setRecognizedTrack] = useState<RecognizedTrack | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [permissionStatus, setPermissionStatus] = useState<PermissionState>('unknown');
  const recordingRef = useRef<Audio.Recording | null>(null);
  const autoStopTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const clearTimer = useCallback(() => {
    if (autoStopTimerRef.current) {
      clearTimeout(autoStopTimerRef.current);
      autoStopTimerRef.current = null;
    }
  }, []);

  const reset = useCallback(() => {
    clearTimer();
    recordingRef.current = null;
    setStatus('idle');
    setRecognizedTrack(null);
    setError(null);
  }, [clearTimer]);

  const cancelListening = useCallback(async () => {
    clearTimer();
    const recording = recordingRef.current;
    recordingRef.current = null;
    if (recording) {
      try {
        await recording.stopAndUnloadAsync();
        const uri = recording.getURI();
        if (uri) {
          await SongRecognitionService.cleanupRecording(uri);
        }
      } catch {
        // ignore
      }
    }
    setStatus('idle');
  }, [clearTimer]);

  const stopAndIdentify = useCallback(async () => {
    clearTimer();
    const recording = recordingRef.current;
    recordingRef.current = null;

    if (!recording) {
      setError('No active recording found');
      setStatus('error');
      return null;
    }

    setStatus('identifying');

    try {
      await recording.stopAndUnloadAsync();
    } catch {
      // Expo throws if recording already stopped; continue
    }

    const uri = recording.getURI();
    if (!uri) {
      setError('Recording did not finish in time');
      setStatus('error');
      return null;
    }

    try {
      const track = await SongRecognitionService.identifyTrackFromFile(uri);
      setRecognizedTrack(track);
      setStatus('success');
      return track;
    } catch (err) {
      console.error('[useSongRecognition] identify error', err);
      setError(err instanceof Error ? err.message : 'Song recognition failed');
      setStatus('error');
      return null;
    } finally {
      await SongRecognitionService.cleanupRecording(uri);
      await Audio.setAudioModeAsync({
        allowsRecordingIOS: false,
        playsInSilentModeIOS: false,
      });
    }
  }, [clearTimer]);

  const startListening = useCallback(async () => {
    try {
      setError(null);
      setRecognizedTrack(null);

      const permission = await Audio.requestPermissionsAsync();
      if (!permission.granted) {
        setPermissionStatus('denied');
        setError('Microphone permission is required to identify songs.');
        setStatus('error');
        return false;
      }

      setPermissionStatus('granted');
      setStatus('listening');

      await Audio.setAudioModeAsync({
        allowsRecordingIOS: true,
        playsInSilentModeIOS: true,
        interruptionModeIOS: InterruptionModeIOS.DoNotMix,
        shouldDuckAndroid: true,
        interruptionModeAndroid: InterruptionModeAndroid.DoNotMix,
        staysActiveInBackground: false,
      });

      const recording = new Audio.Recording();
      await recording.prepareToRecordAsync(Audio.RecordingOptionsPresets.HIGH_QUALITY);
      await recording.startAsync();
      recordingRef.current = recording;

      if (AUTO_CAPTURE_DURATION_MS > 0) {
        clearTimer();
        autoStopTimerRef.current = setTimeout(() => {
          stopAndIdentify();
        }, AUTO_CAPTURE_DURATION_MS);
      }

      return true;
    } catch (err) {
      console.error('[useSongRecognition] start error', err);
      setError(err instanceof Error ? err.message : 'Unable to start listening');
      setStatus('error');
      return false;
    }
  }, [clearTimer, stopAndIdentify]);

  return {
    status,
    recognizedTrack,
    error,
    permissionStatus,
    startListening,
    stopAndIdentify,
    cancelListening,
    reset,
  };
}
