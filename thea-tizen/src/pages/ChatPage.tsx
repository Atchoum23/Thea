/**
 * Chat Page
 * Main AI conversation interface
 */

import { useRef, useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { FocusContext, useFocusable } from '@noriginmedia/norigin-spatial-navigation';
import { useChatStore } from '../stores/chatStore';
import { MessageBubble, EmptyConversation, TypingIndicator } from '../components/chat/MessageBubble';
import { FocusableButton, FocusableCard, FocusableList } from '../components/ui/FocusableCard';
import { ColorButtonHints, CommonHints } from '../components/ui/ColorButtonHints';
import { useTVRemote } from '../hooks/useTVRemote';

export function ChatPage() {
  const { conversationId } = useParams();
  const { ref, focusKey } = useFocusable({
    focusable: false,
    saveLastFocusedChild: true,
  });

  const {
    conversations,
    messages,
    isStreaming,
    streamingText,
    error,
    createConversation,
    setActiveConversation,
    sendMessage,
    cancelStreaming,
    clearError,
  } = useChatStore();

  const [inputText, setInputText] = useState('');
  const [showSuggestions, setShowSuggestions] = useState(true);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  // Get current conversation
  const currentConversation = conversationId
    ? conversations.find((c) => c.id === conversationId)
    : conversations[0];

  const currentMessages = currentConversation
    ? messages[currentConversation.id] || []
    : [];

  // Set active conversation
  useEffect(() => {
    if (currentConversation) {
      setActiveConversation(currentConversation.id);
    }
  }, [currentConversation, setActiveConversation]);

  // Auto-scroll to bottom
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [currentMessages, streamingText]);

  // Handle color buttons
  useTVRemote({
    onRed: () => {
      if (isStreaming) {
        cancelStreaming();
      } else if (inputText) {
        setInputText('');
      }
    },
    onGreen: () => {
      handleSend();
    },
    onBlue: () => {
      // Trigger voice input
      handleVoiceInput();
    },
  });

  const handleSend = async () => {
    if (!inputText.trim() || isStreaming) return;

    const text = inputText;
    setInputText('');
    setShowSuggestions(false);

    // Create conversation if needed
    let convId = currentConversation?.id;
    if (!convId) {
      const newConv = createConversation();
      convId = newConv.id;
    }

    await sendMessage(convId, text);
  };

  const handleVoiceInput = () => {
    // Voice input using Web Speech API
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const SpeechRecognitionAPI = (window as any).webkitSpeechRecognition || (window as any).SpeechRecognition;

    if (SpeechRecognitionAPI) {
      const recognition = new SpeechRecognitionAPI();
      recognition.lang = 'en-US';
      recognition.continuous = false;
      recognition.interimResults = false;

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      recognition.onresult = (event: any) => {
        const transcript = event.results[0][0].transcript;
        setInputText(transcript);
      };

      recognition.start();
    }
  };

  const handleSuggestion = (text: string) => {
    setInputText(text);
    setShowSuggestions(false);
  };

  return (
    <FocusContext.Provider value={focusKey}>
      <div ref={ref} className="flex flex-col h-full bg-gray-950">
        {/* Messages area */}
        <div className="flex-1 overflow-y-auto px-8 py-6">
          {currentMessages.length === 0 && !isStreaming ? (
            <EmptyConversation />
          ) : (
            <div className="max-w-4xl mx-auto space-y-6">
              {currentMessages.map((message, index) => (
                <MessageBubble
                  key={message.id}
                  message={message}
                  isStreaming={
                    isStreaming &&
                    index === currentMessages.length - 1 &&
                    message.role === 'assistant'
                  }
                  streamingText={streamingText}
                />
              ))}
              {isStreaming && currentMessages[currentMessages.length - 1]?.role === 'user' && (
                <MessageBubble
                  message={{
                    id: 'streaming',
                    conversationId: currentConversation?.id || '',
                    role: 'assistant',
                    content: streamingText,
                    timestamp: Date.now(),
                    orderIndex: currentMessages.length,
                  }}
                  isStreaming={true}
                  streamingText={streamingText}
                />
              )}
              <div ref={messagesEndRef} />
            </div>
          )}
        </div>

        {/* Error display */}
        {error && (
          <div className="mx-8 mb-4 bg-red-900/50 border border-red-500 text-red-200 px-6 py-3 rounded-lg flex justify-between items-center">
            <span>{error}</span>
            <FocusableButton onClick={clearError} variant="ghost" size="sm">
              Dismiss
            </FocusableButton>
          </div>
        )}

        {/* Suggestions */}
        {showSuggestions && currentMessages.length === 0 && (
          <div className="px-8 pb-4">
            <SuggestionCards onSelect={handleSuggestion} />
          </div>
        )}

        {/* Input area */}
        <div className="border-t border-gray-800 p-6">
          <div className="max-w-4xl mx-auto">
            <ChatInput
              value={inputText}
              onChange={setInputText}
              onSubmit={handleSend}
              isStreaming={isStreaming}
            />
          </div>
        </div>

        {/* Color button hints */}
        <ColorButtonHints hints={CommonHints.chat} />
      </div>
    </FocusContext.Provider>
  );
}

interface ChatInputProps {
  value: string;
  onChange: (value: string) => void;
  onSubmit: () => void;
  isStreaming: boolean;
}

function ChatInput({ value, onChange, onSubmit, isStreaming }: ChatInputProps) {
  const { ref, focused } = useFocusable({
    onEnterPress: onSubmit,
  });

  return (
    <div
      ref={ref}
      className={`
        flex items-center gap-4 bg-gray-800 rounded-xl px-6 py-4
        transition-all duration-200
        ${focused ? 'ring-2 ring-blue-500' : ''}
      `}
    >
      <input
        type="text"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        onKeyDown={(e) => e.key === 'Enter' && onSubmit()}
        placeholder={isStreaming ? 'THEA is thinking...' : 'Type your message...'}
        disabled={isStreaming}
        className="flex-1 bg-transparent text-xl text-white placeholder-gray-500 outline-none"
      />
      <FocusableButton
        onClick={onSubmit}
        disabled={!value.trim() || isStreaming}
        variant={isStreaming ? 'secondary' : 'primary'}
      >
        {isStreaming ? 'Stop' : 'Send'}
      </FocusableButton>
    </div>
  );
}

interface SuggestionCardsProps {
  onSelect: (text: string) => void;
}

function SuggestionCards({ onSelect }: SuggestionCardsProps) {
  const suggestions = [
    { icon: '💡', text: 'What can you help me with?' },
    { icon: '📺', text: "What's a good movie to watch tonight?" },
    { icon: '🍳', text: 'Give me a quick dinner recipe' },
    { icon: '📝', text: 'Help me write an email' },
  ];

  return (
    <FocusableList direction="horizontal" className="gap-4">
      {suggestions.map((suggestion, index) => (
        <FocusableCard
          key={index}
          className="bg-gray-800/50 border border-gray-700 w-64 flex-shrink-0"
          onEnterPress={() => onSelect(suggestion.text)}
        >
          <div className="text-2xl mb-2">{suggestion.icon}</div>
          <div className="text-base text-gray-300">{suggestion.text}</div>
        </FocusableCard>
      ))}
    </FocusableList>
  );
}
