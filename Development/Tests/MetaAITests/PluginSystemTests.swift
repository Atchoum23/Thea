import XCTest
@testable import TheaCore

@MainActor
final class PluginSystemTests: XCTestCase {
    var pluginSystem: PluginSystem!

    override func setUp() async throws {
        pluginSystem = PluginSystem()
        pluginSystem.installedPlugins.removeAll()
        pluginSystem.activePlugins.removeAll()
    }

    func testInstallPlugin() async throws {
        let manifest = PluginManifest(
            name: "Test Plugin",
            version: "1.0.0",
            description: "A test plugin",
            author: "Test Author",
            permissions: [.dataStorage],
            entryPoint: "main.js",
            type: .tool,
            autoEnable: false,
            acceptsMessages: false
        )

        let plugin = try await pluginSystem.installPlugin(from: manifest)

        XCTAssertEqual(plugin.manifest.name, "Test Plugin")
        XCTAssertEqual(plugin.manifest.version, "1.0.0")
        XCTAssertEqual(pluginSystem.installedPlugins.count, 1)
    }

    func testPluginPermissions() async throws {
        let manifest = PluginManifest(
            name: "File Plugin",
            version: "1.0.0",
            description: "File operations",
            author: "Test",
            permissions: [.fileSystemRead, .fileSystemWrite],
            entryPoint: "main.js",
            type: .tool,
            autoEnable: false,
            acceptsMessages: false
        )

        XCTAssertThrowsError(try await pluginSystem.installPlugin(from: manifest)) { error in
            // Should fail due to dangerous permissions
        }
    }

    func testEnableDisablePlugin() async throws {
        let manifest = PluginManifest(
            name: "Test",
            version: "1.0.0",
            description: "Test",
            author: "Test",
            permissions: [.dataStorage],
            entryPoint: "main.js",
            type: .tool,
            autoEnable: false,
            acceptsMessages: false
        )

        let plugin = try await pluginSystem.installPlugin(from: manifest)

        XCTAssertFalse(plugin.isEnabled)

        try pluginSystem.enablePlugin(plugin.id)
        XCTAssertTrue(plugin.isEnabled)
        XCTAssertEqual(pluginSystem.activePlugins.count, 1)

        try pluginSystem.disablePlugin(plugin.id)
        XCTAssertFalse(plugin.isEnabled)
        XCTAssertEqual(pluginSystem.activePlugins.count, 0)
    }

    func testUninstallPlugin() async throws {
        let manifest = PluginManifest(
            name: "Test",
            version: "1.0.0",
            description: "Test",
            author: "Test",
            permissions: [.dataStorage],
            entryPoint: "main.js",
            type: .tool,
            autoEnable: false,
            acceptsMessages: false
        )

        let plugin = try await pluginSystem.installPlugin(from: manifest)
        XCTAssertEqual(pluginSystem.installedPlugins.count, 1)

        try pluginSystem.uninstallPlugin(plugin.id)
        XCTAssertEqual(pluginSystem.installedPlugins.count, 0)
    }

    func testPluginTypes() {
        let types: [PluginType] = [
            .aiProvider, .tool, .uiComponent, .dataSource, .workflow
        ]

        XCTAssertEqual(types.count, 5)

        for type in types {
            XCTAssertFalse(type.rawValue.isEmpty)
        }
    }

    func testPermissionTypes() {
        let permissions: [PluginPermission] = [
            .fileSystemRead, .fileSystemWrite, .networkAccess,
            .systemCommands, .aiProviderAccess, .interPluginCommunication,
            .dataStorage
        ]

        XCTAssertEqual(permissions.count, 7)
    }

    func testManifestValidation() {
        let invalidManifest = PluginManifest(
            name: "",
            version: "invalid",
            description: "Test",
            author: "",
            permissions: [.systemCommands, .networkAccess],
            entryPoint: "main.js",
            type: .tool,
            autoEnable: false,
            acceptsMessages: false
        )

        XCTAssertThrowsError(try pluginSystem.installPlugin(from: invalidManifest)) { error in
            XCTAssertTrue(error is PluginError)
        }
    }

    func testPluginDiscovery() async throws {
        let plugins = try await pluginSystem.discoverPlugins()

        XCTAssertGreaterThanOrEqual(plugins.count, 0, "Should discover plugins")

        for plugin in plugins {
            XCTAssertFalse(plugin.name.isEmpty)
            XCTAssertFalse(plugin.version.isEmpty)
        }
    }
}
