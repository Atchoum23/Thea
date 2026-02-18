#if os(macOS)
    import SwiftUI

    /// View for managing Cowork skills (file type creation capabilities)
    struct CoworkSkillsView: View {
        @State private var skillsManager = CoworkSkillsManager.shared
        @State private var searchText = ""
        @State private var selectedSkill: CoworkSkillsManager.SkillType?

        private var filteredSkills: [CoworkSkillsManager.SkillType] {
            if searchText.isEmpty {
                return CoworkSkillsManager.SkillType.allCases
            }
            return CoworkSkillsManager.SkillType.allCases.filter {
                $0.rawValue.localizedCaseInsensitiveContains(searchText) ||
                    $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }

        var body: some View {
            HSplitView {
                // Skills list
                skillsList
                    .frame(minWidth: 250, maxWidth: 350)

                // Skill detail
                if let skill = selectedSkill {
                    skillDetailView(skill)
                } else {
                    emptyDetailView
                }
            }
        }

        // MARK: - Skills List

        private var skillsList: some View {
            VStack(spacing: 0) {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    TextField("Search skills...", text: $searchText)
                        .textFieldStyle(.plain)
                        .accessibilityLabel("Search skills")
                }
                .padding(8)
                .background(Color.controlBackground)
                .cornerRadius(8)
                .padding()

                Divider()

                // Skills list
                List(selection: $selectedSkill) {
                    ForEach(filteredSkills, id: \.self) { skill in
                        skillRow(skill)
                            .tag(skill)
                    }
                }
                .listStyle(.sidebar)
            }
        }

        private func skillRow(_ skill: CoworkSkillsManager.SkillType) -> some View {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(skillsManager.isEnabled(skill) ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                        .frame(width: 32, height: 32)

                    Image(systemName: skill.icon)
                        .foregroundStyle(skillsManager.isEnabled(skill) ? Color.accentColor : Color.secondary)
                }
                .accessibilityHidden(true)

                // Name
                VStack(alignment: .leading, spacing: 2) {
                    Text(skill.rawValue)
                        .font(.body)

                    Text("\(skill.supportedExtensions.count) formats")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Enabled indicator
                if skillsManager.isEnabled(skill) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(skill.rawValue), \(skill.supportedExtensions.count) formats, \(skillsManager.isEnabled(skill) ? "enabled" : "disabled")")
        }

        // MARK: - Skill Detail View

        private func skillDetailView(_ skill: CoworkSkillsManager.SkillType) -> some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    skillHeader(skill)

                    Divider()

                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                        Text(skill.description)
                            .foregroundStyle(.secondary)
                    }

                    // Supported formats
                    if !skill.supportedExtensions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Supported Formats")
                                .font(.headline)

                            FlowLayout(spacing: 8) {
                                ForEach(skill.supportedExtensions, id: \.self) { ext in
                                    Text(".\(ext)")
                                        .font(.system(.caption, design: .monospaced))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.accentColor.opacity(0.1))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }

                    // Capabilities
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Capabilities")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 4) {
                            capabilityRow(skill: skill)
                        }
                    }

                    // Actions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Actions")
                            .font(.headline)

                        HStack {
                            Toggle(skillsManager.isEnabled(skill) ? "Enabled" : "Disabled", isOn: Binding(
                                get: { skillsManager.isEnabled(skill) },
                                set: { _ in skillsManager.toggle(skill) }
                            ))
                            .toggleStyle(.switch)

                            Spacer()
                        }
                    }

                    Spacer()
                }
                .padding()
            }
        }

        private func skillHeader(_ skill: CoworkSkillsManager.SkillType) -> some View {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(skillsManager.isEnabled(skill) ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                        .frame(width: 60, height: 60)

                    Image(systemName: skill.icon)
                        .font(.title)
                        .foregroundStyle(skillsManager.isEnabled(skill) ? Color.accentColor : Color.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(skill.rawValue)
                        .font(.title2.bold())

                    HStack {
                        if skillsManager.isEnabled(skill) {
                            Label("Enabled", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Label("Disabled", systemImage: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()
            }
        }

        @ViewBuilder
        private func capabilityRow(skill: CoworkSkillsManager.SkillType) -> some View {
            switch skill {
            case .document:
                capabilityItem("Create new documents", icon: "plus.circle")
                capabilityItem("Edit existing documents", icon: "pencil")
                capabilityItem("Convert between formats", icon: "arrow.triangle.2.circlepath")
                capabilityItem("Extract text content", icon: "doc.text")

            case .spreadsheet:
                capabilityItem("Create spreadsheets", icon: "plus.circle")
                capabilityItem("Add formulas", icon: "function")
                capabilityItem("Create charts", icon: "chart.bar")
                capabilityItem("Import/export CSV", icon: "arrow.left.arrow.right")

            case .presentation:
                capabilityItem("Create presentations", icon: "plus.circle")
                capabilityItem("Add slides", icon: "rectangle.stack")
                capabilityItem("Insert images", icon: "photo")

            case .pdf:
                capabilityItem("Create PDFs", icon: "plus.circle")
                capabilityItem("Extract text", icon: "doc.text")
                capabilityItem("Merge PDFs", icon: "arrow.triangle.merge")

            case .image:
                capabilityItem("Resize images", icon: "arrow.up.left.and.arrow.down.right")
                capabilityItem("Convert formats", icon: "arrow.triangle.2.circlepath")
                capabilityItem("Optimize for web", icon: "globe")

            case .code:
                capabilityItem("Generate source code", icon: "plus.circle")
                capabilityItem("Multiple languages", icon: "chevron.left.forwardslash.chevron.right")
                capabilityItem("Syntax awareness", icon: "text.alignleft")

            case .fileOrganization:
                capabilityItem("Sort by type", icon: "folder.badge.gearshape")
                capabilityItem("Sort by date", icon: "calendar")
                capabilityItem("Rename files", icon: "character.cursor.ibeam")
                capabilityItem("Move files", icon: "arrow.right.doc.on.clipboard")

            case .webScraping:
                capabilityItem("Extract data", icon: "square.and.arrow.down")
                capabilityItem("Parse HTML", icon: "chevron.left.forwardslash.chevron.right")
                capabilityItem("Export to JSON", icon: "doc.text")

            case .dataTransformation:
                capabilityItem("CSV to JSON", icon: "arrow.right")
                capabilityItem("JSON to XML", icon: "arrow.right")
                capabilityItem("YAML to JSON", icon: "arrow.right")

            case .archive:
                capabilityItem("Create ZIP archives", icon: "archivebox")
                capabilityItem("Extract archives", icon: "archivebox.fill")
                capabilityItem("TAR/GZ support", icon: "doc.zipper")

            case .terminal:
                capabilityItem("Execute commands", icon: "terminal")
                capabilityItem("Capture output", icon: "doc.text")
                capabilityItem("Background tasks", icon: "clock")
            }
        }

        private func capabilityItem(_ text: String, icon: String) -> some View {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20)
                Text(text)
                    .font(.body)
            }
            .padding(.vertical, 2)
        }

        // MARK: - Empty Detail View

        private var emptyDetailView: some View {
            ContentUnavailableView {
                Label("Select a Skill", systemImage: "star.circle")
            } description: {
                Text("Select a skill from the list to view details and configure it")
            }
        }
    }

    #Preview {
        CoworkSkillsView()
            .frame(width: 800, height: 600)
    }

#endif
