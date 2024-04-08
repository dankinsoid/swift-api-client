import SwiftUI

// MARK: - Search state

struct Search: Equatable {

	var results: [GeocodingSearch.Result] = []
	var resultForecastRequestInFlight: GeocodingSearch.Result?
	var searchQuery = ""
	var weather: Weather?

	struct Weather: Equatable {

		var id: GeocodingSearch.Result.ID
		var days: [Day]

		struct Day: Equatable {
			var date: Date
			var temperatureMax: Double
			var temperatureMaxUnit: String
			var temperatureMin: Double
			var temperatureMinUnit: String
		}
	}
}

// MARK: - Search actions

@Observable
final class SearchViewModel: @unchecked Sendable {

	var state = Search()
	private var searchQueryChangeDebouncedTask: Task<Void, Never>?
	private var searchResultTappedTask: Task<Void, Never>?

	@MainActor
	func searchQueryChanged(query: String) {
		guard query != state.searchQuery else { return }
		searchQueryChangeDebouncedTask?.cancel()
		if !query.isEmpty {
			searchQueryChangeDebouncedTask = Task {
				await self.searchQueryChangeDebounced()
			}
		} else {
			state.results = []
			state.weather = nil
		}
		state.searchQuery = query
	}

	@MainActor
	func searchResultTapped(location: GeocodingSearch.Result) {
		searchResultTappedTask?.cancel()
		searchResultTappedTask = Task {
			await self.searchResultTapped(location: location)
		}
	}

	@MainActor
	private func searchQueryChangeDebounced() async {
		try? await Task.sleep(nanoseconds: NSEC_PER_SEC / 3)
		guard !state.searchQuery.isEmpty, !Task.isCancelled else {
			return
		}
		do {
            let response = try await WeatherClient().search(name: state.searchQuery)
			try Task.checkCancellation()
			state.results = response.results ?? []
		} catch {
			guard !Task.isCancelled, !(error is CancellationError) else { return }
			state.results = []
		}
	}

	@MainActor
	private func searchResultTapped(location: GeocodingSearch.Result) async {
		state.resultForecastRequestInFlight = location
		defer { state.resultForecastRequestInFlight = nil }
		do {
			let forecast = try await WeatherClient().forecast(
				latitude: location.latitude,
				longitude: location.longitude
			)
			state.weather = Search.Weather(
				id: location.id,
				days: forecast.daily.time.indices.map {
					Search.Weather.Day(
						date: forecast.daily.time[$0],
						temperatureMax: forecast.daily.temperatureMax[$0],
						temperatureMaxUnit: forecast.dailyUnits.temperatureMax,
						temperatureMin: forecast.daily.temperatureMin[$0],
						temperatureMinUnit: forecast.dailyUnits.temperatureMin
					)
				}
			)
		} catch {
			state.weather = nil
		}
	}
}

// MARK: - Search feature view

struct SearchView: View {

	@State var vm = SearchViewModel()

	var body: some View {
		NavigationStack {
			VStack(alignment: .leading) {
				Text("Search weather app example")
					.padding()

				HStack {
					Image(systemName: "magnifyingglass")
					TextField(
						"New York, San Francisco, ...",
						text: Binding {
							vm.state.searchQuery
						} set: { text in
							vm.searchQueryChanged(query: text)
						}
					)
					.textFieldStyle(.roundedBorder)
					.autocapitalization(.none)
					.disableAutocorrection(true)
				}
				.padding(.horizontal, 16)

				List {
					ForEach(vm.state.results) { location in
						VStack(alignment: .leading) {
							Button {
								vm.searchResultTapped(location: location)
							} label: {
								HStack {
									Text(location.name)

									if vm.state.resultForecastRequestInFlight?.id == location.id {
										ProgressView()
									}
								}
							}

							if location.id == vm.state.weather?.id {
								weatherView(locationWeather: vm.state.weather)
							}
						}
					}
				}

				Button("Weather API provided by Open-Meteo") {
					UIApplication.shared.open(URL(string: "https://open-meteo.com/en")!)
				}
				.foregroundColor(.gray)
				.padding(.all, 16)
			}
			.navigationTitle("Search")
		}
	}

	@ViewBuilder
	func weatherView(locationWeather: Search.Weather?) -> some View {
		if let locationWeather {
			let days = locationWeather.days
				.enumerated()
				.map { idx, weather in formattedWeather(day: weather, isToday: idx == 0) }

			VStack(alignment: .leading) {
				ForEach(days, id: \.self) { day in
					Text(day)
				}
			}
			.padding(.leading, 16)
		}
	}
}

// MARK: - Private helpers

private func formattedWeather(day: Search.Weather.Day, isToday: Bool) -> String {
	let date =
		isToday
			? "Today"
			: dateFormatter.string(from: day.date).capitalized
	let min = "\(day.temperatureMin)\(day.temperatureMinUnit)"
	let max = "\(day.temperatureMax)\(day.temperatureMaxUnit)"

	return "\(date), \(min) – \(max)"
}

private let dateFormatter: DateFormatter = {
	let formatter = DateFormatter()
	formatter.dateFormat = "EEEE"
	return formatter
}()

// MARK: - SwiftUI previews

struct SearchView_Previews: PreviewProvider {

	static var previews: some View {
		SearchView()
	}
}
