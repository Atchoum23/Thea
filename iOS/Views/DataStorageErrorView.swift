import SwiftUI

/// View displayed when data storage initialization fails
struct DataStorageErrorView: View {
    let error: Error?
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red)
            
            Text("Storage Error")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Thea encountered an error initializing data storage.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            if let error = error {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding()
                    #if os(iOS)
                    .background(Color(uiColor: .systemGray6))
                    #else
                    .background(Color(nsColor: .controlBackgroundColor))
                    #endif
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 32)
            }
            
            VStack(spacing: 12) {
                Text("Suggested solutions:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("Restart the app", systemImage: "arrow.clockwise")
                    Label("Ensure sufficient storage space", systemImage: "internaldrive")
                    Label("Check file system permissions", systemImage: "lock.shield")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()
            #if os(iOS)
            .background(Color(uiColor: .systemGray6))
            #else
            .background(Color(nsColor: .controlBackgroundColor))
            #endif
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 32)
            
            Button {
                // Exit the app
                exit(0)
            } label: {
                Text("Close App")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.red)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .padding()
    }
}

#Preview {
    DataStorageErrorView(error: NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Sample error message"]))
}
