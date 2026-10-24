import Foundation
import Network
import NotchworkKit

// Connection state is confined to queue after start; stop synchronizes on that queue.
final class LocalServer: @unchecked Sendable {
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "Notchwork.local-api", qos: .utility)
    private var clients: [UUID: NWConnection] = [:]
    private let token = UUID().uuidString + UUID().uuidString
    private let file: URL
    private let handle: @MainActor (HostCommand) async -> HostResponse
    private let status: @MainActor (String) -> Void
    init(file: URL, handle: @escaping @MainActor (HostCommand) async -> HostResponse, status: @escaping @MainActor (String) -> Void) {
        self.file = file; self.handle = handle; self.status = status
    }
    func start() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        let listener = try NWListener(using: parameters)
        self.listener = listener
        listener.stateUpdateHandler = { [weak self, weak listener] state in
            guard let self else { return }
            switch state {
            case .ready:
                guard let port = listener?.port else { return }
                do {
                    let connection = HostConnection(endpoint: "http://127.0.0.1:\(port.rawValue)", token: self.token)
                    try FileManager.default.createDirectory(at: self.file.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: self.file.deletingLastPathComponent().path)
                    try JSONEncoder().encode(connection).write(to: self.file, options: .atomic)
                    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: self.file.path)
                    Task { @MainActor in self.status("Local API ready · 127.0.0.1:\(port.rawValue)") }
                } catch { listener?.cancel(); Task { @MainActor in self.status("Connection failed: " + error.localizedDescription) } }
            case .failed(let error): Task { @MainActor in self.status("Connection failed: " + error.localizedDescription) }
            default: break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self, self.clients.count < 8 else { connection.cancel(); return }
            let id = UUID(); self.clients[id] = connection
            connection.start(queue: self.queue)
            self.queue.asyncAfter(deadline: .now() + 5) { [weak self] in self?.finish(id) }
            self.receive(connection, id: id, buffer: Data())
        }
        listener.start(queue: queue)
    }
    private func finish(_ id: UUID) { clients.removeValue(forKey: id)?.cancel() }
    private func receive(_ connection: NWConnection, id: UUID, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, complete, error in
            guard let self, self.clients[id] != nil else { return }
            var buffer = buffer
            if let data { buffer.append(data) }
            guard buffer.count <= 70_000 else { self.reply(connection, id: id, code: 413, result: HostResponse(ok: false, message: "Request too large.")); return }
            if let boundary = buffer.range(of: Data("\r\n\r\n".utf8)) {
                guard boundary.lowerBound < 4096, let headers = String(data: buffer[..<boundary.lowerBound], encoding: .utf8) else { self.finish(id); return }
                let lines = headers.components(separatedBy: "\r\n")
                guard lines.first == "POST /v1/activity HTTP/1.1" else { self.reply(connection, id: id, code: 404, result: HostResponse(ok: false, message: "Use POST /v1/activity.")); return }
                var fields: [String: String] = [:]
                for line in lines.dropFirst() {
                    let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
                    guard parts.count == 2 else { self.finish(id); return }
                    let key = parts[0].lowercased()
                    guard fields[key] == nil else { self.finish(id); return }
                    fields[key] = parts[1].trimmingCharacters(in: .whitespaces)
                }
                guard fields["origin"] == nil else { self.reply(connection, id: id, code: 403, result: HostResponse(ok: false, message: "Browser-origin requests are not supported.")); return }
                guard fields["authorization"] == "Bearer " + self.token else { self.reply(connection, id: id, code: 401, result: HostResponse(ok: false, message: "Invalid local integration token.")); return }
                guard fields["transfer-encoding"] == nil, let count = fields["content-length"].flatMap(Int.init), (1...16_777_216).contains(count) else { self.reply(connection, id: id, code: 400, result: HostResponse(ok: false, message: "A bounded Content-Length is required.")); return }
                let body = buffer[boundary.upperBound...]
                if body.count >= count {
                    do {
                        let command = try JSONDecoder().decode(HostCommand.self, from: Data(body.prefix(count)))
                        Task { @MainActor in
                            let result = await self.handle(command)
                            self.queue.async { self.reply(connection, id: id, code: result.ok ? 200 : 400, result: result) }
                        }
                    } catch { self.reply(connection, id: id, code: 400, result: HostResponse(ok: false, message: "Invalid JSON activity.")) }
                    return
                }
            } else if buffer.count > 4096 { self.finish(id); return }
            if complete || error != nil { self.finish(id) }
            else { self.receive(connection, id: id, buffer: buffer) }
        }
    }
    private func reply(_ connection: NWConnection, id: UUID, code: Int, result: HostResponse) {
        guard clients[id] != nil, let body = try? JSONEncoder().encode(result) else { return }
        var data = Data("HTTP/1.1 \(code) \(code == 200 ? "OK" : "Error")\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n".utf8)
        data.append(body)
        connection.send(content: data, completion: .contentProcessed { [weak self] _ in self?.finish(id) })
    }
    func stop() {
        queue.sync {
            listener?.cancel(); listener = nil
            for client in clients.values { client.cancel() }; clients.removeAll()
            try? FileManager.default.removeItem(at: file)
        }
    }
}
