import SwiftUI

struct DashboardRootView: View {
    @Bindable var model: AppModel

    var body: some View {
        NavigationSplitView {
            List {
                Section("Repositories") {
                    ForEach(model.repositories) { repo in
                        Label {
                            VStack(alignment: .leading) {
                                Text(repo.nameWithOwner)
                                Text(repo.visibility == .private ? "Private" : "Public")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: repo.isOrganizationOwned ? "building.2" : "person")
                        }
                    }
                }
            }
            .navigationTitle("GitPings")
        } detail: {
            List(model.pullRequests) { pr in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(pr.repositoryNameWithOwner) #\(pr.number)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(pr.title)
                    Text("CI: \(pr.ciState.rawValue) · Merge: \(pr.mergeState.rawValue) · @\(pr.authorLogin)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
            .navigationTitle("Tracked pull requests")
            .safeAreaInset(edge: .bottom) {
                Text(model.statusMessage)
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(.bar)
            }
        }
    }
}
