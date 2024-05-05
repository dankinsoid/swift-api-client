import Foundation
import HTTPTypes
import Metrics

func updateTotalRequestsMetrics(
	for request: HTTPRequestComponents
) {
	Counter(
		label: "api_client_requests_total",
		dimensions: dimensions(for: request)
	).increment()
}

func updateTotalResponseMetrics(
	for request: HTTPRequestComponents,
	successful: Bool
) {
	Counter(
		label: "api_client_responses_total",
		dimensions: dimensions(for: request) + [("successful", successful.description)]
	).increment()
	if !successful {
		updateTotalErrorsMetrics(for: request)
	}
}

func updateTotalErrorsMetrics(
	for request: HTTPRequestComponents?
) {
	Counter(
		label: "api_client_errors_total",
		dimensions: dimensions(for: request)
	).increment()
}

func updateHTTPMetrics(
	for request: HTTPRequestComponents?,
	status: HTTPResponse.Status?,
	duration: Double,
	successful: Bool
) {
	var dimensions = dimensions(for: request)
	dimensions.append(("status", status?.code.description ?? "undefined"))
	dimensions.append(("successful", successful.description))
	Timer(
		label: "http_client_request_duration_seconds",
		dimensions: dimensions,
		preferredDisplayUnit: .seconds
	)
	.recordSeconds(duration)
}

private func dimensions(
	for request: HTTPRequestComponents?
) -> [(String, String)] {
	[
		("method", request?.method.rawValue ?? "undefined"),
		("path", request?.urlComponents.path ?? "undefined"),
	]
}
