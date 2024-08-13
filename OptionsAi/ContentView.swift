import SwiftUI
import Firebase
import FirebaseFirestore

struct OptionsData: Identifiable, Codable {
    let id = UUID()
    let date: String
    let options: [Option]
}

struct Option: Identifiable, Codable {
    let id: String
    let percentage: Double

    var color: Color {
        return percentage > 30 ? .green : .red
    }

    enum CodingKeys: String, CodingKey {
        case id
        case percentage
    }
}

struct ContentView: View {
    @State private var optionsData: [OptionsData] = []
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationView {
            List {
                ForEach(optionsData, id: \.id) { dailyOptions in
                    VStack(alignment: .leading) {
                        Text("Options for \(dailyOptions.date)")
                            .font(.system(size: 20))
                            .fontWeight(.bold)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .padding(.bottom, 5)
                        
                        if dailyOptions.options.isEmpty {
                            Text("No Option Picks Today")
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                        } else {
                            // Sort options by percentage in descending order
                            let sortedOptions = dailyOptions.options.sorted { $0.percentage > $1.percentage }
                            
                            ForEach(sortedOptions) { option in
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
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 5)
                }
            }
            .listStyle(GroupedListStyle())
            .navigationBarTitle("QuinOptionsAi")
            .navigationBarItems(trailing: Button(action: {
                loadData()
            }, label: {
                Image(systemName: "arrow.clockwise")
            }))
            .onAppear {
                loadData()
            }
        }
    }

    private func loadData() {
        loadFirebaseData { result in
            switch result {
            case .success(let data):
                DispatchQueue.main.async {
                    self.optionsData = data
                }
            case .failure(let error):
                print("Failed to load data: \(error)")
            }
        }
    }

    func loadFirebaseData(completion: @escaping (Result<[OptionsData], Error>) -> Void) {
        let db = Firestore.firestore()
        db.collection("options_data")
            .order(by: "date", descending: true)
            .getDocuments { (querySnapshot, error) in
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
                            
                            // Print the decoded data to ensure it's correct
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
        return percentage > 30 ? Color(red: 25/255, green: 194/255, blue: 6/255) : Color(red: 251/255, green: 55/255, blue: 5/255)
    }
}

// Below is your preview provider
#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
