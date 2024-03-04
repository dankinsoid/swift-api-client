import Foundation

public typealias AsyncValue<Res> = () async throws -> Res
