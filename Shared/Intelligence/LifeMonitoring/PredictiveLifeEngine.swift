// PredictiveLifeEngine.swift
// Thea V2 - AI-Powered Predictive Life Intelligence
//
// Uses LLMs and ML to predict user needs, behaviors, and proactively
// suggest optimizations BEFORE the user asks. This is the brain
// behind Thea's anticipatory intelligence.
//
// NOTE: Class definition moved to PredictiveLifeEngine+Core.swift (SRP: single-responsibility)
// Methods split into extension files:
//   +Core.swift               — Class definition, properties, init, setup, lifecycle, context
//   +CyclePredictions.swift   — Prediction cycle and generators
//   +Management.swift         — Prediction management, persistence, public API
//   +Models.swift             — Data models (LifePrediction, LifeContextSnapshot, etc.)
//   +PatternPredictions.swift — Pattern-based and immediate predictions

import Combine
import Foundation
import os.log
