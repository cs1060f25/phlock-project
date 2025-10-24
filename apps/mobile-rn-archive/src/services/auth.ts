import { supabase } from '../lib/supabase';
import { Database } from '../types/database.types';

type User = Database['public']['Tables']['users']['Row'];
type UserInsert = Database['public']['Tables']['users']['Insert'];

export class AuthService {
  /**
   * Sign in with email (sends magic link or OTP)
   */
  static async signInWithEmail(email: string) {
    const { data, error } = await supabase.auth.signInWithOtp({
      email,
      options: {
        emailRedirectTo: 'phlock://auth/callback',
      },
    });

    if (error) throw error;
    return data;
  }

  /**
   * Sign in with phone (sends OTP via SMS)
   */
  static async signInWithPhone(phone: string) {
    const { data, error } = await supabase.auth.signInWithOtp({
      phone,
      options: {
        channel: 'sms',
      },
    });

    if (error) throw error;
    return data;
  }

  /**
   * Verify OTP code
   */
  static async verifyOtp(params: { phone?: string; email?: string; token: string }) {
    const { data, error } = await supabase.auth.verifyOtp({
      phone: params.phone,
      email: params.email,
      token: params.token,
      type: params.phone ? 'sms' : 'email',
    });

    if (error) throw error;
    return data;
  }

  /**
   * Get current session
   */
  static async getSession() {
    const { data, error } = await supabase.auth.getSession();
    if (error) throw error;
    return data.session;
  }

  /**
   * Get current user
   */
  static async getCurrentUser() {
    const { data, error } = await supabase.auth.getUser();
    if (error) throw error;
    return data.user;
  }

  /**
   * Sign out
   */
  static async signOut() {
    const { error } = await supabase.auth.signOut();
    if (error) throw error;
  }

  /**
   * Create user profile in database
   */
  static async createUserProfile(userId: string, profile: Omit<UserInsert, 'id'>) {
    const { data, error } = await supabase
      .from('users')
      .insert({
        id: userId,
        ...profile,
      })
      .select()
      .single();

    if (error) throw error;
    return data;
  }

  /**
   * Get user profile from database
   */
  static async getUserProfile(userId: string): Promise<User | null> {
    const { data, error } = await supabase
      .from('users')
      .select('*')
      .eq('id', userId)
      .single();

    if (error) {
      if (error.code === 'PGRST116') {
        // User not found
        return null;
      }
      throw error;
    }
    return data;
  }

  /**
   * Update user profile
   */
  static async updateUserProfile(
    userId: string,
    updates: Partial<Omit<User, 'id' | 'created_at'>>
  ) {
    const { data, error } = await supabase
      .from('users')
      .update(updates)
      .eq('id', userId)
      .select()
      .single();

    if (error) throw error;
    return data;
  }

  /**
   * Upload profile photo
   */
  static async uploadProfilePhoto(userId: string, photoUri: string) {
    // Read file as blob
    const response = await fetch(photoUri);
    const blob = await response.blob();

    const fileExt = photoUri.split('.').pop()?.toLowerCase() || 'jpg';
    const fileName = `${userId}.${fileExt}`;
    const filePath = `profile-photos/${fileName}`;

    // Upload to Supabase Storage
    const { data, error } = await supabase.storage
      .from('avatars')
      .upload(filePath, blob, {
        contentType: `image/${fileExt}`,
        upsert: true,
      });

    if (error) throw error;

    // Get public URL
    const { data: { publicUrl } } = supabase.storage
      .from('avatars')
      .getPublicUrl(filePath);

    return publicUrl;
  }

  /**
   * Search users by phone or email
   */
  static async searchUsers(query: string) {
    const { data, error } = await supabase
      .from('users')
      .select('id, display_name, profile_photo_url, phone, email')
      .or(`phone.ilike.%${query}%,email.ilike.%${query}%`)
      .limit(20);

    if (error) throw error;
    return data;
  }
}
