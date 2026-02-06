/**
 * Chat State Store
 * Manages conversations, messages, and streaming state
 */

import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { Conversation, Message, ChatMessage } from '../types/chat';
import { ProviderRegistry } from '../services/ai/ProviderRegistry';
import { STORAGE_KEYS, STREAM_CONFIG } from '../config/constants';

interface ChatState {
  // Conversations
  conversations: Conversation[];
  activeConversationId: string | null;

  // Messages (indexed by conversation ID)
  messages: Record<string, Message[]>;

  // Streaming state
  isStreaming: boolean;
  streamingText: string;
  streamingConversationId: string | null;

  // Error state
  error: string | null;

  // Actions
  createConversation: (title?: string) => Conversation;
  deleteConversation: (id: string) => void;
  setActiveConversation: (id: string | null) => void;
  updateConversationTitle: (id: string, title: string) => void;
  togglePin: (id: string) => void;

  // Message actions
  addMessage: (conversationId: string, message: Omit<Message, 'id' | 'orderIndex'>) => Message;
  sendMessage: (conversationId: string, content: string, model?: string) => Promise<void>;
  cancelStreaming: () => void;
  clearError: () => void;

  // Getters
  getConversation: (id: string) => Conversation | undefined;
  getMessages: (conversationId: string) => Message[];
  getActiveConversation: () => Conversation | undefined;
}

function generateId(): string {
  return crypto.randomUUID();
}

export const useChatStore = create<ChatState>()(
  persist(
    (set, get) => ({
      conversations: [],
      activeConversationId: null,
      messages: {},
      isStreaming: false,
      streamingText: '',
      streamingConversationId: null,
      error: null,

      createConversation: (title = 'New Conversation') => {
        const id = generateId();
        const now = Date.now();
        const conversation: Conversation = {
          id,
          title,
          createdAt: now,
          updatedAt: now,
          isPinned: false,
        };

        set(state => ({
          conversations: [conversation, ...state.conversations],
          activeConversationId: id,
          messages: { ...state.messages, [id]: [] },
        }));

        return conversation;
      },

      deleteConversation: (id: string) => {
        set(state => {
          const { [id]: _, ...remainingMessages } = state.messages;
          const conversations = state.conversations.filter(c => c.id !== id);
          const activeId = state.activeConversationId === id
            ? conversations[0]?.id || null
            : state.activeConversationId;

          return {
            conversations,
            messages: remainingMessages,
            activeConversationId: activeId,
          };
        });
      },

      setActiveConversation: (id: string | null) => {
        set({ activeConversationId: id });
      },

      updateConversationTitle: (id: string, title: string) => {
        set(state => ({
          conversations: state.conversations.map(c =>
            c.id === id ? { ...c, title, updatedAt: Date.now() } : c
          ),
        }));
      },

      togglePin: (id: string) => {
        set(state => ({
          conversations: state.conversations.map(c =>
            c.id === id ? { ...c, isPinned: !c.isPinned } : c
          ),
        }));
      },

      addMessage: (conversationId: string, messageData) => {
        const state = get();
        const existingMessages = state.messages[conversationId] || [];
        const orderIndex = existingMessages.length;

        const message: Message = {
          ...messageData,
          id: generateId(),
          orderIndex,
        };

        set(state => ({
          messages: {
            ...state.messages,
            [conversationId]: [...(state.messages[conversationId] || []), message],
          },
          conversations: state.conversations.map(c =>
            c.id === conversationId ? { ...c, updatedAt: Date.now() } : c
          ),
        }));

        return message;
      },

      sendMessage: async (conversationId: string, content: string, modelId?: string) => {
        const state = get();

        // Create or get conversation
        let conversation = state.conversations.find(c => c.id === conversationId);
        if (!conversation) {
          conversation = get().createConversation('New Chat');
          conversationId = conversation.id;
        }

        // Add user message
        get().addMessage(conversationId, {
          conversationId,
          role: 'user',
          content,
          timestamp: Date.now(),
        });

        // Get provider and model
        const provider = ProviderRegistry.bestAvailableProvider;
        if (!provider) {
          set({ error: 'No AI provider configured' });
          return;
        }

        const model = modelId || provider.supportedModels[0]?.id;
        if (!model) {
          set({ error: 'No model available' });
          return;
        }

        // Prepare messages for API
        const messages = get().messages[conversationId] || [];
        const chatMessages: ChatMessage[] = messages.map(m => ({
          role: m.role,
          content: m.content,
        }));

        // Start streaming
        set({
          isStreaming: true,
          streamingText: '',
          streamingConversationId: conversationId,
          error: null,
        });

        let fullResponse = '';
        let lastUIUpdate = 0;

        try {
          for await (const chunk of provider.chat(chatMessages, model, {
            stream: true,
            maxTokens: 4096,
          })) {
            if (chunk.type === 'content') {
              fullResponse += chunk.content;

              // Throttle UI updates
              const now = Date.now();
              if (now - lastUIUpdate >= STREAM_CONFIG.UI_THROTTLE) {
                set({ streamingText: fullResponse });
                lastUIUpdate = now;
              }
            } else if (chunk.type === 'error') {
              throw chunk.error;
            } else if (chunk.type === 'done') {
              // Final update
              set({ streamingText: fullResponse });
            }
          }

          // Add assistant message
          get().addMessage(conversationId, {
            conversationId,
            role: 'assistant',
            content: fullResponse,
            timestamp: Date.now(),
            model,
          });

          // Update conversation title if first exchange
          if (messages.length <= 1) {
            // Generate title from first message
            const title = content.length > 50
              ? content.substring(0, 47) + '...'
              : content;
            get().updateConversationTitle(conversationId, title);
          }
        } catch (error) {
          const errorMessage = error instanceof Error ? error.message : 'Unknown error';
          set({ error: errorMessage });

          // Add error message to conversation
          get().addMessage(conversationId, {
            conversationId,
            role: 'assistant',
            content: `Error: ${errorMessage}`,
            timestamp: Date.now(),
          });
        } finally {
          set({
            isStreaming: false,
            streamingText: '',
            streamingConversationId: null,
          });
        }
      },

      cancelStreaming: () => {
        set({
          isStreaming: false,
          streamingText: '',
          streamingConversationId: null,
        });
      },

      clearError: () => {
        set({ error: null });
      },

      getConversation: (id: string) => {
        return get().conversations.find(c => c.id === id);
      },

      getMessages: (conversationId: string) => {
        return get().messages[conversationId] || [];
      },

      getActiveConversation: () => {
        const state = get();
        return state.activeConversationId
          ? state.conversations.find(c => c.id === state.activeConversationId)
          : undefined;
      },
    }),
    {
      name: STORAGE_KEYS.CONVERSATIONS,
      partialize: (state) => ({
        conversations: state.conversations,
        messages: state.messages,
      }),
    }
  )
);
