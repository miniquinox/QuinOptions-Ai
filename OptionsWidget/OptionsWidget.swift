import WidgetKit
import SwiftUI
import Firebase
import FirebaseFirestore

// MARK: - Model
struct OptionsData: Identifiable, Codable {
    let id = UUID()
    let date: String
    let options: [Option]
}

struct Option: Identifiable, Codable {
    let id: String
    let percentage: Double
    var symbol: String {
        return percentage > 40 ? "arrow.up.right" : "arrow.down.right"
    }
    var color: Color {
        return percentage < 30 ? Color(red: 251/255, green: 55/255, blue: 5/255) : Color(red: 25/255, green: 194/255, blue: 6/255)
    }
}

// MARK: - Data Provider Function
func loadFirebaseData(completion: @escaping (Result<[OptionsData], Error>) -> Void) {
    let db = Firestore.firestore()
    db.collection("options_data")
        .order(by: "date", descending: true)
        .getDocuments { (querySnapshot, error) in
            if let error = error {
                completion(.failure(error))
            } else if let querySnapshot = querySnapshot {
                do {
                    var fetchedData: [OptionsData] = []
                    for document in querySnapshot.documents {
                        let jsonData = try JSONSerialization.data(withJSONObject: document.data(), options: [])
                        let decoder = JSONDecoder()
                        let data = try decoder.decode(OptionsData.self, from: jsonData)
                        fetchedData.append(data)
                    }
                    completion(.success(fetchedData))
                } catch {
                    completion(.failure(error))
                }
            }
        }
}

// MARK: - View Extension for Background Compatibility
extension View {
    @ViewBuilder
    func widgetBackground<T: View>(_ backgroundView: T) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) { backgroundView }
        } else {
            background(backgroundView)
        }
    }
}

// MARK: - Widget Entry
struct SimpleEntry: TimelineEntry {
    let date: Date
    let optionsData: [OptionsData]
}

// MARK: - Widget Entry View
struct OptionsWidgetEntryView: View {
    var entry: SimpleEntry
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let latestOption = entry.optionsData.first {
                HStack {
                    Text("OptionsAi by Quino")
                        .font(.system(size: 20))
                        .fontWeight(.bold)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    Text("- \(latestOption.date)")
                        .font(.system(size: 16))
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 2)
                .padding(.top)

                if latestOption.options.isEmpty {
                    HStack {
                        Text("No Option Picks Today")
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        Spacer()
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 4)
                    Spacer()

                } else {
                    // Sort options by percentage in descending order
                    let sortedOptions = latestOption.options.sorted { $0.percentage > $1.percentage }
                    // Select the top 3 for medium and top 8 for large widgets
                    let displayedOptions = Array(sortedOptions.prefix(widgetFamily == .systemLarge ? 8 : 3))

                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(displayedOptions.indices, id: \.self) { optionIndex in
                            HStack {
                                Text(displayedOptions[optionIndex].id)
                                    .font(.system(size: 16))
                                    .lineLimit(1)
                                Spacer()
                                Text("\(displayedOptions[optionIndex].percentage, specifier: "%.2f")%")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .padding(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                                    .background(displayedOptions[optionIndex].color)
                                    .cornerRadius(5)
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 4)

                            if optionIndex < displayedOptions.count - 1 {
                                Divider()
                                    .background(colorScheme == .dark ? .white : .gray)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                    Spacer()
                }
            }
        }
        .widgetBackground(colorScheme == .dark ? Color.black : Color.white)
        .cornerRadius(10)
        .edgesIgnoringSafeArea(.all)
        .padding(.horizontal)
    }
}

// MARK: - Provider
struct Provider: TimelineProvider {

    // Ensure Firebase is configured only once
    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), optionsData: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        loadFirebaseData { result in
            switch result {
            case .success(let optionsData):
                let entry = SimpleEntry(date: Date(), optionsData: optionsData)
                completion(entry)
            case .failure(_):
                let entry = SimpleEntry(date: Date(), optionsData: [])
                completion(entry)
            }
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        loadFirebaseData { result in
            let currentDate = Date()
            let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
            let entries: [SimpleEntry]

            switch result {
            case .success(let optionsData):
                entries = [SimpleEntry(date: currentDate, optionsData: optionsData)]
            case .failure(_):
                entries = [SimpleEntry(date: currentDate, optionsData: [])]
            }

            let timeline = Timeline(entries: entries, policy: .after(refreshDate))
            completion(timeline)
        }
    }
}

// MARK: - Widget
struct OptionsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.optimiz3d.OptionsApp.OptionsWidget", provider: Provider()) { entry in
            OptionsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Options Widget")
        .description("This is an example widget.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Widget Previews
struct OptionsWidget_Previews: PreviewProvider {
    static var previews: some View {
        OptionsWidgetEntryView(entry: SimpleEntry(date: Date(), optionsData: []))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .environment(\.colorScheme, .dark)
    }
}
