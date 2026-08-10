import Foundation

public enum GitHubCLIExecutableLocator {
    public static func candidates(pathEnvironment: String?) -> [URL] {
        let pathCandidates = (pathEnvironment ?? "")
            .split(separator: ":")
            .map { URL(fileURLWithPath: String($0)).appendingPathComponent("gh") }
        let knownCandidates = [
            URL(fileURLWithPath: "/opt/homebrew/bin/gh"),
            URL(fileURLWithPath: "/usr/local/bin/gh"),
            URL(fileURLWithPath: "/opt/local/bin/gh"),
        ]

        var seen: Set<String> = []
        return (pathCandidates + knownCandidates).filter { seen.insert($0.path).inserted }
    }

    public static func resolve(
        fileManager: FileManager = .default,
        pathEnvironment: String? = ProcessInfo.processInfo.environment["PATH"]
    ) -> URL? {
        candidates(pathEnvironment: pathEnvironment).first {
            fileManager.isExecutableFile(atPath: $0.path)
        }
    }
}

struct GitHubCLITransport {
    private let executableURL: URL?

    init(executableURL: URL? = GitHubCLIExecutableLocator.resolve()) {
        self.executableURL = executableURL
    }

    func executeGraphQL(requestBody: Data) async throws -> Data {
        guard let executableURL else {
            throw GitPingsError.unsupportedConfiguration(
                "GitHub CLI was not found. Install it with ‘brew install gh’, then run ‘gh auth login’."
            )
        }

        let process = Process()
        let input = Pipe()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = executableURL
        process.arguments = [
            "api",
            "graphql",
            "--hostname", "github.com",
            "--input", "-",
        ]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errors
        var environment = ProcessInfo.processInfo.environment
        environment["GH_PAGER"] = "cat"
        environment["PAGER"] = "cat"
        environment["NO_COLOR"] = "1"
        process.environment = environment

        do {
            try process.run()
            try input.fileHandleForWriting.write(contentsOf: requestBody)
            try input.fileHandleForWriting.close()
        } catch {
            throw GitPingsError.unsupportedConfiguration(
                "GitPings could not start GitHub CLI. Reinstall ‘gh’ or choose GitNotary GitHub App in Settings."
            )
        }

        async let responseRead = output.fileHandleForReading.readToEnd()
        async let errorRead = errors.fileHandleForReading.readToEnd()
        process.waitUntilExit()
        let responseData = try await responseRead ?? Data()
        let errorData = try await errorRead ?? Data()

        guard process.terminationStatus == 0 else {
            let message = String(data: errorData, encoding: .utf8)?.lowercased() ?? ""
            if message.contains("not logged")
                || message.contains("authentication")
                || message.contains("http 401")
            {
                throw GitPingsError.reauthorizationRequired(
                    "GitHub CLI is not signed in. Run ‘gh auth login’, then reconnect in Settings."
                )
            }
            if message.contains("http 403") || message.contains("resource protected") {
                throw GitPingsError.reauthorizationRequired(
                    "GitHub CLI cannot access this organization or repository. Check its organization and SSO authorization."
                )
            }
            throw GitPingsError.networkUnavailable
        }

        guard !responseData.isEmpty else { throw GitPingsError.networkUnavailable }
        return responseData
    }
}
