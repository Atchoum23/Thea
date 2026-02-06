/**
 * Trakt Dashboard Component
 * Main view for Trakt integration
 */

import { useEffect } from 'react';
import { FocusContext, useFocusable } from '@noriginmedia/norigin-spatial-navigation';
import { useTraktStore } from '../../stores/traktStore';
import { FocusableCard, FocusableButton, FocusableList } from '../ui/FocusableCard';
import { ColorButtonHints, CommonHints } from '../ui/ColorButtonHints';
import { useTVRemote } from '../../hooks/useTVRemote';

export function TraktDashboard() {
  const { ref, focusKey } = useFocusable({
    focusable: false,
    saveLastFocusedChild: true,
  });

  const {
    authStatus,
    user,
    stats,
    activeCheckIn,
    recentHistory,
    isLoading,
    error,
    startAuth,
    cancelCheckIn,
    loadHistory,
  } = useTraktStore();

  // Handle color buttons
  useTVRemote({
    onRed: () => {
      if (activeCheckIn) {
        cancelCheckIn();
      }
    },
    onGreen: () => {
      // Open quick check-in
    },
    onBlue: () => {
      // Open search
    },
  });

  useEffect(() => {
    if (authStatus.status === 'authenticated') {
      loadHistory();
    }
  }, [authStatus.status, loadHistory]);

  // Not authenticated - show auth flow
  if (authStatus.status !== 'authenticated') {
    return (
      <FocusContext.Provider value={focusKey}>
        <div ref={ref} className="flex flex-col items-center justify-center h-full p-8">
          <TraktAuthFlow />
        </div>
      </FocusContext.Provider>
    );
  }

  return (
    <FocusContext.Provider value={focusKey}>
      <div ref={ref} className="flex flex-col h-full p-8">
        {/* Header */}
        <div className="flex justify-between items-center mb-8">
          <div>
            <h1 className="text-4xl font-bold text-white">Trakt</h1>
            {user && (
              <p className="text-xl text-gray-400 mt-1">
                Welcome, {user.name || user.username}
                {user.vip && <span className="ml-2 text-yellow-500">VIP</span>}
              </p>
            )}
          </div>

          {/* Stats */}
          {stats && (
            <div className="flex gap-8 text-center">
              <StatCard label="Movies" value={stats.movies.watched} />
              <StatCard label="Episodes" value={stats.episodes.watched} />
              <StatCard label="Shows" value={stats.shows.watched} />
            </div>
          )}
        </div>

        {/* Error display */}
        {error && (
          <div className="bg-red-900/50 border border-red-500 text-red-200 px-6 py-4 rounded-lg mb-6 text-xl">
            {error}
          </div>
        )}

        {/* Active check-in */}
        {activeCheckIn && (
          <ActiveCheckInCard checkIn={activeCheckIn} onCancel={cancelCheckIn} />
        )}

        {/* Quick actions */}
        <div className="mb-8">
          <h2 className="text-2xl font-semibold text-white mb-4">Quick Check-in</h2>
          <QuickCheckInGrid />
        </div>

        {/* Recent history */}
        <div className="flex-1 overflow-hidden">
          <h2 className="text-2xl font-semibold text-white mb-4">Recent Watches</h2>
          <HistoryList items={recentHistory} />
        </div>

        {/* Loading overlay */}
        {isLoading && (
          <div className="absolute inset-0 bg-black/50 flex items-center justify-center">
            <div className="text-2xl text-white">Loading...</div>
          </div>
        )}

        {/* Color button hints */}
        <ColorButtonHints hints={CommonHints.trakt} />
      </div>
    </FocusContext.Provider>
  );
}

/**
 * Auth flow component
 */
function TraktAuthFlow() {
  const { authStatus, startAuth, cancelAuth } = useTraktStore();

  if (authStatus.status === 'pending') {
    return (
      <div className="text-center">
        <h2 className="text-3xl font-bold text-white mb-6">Connect to Trakt</h2>
        <p className="text-xl text-gray-400 mb-8">
          Go to <span className="text-blue-400">{authStatus.verificationUrl}</span>
        </p>
        <div className="bg-gray-800 px-12 py-8 rounded-xl mb-8">
          <p className="text-gray-400 mb-2">Enter this code:</p>
          <p className="text-5xl font-mono font-bold text-white tracking-widest">
            {authStatus.userCode}
          </p>
        </div>
        <FocusableButton onClick={cancelAuth} variant="secondary">
          Cancel
        </FocusableButton>
      </div>
    );
  }

  if (authStatus.status === 'polling') {
    return (
      <div className="text-center">
        <div className="text-2xl text-gray-400">Waiting for authorization...</div>
        <div className="mt-4 animate-spin w-8 h-8 border-4 border-blue-500 border-t-transparent rounded-full mx-auto" />
      </div>
    );
  }

  if (authStatus.status === 'expired') {
    return (
      <div className="text-center">
        <p className="text-xl text-red-400 mb-6">Code expired. Please try again.</p>
        <FocusableButton onClick={startAuth}>
          Start Over
        </FocusableButton>
      </div>
    );
  }

  if (authStatus.status === 'denied') {
    return (
      <div className="text-center">
        <p className="text-xl text-red-400 mb-6">Authorization denied.</p>
        <FocusableButton onClick={startAuth}>
          Try Again
        </FocusableButton>
      </div>
    );
  }

  // Idle state
  return (
    <div className="text-center">
      <h2 className="text-4xl font-bold text-white mb-4">Connect to Trakt</h2>
      <p className="text-xl text-gray-400 mb-8 max-w-lg">
        Track what you watch across all your devices. Connect your Trakt account
        to get started.
      </p>
      <FocusableButton onClick={startAuth} size="lg">
        Connect Trakt Account
      </FocusableButton>
    </div>
  );
}

/**
 * Stat card
 */
function StatCard({ label, value }: { label: string; value: number }) {
  return (
    <div className="bg-gray-800 px-6 py-3 rounded-lg">
      <div className="text-3xl font-bold text-white">{value.toLocaleString()}</div>
      <div className="text-sm text-gray-400">{label}</div>
    </div>
  );
}

/**
 * Active check-in display
 */
function ActiveCheckInCard({
  checkIn,
  onCancel,
}: {
  checkIn: { movie?: { title: string }; show?: { title: string }; episode?: { season: number; number: number } };
  onCancel: () => void;
}) {
  const title = checkIn.movie?.title || checkIn.show?.title || 'Unknown';
  const subtitle = checkIn.episode
    ? `S${checkIn.episode.season}E${checkIn.episode.number}`
    : '';

  return (
    <FocusableCard
      className="bg-green-900/30 border border-green-500 mb-6"
      onEnterPress={onCancel}
    >
      <div className="flex justify-between items-center">
        <div>
          <div className="text-sm text-green-400 mb-1">NOW WATCHING</div>
          <div className="text-2xl font-semibold text-white">{title}</div>
          {subtitle && <div className="text-lg text-gray-400">{subtitle}</div>}
        </div>
        <FocusableButton onClick={onCancel} variant="danger" size="sm">
          Cancel Check-in
        </FocusableButton>
      </div>
    </FocusableCard>
  );
}

/**
 * Quick check-in grid
 */
function QuickCheckInGrid() {
  const { upNext, checkInEpisode } = useTraktStore();

  const suggestions = upNext.slice(0, 4);

  return (
    <FocusableList direction="horizontal" className="gap-4">
      {suggestions.map((item) => (
        <FocusableCard
          key={item.show.ids.trakt}
          className="bg-gray-800 w-64 flex-shrink-0"
          onEnterPress={() => {
            if (item.progress.nextEpisode) {
              checkInEpisode(
                item.show.title,
                item.progress.nextEpisode.season,
                item.progress.nextEpisode.number
              );
            }
          }}
        >
          <div className="text-lg font-semibold text-white truncate">
            {item.show.title}
          </div>
          {item.progress.nextEpisode && (
            <div className="text-base text-gray-400">
              Next: S{item.progress.nextEpisode.season}E{item.progress.nextEpisode.number}
            </div>
          )}
          <div className="text-sm text-gray-500 mt-2">
            {item.progress.completed}/{item.progress.aired} episodes
          </div>
        </FocusableCard>
      ))}

      {/* Add custom check-in */}
      <FocusableCard className="bg-gray-800/50 border-2 border-dashed border-gray-600 w-64 flex-shrink-0 flex items-center justify-center">
        <div className="text-center">
          <div className="text-3xl mb-2">+</div>
          <div className="text-lg text-gray-400">Custom Check-in</div>
        </div>
      </FocusableCard>
    </FocusableList>
  );
}

/**
 * History list
 */
function HistoryList({ items }: { items: Array<{ id: number; watchedAt: string; movie?: { title: string }; show?: { title: string }; episode?: { season: number; number: number; title: string } }> }) {
  if (items.length === 0) {
    return (
      <div className="text-center text-gray-500 py-8">
        No watch history yet. Start watching something!
      </div>
    );
  }

  return (
    <FocusableList className="overflow-y-auto max-h-[400px] pr-4">
      {items.map((item) => {
        const title = item.movie?.title || item.show?.title || 'Unknown';
        const subtitle = item.episode
          ? `S${item.episode.season}E${item.episode.number} - ${item.episode.title}`
          : '';
        const watchedAt = new Date(item.watchedAt).toLocaleDateString();

        return (
          <FocusableCard
            key={item.id}
            className="bg-gray-800/50"
            tvPadding={false}
          >
            <div className="flex justify-between items-center px-4 py-3">
              <div>
                <div className="text-lg text-white">{title}</div>
                {subtitle && <div className="text-base text-gray-400">{subtitle}</div>}
              </div>
              <div className="text-sm text-gray-500">{watchedAt}</div>
            </div>
          </FocusableCard>
        );
      })}
    </FocusableList>
  );
}
