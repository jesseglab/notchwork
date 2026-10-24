import Foundation

public struct HostConnection: Codable, Sendable {
    public var endpoint: String
    public var token: String
    public static var defaultFile: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Notchwork/connection.json")
    }
    public static func discover(at file: URL = defaultFile) throws -> Self {
        try JSONDecoder().decode(Self.self, from: Data(contentsOf: file))
    }
    public init(endpoint: String, token: String) { self.endpoint = endpoint; self.token = token }
}
public struct HostResponse: Codable, Sendable {
    public var ok: Bool
    public var message: String
    public var apiVersion: Int?
    public var events: [ActivityEvent]?
    public var capabilities: [String]?
    public init(ok: Bool, message: String, events: [ActivityEvent]? = nil, apiVersion: Int? = nil, capabilities: [String]? = nil) { self.ok = ok; self.message = message; self.events = events; self.apiVersion = apiVersion; self.capabilities = capabilities }
}
public struct SourceRegistration: Codable, Sendable {
    public var id: String
    public var name: String
    public var customInterface: Bool
    public init(id: String, name: String, customInterface: Bool = false) {
        self.id = id; self.name = name; self.customInterface = customInterface
    }
}
public struct HostCommand: Codable, Sendable {
    public var registration: SourceRegistration?
    public var operation: String
    public var activity: NotchActivity?
    public var sourceID: String?
    public var id: String?
    public var after: UInt64?
    public var wait: Bool?
    public init(operation: String, activity: NotchActivity? = nil, sourceID: String? = nil, id: String? = nil, after: UInt64? = nil, wait: Bool? = nil, registration: SourceRegistration? = nil) {
        self.registration = registration; self.operation = operation; self.activity = activity; self.sourceID = sourceID; self.id = id; self.after = after; self.wait = wait
    }
}
/// Use the same client from Swift apps or send its JSON protocol from any local process.
private final class LocalOnlyRedirectPolicy: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
public struct NotchworkClient: Sendable {
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration, delegate: LocalOnlyRedirectPolicy(), delegateQueue: nil)
    }()
    public let connection: HostConnection
    public init(connection: HostConnection) { self.connection = connection }
    public init() throws { connection = try .discover() }
    /// Use an isolated development host without changing the user's connection file.
    public init(connectionFile: URL) throws { connection = try .discover(at: connectionFile) }
    /// Check apiVersion before using operations introduced in a newer runtime.
    public func ping() async throws -> HostResponse {
        try await send(HostCommand(operation: "ping"))
    }
    @discardableResult public func register(_ source: SourceRegistration) async throws -> HostResponse {
        try await send(HostCommand(operation: "register", registration: source))
    }
    /// Call only in response to an explicit user action, never for a status update.
    @discardableResult public func present(sourceID: String, id: String) async throws -> HostResponse {
        try await send(HostCommand(operation: "present", sourceID: sourceID, id: id))
    }
    @discardableResult public func publish(_ activity: NotchActivity) async throws -> HostResponse {
        try activity.validate()
        return try await send(HostCommand(operation: "publish", activity: activity))
    }
    @discardableResult public func remove(sourceID: String, id: String) async throws -> HostResponse {
        try await send(HostCommand(operation: "remove", sourceID: sourceID, id: id))
    }
    public func events(sourceID: String, after: UInt64 = 0, wait: Bool = false) async throws -> [ActivityEvent] {
        try await send(HostCommand(operation: "events", sourceID: sourceID, after: after, wait: wait)).events ?? []
    }
    static func endpointURL(_ endpoint: String) throws -> URL {
        guard let base = URL(string: endpoint), base.scheme == "http", base.host == "127.0.0.1",
              let port = base.port, (1...65535).contains(port), base.user == nil, base.password == nil,
              base.query == nil, base.fragment == nil, ["", "/"].contains(base.path) else {
            throw ActivityError.invalid("The connection must point to the local Notchwork host.")
        }
        return base.appendingPathComponent("v1/activity")
    }
    public func send(_ command: HostCommand) async throws -> HostResponse {
        var request = URLRequest(url: try Self.endpointURL(connection.endpoint))
        request.httpMethod = "POST"; request.timeoutInterval = 5
        request.setValue("Bearer " + connection.token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(command)
        let (data, response) = try await Self.session.data(for: request)
        let decoded = try JSONDecoder().decode(HostResponse.self, from: data)
        guard (response as? HTTPURLResponse)?.statusCode == 200 && decoded.ok else { throw ActivityError.invalid(decoded.message) }
        return decoded
    }
}
