import Firebase
import FirebaseFirestore
import SwiftUI

struct OptionsData: Identifiable, Codable {
    let id = UUID()
    let date: String
    var options: [Option]
}

struct Option: Identifiable, Codable {
    let id: String
    let percentage: Double
    let openPrice: Double?
    let highPrice: Double?

    var color: Color {
        return percentage > 30 ? .green : .red
    }

    enum CodingKeys: String, CodingKey {
        case id
        case percentage
        case openPrice = "open_price"
        case highPrice = "high_price"
    }
}

struct ContentView: View {
    @State private var optionsData: [OptionsData] = []
    @Environment(\.colorScheme) var colorScheme
    @State private var showingInstructions = false
    @State private var expandedDates: Set<String> = [] // Track expanded cards by date

    var body: some View {
        NavigationView {
            List {
                ForEach(optionsData, id: \.id) { dailyOptions in
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Options for \(dailyOptions.date)")
                                .font(.system(size: 20))
                                .fontWeight(.bold)
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            Spacer()
                            Button(action: {
                                toggleExpand(dailyOptions.id.uuidString)
                            }) {
                                Image(systemName: expandedDates.contains(dailyOptions.id.uuidString) ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.bottom, 5)

                        if dailyOptions.options.isEmpty {
                            Text("No Option Picks Today")
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                        } else {
                            let sortedOptions = dailyOptions.options.sorted { $0.percentage > $1.percentage }

                            ForEach(sortedOptions) { option in
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text(option.id)
                                            .lineLimit(1)
                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                        Spacer()
                                        Text("\(option.percentage, specifier: "%.2f")%")
                                            .foregroundColor(.white)
                                            .padding(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                                            .background(background(for: option.percentage))
                                            .cornerRadius(5)
                                    }
                                    .padding(.vertical, 5)

                                    // Display additional information for all options when the date is expanded
                                    if expandedDates.contains(dailyOptions.id.uuidString) {
                                        VStack(alignment: .leading, spacing: 5) {
                                            if let openPrice = option.openPrice {
                                                Text("Open Price: $\(openPrice, specifier: "%.2f")")
                                                    .foregroundColor(.gray)
                                            } else {
                                                Text("Open Price: Not Available")
                                                    .foregroundColor(.red)
                                            }

                                            if let highPrice = option.highPrice {
                                                Text("High Price: $\(highPrice, specifier: "%.2f")")
                                                    .foregroundColor(.gray)
                                            } else {
                                                Text("High Price: Not Available")
                                                    .foregroundColor(.red)
                                            }
                                        }
                                        .padding(.leading, 30) // Align with where the rows start
                                    }
                                }
                                .padding(.vertical, 5)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 5)
                }
            }
            .listStyle(PlainListStyle())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Text("QuinOptionsAi")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        Spacer()
                        Button(action: {
                            showingInstructions.toggle()
                        }, label: {
                            Image(systemName: "info.circle")
                        })
                        Button(action: {
                            loadData()
                        }, label: {
                            Image(systemName: "arrow.clockwise")
                        })
                    }
                }
            }
            .onAppear {
                loadData()
            }
            .sheet(isPresented: $showingInstructions) {
                InstructionsView()
            }
        }
    }

    private func toggleExpand(_ dateId: String) {
        if expandedDates.contains(dateId) {
            expandedDates.remove(dateId)
        } else {
            expandedDates.insert(dateId)
        }
    }

    private func loadData() {
        loadFirebaseData { result in
            switch result {
            case let .success(data):
                DispatchQueue.main.async {
                    self.optionsData = data
                }
            case let .failure(error):
                print("Failed to load data: \(error)")
            }
        }
    }

    func loadFirebaseData(completion: @escaping (Result<[OptionsData], Error>) -> Void) {
        let db = Firestore.firestore()
        db.collection("options_data")
            .order(by: "date", descending: true)
            .getDocuments { querySnapshot, error in
                if let error = error {
                    print("Error getting documents: \(error)")
                    completion(.failure(error))
                } else if let querySnapshot = querySnapshot {
                    print("Documents fetched: \(querySnapshot.documents.count)")
                    do {
                        var fetchedData: [OptionsData] = []
                        for document in querySnapshot.documents {
                            print("Document ID: \(document.documentID)")
                            print("Document data: \(document.data())")

                            let jsonData = try JSONSerialization.data(withJSONObject: document.data(), options: [])
                            let decoder = JSONDecoder()
                            let data = try decoder.decode(OptionsData.self, from: jsonData)

                            print("Decoded OptionsData: \(data)")
                            fetchedData.append(data)
                        }
                        completion(.success(fetchedData))
                    } catch {
                        print("Decoding error: \(error)")
                        completion(.failure(error))
                    }
                }
            }
    }

    private func background(for percentage: Double) -> Color {
        return percentage > 30 ? Color(red: 25 / 255, green: 194 / 255, blue: 6 / 255) : Color(red: 251 / 255, green: 55 / 255, blue: 5 / 255)
    }
}

struct InstructionsView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("📊 How QuinOptionsAi Works")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.bottom, 10)

                    Section(header: Text("🕰 Training Data")
                        .font(.headline)
                        .foregroundColor(.blue))
                    {
                        VStack(alignment: .leading) {
                            Text("• Our AI model trains on historical data from 1920 all the way up to the very morning it is running on.")
                            Text("• This extensive data set ensures accuracy and reliability.")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .frame(maxWidth: .infinity)
                    }

                    Divider()

                    Section(header: Text("⏰ Morning Update at 6:23 AM PST")
                        .font(.headline)
                        .foregroundColor(.blue))
                    {
                        VStack(alignment: .leading) {
                            Text("• Every weekday (Mon-Fri) at exactly 6:23 AM PST, the system processes the latest options data—7 minutes before the Options market opens in the USA.")
                            Text("• You have 7 minutes to review the picks and take action.")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .frame(maxWidth: .infinity)
                    }

                    Divider()

                    Section(header: Text("📲 Your Action Window")
                        .font(.headline)
                        .foregroundColor(.blue))
                    {
                        VStack(alignment: .leading) {
                            Text("• Use these 7 minutes to:")
                            Text("   • Add the options picks you are interested in to your Robinhood watchlist.")
                            Text("   • Place an offer to buy a call.")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .frame(maxWidth: .infinity)
                    }

                    Divider()

                    Section(header: Text("🔄 Ongoing Updates")
                        .font(.headline)
                        .foregroundColor(.blue))
                    {
                        VStack(alignment: .leading) {
                            Text("• The app captures a fresh set of options every weekday morning at 6:23 AM PST.")
                            Text("• After the initial update, the app refreshes the percentage for the following 3 hours and 30 minutes.")
                            Text("• This refresh calculates the open price of the underlying Call and the maximum executed sale that morning.")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .frame(maxWidth: .infinity)
                    }

                    Divider()

                    Section(header: Text("💡 Stay Ahead")
                        .font(.headline)
                        .foregroundColor(.blue))
                    {
                        VStack(alignment: .leading) {
                            Text("• With QuinOptionsAi, you're always 7 minutes ahead of the market, equipped with data-driven insights to make informed decisions.")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .frame(maxWidth: .infinity)
                    }

                    Divider()

                    Section(header: Text("📝 Disclosure")
                        .font(.headline)
                        .foregroundColor(.blue))
                    {
                        VStack(alignment: .leading) {
                            Text("• Remember, all investments carry risks. The data provided by QuinOptionsAi is for informational purposes only. Always do your own research before making any financial decisions.")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding()
            }
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .navigationBarTitle("Instructions", displayMode: .inline)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
