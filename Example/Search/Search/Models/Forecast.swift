@preconcurrency import Foundation
import SwiftAPIClient

struct Forecast: Decodable, Equatable, Sendable {

	var daily: Daily
	var dailyUnits: DailyUnits

	enum CodingKeys: String, CodingKey {

		case daily
		case dailyUnits = "daily_units"
	}

	struct Daily: Decodable, Equatable, Sendable {

		var temperatureMax: [Double]
		var temperatureMin: [Double]
		var time: [Date]

		enum CodingKeys: String, CodingKey {
			case temperatureMax = "temperature_2m_max"
			case temperatureMin = "temperature_2m_min"
			case time
		}
	}

	struct DailyUnits: Decodable, Equatable, Sendable {

		var temperatureMax: String
		var temperatureMin: String

		enum CodingKeys: String, CodingKey, Codable {
			case temperatureMax = "temperature_2m_max"
			case temperatureMin = "temperature_2m_min"
		}
	}
}

// MARK: - Mocks

extension Forecast: Mockable {

	static let mock = Forecast(daily: .mock, dailyUnits: .mock)
}

extension Forecast.Daily: Mockable {

	static let mock = Forecast.Daily(
		temperatureMax: [17, 20, 25],
		temperatureMin: [10, 12, 15],
		time: [0, 86400, 172_800].map(Date.init(timeIntervalSince1970:))
	)
}

extension Forecast.DailyUnits: Mockable {

	static let mock = Forecast.DailyUnits(temperatureMax: "°C", temperatureMin: "°C")
}
