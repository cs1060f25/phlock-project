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
        Relationships: []
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
        Relationships: [
          {
            foreignKeyName: 'friendships_user_id_1_fkey',
            columns: ['user_id_1'],
            referencedRelation: 'users',
            referencedColumns: ['id'],
          },
          {
            foreignKeyName: 'friendships_user_id_2_fkey',
            columns: ['user_id_2'],
            referencedRelation: 'users',
            referencedColumns: ['id'],
          },
        ]
      }
      shares: {
        Row: {
          id: string
          sender_id: string | null
          recipient_id: string | null
          track_id: string
          track_name: string
          artist_name: string
          album_art_url: string | null
          message: string | null
          status: 'sent' | 'received' | 'played' | 'saved' | 'forwarded' | 'dismissed'
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          sender_id?: string | null
          recipient_id?: string | null
          track_id: string
          track_name: string
          artist_name: string
          album_art_url?: string | null
          message?: string | null
          status?: 'sent' | 'received' | 'played' | 'saved' | 'forwarded' | 'dismissed'
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          sender_id?: string | null
          recipient_id?: string | null
          track_id?: string
          track_name?: string
          artist_name?: string
          album_art_url?: string | null
          message?: string | null
          status?: 'sent' | 'received' | 'played' | 'saved' | 'forwarded' | 'dismissed'
          created_at?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: 'shares_sender_id_fkey',
            columns: ['sender_id'],
            referencedRelation: 'users',
            referencedColumns: ['id'],
          },
          {
            foreignKeyName: 'shares_recipient_id_fkey',
            columns: ['recipient_id'],
            referencedRelation: 'users',
            referencedColumns: ['id'],
          },
        ]
      }
      phlocks: {
        Row: {
          id: string
          origin_share_id: string | null
          created_by: string | null
          track_id: string
          track_name: string
          artist_name: string
          album_art_url: string | null
          total_reach: number
          max_depth: number
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          origin_share_id?: string | null
          created_by?: string | null
          track_id: string
          track_name: string
          artist_name: string
          album_art_url?: string | null
          total_reach?: number
          max_depth?: number
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          origin_share_id?: string | null
          created_by?: string | null
          track_id?: string
          track_name?: string
          artist_name?: string
          album_art_url?: string | null
          total_reach?: number
          max_depth?: number
          created_at?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: 'phlocks_origin_share_id_fkey',
            columns: ['origin_share_id'],
            referencedRelation: 'shares',
            referencedColumns: ['id'],
          },
          {
            foreignKeyName: 'phlocks_created_by_fkey',
            columns: ['created_by'],
            referencedRelation: 'users',
            referencedColumns: ['id'],
          },
        ]
      }
      phlock_nodes: {
        Row: {
          id: string
          phlock_id: string
          share_id: string | null
          user_id: string
          depth: number
          parent_node_id: string | null
          forwarded: boolean
          saved: boolean
          played: boolean
          created_at: string
        }
        Insert: {
          id?: string
          phlock_id: string
          share_id?: string | null
          user_id: string
          depth?: number
          parent_node_id?: string | null
          forwarded?: boolean
          saved?: boolean
          played?: boolean
          created_at?: string
        }
        Update: {
          id?: string
          phlock_id?: string
          share_id?: string | null
          user_id?: string
          depth?: number
          parent_node_id?: string | null
          forwarded?: boolean
          saved?: boolean
          played?: boolean
          created_at?: string
        }
        Relationships: [
          {
            foreignKeyName: 'phlock_nodes_phlock_id_fkey',
            columns: ['phlock_id'],
            referencedRelation: 'phlocks',
            referencedColumns: ['id'],
          },
          {
            foreignKeyName: 'phlock_nodes_share_id_fkey',
            columns: ['share_id'],
            referencedRelation: 'shares',
            referencedColumns: ['id'],
          },
          {
            foreignKeyName: 'phlock_nodes_user_id_fkey',
            columns: ['user_id'],
            referencedRelation: 'users',
            referencedColumns: ['id'],
          },
          {
            foreignKeyName: 'phlock_nodes_parent_node_id_fkey',
            columns: ['parent_node_id'],
            referencedRelation: 'phlock_nodes',
            referencedColumns: ['id'],
          },
        ]
      }
      engagements: {
        Row: {
          id: string
          share_id: string
          user_id: string
          action: 'played' | 'saved' | 'forwarded' | 'dismissed'
          created_at: string
        }
        Insert: {
          id?: string
          share_id: string
          user_id: string
          action: 'played' | 'saved' | 'forwarded' | 'dismissed'
          created_at?: string
        }
        Update: {
          id?: string
          share_id?: string
          user_id?: string
          action?: 'played' | 'saved' | 'forwarded' | 'dismissed'
          created_at?: string
        }
        Relationships: [
          {
            foreignKeyName: 'engagements_share_id_fkey',
            columns: ['share_id'],
            referencedRelation: 'shares',
            referencedColumns: ['id'],
          },
          {
            foreignKeyName: 'engagements_user_id_fkey',
            columns: ['user_id'],
            referencedRelation: 'users',
            referencedColumns: ['id'],
          },
        ]
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
