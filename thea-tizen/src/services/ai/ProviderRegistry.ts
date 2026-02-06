/**
 * Provider Registry - Central management of AI providers
 * Mirrors: Shared/Providers/Registry/ProviderRegistry.swift
 */

import type { AIProvider, ProviderCapability } from './AIProvider';
import type { AIModel, ProviderHealth } from '../../types/chat';
import { AnthropicProvider } from './AnthropicProvider';
import { OpenRouterProvider } from './OpenRouterProvider';

/**
 * Singleton registry for managing AI providers
 */
class ProviderRegistryClass {
  private providers: Map<string, AIProvider> = new Map();
  private healthCache: Map<string, ProviderHealth> = new Map();
  private defaultProviderId: string = 'openrouter';

  constructor() {
    // Register default providers
    this.register(new AnthropicProvider());
    this.register(new OpenRouterProvider());
  }

  /**
   * Register a provider
   */
  register(provider: AIProvider): void {
    this.providers.set(provider.id, provider);
  }

  /**
   * Unregister a provider
   */
  unregister(providerId: string): void {
    this.providers.delete(providerId);
    this.healthCache.delete(providerId);
  }

  /**
   * Get a provider by ID
   */
  getProvider(id: string): AIProvider | undefined {
    return this.providers.get(id);
  }

  /**
   * Get the default provider
   */
  get defaultProvider(): AIProvider | undefined {
    return this.providers.get(this.defaultProviderId);
  }

  /**
   * Set the default provider
   */
  setDefaultProvider(providerId: string): void {
    if (this.providers.has(providerId)) {
      this.defaultProviderId = providerId;
    }
  }

  /**
   * Get all registered providers
   */
  get allProviders(): AIProvider[] {
    return Array.from(this.providers.values());
  }

  /**
   * Get only configured providers
   */
  get configuredProviders(): AIProvider[] {
    return this.allProviders.filter(p => p.isConfigured);
  }

  /**
   * Get providers with specific capability
   */
  getProvidersWithCapability(capability: ProviderCapability): AIProvider[] {
    return this.allProviders.filter(p => p.capabilities.has(capability));
  }

  /**
   * Get all models from all providers
   */
  get allModels(): AIModel[] {
    return this.allProviders.flatMap(p => p.supportedModels);
  }

  /**
   * Get models from configured providers only
   */
  get availableModels(): AIModel[] {
    return this.configuredProviders.flatMap(p => p.supportedModels);
  }

  /**
   * Find a model by ID
   */
  findModel(modelId: string): { provider: AIProvider; model: AIModel } | undefined {
    for (const provider of this.allProviders) {
      const model = provider.supportedModels.find(m => m.id === modelId);
      if (model) {
        return { provider, model };
      }
    }
    return undefined;
  }

  /**
   * Get the best available provider (first configured one)
   */
  get bestAvailableProvider(): AIProvider | undefined {
    // Prefer default if configured
    const defaultProv = this.defaultProvider;
    if (defaultProv?.isConfigured) {
      return defaultProv;
    }

    // Return first configured provider
    return this.configuredProviders[0];
  }

  /**
   * Check health of all providers
   */
  async checkAllHealth(): Promise<Map<string, ProviderHealth>> {
    const checks = this.configuredProviders.map(async provider => {
      const health = await provider.checkHealth();
      this.healthCache.set(provider.id, health);
      return [provider.id, health] as const;
    });

    const results = await Promise.all(checks);
    return new Map(results);
  }

  /**
   * Get cached health for a provider
   */
  getHealth(providerId: string): ProviderHealth | undefined {
    return this.healthCache.get(providerId);
  }

  /**
   * Get registry statistics
   */
  getStatistics(): {
    totalProviders: number;
    configuredProviders: number;
    healthyProviders: number;
    totalModels: number;
    availableModels: number;
  } {
    const healthyCount = Array.from(this.healthCache.values()).filter(
      h => h.isHealthy
    ).length;

    return {
      totalProviders: this.providers.size,
      configuredProviders: this.configuredProviders.length,
      healthyProviders: healthyCount,
      totalModels: this.allModels.length,
      availableModels: this.availableModels.length,
    };
  }

  /**
   * Configure a provider with an API key
   */
  configureProvider(providerId: string, apiKey: string): boolean {
    const provider = this.providers.get(providerId);
    if (provider && 'setApiKey' in provider) {
      (provider as { setApiKey: (key: string) => void }).setApiKey(apiKey);
      return true;
    }
    return false;
  }

  /**
   * Load API keys from storage
   */
  loadFromStorage(storage: {
    getItem: (key: string) => string | null;
  }): void {
    const keyMap: Record<string, string> = {
      anthropic: 'thea_api_anthropic',
      openrouter: 'thea_api_openrouter',
      openai: 'thea_api_openai',
      google: 'thea_api_google',
    };

    for (const [providerId, storageKey] of Object.entries(keyMap)) {
      const apiKey = storage.getItem(storageKey);
      if (apiKey) {
        this.configureProvider(providerId, apiKey);
      }
    }
  }
}

// Create singleton instance
const registryInstance = new ProviderRegistryClass();

// Export with static helper methods
export const ProviderRegistry = Object.assign(registryInstance, {
  /** Get singleton instance */
  getInstance: () => registryInstance,
  /** Get the best available configured provider */
  getDefaultProvider: () => registryInstance.bestAvailableProvider,
});
