import Foundation

public extension APIClient {

	/// Whether to report metrics.
	/// - Parameter reportMetrics: A boolean value indicating whether to report metrics.
	/// - Returns: An instance of `APIClient` configured with the specified metrics reporting setting.
	func reportMetrics(_ reportMetrics: Bool) -> APIClient {
		configs(\.reportMetrics, reportMetrics)
	}
}

public extension APIClient.Configs {

	/// Whether to report metrics.
	var reportMetrics: Bool {
		get { self[\.reportMetrics] ?? true }
		set { self[\.reportMetrics] = newValue }
	}
}
