/**
 * Home Page
 * Landing page with quick actions and status
 */

import { useNavigate } from 'react-router-dom';
import { FocusContext, useFocusable } from '@noriginmedia/norigin-spatial-navigation';
import { FocusableCard, FocusableList } from '../components/ui/FocusableCard';
import { useChatStore } from '../stores/chatStore';
import { useTraktStore } from '../stores/traktStore';
import { ProviderRegistry } from '../services/ai/ProviderRegistry';

export function HomePage() {
  const navigate = useNavigate();
  const { ref, focusKey } = useFocusable({
    focusable: false,
    saveLastFocusedChild: true,
  });

  const conversations = useChatStore((s) => s.conversations);
  const traktUser = useTraktStore((s) => s.user);
  const activeCheckIn = useTraktStore((s) => s.activeCheckIn);

  const recentConversations = conversations.slice(0, 3);
  const hasProviders = ProviderRegistry.configuredProviders.length > 0;

  return (
    <FocusContext.Provider value={focusKey}>
      <div ref={ref} className="h-full p-8 overflow-y-auto">
        {/* Header */}
        <div className="mb-12">
          <h1 className="text-5xl font-bold mb-2">
            <span className="text-purple-500">T</span>
            <span className="text-blue-500">H</span>
            <span className="text-cyan-500">E</span>
            <span className="text-green-500">A</span>
          </h1>
          <p className="text-2xl text-gray-400">Your AI Assistant for Samsung TV</p>
        </div>

        {/* Status bar */}
        <div className="flex gap-6 mb-12">
          <StatusCard
            label="AI Provider"
            value={hasProviders ? ProviderRegistry.bestAvailableProvider?.name || 'Ready' : 'Not configured'}
            status={hasProviders ? 'success' : 'warning'}
          />
          <StatusCard
            label="Trakt"
            value={traktUser ? `@${traktUser.username}` : 'Not connected'}
            status={traktUser ? 'success' : 'neutral'}
          />
          {activeCheckIn && (
            <StatusCard
              label="Watching"
              value={activeCheckIn.movie?.title || activeCheckIn.show?.title || 'Something'}
              status="active"
            />
          )}
        </div>

        {/* Quick actions */}
        <section className="mb-12">
          <h2 className="text-2xl font-semibold text-white mb-6">Quick Actions</h2>
          <FocusableList direction="horizontal" className="gap-6">
            <QuickActionCard
              icon="💬"
              title="New Chat"
              description="Start a conversation with THEA"
              onClick={() => navigate('/chat')}
            />
            <QuickActionCard
              icon="📺"
              title="Check In"
              description="Log what you're watching"
              onClick={() => navigate('/trakt')}
            />
            <QuickActionCard
              icon="🎤"
              title="Voice Command"
              description="Press BLUE button to speak"
              onClick={() => {/* trigger voice */}}
            />
            <QuickActionCard
              icon="⚙️"
              title="Settings"
              description="Configure API keys & preferences"
              onClick={() => navigate('/settings')}
            />
          </FocusableList>
        </section>

        {/* Recent conversations */}
        {recentConversations.length > 0 && (
          <section className="mb-12">
            <h2 className="text-2xl font-semibold text-white mb-6">Recent Conversations</h2>
            <FocusableList direction="horizontal" className="gap-4">
              {recentConversations.map((conv) => (
                <FocusableCard
                  key={conv.id}
                  className="bg-gray-800 w-80"
                  onEnterPress={() => navigate(`/chat/${conv.id}`)}
                >
                  <div className="text-lg font-medium text-white truncate">
                    {conv.title}
                  </div>
                  <div className="text-sm text-gray-400 mt-1">
                    {new Date(conv.updatedAt).toLocaleDateString()}
                  </div>
                </FocusableCard>
              ))}
            </FocusableList>
          </section>
        )}

        {/* Setup prompts */}
        {!hasProviders && (
          <section className="bg-yellow-900/20 border border-yellow-600 rounded-xl p-6">
            <h3 className="text-xl font-semibold text-yellow-400 mb-2">
              Setup Required
            </h3>
            <p className="text-gray-300 mb-4">
              Configure an AI provider to start chatting with THEA.
            </p>
            <FocusableCard
              className="bg-yellow-600 text-white inline-block"
              onEnterPress={() => navigate('/settings')}
              tvPadding={false}
            >
              <span className="px-4 py-2 block">Go to Settings</span>
            </FocusableCard>
          </section>
        )}
      </div>
    </FocusContext.Provider>
  );
}

interface StatusCardProps {
  label: string;
  value: string;
  status: 'success' | 'warning' | 'neutral' | 'active';
}

function StatusCard({ label, value, status }: StatusCardProps) {
  const statusColors = {
    success: 'border-green-500 bg-green-900/20',
    warning: 'border-yellow-500 bg-yellow-900/20',
    neutral: 'border-gray-600 bg-gray-800/50',
    active: 'border-purple-500 bg-purple-900/20',
  };

  const dotColors = {
    success: 'bg-green-500',
    warning: 'bg-yellow-500',
    neutral: 'bg-gray-500',
    active: 'bg-purple-500 animate-pulse',
  };

  return (
    <div className={`px-6 py-4 rounded-xl border ${statusColors[status]}`}>
      <div className="flex items-center gap-2 mb-1">
        <div className={`w-2 h-2 rounded-full ${dotColors[status]}`} />
        <span className="text-sm text-gray-400">{label}</span>
      </div>
      <div className="text-lg font-medium text-white">{value}</div>
    </div>
  );
}

interface QuickActionCardProps {
  icon: string;
  title: string;
  description: string;
  onClick: () => void;
}

function QuickActionCard({ icon, title, description, onClick }: QuickActionCardProps) {
  return (
    <FocusableCard
      className="bg-gray-800 w-64"
      onEnterPress={onClick}
    >
      <div className="text-4xl mb-3">{icon}</div>
      <div className="text-xl font-semibold text-white">{title}</div>
      <div className="text-base text-gray-400 mt-1">{description}</div>
    </FocusableCard>
  );
}
