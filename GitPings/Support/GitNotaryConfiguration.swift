import Foundation

enum GitNotaryConfiguration {
    // GitHub App client IDs are public identifiers. Never add a client secret or
    // private key to the client-only application.
    static let clientID = "Iv23li1INlISnAzx1Nsj"
    static let publicURL = URL(string: "https://github.com/apps/gitnotary")!
    static let installationURL = publicURL.appending(path: "installations/new")
}
