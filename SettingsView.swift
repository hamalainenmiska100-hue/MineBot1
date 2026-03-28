import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var showingAddServer = false
    @State private var showDeveloperSettings = false
    @State private var buildTapTimestamps: [Date] = []
    @AppStorage("developerModeUnlocked") private var developerModeUnlocked = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                accountCard
                serversCard
                communityCard
                aboutCard
                if developerModeUnlocked {
                    developerCard
                }
                sessionCard
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .navigationTitle("Settings")
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showingAddServer) {
            AddServerView()
                .environmentObject(appModel)
        }
        .sheet(isPresented: $showDeveloperSettings) {
            NavigationStack {
                DeveloperSettingsView()
            }
        }
    }

    private var accountCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Account")
                    .font(.headline)
                Text(appModel.isLoggedIn ? "Signed in" : "Signed out")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var serversCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Servers")
                        .font(.headline)
                    Spacer()
                    Text("\(appModel.servers.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if appModel.servers.isEmpty {
                    Text("No saved servers.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(appModel.servers.enumerated()), id: \.offset) { index, server in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(server.ip)
                                    .font(.subheadline.weight(.semibold))
                                Text("Port \(server.port)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                appModel.removeServers(at: IndexSet(integer: index))
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 6)
                    }
                }

                Button("Add Server") {
                    showingAddServer = true
                    Haptics.light()
                }
                .buttonStyle(SecondaryButtonStyle(color: .blue))
            }
        }
    }

    private var communityCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Community")
                    .font(.headline)

                Button("Join Discord") {
                    appModel.openDiscord()
                }
                .buttonStyle(SecondaryButtonStyle(color: .blue))
            }
        }
    }

    private var aboutCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("About")
                    .font(.headline)

                MetricRow(title: "Version", value: appVersion)
                buildRow
                MetricRow(title: "Language", value: "English")
                MetricRow(title: "Developer", value: "@ilovecatssm2")
            }
        }
    }

    private var developerCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Developer")
                    .font(.headline)

                Text("Advanced diagnostics and testing controls are enabled.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Open Developer Settings") {
                    showDeveloperSettings = true
                }
                .buttonStyle(SecondaryButtonStyle(color: .indigo))
            }
        }
    }

    private var sessionCard: some View {
        CardView {
            Button("Sign Out") {
                Task {
                    await appModel.logout()
                }
            }
            .buttonStyle(PrimaryButtonStyle(color: .red))
        }
    }

    private var buildRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("Build")
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(buildNumber)
                .multilineTextAlignment(.trailing)
        }
        .font(.body)
        .contentShape(Rectangle())
        .onTapGesture {
            processBuildTap()
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
    }

    private func processBuildTap() {
        let now = Date()
        buildTapTimestamps.append(now)
        buildTapTimestamps = buildTapTimestamps.filter { now.timeIntervalSince($0) <= 2.2 }

        if developerModeUnlocked {
            appModel.showSnackbar("Developer mode is already enabled.", style: .info)
            return
        }

        let remaining = max(0, 9 - buildTapTimestamps.count)
        if remaining == 0 {
            developerModeUnlocked = true
            buildTapTimestamps.removeAll()
            appModel.showSnackbar("Developer mode enabled.", style: .success)
        } else if buildTapTimestamps.count >= 3 {
            appModel.showSnackbar("\(remaining) taps remaining to enable Developer mode.", style: .info)
        }
    }
}

private struct DeveloperSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("dev_verbose_network_logs") private var verboseNetworkLogs = false
    @AppStorage("dev_show_network_timing") private var showNetworkTiming = true
    @AppStorage("dev_capture_response_body") private var captureResponseBody = false
    @AppStorage("dev_force_mock_bootstrap") private var forceMockBootstrap = false
    @AppStorage("dev_disable_status_polling") private var disableStatusPolling = false
    @AppStorage("dev_force_offline_ui") private var forceOfflineUI = false
    @AppStorage("dev_disable_haptics") private var disableHaptics = false
    @AppStorage("dev_enable_accessibility_debug") private var enableAccessibilityDebug = false
    @AppStorage("dev_use_high_contrast_cards") private var useHighContrastCards = false
    @AppStorage("dev_show_layout_bounds") private var showLayoutBounds = false
    @AppStorage("dev_enable_experimental_theme") private var enableExperimentalTheme = false
    @AppStorage("dev_enable_compact_metrics") private var enableCompactMetrics = false
    @AppStorage("dev_allow_background_refresh_logs") private var allowBackgroundRefreshLogs = true
    @AppStorage("dev_auto_open_remote_announcements") private var autoOpenRemoteAnnouncements = false
    @AppStorage("dev_force_error_snackbars") private var forceErrorSnackbars = false
    @AppStorage("dev_simulate_slow_network") private var simulateSlowNetwork = false
    @AppStorage("dev_use_staging_endpoints") private var useStagingEndpoints = false
    @AppStorage("dev_allow_untrusted_certificates") private var allowUntrustedCertificates = false
    @AppStorage("dev_override_poll_interval") private var overridePollInterval = false
    @AppStorage("dev_poll_interval_seconds") private var pollIntervalSeconds = 30.0
    @AppStorage("dev_request_timeout_seconds") private var requestTimeoutSeconds = 12.0
    @AppStorage("dev_max_retry_count") private var maxRetryCount = 2
    @AppStorage("dev_status_refresh_limit") private var statusRefreshLimit = 5
    @AppStorage("dev_simulated_latency_ms") private var simulatedLatencyMs = 0.0
    @AppStorage("dev_custom_offline_username") private var customOfflineUsername = ""
    @AppStorage("dev_debug_banner_text") private var debugBannerText = ""
    @AppStorage("dev_remote_bootstrap_cache_seconds") private var remoteBootstrapCacheSeconds = 120.0
    @AppStorage("dev_enable_announcement_preview") private var enableAnnouncementPreview = false
    @AppStorage("dev_announcement_preview_title") private var announcementPreviewTitle = "Maintenance notice"
    @AppStorage("dev_announcement_preview_body") private var announcementPreviewBody = "Server maintenance starts in 15 minutes."
    @AppStorage("dev_telemetry_sampling_rate") private var telemetrySamplingRate = 0.5
    @AppStorage("dev_force_light_mode") private var forceLightMode = false
    @AppStorage("dev_force_dark_mode") private var forceDarkMode = false
    @AppStorage("dev_show_internal_ids") private var showInternalIDs = false
    @AppStorage("dev_enable_debug_actions") private var enableDebugActions = false

    var body: some View {
        Form {
            Section("Diagnostics") {
                Toggle("Verbose network logs", isOn: $verboseNetworkLogs)
                Toggle("Show request timing", isOn: $showNetworkTiming)
                Toggle("Capture response body", isOn: $captureResponseBody)
                Toggle("Show internal IDs", isOn: $showInternalIDs)
                Toggle("Enable debug actions", isOn: $enableDebugActions)
                Toggle("Background refresh logs", isOn: $allowBackgroundRefreshLogs)
            }

            Section("Networking") {
                Toggle("Use staging endpoints", isOn: $useStagingEndpoints)
                Toggle("Allow untrusted certificates", isOn: $allowUntrustedCertificates)
                Toggle("Simulate slow network", isOn: $simulateSlowNetwork)
                Toggle("Override polling interval", isOn: $overridePollInterval)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Polling interval: \(Int(pollIntervalSeconds))s")
                    Slider(value: $pollIntervalSeconds, in: 5...120, step: 1)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Request timeout: \(Int(requestTimeoutSeconds))s")
                    Slider(value: $requestTimeoutSeconds, in: 5...60, step: 1)
                }

                Stepper("Retry count: \(maxRetryCount)", value: $maxRetryCount, in: 0...10)
                Stepper("Status refresh limit: \(statusRefreshLimit)", value: $statusRefreshLimit, in: 1...20)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Simulated latency: \(Int(simulatedLatencyMs)) ms")
                    Slider(value: $simulatedLatencyMs, in: 0...5000, step: 50)
                }
            }

            Section("Remote bootstrap") {
                Toggle("Force mock bootstrap", isOn: $forceMockBootstrap)
                Toggle("Auto-open announcements", isOn: $autoOpenRemoteAnnouncements)
                Toggle("Enable announcement preview", isOn: $enableAnnouncementPreview)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Cache duration: \(Int(remoteBootstrapCacheSeconds))s")
                    Slider(value: $remoteBootstrapCacheSeconds, in: 30...1800, step: 10)
                }

                TextField("Preview title", text: $announcementPreviewTitle)
                TextField("Preview body", text: $announcementPreviewBody, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section("UI and behavior") {
                Toggle("Disable status polling", isOn: $disableStatusPolling)
                Toggle("Force offline UI", isOn: $forceOfflineUI)
                Toggle("Disable haptics", isOn: $disableHaptics)
                Toggle("Accessibility debug overlay", isOn: $enableAccessibilityDebug)
                Toggle("High contrast cards", isOn: $useHighContrastCards)
                Toggle("Show layout bounds", isOn: $showLayoutBounds)
                Toggle("Experimental theme", isOn: $enableExperimentalTheme)
                Toggle("Compact metrics UI", isOn: $enableCompactMetrics)
                Toggle("Force error snackbars", isOn: $forceErrorSnackbars)
                Toggle("Force light mode", isOn: $forceLightMode)
                Toggle("Force dark mode", isOn: $forceDarkMode)
            }

            Section("Overrides") {
                TextField("Custom offline username", text: $customOfflineUsername)
                TextField("Debug banner text", text: $debugBannerText)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Telemetry sample rate: \(telemetrySamplingRate.formatted(.number.precision(.fractionLength(2))))")
                    Slider(value: $telemetrySamplingRate, in: 0...1, step: 0.05)
                }
            }
        }
        .navigationTitle("Developer Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}
