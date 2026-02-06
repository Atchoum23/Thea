/**
 * Trakt State Store
 * Manages Trakt authentication and watch tracking state
 */

import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type {
  TraktHistoryItem,
  TraktCheckin,
  TraktSearchResult,
  TraktUser,
  TraktStats,
  TraktShowProgress,
  TraktShow,
} from '../types/trakt';
import { TraktAuth, AuthStatus } from '../services/trakt/TraktAuth';
import { TraktClient } from '../services/trakt/TraktClient';

interface TraktState {
  // Authentication
  authStatus: AuthStatus;
  user: TraktUser | null;
  stats: TraktStats | null;

  // Current check-in
  activeCheckIn: TraktCheckin | null;

  // History and watchlist
  recentHistory: TraktHistoryItem[];
  upNext: Array<{ show: TraktShow; progress: TraktShowProgress }>;

  // Search
  searchResults: TraktSearchResult[];
  isSearching: boolean;

  // Loading states
  isLoading: boolean;
  error: string | null;

  // Actions
  initAuth: (clientId: string, clientSecret: string) => void;
  startAuth: () => Promise<void>;
  cancelAuth: () => void;
  logout: () => void;

  // Check-in actions
  checkInMovie: (title: string) => Promise<void>;
  checkInEpisode: (showTitle: string, season: number, episode: number) => Promise<void>;
  smartCheckIn: (query: string) => Promise<boolean>;
  cancelCheckIn: () => Promise<void>;

  // Search
  search: (query: string) => Promise<void>;
  clearSearch: () => void;

  // Data loading
  loadUserData: () => Promise<void>;
  loadHistory: () => Promise<void>;
  loadUpNext: () => Promise<void>;

  // Clear error
  clearError: () => void;
}

export const useTraktStore = create<TraktState>()(
  persist(
    (set, get) => ({
      authStatus: { status: 'idle' },
      user: null,
      stats: null,
      activeCheckIn: null,
      recentHistory: [],
      upNext: [],
      searchResults: [],
      isSearching: false,
      isLoading: false,
      error: null,

      initAuth: (clientId: string, clientSecret: string) => {
        TraktAuth.configure(clientId, clientSecret);
        TraktClient.configure(clientId);

        // Subscribe to auth status changes
        TraktAuth.subscribe((status) => {
          set({ authStatus: status });

          // Load user data on successful auth
          if (status.status === 'authenticated') {
            get().loadUserData();
          }
        });

        // Check if already authenticated
        if (TraktAuth.isAuthenticated) {
          set({ authStatus: { status: 'authenticated', tokens: TraktAuth.getTokens()! } });
          get().loadUserData();
        }
      },

      startAuth: async () => {
        try {
          await TraktAuth.startDeviceAuth();
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Failed to start auth',
          });
        }
      },

      cancelAuth: () => {
        TraktAuth.cancel();
      },

      logout: () => {
        TraktAuth.logout();
        set({
          user: null,
          stats: null,
          activeCheckIn: null,
          recentHistory: [],
          upNext: [],
        });
      },

      checkInMovie: async (title: string) => {
        set({ isLoading: true, error: null });

        try {
          // Search for the movie
          const results = await TraktClient.searchMovies(title, 1);
          if (results.length === 0 || !results[0].movie) {
            throw new Error(`Movie not found: ${title}`);
          }

          const checkIn = await TraktClient.checkInMovie(results[0].movie);
          set({ activeCheckIn: checkIn });
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Check-in failed',
          });
        } finally {
          set({ isLoading: false });
        }
      },

      checkInEpisode: async (showTitle: string, season: number, episode: number) => {
        set({ isLoading: true, error: null });

        try {
          // Search for the show
          const results = await TraktClient.searchShows(showTitle, 1);
          if (results.length === 0 || !results[0].show) {
            throw new Error(`Show not found: ${showTitle}`);
          }

          const show = results[0].show;
          const episodeObj = {
            season,
            number: episode,
            title: '',
            ids: { trakt: 0, slug: '' },
          };

          const checkIn = await TraktClient.checkInEpisode(show, episodeObj);
          set({ activeCheckIn: checkIn });
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Check-in failed',
          });
        } finally {
          set({ isLoading: false });
        }
      },

      smartCheckIn: async (query: string) => {
        set({ isLoading: true, error: null });

        try {
          // Use AI to parse the query
          // This requires a configured AI provider
          const { ProviderRegistry } = await import('../services/ai/ProviderRegistry');
          const provider = ProviderRegistry.bestAvailableProvider;

          if (!provider) {
            // Fall back to simple parsing
            const match = query.match(/(.+?)\s+[sS](\d+)\s*[eE](\d+)/);
            if (match) {
              await get().checkInEpisode(match[1], parseInt(match[2]), parseInt(match[3]));
              return true;
            }
            // Assume it's a movie
            await get().checkInMovie(query);
            return true;
          }

          const aiParser = async (prompt: string) => {
            return provider.chatSync(
              [{ role: 'user', content: prompt }],
              provider.supportedModels[0].id,
              { maxTokens: 100 }
            );
          };

          const checkIn = await TraktClient.smartCheckIn(query, aiParser);
          if (checkIn) {
            set({ activeCheckIn: checkIn });
            return true;
          }
          return false;
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Smart check-in failed',
          });
          return false;
        } finally {
          set({ isLoading: false });
        }
      },

      cancelCheckIn: async () => {
        try {
          await TraktClient.cancelCheckIn();
          set({ activeCheckIn: null });
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Cancel failed',
          });
        }
      },

      search: async (query: string) => {
        if (!query.trim()) {
          set({ searchResults: [] });
          return;
        }

        set({ isSearching: true, error: null });

        try {
          const results = await TraktClient.search(query, 20);
          set({ searchResults: results });
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Search failed',
          });
        } finally {
          set({ isSearching: false });
        }
      },

      clearSearch: () => {
        set({ searchResults: [] });
      },

      loadUserData: async () => {
        set({ isLoading: true });

        try {
          const [user, stats] = await Promise.all([
            TraktClient.getCurrentUser(),
            TraktClient.getUserStats(),
          ]);

          set({ user, stats });

          // Also load history and up next
          await Promise.all([get().loadHistory(), get().loadUpNext()]);
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Failed to load user data',
          });
        } finally {
          set({ isLoading: false });
        }
      },

      loadHistory: async () => {
        try {
          const history = await TraktClient.getHistory('episodes', 1, 20);
          set({ recentHistory: history });
        } catch (error) {
          console.error('Failed to load history:', error);
        }
      },

      loadUpNext: async () => {
        try {
          const upNext = await TraktClient.getUpNext();
          set({ upNext: upNext.slice(0, 10) }); // Limit to 10
        } catch (error) {
          console.error('Failed to load up next:', error);
        }
      },

      clearError: () => {
        set({ error: null });
      },
    }),
    {
      name: 'thea_trakt',
      partialize: (state) => ({
        user: state.user,
        stats: state.stats,
        recentHistory: state.recentHistory.slice(0, 10), // Only persist recent
      }),
    }
  )
);
