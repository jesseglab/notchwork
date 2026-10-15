import Foundation
import NotchworkKit

@main struct CLI {
    static func main() async {
        do {
            var args = Array(CommandLine.arguments.dropFirst())
            var connectionFile = HostConnection.defaultFile
            if args.first == "--connection", args.count >= 3 { connectionFile = URL(fileURLWithPath: args[1]); args.removeFirst(2) }
            guard let verb = args.first else { print("Usage: notchworkctl [--connection FILE] publish activity.json | remove SOURCE ID | ping | run [--name NAME] -- COMMAND [ARGS…]"); return }
            if verb == "run" { exit(try await RunCommand.run(Array(args.dropFirst()), connectionFile: connectionFile)) }
            let client = NotchworkClient(connection: try .discover(at: connectionFile))
            let result: HostResponse
            switch verb {
            case "publish":
                guard args.count == 2 else { throw ActivityError.invalid("Specify a JSON activity file, or - for stdin.") }
                let data = args[1] == "-" ? FileHandle.standardInput.readDataToEndOfFile() : try Data(contentsOf: URL(fileURLWithPath: args[1]))
                result = try await client.publish(JSONDecoder().decode(NotchActivity.self, from: data))
            case "remove":
                guard args.count == 3 else { throw ActivityError.invalid("Specify sourceID and activity id.") }
                result = try await client.remove(sourceID: args[1], id: args[2])
            case "ping": result = try await client.send(HostCommand(operation: "ping"))
            default: throw ActivityError.invalid("Unknown command.")
            }
            print(result.message)
        } catch { FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8)); exit(1) }
    }
}
