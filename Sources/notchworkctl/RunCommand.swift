import Foundation
import Darwin
import NotchworkKit

struct RunCommand {
    static func run(_ arguments: [String], connectionFile: URL) async throws -> Int32 {
        guard let separator = arguments.firstIndex(of: "--"), separator + 1 < arguments.count else {
            throw ActivityError.invalid("Usage: notchworkctl run [--name NAME] -- COMMAND [ARGUMENTS…]")
        }
        let options = Array(arguments[..<separator])
        guard options.isEmpty || (options.count == 2 && options[0] == "--name") else {
            throw ActivityError.invalid("Only --name NAME is accepted before --.")
        }
        let command = Array(arguments[(separator + 1)...])
        let name = options.isEmpty ? URL(fileURLWithPath: command[0]).lastPathComponent : options[1]
        guard !name.isEmpty, name.count <= 100 else { throw ActivityError.invalid("Use a name of 1–100 characters.") }
        let id = UUID().uuidString
        let start = Date()
        func activity(exit: Int32? = nil) -> NotchActivity {
            let title = exit.map { $0 == 0 ? "\(name) · complete" : "\(name) · failed" } ?? "\(name) · running"
            return NotchActivity(id: id, sourceID: "app.notchwork.commands", sourceName: "Builds & commands", title: title,
                subtitle: exit.map { "Exit \($0) · \(Int(Date().timeIntervalSince(start)))s" } ?? "Command in progress",
                symbol: exit.map { $0 == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill" } ?? "hammer.fill",
                priority: exit.map { $0 == 0 ? .normal : .urgent } ?? .normal,
                preferredSide: .right, details: ["Output stays in your terminal."], ttl: exit == nil ? 60 : 30)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError
        // Forward external termination to the child; terminal-generated signals also reach its process group.
        let signals = [SIGINT, SIGTERM, SIGHUP].map { signalNumber -> DispatchSourceSignal in
            Darwin.signal(signalNumber, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .global(qos: .utility))
            source.setEventHandler {
                if process.isRunning {
                    let pid = process.processIdentifier
                    Darwin.kill(getpgid(pid) == pid ? -pid : pid, signalNumber)
                }
            }
            source.resume()
            return source
        }
        defer { signals.forEach { $0.cancel() } }
        // Connection discovery is repeated so a restarted host can reconnect during a long build.
        let publishing = Task {
            var warned = false
            while !Task.isCancelled {
                do { try await NotchworkClient(connection: .discover(at: connectionFile)).publish(activity()) }
                catch {
                    if !warned && !Task.isCancelled {
                        FileHandle.standardError.write(Data("Notchwork is unavailable; the command continues normally.\n".utf8))
                        warned = true
                    }
                }
                do { try await Task.sleep(nanoseconds: 20_000_000_000) } catch { break }
            }
        }
        let result: Int32
        do {
            result = try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { child in
                    continuation.resume(returning: child.terminationReason == .uncaughtSignal ? 128 + child.terminationStatus : child.terminationStatus)
                }
                do { try process.run() } catch { continuation.resume(throwing: error) }
            }
        } catch {
            publishing.cancel(); await publishing.value
            _ = try? await NotchworkClient(connection: .discover(at: connectionFile)).publish(activity(exit: 127))
            throw error
        }
        publishing.cancel(); await publishing.value
        _ = try? await NotchworkClient(connection: .discover(at: connectionFile)).publish(activity(exit: result))
        return result
    }
}
