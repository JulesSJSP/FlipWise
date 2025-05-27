import SwiftUI

// MARK: - Model
struct Flashcard: Identifiable, Codable {
    let id = UUID()
    var question: String
    var answer: String
}

struct Game: Identifiable, Codable {
    let id = UUID()
    var title: String
    var cards: [Flashcard]
}

// MARK: - GameManager
class GameManager: ObservableObject {
    @Published var games: [Game] = []

    var username: String {
        UserDefaults.standard.string(forKey: "currentUsername") ?? "default"
    }

    init() {
        load()
    }

    func saveGame(_ game: Game) {
        if let index = games.firstIndex(where: { $0.id == game.id }) {
            games[index] = game
        } else {
            games.append(game)
        }
        save()
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(games) {
            UserDefaults.standard.set(encoded, forKey: "games_\(username)")
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: "games_\(username)"),
           let decoded = try? JSONDecoder().decode([Game].self, from: data) {
            games = decoded
        }
    }
}

// MARK: - AuthManager
class AuthManager: ObservableObject {
    func login(username: String, password: String) -> Bool {
        let users = UserDefaults.standard.dictionary(forKey: "users") as? [String: String] ?? [:]
        if users[username] == password {
            UserDefaults.standard.set(true, forKey: "isLoggedIn")
            UserDefaults.standard.set(username, forKey: "currentUsername")
            return true
        }
        return false
    }

    func register(username: String, password: String) -> Bool {
        var users = UserDefaults.standard.dictionary(forKey: "users") as? [String: String] ?? [:]
        if users[username] != nil {
            return false
        }
        users[username] = password
        UserDefaults.standard.set(users, forKey: "users")
        return true
    }

    func logout() {
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
        UserDefaults.standard.removeObject(forKey: "currentUsername")
    }
}

// MARK: - SavedGamesView
struct SavedGamesView: View {
    @ObservedObject var gameManager: GameManager
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(gameManager.games) { game in
                        NavigationLink(destination: PlayGameView(game: game)
                                        .navigationBarBackButtonHidden(true)) {
                            VStack(spacing: 16) {
                              
                                Image(systemName: "gamecontroller.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(
                                        Circle()
                                            .fill(Color(hex: "#FF6F61"))
                                            .frame(width: 70, height: 70)
                                    )
                                    .padding(.top, 8)
                                
                                Text(game.title)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal)
                                
                                Text("\(game.cards.count) kaarten")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.bottom, 8)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                            )
                            .padding(.horizontal, 8)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Opgeslagen spellen")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGray6).ignoresSafeArea())
        }
    }
}

// MARK: - PlayGameView
struct PlayGameView: View {
    let game: Game
    @State private var currentCardIndex = 0
    @State private var flipped: [UUID: Bool] = [:]
    @State private var isGameCompleted = false
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            Text(game.title)
                .font(.largeTitle)
                .bold()
                .padding(.top)

            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color(hex: "#ff5757"))
                    .frame(height: 120)
                    .overlay(
                        Text(flipped[game.cards[currentCardIndex].id] == true ? game.cards[currentCardIndex].answer : game.cards[currentCardIndex].question)
                            .foregroundColor(.white)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding()
                    )
                    .onTapGesture {
                        flipped[game.cards[currentCardIndex].id]?.toggle()
                    }
                    .onAppear {
                        flipped[game.cards[currentCardIndex].id] = false
                    }
                    .animation(.easeInOut, value: flipped[game.cards[currentCardIndex].id])
            }

            Spacer()

            HStack {
                Button(action: previousCard) {
                    Image(systemName: "arrow.left.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                }
                .disabled(currentCardIndex == 0)

                Spacer()

                Button(action: nextCard) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                }
            }
            .padding()

        }
        .padding()
        .navigationTitle(game.title)
        .alert("Gefeliciteerd!", isPresented: $isGameCompleted) {
            Button("OK") {
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Je hebt alle kaarten bekeken!")
        }
    }

    private func previousCard() {
        if currentCardIndex > 0 {
            currentCardIndex -= 1
            flipped[game.cards[currentCardIndex].id] = false
        }
    }

    private func nextCard() {
        if currentCardIndex < game.cards.count - 1 {
            currentCardIndex += 1
            flipped[game.cards[currentCardIndex].id] = false
        } else {
            isGameCompleted = true
        }
    }
}

// MARK: - HomeView
struct HomeView: View {
    @AppStorage("isLoggedIn") var isLoggedIn = false
    @State private var username = UserDefaults.standard.string(forKey: "currentUsername") ?? ""
    @StateObject var gameManager = GameManager()

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack {
                    Text("Welkom terug,")
                        .font(.title3)
                        .foregroundColor(.gray)
                    Text(username)
                        .font(.largeTitle.bold())
                        .foregroundColor(Color(hex: "#ff5757"))
                }

                NavigationLink(destination: SavedGamesView(gameManager: gameManager)) {
                    Text("📚 Opgeslagen spellen")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "#ff5757"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                NavigationLink(destination: NewGameView(gameManager: gameManager)) {
                    Text("➕ Nieuw spel maken")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "#ff5757"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                Spacer()

                Button("Uitloggen") {
                    isLoggedIn = false
                }
                .foregroundColor(.gray)
            }
            .padding()
        }
    }
}

// MARK: - NewGameView
struct NewGameView: View {
    @ObservedObject var gameManager: GameManager
    @Environment(\.presentationMode) var presentationMode

    @State private var title = ""
    @State private var cards: [Flashcard] = []
    @State private var question = ""
    @State private var answer = ""

    var body: some View {
        VStack {
            TextField("Titel van spel", text: $title)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.bottom)

            VStack {
                TextField("Vraag", text: $question)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Antwoord", text: $answer)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("➕ Voeg kaart toe") {
                    guard !question.isEmpty && !answer.isEmpty else { return }
                    cards.append(Flashcard(question: question, answer: answer))
                    question = ""
                    answer = ""
                }
                .padding(.top, 5)
            }

            List(cards) { card in
                VStack(alignment: .leading) {
                    Text("Q: \(card.question)")
                    Text("A: \(card.answer)").foregroundColor(.gray)
                }
            }

            Button("✅ Klaar") {
                let newGame = Game(title: title, cards: cards)
                gameManager.saveGame(newGame)
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
            .background(Color(hex: "#ff5757"))
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
        .navigationTitle("Nieuw spel")
        .background()
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - AppView
struct AppView: View {
    @AppStorage("isLoggedIn") var isLoggedIn = false

    var body: some View {
        if isLoggedIn {
            HomeView()
        } else {
            LoginView()
        }
    }
}

struct LoginView: View {
    @StateObject var auth = AuthManager()
    @State private var username = ""
    @State private var password = ""
    @State private var showError = false
    @State private var navigateToRegister = false
    @AppStorage("isLoggedIn") var isLoggedIn = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Login")
                    .font(.largeTitle)
                    .foregroundColor(Color(hex: "#ff5757"))

                TextField("Username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                if showError {
                    Text("Ongeldige gegevens").foregroundColor(.red)
                }

                Button("Login") {
                    if auth.login(username: username, password: password) {
                        isLoggedIn = true
                    } else {
                        showError = true
                    }
                }
                .padding()
                .background(Color(hex: "#ff5757"))
                .foregroundColor(.white)
                .cornerRadius(10)

                NavigationLink(destination: RegisterView(auth: auth), isActive: $navigateToRegister) {
                    Button("Nog geen account? Registreer") {
                        navigateToRegister = true
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - RegisterView
struct RegisterView: View {
    @ObservedObject var auth: AuthManager
    @Environment(\.presentationMode) var presentationMode
    @State private var newUsername = ""
    @State private var newPassword = ""
    @State private var showPassword = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Registreren")
                .font(.largeTitle)
                .foregroundColor(Color(hex: "#ff5757"))

            TextField("Nieuwe gebruikersnaam", text: $newUsername)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            HStack {
                Group {
                    if showPassword {
                        TextField("Nieuw wachtwoord", text: $newPassword)
                    } else {
                        SecureField("Nieuw wachtwoord", text: $newPassword)
                    }
                }
                .textFieldStyle(RoundedBorderTextFieldStyle())

                Button(action: { showPassword.toggle() }) {
                    Image(systemName: showPassword ? "eye" : "eye.slash")
                }
            }

            if let errorMessage = errorMessage {
                Text(errorMessage).foregroundColor(.red)
            }

            Button("Registreer") {
                if auth.register(username: newUsername, password: newPassword) {
                    presentationMode.wrappedValue.dismiss()
                } else {
                    errorMessage = "Gebruikersnaam bestaat al"
                }
            }
            .padding()
            .background(Color(hex: "#ff5757"))
            .foregroundColor(.white)
            .cornerRadius(10)

            Spacer()
        }
        .padding()
    }
}

#Preview {
    AppView()
}
