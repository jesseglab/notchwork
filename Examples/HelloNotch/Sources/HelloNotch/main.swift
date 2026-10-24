import Foundation
import NotchworkKit

@main struct HelloNotch {
    static func main() async throws {
        let client: NotchworkClient
        if let path = ProcessInfo.processInfo.environment["NOTCHWORK_CONNECTION_FILE"] {
            client = try NotchworkClient(connectionFile: URL(fileURLWithPath: path))
        } else {
            client = try NotchworkClient()
        }
        let response = try await client.ping()
        guard (response.apiVersion ?? 0) >= 2 else {
            throw ActivityError.invalid("HelloNotch requires Notchwork API 2. Build and start the current runtime.")
        }
        let source = "com.example.hello-notch"
        try await client.register(.init(id: source, name: "Hello Notch"))
        let card = NotchActivity(id: "hello", sourceID: source, sourceName: "Hello Notch",
                                 title: "Hello from Swift", priority: .low, ttl: 30)
        try await client.publish(card)
        do {
            if CommandLine.arguments.contains("--present") {
                try await client.present(sourceID: source, id: card.id)
            }
            print("Published for 10 seconds. The app owns the content; Notchwork owns the window.")
            try await Task.sleep(nanoseconds: 10_000_000_000)
        } catch {
            _ = try? await client.remove(sourceID: source, id: card.id)
            throw error
        }
        try await client.remove(sourceID: source, id: card.id)
        print("Removed. If interrupted, the 30-second TTL handles cleanup.")
    }
}
