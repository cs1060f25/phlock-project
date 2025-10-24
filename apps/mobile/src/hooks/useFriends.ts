import { useState, useEffect } from 'react';
import { FriendsService, FriendWithProfile } from '../services/friends';
import { useAuth } from './useAuth';

export function useFriends() {
  const { supabaseUser } = useAuth();
  const [friends, setFriends] = useState<FriendWithProfile[]>([]);
  const [pendingRequests, setPendingRequests] = useState<FriendWithProfile[]>([]);
  const [sentRequests, setSentRequests] = useState<FriendWithProfile[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  const loadFriends = async () => {
    if (!supabaseUser) return;

    try {
      setLoading(true);
      const [friendsData, pendingData, sentData] = await Promise.all([
        FriendsService.getFriends(supabaseUser.id),
        FriendsService.getPendingRequests(supabaseUser.id),
        FriendsService.getSentRequests(supabaseUser.id),
      ]);

      setFriends(friendsData);
      setPendingRequests(pendingData);
      setSentRequests(sentData);
      setError(null);
    } catch (err) {
      setError(err as Error);
      console.error('Error loading friends:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (supabaseUser) {
      loadFriends();
    }
  }, [supabaseUser]);

  const sendFriendRequest = async (targetUserId: string) => {
    if (!supabaseUser) throw new Error('Not authenticated');

    try {
      await FriendsService.sendFriendRequest(supabaseUser.id, targetUserId);
      await loadFriends();
    } catch (err) {
      setError(err as Error);
      throw err;
    }
  };

  const acceptFriendRequest = async (friendshipId: string) => {
    try {
      await FriendsService.acceptFriendRequest(friendshipId);
      await loadFriends();
    } catch (err) {
      setError(err as Error);
      throw err;
    }
  };

  const rejectFriendRequest = async (friendshipId: string) => {
    try {
      await FriendsService.rejectFriendRequest(friendshipId);
      await loadFriends();
    } catch (err) {
      setError(err as Error);
      throw err;
    }
  };

  const unfriend = async (friendId: string) => {
    if (!supabaseUser) throw new Error('Not authenticated');

    try {
      await FriendsService.unfriend(supabaseUser.id, friendId);
      await loadFriends();
    } catch (err) {
      setError(err as Error);
      throw err;
    }
  };

  const blockUser = async (targetUserId: string) => {
    if (!supabaseUser) throw new Error('Not authenticated');

    try {
      await FriendsService.blockUser(supabaseUser.id, targetUserId);
      await loadFriends();
    } catch (err) {
      setError(err as Error);
      throw err;
    }
  };

  const checkFriendshipStatus = async (userId: string) => {
    if (!supabaseUser) throw new Error('Not authenticated');

    return await FriendsService.getFriendshipStatus(supabaseUser.id, userId);
  };

  return {
    friends,
    pendingRequests,
    sentRequests,
    loading,
    error,
    refresh: loadFriends,
    sendFriendRequest,
    acceptFriendRequest,
    rejectFriendRequest,
    unfriend,
    blockUser,
    checkFriendshipStatus,
  };
}
