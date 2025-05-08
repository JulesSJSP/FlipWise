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
            updateStreak()
            return true
        }
        return false
    }

    func register(username: String, password: String) -> Bool {
        var users = UserDefaults.standard.dictionary(forKey: "users") as? [String: String] ?? [:]
        if users[username] != nil {
            // Gebruiker bestaat al
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

    private func updateStreak() {
        let today = Calendar.current.startOfDay(for: Date())
        let lastDate = UserDefaults.standard.object(forKey: "lastLoginDate") as? Date ?? Date.distantPast
        if Calendar.current.isDateInToday(lastDate) { return }

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let currentStreak = UserDefaults.standard.integer(forKey: "streak")
        if Calendar.current.isDate(lastDate, inSameDayAs: yesterday) {
            UserDefaults.standard.set(currentStreak + 1, forKey: "streak")
        } else {
            UserDefaults.standard.set(1, forKey: "streak")
        }
        UserDefaults.standard.set(today, forKey: "lastLoginDate")
    }
}
struct EditGameView: View {
    @ObservedObject var gameManager: GameManager
    @State var game: Game
    @State private var newQuestion = ""
    @State private var newAnswer = ""

    var body: some View {
        VStack {
            TextField("Titel van spel", text: $game.title)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.bottom)

            VStack {
                TextField("Vraag", text: $newQuestion)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Antwoord", text: $newAnswer)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("➕ Voeg kaart toe") {
                    guard !newQuestion.isEmpty && !newAnswer.isEmpty else { return }
                    game.cards.append(Flashcard(question: newQuestion, answer: newAnswer))
                    newQuestion = ""
                    newAnswer = ""
                }
                .padding(.top, 5)
            }

            List(game.cards) { card in
                VStack(alignment: .leading) {
                    HStack {
                        Text("Q: \(card.question)")
                        Spacer()
                        Button(action: {
                            if let index = game.cards.firstIndex(where: { $0.id == card.id }) {
                                game.cards.remove(at: index)
                            }
                        }) {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                        }
                    }
                    Text("A: \(card.answer)").foregroundColor(.gray)
                    Button(action: {
                        newQuestion = card.question
                        newAnswer = card.answer
                    }) {
                        Text("Bewerk kaart")
                            .foregroundColor(.blue)
                    }
                }
            }

            Button("✅ Opslaan") {
                gameManager.saveGame(game)
            }
            .padding()
            .background(Color(hex: "#ff5757"))
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
        .navigationTitle("Bewerk spel")
    }
}

struct SavedGamesView: View {
    @ObservedObject var gameManager: GameManager

    var body: some View {
        List(gameManager.games) { game in
            HStack {
                NavigationLink(destination: PlayGameView(game: game)) {
                    Text(game.title)
                }
                
                Spacer()
                
                NavigationLink(destination: EditGameView(gameManager: gameManager, game: game)) {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundColor(.blue)
                }
            }
        }
        .navigationTitle("Opgeslagen spellen")
    }
}

// MARK: - PlayGameView
struct PlayGameView: View {
    let game: Game
    @State private var flipped: [UUID: Bool] = [:]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(game.cards) { card in
                    ZStack {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color(hex: "#ff5757"))
                            .frame(height: 120)
                            .overlay(
                                Text(flipped[card.id] == true ? card.answer : card.question)
                                    .foregroundColor(.white)
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                    .padding()
                            )
                            .onTapGesture {
                                flipped[card.id]?.toggle()
                            }
                            .onAppear {
                                flipped[card.id] = false
                            }
                            .animation(.easeInOut, value: flipped[card.id])
                    }
                }
            }
            .padding()
        }
        .navigationTitle(game.title)
    }
}

// MARK: - HomeView
struct HomeView: View {
    @AppStorage("isLoggedIn") var isLoggedIn = false
    @State private var username = UserDefaults.standard.string(forKey: "currentUsername") ?? ""
    @State private var streak = UserDefaults.standard.integer(forKey: "streak")
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

                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("Streak: \(streak) dag(en)")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

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
