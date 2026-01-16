import SwiftUI

// MARK: - Model Capability View
// Settings panel and browser for AI model capabilities

@MainActor
public struct ModelCapabilityView: View {
    @State private var database = ModelCapabilityDatabase.shared
    @State private var selectedModel: ModelCapability?
    @State private var selectedTaskType: ModelCapability.TaskType?
    @State private var searchText = ""
    @State private var showingCostCalculator = false
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            // Model list sidebar
            modelListSidebar
        } detail: {
            // Model detail view
            if let model = selectedModel {
                modelDetailView(model: model)
            } else {
                emptyDetailView
            }
        }
        .navigationTitle("Model Capabilities")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                updateButton
            }
            
            ToolbarItem(placement: .automatic) {
                settingsMenu
            }
        }
        .sheet(isPresented: $showingCostCalculator) {
            if let model = selectedModel {
                CostCalculatorSheet(model: model)
            }
        }
    }
    
    // MARK: - Model List Sidebar
    
    private var modelListSidebar: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar
            
            // Task type filter
            taskTypeFilter
            
            Divider()
            
            // Model list
            List(filteredModels, selection: $selectedModel) { model in
                ModelCapabilityRow(model: model)
                    .tag(model as ModelCapability?)
            }
            .listStyle(.sidebar)
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search models...", text: $searchText)
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
        .padding()
    }
    
    private var taskTypeFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                TaskTypeButton(
                    taskType: nil,
                    isSelected: selectedTaskType == nil
                ) {
                    selectedTaskType = nil
                }
                
                ForEach(ModelCapability.TaskType.allCases, id: \.self) { taskType in
                    TaskTypeButton(
                        taskType: taskType,
                        isSelected: selectedTaskType == taskType
                    ) {
                        selectedTaskType = taskType
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    private var filteredModels: [ModelCapability] {
        var filtered = database.models
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { model in
                model.displayName.localizedCaseInsensitiveContains(searchText) ||
                model.modelId.localizedCaseInsensitiveContains(searchText) ||
                model.provider.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Filter by task type
        if let taskType = selectedTaskType {
            filtered = filtered.filter { $0.strengths.contains(taskType) }
        }
        
        return filtered.sorted { $0.qualityScore > $1.qualityScore }
    }
    
    // MARK: - Model Detail View
    
    private func modelDetailView(model: ModelCapability) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                modelHeader(model: model)
                
                Divider()
                
                // Capabilities
                capabilitiesSection(model: model)
                
                Divider()
                
                // Specifications
                specificationsSection(model: model)
                
                Divider()
                
                // Pricing
                pricingSection(model: model)
                
                Divider()
                
                // Metadata
                metadataSection(model: model)
            }
            .padding()
        }
    }
    
    private func modelHeader(model: ModelCapability) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(model.modelId)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                
                Spacer()
                
                qualityBadge(score: model.qualityScore)
            }
            
            HStack(spacing: 16) {
                Label(model.provider.capitalized, systemImage: "building.2")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Label(model.source.rawValue, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func capabilitiesSection(model: ModelCapability) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Strengths")
                .font(.headline)
            
            FlowLayout(spacing: 8) {
                ForEach(model.strengths, id: \.self) { strength in
                    Text(strength.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .cornerRadius(8)
                }
            }
        }
    }
    
    private func specificationsSection(model: ModelCapability) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Specifications")
                .font(.headline)
            
            VStack(spacing: 8) {
                SpecRow(label: "Context Window", value: "\(formatNumber(model.contextWindow)) tokens")
                SpecRow(label: "Average Latency", value: "\(Int(model.averageLatency))ms")
                SpecRow(label: "Quality Score", value: String(format: "%.1f%%", model.qualityScore * 100))
            }
        }
    }
    
    private func pricingSection(model: ModelCapability) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pricing")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingCostCalculator = true }) {
                    Label("Calculator", systemImage: "dollarsign.circle")
                        .font(.caption)
                }
            }
            
            VStack(spacing: 8) {
                SpecRow(label: "Input", value: "$\(model.costPerMillionInput, default: "%.2f") / 1M tokens")
                SpecRow(label: "Output", value: "$\(model.costPerMillionOutput, default: "%.2f") / 1M tokens")
                SpecRow(label: "Quality/Cost Ratio", value: String(format: "%.2f", model.qualityCostRatio))
            }
        }
    }
    
    private func metadataSection(model: ModelCapability) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metadata")
                .font(.headline)
            
            VStack(spacing: 8) {
                SpecRow(label: "Last Updated", value: formatDate(model.lastUpdated))
                SpecRow(label: "Data Source", value: model.source.rawValue)
            }
        }
    }
    
    private var emptyDetailView: some View {
        ContentUnavailableView(
            "No Model Selected",
            systemImage: "cpu",
            description: Text("Select a model to view its capabilities and specifications")
        )
    }
    
    // MARK: - Toolbar
    
    private var updateButton: some View {
        Button(action: { Task { await database.updateNow() } }) {
            if database.isUpdating {
                ProgressView()
                    .scaleEffect(0.7)
            } else {
                Label("Update", systemImage: "arrow.clockwise")
            }
        }
        .disabled(database.isUpdating)
    }
    
    private var settingsMenu: some View {
        Menu {
            Toggle("Auto-Update", isOn: $database.autoUpdate)
            
            Divider()
            
            Menu("Update Frequency") {
                ForEach(ModelCapabilityDatabase.UpdateFrequency.allCases, id: \.self) { frequency in
                    Button(frequency.rawValue) {
                        database.updateFrequency = frequency
                    }
                }
            }
            
            Divider()
            
            if let lastUpdate = database.lastUpdated {
                Text("Last updated: \(formatDate(lastUpdate))")
                    .font(.caption)
            }
            
            Text("\(database.models.count) models indexed")
                .font(.caption)
        } label: {
            Image(systemName: "gear")
        }
    }
    
    // MARK: - Helper Views
    
    private func qualityBadge(score: Double) -> some View {
        let percentage = Int(score * 100)
        let color: Color = score >= 0.9 ? .green : (score >= 0.8 ? .blue : .orange)
        
        return HStack(spacing: 4) {
            Image(systemName: "star.fill")
            Text("\(percentage)%")
        }
        .font(.caption)
        .fontWeight(.semibold)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.2))
        .foregroundStyle(color)
        .cornerRadius(6)
    }
    
    // MARK: - Utilities
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Supporting Views

private struct ModelCapabilityRow: View {
    let model: ModelCapability
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.displayName)
                .font(.headline)
            
            HStack {
                Text(model.provider.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                    Text(String(format: "%.0f%%", model.qualityScore * 100))
                        .font(.caption)
                }
                .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct TaskTypeButton: View {
    let taskType: ModelCapability.TaskType?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(taskType?.rawValue ?? "All")
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
                .foregroundStyle(isSelected ? .white : .primary)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

private struct SpecRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .textSelection(.enabled)
        }
        .font(.subheadline)
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var positions: [CGPoint] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - Cost Calculator Sheet

private struct CostCalculatorSheet: View {
    let model: ModelCapability
    @State private var inputTokens: Double = 100000
    @State private var outputTokens: Double = 50000
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Token Usage") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Input Tokens: \(Int(inputTokens).formatted())")
                        Slider(value: $inputTokens, in: 1000...1000000, step: 1000)
                        
                        Text("Output Tokens: \(Int(outputTokens).formatted())")
                        Slider(value: $outputTokens, in: 1000...1000000, step: 1000)
                    }
                }
                
                Section("Estimated Cost") {
                    let inputCost = (inputTokens / 1_000_000) * model.costPerMillionInput
                    let outputCost = (outputTokens / 1_000_000) * model.costPerMillionOutput
                    let totalCost = inputCost + outputCost
                    
                    HStack {
                        Text("Input")
                        Spacer()
                        Text("$\(inputCost, specifier: "%.4f")")
                    }
                    
                    HStack {
                        Text("Output")
                        Spacer()
                        Text("$\(outputCost, specifier: "%.4f")")
                    }
                    
                    HStack {
                        Text("Total")
                            .fontWeight(.bold)
                        Spacer()
                        Text("$\(totalCost, specifier: "%.4f")")
                            .fontWeight(.bold)
                    }
                }
            }
            .navigationTitle("Cost Calculator")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

// MARK: - Previews

#Preview {
    ModelCapabilityView()
}
