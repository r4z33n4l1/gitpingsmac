import SwiftUI

struct DashboardRootView: View {
    @Bindable var model: AppModel
    @State private var showingRepositoryPicker = false

    var body: some View {
        Group {
            if model.signedInAccount == nil {
                signInView
            } else {
                dashboard
            }
        }
        .alert("GitPings", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var dashboard: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(model.selectedRepositories) { repo in
                    HStack {
                        HStack(spacing: 9) {
                            Image(systemName: repo.isOrganizationOwned ? "building.2" : "person")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(repo.nameWithOwner)
                                    .lineLimit(1)
                                Text(repo.visibility == .private ? "Private" : "Public")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button {
                            model.toggleRepository(repo)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Stop monitoring \(repo.nameWithOwner)")
                    }
                }
                .overlay {
                    if model.selectedRepositories.isEmpty {
                        ContentUnavailableView(
                            "No repositories",
                            systemImage: "shippingbox",
                            description: Text("Add a repository to begin monitoring.")
                        )
                    }
                }

                HStack {
                    Button {
                        model.repositorySearch = ""
                        showingRepositoryPicker = true
                    } label: {
                        Label("Add Repository", systemImage: "plus")
                    }
                    Spacer()
                    Button {
                        model.reloadRepositories()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Reload repositories")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(10)
            }
            .navigationTitle("Repositories")
            .navigationSplitViewColumnWidth(min: 230, ideal: 280)
            .sheet(isPresented: $showingRepositoryPicker) {
                RepositoryPickerSheet(model: model, isPresented: $showingRepositoryPicker)
            }
        } detail: {
            VStack(spacing: 0) {
                if model.selectedRepositoryIDs.isEmpty {
                    ContentUnavailableView(
                        "Choose repositories",
                        systemImage: "shippingbox",
                        description: Text("Select one or more repositories in the sidebar to track their open pull requests.")
                    )
                } else if model.pullRequests.isEmpty && !model.isRefreshing {
                    ContentUnavailableView(
                        "No matching pull requests",
                        systemImage: "checkmark.circle",
                        description: Text("Try changing your PR filters in Settings.")
                    )
                } else {
                    List(model.pullRequests) { pr in
                        pullRequestRow(pr)
                    }
                    .listStyle(.inset)
                }

                Divider()
                HStack(spacing: 8) {
                    if model.isRefreshing { ProgressView().controlSize(.small) }
                    Text(model.statusMessage)
                    Spacer()
                    if let refreshed = model.lastSuccessfulRefreshAt {
                        Text("Last refresh \(refreshed, style: .relative)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .frame(height: 34)
            }
            .navigationTitle("Pull Requests")
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        model.sendTestNotchNotification()
                    } label: {
                        Label("Test Notch", systemImage: "bell.and.waves.left.and.right")
                    }
                    .help("Preview a notch notification")

                    Button {
                        model.refresh()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(model.isRefreshing)
                }
            }
        }
    }

    private func pullRequestRow(_ pr: PullRequestSummary) -> some View {
        HStack(alignment: .top, spacing: 12) {
            stateIcon(pr)
                .font(.title3)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("\(pr.repositoryNameWithOwner) #\(pr.number)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("@\(pr.authorLogin)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Text(pr.title)
                    .fontWeight(.medium)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    StatusCapsule(text: ciLabel(pr.ciState), color: ciColor(pr.ciState))
                    StatusCapsule(text: mergeLabel(pr.mergeState), color: mergeColor(pr.mergeState))
                    Text("\(pr.headRefName) → \(pr.baseRefName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Button {
                model.togglePin(pr)
            } label: {
                Image(systemName: model.pinnedIDs.contains(pr.id) ? "pin.fill" : "pin")
            }
            .buttonStyle(.borderless)
            .help(model.pinnedIDs.contains(pr.id) ? "Unpin" : "Pin to menu bar")

            Button {
                model.openPullRequest(id: pr.id)
            } label: {
                Image(systemName: "arrow.up.right.square")
            }
            .buttonStyle(.borderless)
            .help("Open on GitHub")
        }
        .padding(.vertical, 7)
    }

    @ViewBuilder
    private func stateIcon(_ pr: PullRequestSummary) -> some View {
        if pr.ciState == .failing || pr.mergeState == .conflicting {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
        } else if pr.ciState == .passing && pr.mergeState == .mergeable {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        } else {
            Image(systemName: "clock.fill").foregroundStyle(.orange)
        }
    }

    private var signInView: some View {
        VStack(spacing: 20) {
            Image(systemName: "dot.radiowaves.up.forward")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(.tint)
            VStack(spacing: 7) {
                Text("Keep every pull request in sight")
                    .font(.largeTitle.bold())
                Text("GitPings watches CI and mergeability directly from your Mac, then surfaces changes in the menu bar and around the notch.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 520)
            }

            switch model.authState {
            case .deviceFlowPending(let code, let url):
                VStack(spacing: 10) {
                    Text("Enter this code on GitHub")
                        .font(.headline)
                    Text(code)
                        .font(.system(.title2, design: .monospaced, weight: .bold))
                        .textSelection(.enabled)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                    Link("Open GitHub Device Login", destination: url)
                    Button("Cancel", role: .cancel) { model.cancelSignIn() }
                }
            case .needsReauthorization(let reason):
                Text(reason).foregroundStyle(.red)
                Button("Sign in again") { model.beginSignIn() }
                    .buttonStyle(.borderedProminent)
            default:
                Button("Sign in with GitHub") { model.beginSignIn() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                if model.oauthClientID.isEmpty {
                    Text("A GitHub OAuth client ID is required for device login. Add it in Settings → Account, or launch with GITPINGS_GITHUB_CLIENT_ID.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 460)
                }
            }
        }
        .padding(48)
        .frame(minWidth: 720, minHeight: 500)
    }

    private func ciLabel(_ state: CIState) -> String {
        switch state {
        case .passing: "CI passing"
        case .pending: "CI pending"
        case .failing: "CI failing"
        case .noChecks: "No checks"
        case .unknown: "CI unknown"
        }
    }

    private func mergeLabel(_ state: MergeState) -> String {
        switch state {
        case .mergeable: "Mergeable"
        case .blocked: "Blocked"
        case .conflicting: "Conflicts"
        case .checking: "Checking"
        case .unknown: "Unknown"
        }
    }

    private func ciColor(_ state: CIState) -> Color {
        switch state {
        case .passing: .green
        case .failing: .red
        case .pending: .orange
        case .noChecks, .unknown: .secondary
        }
    }

    private func mergeColor(_ state: MergeState) -> Color {
        switch state {
        case .mergeable: .green
        case .conflicting: .red
        case .blocked, .checking: .orange
        case .unknown: .secondary
        }
    }
}

private struct RepositoryPickerSheet: View {
    @Bindable var model: AppModel
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add Repositories")
                        .font(.title2.bold())
                    Text("Choose which repositories GitPings should monitor.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { isPresented = false }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(18)

            Divider()

            List(model.filteredRepositories) { repo in
                Button {
                    model.toggleRepository(repo)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: model.selectedRepositoryIDs.contains(repo.id)
                              ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(model.selectedRepositoryIDs.contains(repo.id)
                                             ? Color.accentColor : Color.secondary)
                        Image(systemName: repo.isOrganizationOwned ? "building.2" : "person")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(repo.nameWithOwner)
                            Text(repo.visibility == .private ? "Private" : "Public")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $model.repositorySearch, prompt: "Search all repositories")

            Divider()
            HStack {
                Text("\(model.selectedRepositoryIDs.count) selected")
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    model.reloadRepositories()
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
            }
            .font(.caption)
            .padding(12)
        }
        .frame(minWidth: 560, minHeight: 520)
    }
}

private struct StatusCapsule: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }
}
