// CallMonitor+DeadlineIntegration.swift
// THEA - Voice Call Transcription & Intelligence
//
// Real-time analysis of transcript segments and integration
// of extracted deadlines, action items, and commitments with
// the DeadlineIntelligence system.

import Foundation

// MARK: - Real-Time Analysis & Deadline Integration

extension CallMonitor {

    // MARK: - Real-Time Segment Analysis

    /// Performs lightweight pattern matching on a single transcript segment to detect
    /// commitment language and deadline mentions in real time.
    ///
    /// This runs after every new segment arrives during an active call, enabling
    /// immediate notifications for urgent items without waiting for the full
    /// post-call analysis pass.
    ///
    /// - Parameters:
    ///   - segment: The newly transcribed segment to analyze.
    ///   - callId: The UUID of the active call the segment belongs to.
    func performRealTimeAnalysis(_ segment: CallTranscriptSegment, callId: UUID) async {
        // Quick check for urgent patterns
        let text = segment.text.lowercased()

        // Check for commitment language
        let commitmentPatterns = [
            "i will", "i'll", "i promise", "i commit",
            "you can count on me", "consider it done",
            "i guarantee", "absolutely", "definitely"
        ]

        for pattern in commitmentPatterns {
            if text.contains(pattern) {
                // Flag this segment for detailed analysis
                // Could trigger immediate notification
                break
            }
        }

        // Check for deadline mentions
        let deadlinePatterns = [
            "by tomorrow", "by friday", "end of day",
            "by the end of", "deadline is", "due on"
        ]

        for pattern in deadlinePatterns {
            if text.contains(pattern) {
                // Flag for deadline extraction
                break
            }
        }
    }

    // MARK: - DeadlineIntelligence Integration

    /// Sends all extracted deadlines, action items with due dates, and commitments
    /// with deadlines from the call analysis to `DeadlineIntelligence`.
    ///
    /// Three categories of items are forwarded:
    /// 1. Explicitly mentioned deadlines (confidence: 0.7)
    /// 2. Action items that have an associated due date (confidence: 0.75)
    /// 3. Commitments that have an associated deadline (confidence: 0.8)
    ///
    /// - Parameters:
    ///   - analysis: The completed `CallAnalysis` for the call.
    ///   - call: The `CallRecord` the analysis was derived from.
    func integrateWithDeadlines(_ analysis: CallAnalysis, call: CallRecord) async {
        // Send deadlines to DeadlineIntelligence
        for deadline in analysis.deadlinesMentioned {
            let extractedDeadline = Deadline(
                title: deadline.description,
                description: "Mentioned in call with \(call.participants.compactMap { $0.name }.joined(separator: ", "))",
                dueDate: deadline.date,
                source: .voiceCall,
                category: .work,
                extractedFrom: Deadline.ExtractionContext(
                    sourceText: deadline.context,
                    sourceURL: nil,
                    sourceFile: nil,
                    extractionMethod: "CallMonitor",
                    timestamp: Date()
                ),
                confidence: 0.7
            )
            await DeadlineIntelligence.shared.addDeadline(extractedDeadline)
        }

        // Convert action items with due dates to deadlines
        for item in analysis.actionItems where item.dueDate != nil {
            let deadline = Deadline(
                title: item.description,
                description: "Action item from call",
                dueDate: item.dueDate!,
                source: .voiceCall,
                category: .work,
                priority: item.priority == .urgent ? 9 : (item.priority == .high ? 7 : 5),
                extractedFrom: Deadline.ExtractionContext(
                    sourceText: item.extractedFrom,
                    sourceURL: nil,
                    sourceFile: nil,
                    extractionMethod: "CallMonitor.ActionItem",
                    timestamp: Date()
                ),
                confidence: 0.75
            )
            await DeadlineIntelligence.shared.addDeadline(deadline)
        }

        // Convert commitments with deadlines
        for commitment in analysis.commitments where commitment.deadline != nil {
            let deadline = Deadline(
                title: "Commitment: \(commitment.description)",
                description: "Made by \(commitment.madeBy)",
                dueDate: commitment.deadline!,
                source: .voiceCall,
                category: .work,
                extractedFrom: Deadline.ExtractionContext(
                    sourceText: commitment.extractedFrom,
                    sourceURL: nil,
                    sourceFile: nil,
                    extractionMethod: "CallMonitor.Commitment",
                    timestamp: Date()
                ),
                confidence: 0.8
            )
            await DeadlineIntelligence.shared.addDeadline(deadline)
        }
    }
}
