/**
 * Thea Dashboard Component
 *
 * Main status dashboard showing:
 * - Service health status
 * - Active downloads
 * - Currently watching
 * - Upcoming episodes
 * - Notifications
 * - Quick actions
 *
 * TV-optimized with spatial navigation.
 */

import React, { useState, useEffect } from 'react';
import { useFocusable, FocusContext } from '@noriginmedia/norigin-spatial-navigation';
import { theaOrchestrator, OrchestratorState, TheaNotification } from '../../services/core/TheaOrchestrator';
import { traktCalendarService, TraktCalendarItem } from '../../services/trakt/TraktCalendarService';
import { contentPredictionService, PredictedContent } from '../../services/prediction/ContentPredictionService';
import './TheaDashboard.css';

// ============================================================
// MAIN DASHBOARD
// ============================================================

export const TheaDashboard: React.FC = () => {
  const [state, setState] = useState<OrchestratorState | null>(null);
  const [upcomingEpisodes, setUpcomingEpisodes] = useState<TraktCalendarItem[]>([]);
  const [predictions, setPredictions] = useState<PredictedContent[]>([]);
  const [currentTime, setCurrentTime] = useState(new Date());

  const { ref, focusKey } = useFocusable({
    focusable: true,
    saveLastFocusedChild: true,
  });

  // Subscribe to orchestrator state
  useEffect(() => {
    const unsub = theaOrchestrator.onStateChange(setState);
    return unsub;
  }, []);

  // Load upcoming episodes
  useEffect(() => {
    const loadUpcoming = async () => {
      try {
        const items = await traktCalendarService.getMyShows(undefined, 7);
        setUpcomingEpisodes(items.slice(0, 5));
      } catch (error) {
        console.warn('Dashboard: Failed to load calendar', error);
      }
    };
    loadUpcoming();
  }, []);

  // Load predictions
  useEffect(() => {
    setPredictions(contentPredictionService.getPredictions());
  }, [state?.predictions]);

  // Update clock
  useEffect(() => {
    const timer = setInterval(() => setCurrentTime(new Date()), 60000);
    return () => clearInterval(timer);
  }, []);

  if (!state) {
    return <div className="dashboard-loading">Loading...</div>;
  }

  return (
    <FocusContext.Provider value={focusKey}>
      <div ref={ref} className="thea-dashboard">
        {/* Header */}
        <header className="dashboard-header">
          <div className="header-left">
            <h1 className="app-title">THEA</h1>
            <span className="app-tagline">Absolutely Everything AI-Powered</span>
          </div>
          <div className="header-center">
            <span className="current-time">
              {currentTime.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
            </span>
            <span className="current-date">
              {currentTime.toLocaleDateString([], { weekday: 'long', month: 'long', day: 'numeric' })}
            </span>
          </div>
          <div className="header-right">
            <HealthIndicator health={state.health} />
            <NotificationBadge count={theaOrchestrator.getUnreadCount()} />
          </div>
        </header>

        {/* Main Content */}
        <main className="dashboard-main">
          {/* Left Column - Status */}
          <section className="dashboard-column status-column">
            {/* Currently Watching */}
            {state.currentlyWatching && (
              <StatusCard
                title="Now Playing"
                icon="▶️"
                accent="green"
              >
                <div className="now-playing">
                  <span className="now-playing-title">
                    {state.currentlyWatching.title}
                  </span>
                  <span className="now-playing-device">
                    on {state.currentlyWatching.device}
                  </span>
                  <ProgressBar progress={state.currentlyWatching.progress} />
                </div>
              </StatusCard>
            )}

            {/* Active Downloads */}
            <StatusCard
              title="Downloads"
              icon="⬇️"
              count={state.activeDownloads.length}
              accent={state.activeDownloads.length > 0 ? 'blue' : undefined}
            >
              {state.activeDownloads.length === 0 ? (
                <div className="empty-state">No active downloads</div>
              ) : (
                <div className="downloads-list">
                  {state.activeDownloads.slice(0, 3).map(dl => (
                    <div key={dl.hash} className="download-item">
                      <span className="download-name">{dl.name}</span>
                      <div className="download-progress">
                        <ProgressBar progress={dl.progress} />
                        <span className="download-eta">{dl.eta}</span>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </StatusCard>

            {/* SmartDNS Status */}
            <StatusCard
              title="SmartDNS"
              icon="🌐"
              accent={state.ipStatus?.ip ? 'green' : 'gray'}
            >
              <div className="smartdns-status">
                <span className="ip-address">
                  {state.ipStatus?.ip || 'Checking...'}
                </span>
                <span className="ip-location">
                  {state.ipStatus?.country || ''}
                </span>
              </div>
            </StatusCard>
          </section>

          {/* Center Column - Content */}
          <section className="dashboard-column content-column">
            {/* Up Next */}
            <ContentSection title="Up Next" icon="📅">
              {upcomingEpisodes.length === 0 ? (
                <div className="empty-state">No upcoming episodes</div>
              ) : (
                <div className="content-grid">
                  {upcomingEpisodes.map(item => (
                    <EpisodeCard key={`${item.show.ids.trakt}-${item.episode.season}-${item.episode.number}`} item={item} />
                  ))}
                </div>
              )}
            </ContentSection>

            {/* Predictions */}
            {predictions.length > 0 && (
              <ContentSection title="For You" icon="✨">
                <div className="content-grid">
                  {predictions.slice(0, 4).map(pred => (
                    <PredictionCard key={pred.id} prediction={pred} />
                  ))}
                </div>
              </ContentSection>
            )}
          </section>

          {/* Right Column - Actions & Notifications */}
          <section className="dashboard-column actions-column">
            {/* Quick Actions */}
            <StatusCard title="Quick Actions" icon="⚡">
              <div className="quick-actions">
                <QuickActionButton
                  label="Check Episodes"
                  icon="🔄"
                  onPress={() => theaOrchestrator.checkEpisodesNow()}
                />
                <QuickActionButton
                  label="Movie Mode"
                  icon="🎬"
                  onPress={() => console.log('Movie mode')}
                />
                <QuickActionButton
                  label="Voice Search"
                  icon="🎤"
                  onPress={() => console.log('Voice search')}
                />
                <QuickActionButton
                  label="Settings"
                  icon="⚙️"
                  onPress={() => console.log('Settings')}
                />
              </div>
            </StatusCard>

            {/* Notifications */}
            <StatusCard
              title="Notifications"
              icon="🔔"
              count={theaOrchestrator.getUnreadCount()}
            >
              <div className="notifications-list">
                {state.notifications.slice(0, 4).map(notif => (
                  <NotificationItem key={notif.id} notification={notif} />
                ))}
                {state.notifications.length === 0 && (
                  <div className="empty-state">No notifications</div>
                )}
              </div>
            </StatusCard>
          </section>
        </main>

        {/* Footer - Service Status */}
        <footer className="dashboard-footer">
          <ServiceStatusBar services={state.health?.services || []} />
        </footer>
      </div>
    </FocusContext.Provider>
  );
};

// ============================================================
// SUB-COMPONENTS
// ============================================================

interface StatusCardProps {
  title: string;
  icon: string;
  count?: number;
  accent?: 'green' | 'blue' | 'yellow' | 'red' | 'gray';
  children: React.ReactNode;
}

const StatusCard: React.FC<StatusCardProps> = ({ title, icon, count, accent, children }) => {
  return (
    <div className={`status-card ${accent ? `accent-${accent}` : ''}`}>
      <div className="card-header">
        <span className="card-icon">{icon}</span>
        <span className="card-title">{title}</span>
        {count !== undefined && count > 0 && (
          <span className="card-count">{count}</span>
        )}
      </div>
      <div className="card-content">
        {children}
      </div>
    </div>
  );
};

interface ContentSectionProps {
  title: string;
  icon: string;
  children: React.ReactNode;
}

const ContentSection: React.FC<ContentSectionProps> = ({ title, icon, children }) => {
  return (
    <div className="content-section">
      <h2 className="section-title">
        <span className="section-icon">{icon}</span>
        {title}
      </h2>
      {children}
    </div>
  );
};

interface EpisodeCardProps {
  item: TraktCalendarItem;
}

const EpisodeCard: React.FC<EpisodeCardProps> = ({ item }) => {
  const { ref, focused } = useFocusable({
    onEnterPress: () => console.log('Open episode', item),
  });

  const airDate = new Date(item.first_aired);
  const isAired = airDate <= new Date();

  return (
    <div ref={ref} className={`episode-card ${focused ? 'focused' : ''} ${isAired ? 'aired' : 'upcoming'}`}>
      <div className="episode-show">{item.show.title}</div>
      <div className="episode-info">
        S{item.episode.season}E{item.episode.number} • {item.episode.title}
      </div>
      <div className="episode-air">
        {isAired ? 'Available' : airDate.toLocaleDateString()}
      </div>
    </div>
  );
};

interface PredictionCardProps {
  prediction: PredictedContent;
}

const PredictionCard: React.FC<PredictionCardProps> = ({ prediction }) => {
  const { ref, focused } = useFocusable({
    onEnterPress: () => console.log('Open prediction', prediction),
  });

  return (
    <div ref={ref} className={`prediction-card ${focused ? 'focused' : ''}`}>
      {prediction.poster && (
        <img src={prediction.poster} alt={prediction.title} className="prediction-poster" />
      )}
      <div className="prediction-info">
        <div className="prediction-title">
          {prediction.showTitle || prediction.title}
        </div>
        {prediction.season && prediction.episode && (
          <div className="prediction-episode">
            S{prediction.season}E{prediction.episode}
          </div>
        )}
        <div className="prediction-reason">
          {formatReason(prediction.reason)}
        </div>
      </div>
    </div>
  );
};

interface QuickActionButtonProps {
  label: string;
  icon: string;
  onPress: () => void;
}

const QuickActionButton: React.FC<QuickActionButtonProps> = ({ label, icon, onPress }) => {
  const { ref, focused } = useFocusable({
    onEnterPress: onPress,
  });

  return (
    <button ref={ref} className={`quick-action ${focused ? 'focused' : ''}`} onClick={onPress}>
      <span className="action-icon">{icon}</span>
      <span className="action-label">{label}</span>
    </button>
  );
};

interface NotificationItemProps {
  notification: TheaNotification;
}

const NotificationItem: React.FC<NotificationItemProps> = ({ notification }) => {
  const { ref, focused } = useFocusable({
    onEnterPress: () => {
      theaOrchestrator.markNotificationRead(notification.id);
      if (notification.action) {
        notification.action.callback();
      }
    },
  });

  const typeIcons = {
    info: 'ℹ️',
    success: '✅',
    warning: '⚠️',
    error: '❌',
  };

  return (
    <div
      ref={ref}
      className={`notification-item ${focused ? 'focused' : ''} ${notification.read ? 'read' : 'unread'} type-${notification.type}`}
    >
      <span className="notif-icon">{typeIcons[notification.type]}</span>
      <div className="notif-content">
        <span className="notif-title">{notification.title}</span>
        <span className="notif-message">{notification.message}</span>
      </div>
      <span className="notif-time">
        {formatTimeAgo(notification.timestamp)}
      </span>
    </div>
  );
};

interface HealthIndicatorProps {
  health: OrchestratorState['health'];
}

const HealthIndicator: React.FC<HealthIndicatorProps> = ({ health }) => {
  const statusColors = {
    healthy: '#4ade80',
    degraded: '#fbbf24',
    unhealthy: '#f87171',
  };

  const status = health?.overallStatus || 'healthy';

  return (
    <div className="health-indicator" title={`System: ${status}`}>
      <div
        className="health-dot"
        style={{ backgroundColor: statusColors[status] }}
      />
      <span className="health-label">{status}</span>
    </div>
  );
};

interface NotificationBadgeProps {
  count: number;
}

const NotificationBadge: React.FC<NotificationBadgeProps> = ({ count }) => {
  if (count === 0) return null;

  return (
    <div className="notification-badge">
      <span className="badge-icon">🔔</span>
      <span className="badge-count">{count > 99 ? '99+' : count}</span>
    </div>
  );
};

interface ProgressBarProps {
  progress: number;
}

const ProgressBar: React.FC<ProgressBarProps> = ({ progress }) => {
  return (
    <div className="progress-bar">
      <div className="progress-fill" style={{ width: `${progress}%` }} />
    </div>
  );
};

interface ServiceStatusBarProps {
  services: Array<{ id: string; name: string; status: string }>;
}

const ServiceStatusBar: React.FC<ServiceStatusBarProps> = ({ services }) => {
  return (
    <div className="service-status-bar">
      {services.map(service => (
        <div key={service.id} className={`service-status status-${service.status}`}>
          <span className="service-dot" />
          <span className="service-name">{service.name}</span>
        </div>
      ))}
    </div>
  );
};

// ============================================================
// HELPERS
// ============================================================

function formatReason(reason: string): string {
  const reasonLabels: Record<string, string> = {
    next_episode: 'Continue watching',
    new_episode: 'New episode',
    trending: 'Trending',
    time_pattern: 'Based on your habits',
    genre_preference: 'Your favorite genre',
    recommendation: 'Recommended',
    calendar: 'From your calendar',
    recently_added_plex: 'New in Plex',
  };
  return reasonLabels[reason] || reason;
}

function formatTimeAgo(date: Date): string {
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffMins = Math.floor(diffMs / 60000);

  if (diffMins < 1) return 'now';
  if (diffMins < 60) return `${diffMins}m`;
  if (diffMins < 1440) return `${Math.floor(diffMins / 60)}h`;
  return `${Math.floor(diffMins / 1440)}d`;
}

export default TheaDashboard;
