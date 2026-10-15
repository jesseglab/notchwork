import NotchworkKit

// Call whenever the app's state changes; refresh before ttl expires if it stays active.
func publishBuild(progress: Double) async throws {
    let client = try NotchworkClient()
    try await client.publish(NotchActivity(
        id: "build-main", sourceID: "com.example.builder", sourceName: "Builder",
        title: "Building · \(Int(progress * 100))%", symbol: "hammer.fill",
        preferredSide: .left, progress: progress, ttl: 60
    ))
}

func clearBuild() async throws {
    try await NotchworkClient().remove(sourceID: "com.example.builder", id: "build-main")
}
