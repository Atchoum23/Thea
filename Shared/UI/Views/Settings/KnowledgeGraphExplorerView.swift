// KnowledgeGraphExplorerView.swift
// Thea — Personal Knowledge Graph Explorer

import SwiftUI
import os.log

struct KnowledgeGraphExplorerView: View {
    @State private var stats: KGStatistics?
    @State private var recentEntities: [KGEntity] = []
    @State private var searchText = ""
    @State private var searchResults: [KGEntity] = []
    @State private var selectedEntity: KGEntity?
    @State private var entityEdges: [KGEdge] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isLoading {
                    ProgressView("Loading graph...").frame(maxWidth: .infinity, minHeight: 100)
                } else {
                    statisticsSection; typeBreakdownSection; searchSection
                    if let e = selectedEntity { entityDetailSection(e) }
                    recentEntitiesSection
                }
            }.padding()
        }
        .navigationTitle("Knowledge Graph")
        .task { await loadData() }
    }

    // MARK: - Statistics
    private var statisticsSection: some View {
        Section {
            HStack(spacing: 24) {
                statCard("Entities", "\(stats?.entityCount ?? 0)", "circle.hexagongrid")
                statCard("Edges", "\(stats?.edgeCount ?? 0)", "arrow.triangle.branch")
                statCard("Avg Connections", String(format: "%.1f", stats?.averageConnections ?? 0), "point.3.connected.trianglepath.dotted")
            }
        } header: { Text("Graph Statistics").font(.theaHeadline) }
    }

    private func statCard(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title2).foregroundStyle(.blue)
            Text(value).font(.theaTitle2)
            Text(title).font(.theaCaption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Type Breakdown
    private var typeBreakdownSection: some View {
        Section {
            if let dist = stats?.typeDistribution, !dist.isEmpty {
                let sorted = dist.sorted { $0.value > $1.value }
                let maxVal = sorted.first?.value ?? 1
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(sorted, id: \.key) { type, count in
                        HStack(spacing: 8) {
                            Image(systemName: icon(for: type)).frame(width: 20).foregroundStyle(color(for: type))
                            Text(type.rawValue.capitalized).font(.theaCaption1).frame(width: 90, alignment: .leading)
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 3).fill(color(for: type))
                                    .frame(width: geo.size.width * CGFloat(count) / CGFloat(maxVal))
                            }.frame(height: 14)
                            Text("\(count)").font(.theaCaption2).foregroundStyle(.secondary).frame(width: 30, alignment: .trailing)
                        }
                    }
                }
            } else { Text("No entities yet").foregroundStyle(.secondary) }
        } header: { Text("Entity Types").font(.theaHeadline) }
    }

    // MARK: - Search
    private var searchSection: some View {
        Section {
            TextField("Search entities...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: searchText) { _, q in Task { await performSearch(q) } }
            if !searchResults.isEmpty {
                ForEach(searchResults) { e in
                    Button { selectEntity(e) } label: { entityRow(e) }.buttonStyle(.plain)
                }
            }
        } header: { Text("Search").font(.theaHeadline) }
    }

    // MARK: - Entity Detail
    private func entityDetailSection(_ entity: KGEntity) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon(for: entity.type)).foregroundStyle(color(for: entity.type))
                    Text(entity.name).font(.theaTitle3)
                    Spacer()
                    Text(entity.type.rawValue.capitalized).font(.theaCaption1)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(color(for: entity.type).opacity(0.15), in: Capsule())
                }
                if !entity.attributes.isEmpty {
                    ForEach(Array(entity.attributes), id: \.key) { k, v in
                        LabeledContent(k.capitalized, value: v).font(.theaCaption1)
                    }
                }
                LabeledContent("References", value: "\(entity.referenceCount)").font(.theaCaption1)
                LabeledContent("Updated", value: entity.lastUpdatedAt.formatted(.dateTime.month().day().hour().minute())).font(.theaCaption1)
                if !entityEdges.isEmpty {
                    Text("Relationships (\(entityEdges.count))").font(.theaCaption1).foregroundStyle(.secondary).padding(.top, 4)
                    ForEach(Array(entityEdges.prefix(10).enumerated()), id: \.offset) { _, edge in
                        HStack(spacing: 4) {
                            Text(edge.sourceID == entity.id ? edge.targetID : edge.sourceID).font(.theaCaption2).lineLimit(1)
                            Text("(\(edge.relationship))").font(.theaCaption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }.padding(8).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        } header: { Text("Selected Entity").font(.theaHeadline) }
    }

    // MARK: - Recent Entities
    private var recentEntitiesSection: some View {
        Section {
            if recentEntities.isEmpty {
                Text("No entities recorded yet").foregroundStyle(.secondary)
            } else {
                ForEach(recentEntities) { e in
                    Button { selectEntity(e) } label: { entityRow(e) }.buttonStyle(.plain)
                }
            }
        } header: { Text("Recent Entities (last 20)").font(.theaHeadline) }
    }

    private func entityRow(_ entity: KGEntity) -> some View {
        HStack {
            Image(systemName: icon(for: entity.type)).foregroundStyle(color(for: entity.type)).frame(width: 20)
            Text(entity.name).font(.theaBody)
            Spacer()
            Text(entity.type.rawValue.capitalized).font(.theaCaption2).foregroundStyle(.secondary)
            Text("x\(entity.referenceCount)").font(.theaCaption2).foregroundStyle(.tertiary)
        }.padding(.vertical, 2)
    }

    // MARK: - Data
    private func loadData() async {
        let g = PersonalKnowledgeGraph.shared
        stats = await g.statistics(); recentEntities = await g.recentEntities(limit: 20); isLoading = false
    }

    private func performSearch(_ query: String) async {
        guard query.count >= 2 else { searchResults = []; return }
        searchResults = await PersonalKnowledgeGraph.shared.searchEntities(query: query)
    }

    private func selectEntity(_ entity: KGEntity) {
        selectedEntity = entity
        Task { entityEdges = await PersonalKnowledgeGraph.shared.relationships(for: entity.id) }
    }

    // MARK: - Helpers
    private func icon(for t: KGEntityType) -> String {
        switch t {
        case .person: "person.fill"; case .place: "mappin.circle.fill"; case .habit: "repeat.circle.fill"
        case .goal: "target"; case .healthMetric: "heart.fill"; case .project: "folder.fill"
        case .event: "calendar"; case .topic: "text.book.closed.fill"; case .skill: "star.fill"
        case .preference: "slider.horizontal.3"
        }
    }

    private func color(for t: KGEntityType) -> Color {
        switch t {
        case .person: .blue; case .place: .orange; case .habit: .purple; case .goal: .green
        case .healthMetric: .red; case .project: .teal; case .event: .indigo; case .topic: .brown
        case .skill: .yellow; case .preference: .cyan
        }
    }
}

#Preview { KnowledgeGraphExplorerView().frame(width: 700, height: 600) }
