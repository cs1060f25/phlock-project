import { supabase } from '../lib/supabase';
import { Database } from '../types/database.types';
import { RecognizedTrack } from './songRecognition';

type ShareRow = Database['public']['Tables']['shares']['Row'];

interface SendSharePayload {
  senderId: string;
  recipientId: string;
  track: RecognizedTrack;
  message?: string;
}

export class SharesService {
  static async sendRecognizedShare({
    senderId,
    recipientId,
    track,
    message,
  }: SendSharePayload): Promise<ShareRow> {
    const { data, error } = await supabase
      .from('shares')
      .insert({
        sender_id: senderId,
        recipient_id: recipientId,
        track_id: track.trackId,
        track_name: track.trackName,
        artist_name: track.artistName,
        album_art_url: track.albumArtUrl,
        message: message ?? null,
        status: 'sent',
      })
      .select()
      .single();

    if (error) {
      console.error('[SharesService] sendRecognizedShare failed', error);
      throw error;
    }

    return data;
  }
}
