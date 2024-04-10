@preconcurrency import Foundation

public typealias AsyncThrowingValue<Res> = () async throws -> Res
