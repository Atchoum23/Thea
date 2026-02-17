/**
 * Voice Torrent Search Component
 *
 * Provides voice-controlled torrent search with AI-powered query optimization.
 * Features:
 * - Voice input with visual feedback
 * - AI query optimization display
 * - Quality preference quick toggles
 * - Learning feedback on selection
 */

import { useState, useEffect, useCallback, useRef } from 'react';
import { FocusContext, useFocusable, setFocus } from '@noriginmedia/norigin-spatial-navigation';
import { FocusableList } from '../ui/FocusableCard';
import { useTVRemote } from '../../hooks/useTVRemote';
import {
  aiTorrentSearchService,
  VoiceSearchResult,
  UserPreferences,
} from '../../services/search/AITorrentSearchService';
import { TorrentSearchResult } from '../../services/hub/SmartHubService';

// Speech Recognition types
type SpeechRecognitionType = {
  continuous: boolean;
  interimResults: boolean;
  lang: string;
  start(): void;
  stop(): void;
  abort(): void;
  onresult: (event: SpeechRecognitionEvent) => void;
  onerror: (event: SpeechRecognitionErrorEvent) => void;
  onend: () => void;
  onstart: () => void;
};

type SpeechRecognitionEvent = {
  results: {
    [index: number]: {
      [index: number]: { transcript: string; confidence: number };
      isFinal: boolean;
    };
    length: number;
  };
};

type SpeechRecognitionErrorEvent = { error: string };

interface VoiceTorrentSearchProps {
  onDownload: (torrent: TorrentSearchResult) => Promise<void>;
  onClose?: () => void;
  initialQuery?: string;
}

export function VoiceTorrentSearch({ onDownload, onClose, initialQuery }: VoiceTorrentSearchProps) {
  const { ref, focusKey } = useFocusable({
    focusable: false,
    isFocusBoundary: true,
  });

  const [isListening, setIsListening] = useState(false);
  const [interimTranscript, setInterimTranscript] = useState('');
  const [searchResult, setSearchResult] = useState<VoiceSearchResult | null>(null);
  const [isSearching, setIsSearching] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showPreferences, setShowPreferences] = useState(false);
  const [preferences, setPreferences] = useState<UserPreferences>(aiTorrentSearchService.getPreferences());

  const recognitionRef = useRef<SpeechRecognitionType | null>(null);

  // Initialize speech recognition
  useEffect(() => {
    const SpeechRecognitionAPI =
      (window as any).webkitSpeechRecognition || (window as any).SpeechRecognition;

    if (SpeechRecognitionAPI) {
      const recognition = new SpeechRecognitionAPI() as SpeechRecognitionType;
      recognition.continuous = false;
      recognition.interimResults = true;
      recognition.lang = 'en-US';

      recognition.onstart = () => {
        setIsListening(true);
        setError(null);
      };

      recognition.onresult = (event: SpeechRecognitionEvent) => {
        let interim = '';
        let final = '';

        for (let i = 0; i < event.results.length; i++) {
          const result = event.results[i];
          if (result.isFinal) {
            final += result[0].transcript;
          } else {
            interim += result[0].transcript;
          }
        }

        setInterimTranscript(interim);

        if (final) {
          handleVoiceResult(final);
        }
      };

      recognition.onerror = (event: SpeechRecognitionErrorEvent) => {
        console.error('Speech recognition error:', event.error);
        setIsListening(false);
        setError(`Voice input error: ${event.error}`);
      };

      recognition.onend = () => {
        setIsListening(false);
      };

      recognitionRef.current = recognition;
    }

    // Load saved preferences
    aiTorrentSearchService.loadPreferences();
    setPreferences(aiTorrentSearchService.getPreferences());

    // Load search history for learning
    aiTorrentSearchService.loadSearchHistory();

    // Process initial query if provided
    if (initialQuery) {
      handleSearch(initialQuery);
    }

    return () => {
      recognitionRef.current?.abort();
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [initialQuery]);

  // Start/stop voice input
  const toggleVoiceInput = useCallback(() => {
    if (!recognitionRef.current) {
      setError('Voice input not supported on this device');
      return;
    }

    if (isListening) {
      recognitionRef.current.stop();
    } else {
      setInterimTranscript('');
      recognitionRef.current.start();
    }
  }, [isListening]);

  // Handle voice result
  const handleVoiceResult = async (transcript: string) => {
    setIsListening(false);
    setInterimTranscript('');
    await handleSearch(transcript);
  };

  // Perform AI-powered search
  const handleSearch = async (query: string) => {
    setIsSearching(true);
    setError(null);

    try {
      const result = await aiTorrentSearchService.searchFromVoice(query);
      setSearchResult(result);

      if (result.torrents.length === 0) {
        setError('No torrents found. Try a different search.');
      }
    } catch (err) {
      console.error('Search failed:', err);
      setError('Search failed. Please try again.');
    }

    setIsSearching(false);
  };

  // Handle torrent selection
  const handleTorrentSelect = async (torrent: TorrentSearchResult) => {
    // Record selection for learning
    aiTorrentSearchService.recordTorrentSelection(torrent);

    // Trigger download
    await onDownload(torrent);
  };

  // Update preferences
  const handlePreferenceChange = (key: keyof UserPreferences, value: any) => {
    const updated = { ...preferences, [key]: value };
    setPreferences(updated);
    aiTorrentSearchService.updatePreferences({ [key]: value });
  };

  // Color button handlers
  useTVRemote({
    onBlue: toggleVoiceInput,
    onRed: () => {
      if (showPreferences) {
        setShowPreferences(false);
      } else if (onClose) {
        onClose();
      }
    },
    onYellow: () => setShowPreferences(!showPreferences),
  });

  useEffect(() => {
    setFocus('voice-search-main');
  }, []);

  return (
    <FocusContext.Provider value={focusKey}>
      <div ref={ref} className="flex flex-col h-full bg-gray-950 p-8">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-white mb-2">Voice Torrent Search</h1>
          <p className="text-gray-400 text-lg">
            Press the Blue button or click the microphone to speak
          </p>
        </div>

        {/* Voice Input Area */}
        <VoiceInputArea
          isListening={isListening}
          interimTranscript={interimTranscript}
          onToggle={toggleVoiceInput}
        />

        {/* Search Info */}
        {searchResult && (
          <SearchInfoBar
            result={searchResult}
            onAlternativeSelect={handleSearch}
          />
        )}

        {/* Error Display */}
        {error && (
          <div className="bg-red-900/50 border border-red-500 text-red-200 px-6 py-3 rounded-lg mb-4">
            {error}
          </div>
        )}

        {/* Results or Preferences */}
        <div className="flex-1 overflow-y-auto">
          {showPreferences ? (
            <PreferencesPanel
              preferences={preferences}
              onChange={handlePreferenceChange}
            />
          ) : isSearching ? (
            <SearchingState />
          ) : searchResult?.torrents.length ? (
            <TorrentResultsList
              torrents={searchResult.torrents}
              onSelect={handleTorrentSelect}
            />
          ) : (
            <EmptyState />
          )}
        </div>

        {/* Quick Preference Toggles */}
        {!showPreferences && (
          <QuickPreferenceBar
            preferences={preferences}
            onChange={handlePreferenceChange}
          />
        )}
      </div>
    </FocusContext.Provider>
  );
}

// Voice Input Area Component
interface VoiceInputAreaProps {
  isListening: boolean;
  interimTranscript: string;
  onToggle: () => void;
}

function VoiceInputArea({ isListening, interimTranscript, onToggle }: VoiceInputAreaProps) {
  const { ref, focused } = useFocusable({
    focusKey: 'voice-search-main',
    onEnterPress: onToggle,
  });

  return (
    <div
      ref={ref}
      onClick={onToggle}
      className={`
        relative flex items-center justify-center p-8 mb-6
        bg-gray-800 rounded-2xl cursor-pointer
        transition-all duration-300
        ${isListening ? 'bg-blue-900/50 ring-4 ring-blue-500' : ''}
        ${focused ? 'ring-2 ring-white scale-[1.02]' : ''}
      `}
    >
      {/* Microphone Icon */}
      <div className={`
        w-20 h-20 rounded-full flex items-center justify-center
        transition-all duration-300
        ${isListening ? 'bg-red-600 animate-pulse' : 'bg-blue-600'}
      `}>
        <span className="text-4xl">{isListening ? '🎙️' : '🎤'}</span>
      </div>

      {/* Listening indicator */}
      {isListening && (
        <div className="absolute inset-0 flex items-center justify-center">
          <div className="flex gap-1">
            {[...Array(5)].map((_, i) => (
              <div
                key={i}
                className="w-2 bg-blue-500 rounded-full animate-pulse"
                style={{
                  height: `${20 + Math.random() * 30}px`,
                  animationDelay: `${i * 0.1}s`,
                }}
              />
            ))}
          </div>
        </div>
      )}

      {/* Interim transcript */}
      {interimTranscript && (
        <div className="absolute bottom-4 left-0 right-0 text-center">
          <span className="text-xl text-blue-300 italic">"{interimTranscript}"</span>
        </div>
      )}

      {/* Hint text */}
      {!isListening && !interimTranscript && (
        <div className="ml-6 text-center">
          <p className="text-xl text-gray-300">Click or press Blue button to speak</p>
          <p className="text-lg text-gray-500 mt-1">
            Try: "The Bear season 3" or "download Dune 2 in 4K"
          </p>
        </div>
      )}
    </div>
  );
}

// Search Info Bar
interface SearchInfoBarProps {
  result: VoiceSearchResult;
  onAlternativeSelect: (query: string) => void;
}

function SearchInfoBar({ result, onAlternativeSelect }: SearchInfoBarProps) {
  return (
    <div className="bg-gray-800/50 rounded-xl p-4 mb-4">
      <div className="flex items-center justify-between flex-wrap gap-4">
        <div>
          <span className="text-gray-400 text-sm">Original: </span>
          <span className="text-white">"{result.originalQuery}"</span>
        </div>
        <div>
          <span className="text-gray-400 text-sm">AI Optimized: </span>
          <span className="text-blue-400 font-mono">{result.optimizedQuery}</span>
        </div>
        <div>
          <span className={`
            px-2 py-1 rounded text-sm
            ${result.confidence > 0.8 ? 'bg-green-600' : result.confidence > 0.5 ? 'bg-yellow-600' : 'bg-red-600'}
          `}>
            {Math.round(result.confidence * 100)}% confident
          </span>
        </div>
      </div>

      {/* Parsed info */}
      {result.parsed.title && (
        <div className="flex flex-wrap gap-2 mt-3">
          {result.parsed.title && (
            <span className="bg-gray-700 px-2 py-1 rounded text-sm text-gray-300">
              {result.parsed.title}
            </span>
          )}
          {result.parsed.season && (
            <span className="bg-purple-700 px-2 py-1 rounded text-sm">
              Season {result.parsed.season}
            </span>
          )}
          {result.parsed.episode && (
            <span className="bg-purple-700 px-2 py-1 rounded text-sm">
              Episode {result.parsed.episode}
            </span>
          )}
          {result.parsed.year && (
            <span className="bg-gray-700 px-2 py-1 rounded text-sm">
              {result.parsed.year}
            </span>
          )}
          {result.parsed.quality && (
            <span className="bg-blue-700 px-2 py-1 rounded text-sm">
              {result.parsed.quality}
            </span>
          )}
        </div>
      )}

      {/* Alternative queries */}
      {result.alternativeQueries.length > 0 && (
        <div className="mt-3 pt-3 border-t border-gray-700">
          <span className="text-sm text-gray-400">Try also: </span>
          <div className="flex flex-wrap gap-2 mt-1">
            {result.alternativeQueries.slice(0, 3).map((alt, i) => (
              <button
                key={i}
                onClick={() => onAlternativeSelect(alt)}
                className="text-sm text-blue-400 hover:text-blue-300 underline"
              >
                {alt}
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

// Torrent Results List
interface TorrentResultsListProps {
  torrents: TorrentSearchResult[];
  onSelect: (torrent: TorrentSearchResult) => void;
}

function TorrentResultsList({ torrents, onSelect }: TorrentResultsListProps) {
  return (
    <FocusableList direction="vertical" className="gap-3">
      {torrents.map((torrent, index) => (
        <TorrentResultItem
          key={torrent.id || index}
          torrent={torrent}
          rank={index + 1}
          onSelect={() => onSelect(torrent)}
        />
      ))}
    </FocusableList>
  );
}

// Torrent Result Item
interface TorrentResultItemProps {
  torrent: TorrentSearchResult;
  rank: number;
  onSelect: () => void;
}

function TorrentResultItem({ torrent, rank, onSelect }: TorrentResultItemProps) {
  const { ref, focused } = useFocusable({
    onEnterPress: onSelect,
  });

  // Extract quality/codec badges from title
  const badges = extractBadges(torrent.title);

  return (
    <div
      ref={ref}
      onClick={onSelect}
      className={`
        bg-gray-800 rounded-xl p-4 cursor-pointer
        transition-all duration-200
        ${focused ? 'ring-2 ring-blue-500 scale-[1.01] bg-gray-700' : ''}
      `}
    >
      <div className="flex items-start gap-4">
        {/* Rank */}
        <div className={`
          w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold
          ${rank <= 3 ? 'bg-blue-600' : 'bg-gray-700'}
        `}>
          {rank}
        </div>

        {/* Content */}
        <div className="flex-1 min-w-0">
          <h4 className="text-lg text-white truncate">{torrent.title}</h4>

          {/* Badges */}
          <div className="flex flex-wrap gap-2 mt-2">
            {badges.map((badge, i) => (
              <span
                key={i}
                className={`px-2 py-0.5 rounded text-xs font-medium ${badge.color}`}
              >
                {badge.label}
              </span>
            ))}
          </div>

          <p className="text-sm text-gray-400 mt-2">
            {torrent.indexer} • {torrent.sizeFormatted}
          </p>
        </div>

        {/* Stats */}
        <div className="flex items-center gap-6">
          <div className="text-center">
            <div className="text-green-500 font-bold text-xl">{torrent.seeders}</div>
            <div className="text-xs text-gray-500">Seeds</div>
          </div>
          <div className="text-center">
            <div className="text-red-500 font-bold text-xl">{torrent.leechers}</div>
            <div className="text-xs text-gray-500">Leech</div>
          </div>
        </div>
      </div>
    </div>
  );
}

// Extract quality badges from title
function extractBadges(title: string): Array<{ label: string; color: string }> {
  const badges: Array<{ label: string; color: string }> = [];
  const titleLower = title.toLowerCase();

  // Quality
  if (titleLower.includes('2160p') || titleLower.includes('4k')) {
    badges.push({ label: '4K', color: 'bg-purple-600 text-white' });
  } else if (titleLower.includes('1080p')) {
    badges.push({ label: '1080p', color: 'bg-blue-600 text-white' });
  } else if (titleLower.includes('720p')) {
    badges.push({ label: '720p', color: 'bg-gray-600 text-white' });
  }

  // HDR
  if (titleLower.includes('hdr') || titleLower.includes('dolby vision') || titleLower.includes('dovi')) {
    badges.push({ label: 'HDR', color: 'bg-yellow-600 text-black' });
  }

  // Codec
  if (titleLower.includes('x265') || titleLower.includes('hevc')) {
    badges.push({ label: 'x265', color: 'bg-green-700 text-white' });
  } else if (titleLower.includes('x264')) {
    badges.push({ label: 'x264', color: 'bg-gray-700 text-white' });
  }

  // Audio
  if (titleLower.includes('atmos')) {
    badges.push({ label: 'Atmos', color: 'bg-red-700 text-white' });
  } else if (titleLower.includes('truehd')) {
    badges.push({ label: 'TrueHD', color: 'bg-orange-700 text-white' });
  } else if (titleLower.includes('dts')) {
    badges.push({ label: 'DTS', color: 'bg-orange-800 text-white' });
  }

  return badges;
}

// Quick Preference Bar
interface QuickPreferenceBarProps {
  preferences: UserPreferences;
  onChange: (key: keyof UserPreferences, value: any) => void;
}

function QuickPreferenceBar({ preferences, onChange }: QuickPreferenceBarProps) {
  return (
    <div className="flex items-center gap-4 py-4 border-t border-gray-800">
      <span className="text-gray-400 text-sm">Quick filters:</span>

      {/* Quality toggle */}
      <QualityToggle
        value={preferences.preferredQuality}
        onChange={(v) => onChange('preferredQuality', v)}
      />

      {/* HDR toggle */}
      <ToggleButton
        label="HDR"
        active={preferences.preferHDR}
        onToggle={() => onChange('preferHDR', !preferences.preferHDR)}
      />

      {/* Atmos toggle */}
      <ToggleButton
        label="Atmos"
        active={preferences.preferDolbyAtmos}
        onToggle={() => onChange('preferDolbyAtmos', !preferences.preferDolbyAtmos)}
      />
    </div>
  );
}

// Quality Toggle
interface QualityToggleProps {
  value: '4K' | '1080p' | '720p' | 'any';
  onChange: (value: '4K' | '1080p' | '720p' | 'any') => void;
}

function QualityToggle({ value, onChange }: QualityToggleProps) {
  const options: Array<'4K' | '1080p' | '720p' | 'any'> = ['4K', '1080p', '720p', 'any'];

  return (
    <div className="flex rounded-lg overflow-hidden bg-gray-800">
      {options.map((opt) => (
        <button
          key={opt}
          onClick={() => onChange(opt)}
          className={`
            px-3 py-1 text-sm transition-colors
            ${value === opt ? 'bg-blue-600 text-white' : 'text-gray-400 hover:text-white'}
          `}
        >
          {opt}
        </button>
      ))}
    </div>
  );
}

// Toggle Button
interface ToggleButtonProps {
  label: string;
  active: boolean;
  onToggle: () => void;
}

function ToggleButton({ label, active, onToggle }: ToggleButtonProps) {
  const { ref, focused } = useFocusable({
    onEnterPress: onToggle,
  });

  return (
    <button
      ref={ref}
      onClick={onToggle}
      className={`
        px-3 py-1 rounded-lg text-sm transition-all
        ${active ? 'bg-blue-600 text-white' : 'bg-gray-800 text-gray-400'}
        ${focused ? 'ring-2 ring-white' : ''}
      `}
    >
      {label}
    </button>
  );
}

// Preferences Panel
interface PreferencesPanelProps {
  preferences: UserPreferences;
  onChange: (key: keyof UserPreferences, value: any) => void;
}

function PreferencesPanel({ preferences, onChange }: PreferencesPanelProps) {
  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold text-white">Search Preferences</h2>
      <p className="text-gray-400">
        These preferences are learned from your selections but can be adjusted manually.
      </p>

      {/* Quality */}
      <div className="bg-gray-800 rounded-xl p-4">
        <h3 className="text-lg font-medium text-white mb-3">Preferred Quality</h3>
        <QualityToggle
          value={preferences.preferredQuality}
          onChange={(v) => onChange('preferredQuality', v)}
        />
      </div>

      {/* Codec */}
      <div className="bg-gray-800 rounded-xl p-4">
        <h3 className="text-lg font-medium text-white mb-3">Preferred Codec</h3>
        <div className="flex gap-2">
          {(['x265', 'x264', 'any'] as const).map((codec) => (
            <button
              key={codec}
              onClick={() => onChange('preferredCodec', codec)}
              className={`
                px-4 py-2 rounded-lg transition-colors
                ${preferences.preferredCodec === codec
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-700 text-gray-300'}
              `}
            >
              {codec}
            </button>
          ))}
        </div>
      </div>

      {/* Release Groups */}
      <div className="bg-gray-800 rounded-xl p-4">
        <h3 className="text-lg font-medium text-white mb-3">Preferred Release Groups</h3>
        <div className="flex flex-wrap gap-2">
          {preferences.preferredReleaseGroups.map((group, i) => (
            <span key={i} className="bg-green-700 px-3 py-1 rounded-lg text-sm">
              {group}
            </span>
          ))}
        </div>
        <p className="text-sm text-gray-500 mt-2">
          Learned from your selections. Top groups are prioritized in results.
        </p>
      </div>

      {/* Audio/Video Preferences */}
      <div className="bg-gray-800 rounded-xl p-4">
        <h3 className="text-lg font-medium text-white mb-3">Audio/Video Preferences</h3>
        <div className="flex gap-4">
          <ToggleButton
            label="Prefer HDR"
            active={preferences.preferHDR}
            onToggle={() => onChange('preferHDR', !preferences.preferHDR)}
          />
          <ToggleButton
            label="Prefer Dolby Atmos"
            active={preferences.preferDolbyAtmos}
            onToggle={() => onChange('preferDolbyAtmos', !preferences.preferDolbyAtmos)}
          />
        </div>
      </div>
    </div>
  );
}

// Searching State
function SearchingState() {
  return (
    <div className="flex flex-col items-center justify-center h-64">
      <div className="animate-spin rounded-full h-12 w-12 border-4 border-blue-500 border-t-transparent mb-4" />
      <p className="text-gray-400 text-xl">AI is optimizing your search...</p>
      <p className="text-gray-500 text-lg mt-2">Finding the best torrents</p>
    </div>
  );
}

// Empty State
function EmptyState() {
  return (
    <div className="flex flex-col items-center justify-center h-64 text-gray-500">
      <span className="text-6xl mb-4">🎬</span>
      <p className="text-xl">Ready to search</p>
      <p className="text-lg mt-2 text-center max-w-md">
        Say something like "The Bear season 3 episode 1" or "Dune Part Two in 4K"
      </p>
    </div>
  );
}
