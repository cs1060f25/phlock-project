export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export interface Database {
  public: {
    Tables: {
      users: {
        Row: {
          id: string
          phone: string | null
          email: string | null
          display_name: string
          profile_photo_url: string | null
          bio: string | null
          privacy_who_can_send: 'everyone' | 'friends' | 'specific'
          created_at: string
        }
        Insert: {
          id?: string
          phone?: string | null
          email?: string | null
          display_name: string
          profile_photo_url?: string | null
          bio?: string | null
          privacy_who_can_send?: 'everyone' | 'friends' | 'specific'
          created_at?: string
        }
        Update: {
          id?: string
          phone?: string | null
          email?: string | null
          display_name?: string
          profile_photo_url?: string | null
          bio?: string | null
          privacy_who_can_send?: 'everyone' | 'friends' | 'specific'
          created_at?: string
        }
      }
      friendships: {
        Row: {
          id: string
          user_id_1: string
          user_id_2: string
          status: 'pending' | 'accepted' | 'blocked'
          created_at: string
        }
        Insert: {
          id?: string
          user_id_1: string
          user_id_2: string
          status?: 'pending' | 'accepted' | 'blocked'
          created_at?: string
        }
        Update: {
          id?: string
          user_id_1?: string
          user_id_2?: string
          status?: 'pending' | 'accepted' | 'blocked'
          created_at?: string
        }
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      friendship_status: 'pending' | 'accepted' | 'blocked'
      privacy_setting: 'everyone' | 'friends' | 'specific'
    }
  }
}
