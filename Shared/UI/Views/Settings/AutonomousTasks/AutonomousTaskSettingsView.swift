//
//  AutonomousTaskSettingsView.swift
//  Thea
//
//  Comprehensive UI for configuring autonomous tasks with multiple triggers and actions
//
//  Split into extension files:
//  - AutonomousTaskSections.swift: UI sections and template creation methods
//  - TaskEditorSheet.swift: Task editor sheet
//  - ConditionPickerSheet.swift: Condition picker sheet
//  - ActionPickerSheet.swift: Action picker sheet
//

import SwiftUI

struct AutonomousTaskSettingsView: View {
    @State var executor = AutonomousTaskExecutor.shared
    @State var showingNewTaskSheet = false
    @State var showingEditTaskSheet: AutonomousTask?
    @State var showingDeleteConfirmation = false
    @State var taskToDelete: AutonomousTask?

    var body: some View {
        Form {
            globalSettingsSection
            registeredTasksSection
            quickTemplatesSection
            executionHistorySection
        }
        .formStyle(.grouped)
        #if os(macOS)
        .padding()
        #endif
        .sheet(isPresented: $showingNewTaskSheet) {
            TaskEditorSheet(task: nil) { newTask in
                executor.registerTask(newTask)
            }
        }
        .sheet(item: $showingEditTaskSheet) { task in
            TaskEditorSheet(task: task) { updatedTask in
                executor.unregisterTask(id: task.id)
                executor.registerTask(updatedTask)
            }
        }
        .confirmationDialog(
            "Delete Task",
            isPresented: $showingDeleteConfirmation,
            presenting: taskToDelete
        ) { task in
            Button("Delete", role: .destructive) {
                executor.unregisterTask(id: task.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: { task in
            Text("Delete '\(task.name)'? This cannot be undone.")
        }
    }
}

// MARK: - Preview

#if os(macOS)
#Preview {
    AutonomousTaskSettingsView()
        .frame(width: 700, height: 800)
}
#else
#Preview {
    NavigationStack {
        AutonomousTaskSettingsView()
            .navigationTitle("Autonomous Tasks")
    }
}
#endif
