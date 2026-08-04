@MainActor
protocol PolishEngine {
    func polish(_ raw: String) async throws -> String
}
