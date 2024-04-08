import Foundation
import SwiftAPIClient

@API
struct WeatherClient {

	init() {
		client = APIClient(baseURL: \.weatherURL.url)
			.path("v1")
			.bodyDecoder(jsonDecoder)
			.queryEncoder(.urlQuery(arrayEncodingStrategy: .commaSeparator))
	}

    /// **GET** https://api.open-meteo.com/v1/forecast
	@GET
	func forecast(
		@Query latitude: Double,
		@Query longitude: Double,
		@Query daily: [Forecast.DailyUnits.CodingKeys] = [.temperatureMin, .temperatureMax],
		@Query timezone: String = TimeZone.autoupdatingCurrent.identifier
	) async throws -> Forecast {}

    /// **GET** https://geocoding-api.open-meteo.com/v1/search
	@GET
	func search(@Query name: String) async throws -> GeocodingSearch {
		client.configs(\.weatherURL, .geocoding)
	}
}

extension WeatherClient {

	enum BaseURL: String {

		case base = "https://api.open-meteo.com"
		case geocoding = "https://geocoding-api.open-meteo.com"

		var url: URL { URL(string: rawValue)! }
	}
}

extension APIClient.Configs {

	var weatherURL: WeatherClient.BaseURL {
		get { self[\.weatherURL] ?? .base }
		set { self[\.weatherURL] = newValue }
	}
}

// MARK: - Private helpers

private let jsonDecoder: JSONDecoder = {
	let decoder = JSONDecoder()
	let formatter = DateFormatter()
	formatter.calendar = Calendar(identifier: .iso8601)
	formatter.dateFormat = "yyyy-MM-dd"
	formatter.timeZone = TimeZone(secondsFromGMT: 0)
	formatter.locale = Locale(identifier: "en_US_POSIX")
	decoder.dateDecodingStrategy = .formatted(formatter)
	return decoder
}()
