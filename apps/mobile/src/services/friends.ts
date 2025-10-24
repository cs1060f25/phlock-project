import { supabase } from '../lib/supabase';
import { Database } from '../types/database.types';

type Friendship = Database['public']['Tables']['friendships']['Row'];
type FriendshipInsert = Database['public']['Tables']['friendships']['Insert'];
type User = Database['public']['Tables']['users']['Row'];

export interface FriendWithProfile extends Friendship {
  friend: User;
}

export class FriendsService {
  /**
   * Send a friend request
   */
  static async sendFriendRequest(currentUserId: string, targetUserId: string) {
    const { data, error } = await supabase
      .from('friendships')
      .insert({
        user_id_1: currentUserId,
        user_id_2: targetUserId,
        status: 'pending',
      })
      .select()
      .single();

    if (error) throw error;
    return data;
  }

  /**
   * Accept a friend request
   */
  static async acceptFriendRequest(friendshipId: string) {
    const { data, error } = await supabase
      .from('friendships')
      .update({ status: 'accepted' })
      .eq('id', friendshipId)
      .select()
      .single();

    if (error) throw error;
    return data;
  }

  /**
   * Reject a friend request
   */
  static async rejectFriendRequest(friendshipId: string) {
    const { error } = await supabase
      .from('friendships')
      .delete()
      .eq('id', friendshipId);

    if (error) throw error;
  }

  /**
   * Block a user
   */
  static async blockUser(currentUserId: string, targetUserId: string) {
    const { data, error } = await supabase
      .from('friendships')
      .upsert({
        user_id_1: currentUserId,
        user_id_2: targetUserId,
        status: 'blocked',
      })
      .select()
      .single();

    if (error) throw error;
    return data;
  }

  /**
   * Unfriend a user
   */
  static async unfriend(currentUserId: string, friendId: string) {
    const { error } = await supabase
      .from('friendships')
      .delete()
      .or(
        `and(user_id_1.eq.${currentUserId},user_id_2.eq.${friendId}),and(user_id_1.eq.${friendId},user_id_2.eq.${currentUserId})`
      );

    if (error) throw error;
  }

  /**
   * Get all friends (accepted friendships)
   */
  static async getFriends(userId: string): Promise<FriendWithProfile[]> {
    // Get friendships where user is either user_id_1 or user_id_2 and status is accepted
    const { data, error } = await supabase
      .from('friendships')
      .select(`
        *,
        friend:users!user_id_2(*)
      `)
      .eq('user_id_1', userId)
      .eq('status', 'accepted');

    if (error) throw error;

    // Also get friendships where user is user_id_2
    const { data: data2, error: error2 } = await supabase
      .from('friendships')
      .select(`
        *,
        friend:users!user_id_1(*)
      `)
      .eq('user_id_2', userId)
      .eq('status', 'accepted');

    if (error2) throw error2;

    return [...(data || []), ...(data2 || [])];
  }

  /**
   * Get pending friend requests (received)
   */
  static async getPendingRequests(userId: string): Promise<FriendWithProfile[]> {
    const { data, error } = await supabase
      .from('friendships')
      .select(`
        *,
        friend:users!user_id_1(*)
      `)
      .eq('user_id_2', userId)
      .eq('status', 'pending');

    if (error) throw error;
    return data || [];
  }

  /**
   * Get sent friend requests (pending)
   */
  static async getSentRequests(userId: string): Promise<FriendWithProfile[]> {
    const { data, error } = await supabase
      .from('friendships')
      .select(`
        *,
        friend:users!user_id_2(*)
      `)
      .eq('user_id_1', userId)
      .eq('status', 'pending');

    if (error) throw error;
    return data || [];
  }

  /**
   * Check friendship status between two users
   */
  static async getFriendshipStatus(userId1: string, userId2: string): Promise<'none' | 'pending' | 'accepted' | 'blocked'> {
    const { data, error } = await supabase
      .from('friendships')
      .select('status')
      .or(
        `and(user_id_1.eq.${userId1},user_id_2.eq.${userId2}),and(user_id_1.eq.${userId2},user_id_2.eq.${userId1})`
      )
      .single();

    if (error) {
      if (error.code === 'PGRST116') {
        return 'none';
      }
      throw error;
    }

    return data.status as 'pending' | 'accepted' | 'blocked';
  }

  /**
   * Get friend count
   */
  static async getFriendCount(userId: string): Promise<number> {
    const { count, error } = await supabase
      .from('friendships')
      .select('*', { count: 'exact', head: true })
      .or(`user_id_1.eq.${userId},user_id_2.eq.${userId}`)
      .eq('status', 'accepted');

    if (error) throw error;
    return count || 0;
  }
}
