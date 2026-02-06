//
//  CredentialProviderViewController.swift
//  TheaCredentialsExtension
//
//  Created by Thea
//

import AuthenticationServices
import os.log

/// Credential Provider Extension for Thea
/// Provides AI-assisted credential autofill and management
class CredentialProviderViewController: ASCredentialProviderViewController {
    private let logger = Logger(subsystem: "app.thea.credentials", category: "CredentialProvider")
    private let appGroupID = "group.app.theathe"

    // UI Elements
    private var tableView: UITableView!
    private var searchController: UISearchController!
    private var credentials: [CredentialEntry] = []
    private var filteredCredentials: [CredentialEntry] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadCredentials()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground

        // Navigation bar
        title = "Thea Credentials"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )

        // Search controller
        searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search credentials..."
        navigationItem.searchController = searchController

        // Table view
        tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(CredentialCell.self, forCellReuseIdentifier: "CredentialCell")
        view.addSubview(tableView)

        // Header
        let headerView = createHeaderView()
        tableView.tableHeaderView = headerView
    }

    private func createHeaderView() -> UIView {
        let header = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 100))

        let iconView = UIImageView(image: UIImage(systemName: "key.fill"))
        iconView.tintColor = .systemPurple
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(iconView)

        let titleLabel = UILabel()
        titleLabel.text = "Thea Credentials"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titleLabel)

        let subtitleLabel = UILabel()
        subtitleLabel.text = "AI-powered secure credential management"
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            iconView.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 44),
            iconView.heightAnchor.constraint(equalToConstant: 44),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: header.topAnchor, constant: 25),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4)
        ])

        return header
    }

    // MARK: - Credential Provider Methods

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        logger.info("Preparing credential list for \(serviceIdentifiers.count) services")

        // Filter credentials based on service identifiers
        if serviceIdentifiers.isEmpty {
            filteredCredentials = credentials
        } else {
            let domains = serviceIdentifiers.compactMap { identifier -> String? in
                if identifier.type == .domain {
                    return identifier.identifier.lowercased()
                } else if identifier.type == .URL, let url = URL(string: identifier.identifier) {
                    return url.host?.lowercased()
                }
                return nil
            }

            filteredCredentials = credentials.filter { credential in
                domains.contains { domain in
                    credential.domain.lowercased().contains(domain) ||
                        domain.contains(credential.domain.lowercased())
                }
            }

            // If no exact matches, show all credentials
            if filteredCredentials.isEmpty {
                filteredCredentials = credentials
            }
        }

        tableView.reloadData()
    }

    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        logger.info("Providing credential without interaction")

        // Try to provide credential without showing UI
        if let credential = findCredential(for: credentialIdentity) {
            let passwordCredential = ASPasswordCredential(
                user: credential.username,
                password: credential.password
            )
            extensionContext.completeRequest(withSelectedCredential: passwordCredential)
        } else {
            // Need user interaction
            extensionContext.cancelRequest(withError: ASExtensionError(.userInteractionRequired))
        }
    }

    override func prepareInterfaceToProvideCredential(for credentialIdentity: ASPasswordCredentialIdentity) {
        logger.info("Preparing interface for credential")

        // Find and highlight the matching credential
        if let credential = findCredential(for: credentialIdentity),
           let index = filteredCredentials.firstIndex(where: { $0.id == credential.id })
        {
            let indexPath = IndexPath(row: index, section: 0)
            tableView.selectRow(at: indexPath, animated: true, scrollPosition: .middle)
        }
    }

    // Note: prepareInterfaceForExtensionConfiguration is available from iOS 12.0 as part of ASCredentialProviderViewController
    // The extension's deployment target (iOS 17.0) already satisfies this requirement
    override func prepareInterfaceForExtensionConfiguration() {
        // Called when user wants to configure the extension
        logger.info("Preparing extension configuration")
    }

    // MARK: - Private Methods

    private func loadCredentials() {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return
        }

        let credentialsPath = containerURL.appendingPathComponent("credentials.encrypted")

        // In production, use Keychain and proper encryption
        if let data = try? Data(contentsOf: credentialsPath),
           let decoded = try? JSONDecoder().decode([CredentialEntry].self, from: data)
        {
            credentials = decoded
            filteredCredentials = credentials
        } else {
            // Demo credentials for testing
            credentials = []
            filteredCredentials = []
        }

        tableView?.reloadData()
    }

    private func findCredential(for identity: ASPasswordCredentialIdentity) -> CredentialEntry? {
        credentials.first { credential in
            credential.username == identity.user &&
                (credential.domain == identity.serviceIdentifier.identifier ||
                    credential.domain.contains(identity.serviceIdentifier.identifier))
        }
    }

    private func selectCredential(_ credential: CredentialEntry) {
        logger.info("Selected credential for \(credential.domain)")

        let passwordCredential = ASPasswordCredential(
            user: credential.username,
            password: credential.password
        )

        // Log usage for Thea awareness (without the password)
        logCredentialUsage(credential)

        extensionContext.completeRequest(withSelectedCredential: passwordCredential)
    }

    private func logCredentialUsage(_ credential: CredentialEntry) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return
        }

        let logEntry: [String: Any] = [
            "domain": credential.domain,
            "username": credential.username,
            "timestamp": Date().timeIntervalSince1970,
            "action": "autofill"
        ]

        let logsDir = containerURL.appendingPathComponent("CredentialLogs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)

        let logPath = logsDir.appendingPathComponent("usage.jsonl")

        if let data = try? JSONSerialization.data(withJSONObject: logEntry),
           let line = String(data: data, encoding: .utf8)
        {
            if let handle = try? FileHandle(forWritingTo: logPath) {
                handle.seekToEndOfFile()
                handle.write((line + "\n").data(using: .utf8)!)
                try? handle.close()
            } else {
                try? (line + "\n").write(to: logPath, atomically: true, encoding: .utf8)
            }
        }
    }

    @objc private func cancelTapped() {
        extensionContext.cancelRequest(withError: ASExtensionError(.userCanceled))
    }
}

// MARK: - UITableViewDataSource & Delegate

extension CredentialProviderViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        filteredCredentials.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CredentialCell", for: indexPath) as! CredentialCell
        let credential = filteredCredentials[indexPath.row]
        cell.configure(with: credential)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let credential = filteredCredentials[indexPath.row]
        selectCredential(credential)
    }

    func tableView(_: UITableView, titleForHeaderInSection _: Int) -> String? {
        filteredCredentials.isEmpty ? nil : "Available Credentials"
    }
}

// MARK: - UISearchResultsUpdating

extension CredentialProviderViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text?.lowercased() ?? ""

        if searchText.isEmpty {
            filteredCredentials = credentials
        } else {
            filteredCredentials = credentials.filter { credential in
                credential.domain.lowercased().contains(searchText) ||
                    credential.username.lowercased().contains(searchText) ||
                    (credential.notes?.lowercased().contains(searchText) ?? false)
            }
        }

        tableView.reloadData()
    }
}

// MARK: - Credential Entry Model

struct CredentialEntry: Codable, Identifiable {
    let id: String
    let domain: String
    let username: String
    let password: String
    let notes: String?
    let created: Date
    let lastUsed: Date?
    let category: String?
}

// MARK: - Credential Cell

class CredentialCell: UITableViewCell {
    private let iconView = UIImageView()
    private let domainLabel = UILabel()
    private let usernameLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupCell() {
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .systemPurple
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)

        domainLabel.font = .systemFont(ofSize: 16, weight: .medium)
        domainLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(domainLabel)

        usernameLabel.font = .systemFont(ofSize: 14)
        usernameLabel.textColor = .secondaryLabel
        usernameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(usernameLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            domainLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            domainLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            domainLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            usernameLabel.leadingAnchor.constraint(equalTo: domainLabel.leadingAnchor),
            usernameLabel.topAnchor.constraint(equalTo: domainLabel.bottomAnchor, constant: 2),
            usernameLabel.trailingAnchor.constraint(equalTo: domainLabel.trailingAnchor),
            usernameLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])

        accessoryType = .disclosureIndicator
    }

    func configure(with credential: CredentialEntry) {
        domainLabel.text = credential.domain
        usernameLabel.text = credential.username

        // Set icon based on category or domain
        let iconName = switch credential.category?.lowercased() {
        case "social":
            "person.2.fill"
        case "email":
            "envelope.fill"
        case "banking":
            "banknote.fill"
        case "shopping":
            "cart.fill"
        default:
            "globe"
        }
        iconView.image = UIImage(systemName: iconName)
    }
}
