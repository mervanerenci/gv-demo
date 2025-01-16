import Debug "mo:base/Debug";
import Array "mo:base/Array";
import Time "mo:base/Time";
import Trie "mo:base/Trie";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Int "mo:base/Int";
import Principal "mo:base/Principal";
import Option "mo:base/Option";



actor MemoryGame {

    // Oda bilgileri
    type Room = {
        players: [Player];
        gameBoard: [Card];
        currentPlayer: Principal;
        gameStarted: Bool;
    };

    // Oyuncu bilgileri
    type Player = {
        id: Principal;
        score: Nat;
    };

    // Kart bilgileri
    type Card = {
        id: Nat;
        value: Text;
        revealed: Bool;
    };

    // Tüm odaları tutan harita
    var rooms: Trie.Trie<Text, Room> = Trie.empty();

    // Oda oluşturma
    public shared(msg) func createRoom(): async Text {
        let playerId = msg.caller;
        let roomId = "room_" # Nat.toText(Int.abs(Time.now()));
        let existingRoom = Trie.get(rooms, keyText(roomId), Text.equal);
        
        // Create initial game board with pairs of cards
        let symbols = ["🎮", "🎲", "🎯", "🎪", "🎨", "🎭", "🎸", "🎺"];
        let initialBoard = Array.tabulate<Card>(16, func(i) {
            {
                id = i;
                value = symbols[i / 2];  // Each symbol appears twice
                revealed = false;
            }
        });
        
        switch (existingRoom) {
            case (?_) return "Bu oda zaten mevcut.";
            case null {
                let newRoom = {
                    players = [{ id = playerId; score = 0 }];
                    gameBoard = initialBoard;
                    currentPlayer = playerId;
                    gameStarted = true;  // Start game immediately for testing
                };

                rooms := Trie.put(
                    rooms,
                    keyText(roomId),
                    Text.equal,
                    newRoom
                ).0;

                return roomId;
            };
        };
    };

    // Odaya katılma
    public shared(msg) func joinRoom(roomId: Text): async Text {
        let playerId = msg.caller;
        let roomOpt = Trie.get(rooms, keyText(roomId), Text.equal);
        switch (roomOpt) {
            case (null) {
                return "Oda bulunamadı.";
            };
            case (?room) {
                if (room.players.size() >= 2) {
                    return "Oda zaten dolu.";
                };
                if (Array.find<Player>(room.players, func(p: Player) { p.id == playerId }) != null) {
                    return "Bu oyuncu zaten odada.";
                };
                let updatedPlayers = Array.tabulate<Player>(
                    room.players.size() + 1,
                    func(i) {
                        if (i < room.players.size()) {
                            room.players[i]
                        } else {
                            { id = playerId; score = 0 }
                        }
                    }
                );
                let updatedRoom = {
                    players = updatedPlayers;
                    gameBoard = room.gameBoard;
                    currentPlayer = room.currentPlayer;
                    gameStarted = room.gameStarted;
                };

                rooms := Trie.put(
                    rooms,
                    keyText(roomId),
                    Text.equal,
                    updatedRoom
                ).0;

                if (room.players.size() == 2) {
                    startGame(roomId);
                };

                // Debug.print(playerId # " odaya katıldı: " # roomId);
                return "Odaya başarıyla katıldınız.";
            };
        };
    };

    // Oyunu başlat
    private func startGame(roomId: Text) {
        let roomOpt = Trie.get(rooms, keyText(roomId), Text.equal);
        switch (roomOpt) {
            case null {};
            case (?room) {
                Debug.print("Oyun başlıyor... Oda: " # roomId);
                let updatedRoom = {
                    players = room.players;
                    gameBoard = room.gameBoard;
                    currentPlayer = room.players[0].id;
                    gameStarted = true;
                };

                rooms := Trie.put(
                    rooms,
                    keyText(roomId),
                    Text.equal,
                    updatedRoom
                ).0;
            };
        };
    };

    // Oyunun durumunu görüntüleme
    public shared(msg) func viewGame(roomId: Text): async { 
        gameBoard: [Card]; 
        currentPlayer: Principal;
        players: [Player];
        gameStarted: Bool;
    } {
        let playerId = msg.caller;
        let roomOpt = Trie.get(rooms, keyText(roomId), Text.equal);
        switch (roomOpt) {
            case null {
                return { 
                    gameBoard = []; 
                    currentPlayer = Principal.fromText("");
                    players = [];
                    gameStarted = false;
                };
            };
            case (?room) {
                switch (Array.find<Player>(room.players, func(p: Player) { p.id == playerId })) {
                    case null { 
                        return { 
                            gameBoard = []; 
                            currentPlayer = Principal.fromText("");
                            players = [];
                            gameStarted = false;
                        } 
                    };
                    case _ {
                        return {
                            gameBoard = room.gameBoard;
                            currentPlayer = room.currentPlayer;
                            players = room.players;
                            gameStarted = room.gameStarted;
                        };
                    };
                };
            };
        };
    };

    // Oyuncunun bir kartı açması
    public shared(msg) func move(roomId: Text, cardIndex: Nat): async Text {
        let playerId = msg.caller;
        let roomOpt = Trie.get(rooms, keyText(roomId), Text.equal);
        
        switch (roomOpt) {
            case null { return "Room not found" };
            case (?room) {
                if (room.currentPlayer != playerId) {
                    return "Not your turn";
                };

                // Count currently revealed unmatched cards
                let currentlyRevealed = Array.filter<Card>(room.gameBoard, func(c: Card) { 
                    c.revealed and Option.isNull(Array.find<Card>(room.gameBoard, func(m: Card) { 
                        m.id != c.id and m.revealed and m.value == c.value 
                    }))
                });

                // Reveal the new card
                let updatedGameBoard = Array.tabulate<Card>(room.gameBoard.size(), func(i) {
                    if (i == cardIndex) {
                        {
                            id = room.gameBoard[i].id;
                            value = room.gameBoard[i].value;
                            revealed = true;
                        }
                    } else {
                        room.gameBoard[i]
                    }
                });

                // Check for a potential match
                let newRevealedCards = Array.filter<Card>(updatedGameBoard, func(c: Card) { 
                    c.revealed and Option.isNull(Array.find<Card>(updatedGameBoard, func(m: Card) { 
                        m.id != c.id and m.revealed and m.value == c.value 
                    }))
                });

                if (newRevealedCards.size() == 2) {
                    if (newRevealedCards[0].value == newRevealedCards[1].value) {
                        // Match found - update score
                        let updatedPlayers = Array.map<Player, Player>(room.players, func(p: Player): Player {
                            if (p.id == playerId) {
                                { id = p.id; score = p.score + 1 }
                            } else {
                                p
                            }
                        });
                        
                        rooms := Trie.put(rooms, keyText(roomId), Text.equal, {
                            players = updatedPlayers;
                            gameBoard = updatedGameBoard;
                            currentPlayer = playerId;  // Keep turn after match
                            gameStarted = room.gameStarted;
                        }).0;
                    } else {
                        // No match - reset unmatched cards and switch turns
                        let finalGameBoard = Array.map<Card, Card>(updatedGameBoard, func(c: Card): Card {
                            if (Array.find<Card>(updatedGameBoard, func(m: Card) { 
                                m.id != c.id and m.revealed and m.value == c.value 
                            }) != null) {
                                // Keep matched pairs revealed
                                c
                            } else {
                                // Reset unmatched cards
                                { id = c.id; value = c.value; revealed = false }
                            }
                        });
                        
                        let nextPlayer = Array.find<Player>(room.players, func(p: Player) { p.id != playerId });
                        switch (nextPlayer) {
                            case (?p) {
                                rooms := Trie.put(rooms, keyText(roomId), Text.equal, {
                                    players = room.players;
                                    gameBoard = finalGameBoard;
                                    currentPlayer = p.id;
                                    gameStarted = room.gameStarted;
                                }).0;
                            };
                            case null {};
                        };
                    };
                } else {
                    // First card of the pair
                    rooms := Trie.put(rooms, keyText(roomId), Text.equal, {
                        players = room.players;
                        gameBoard = updatedGameBoard;
                        currentPlayer = playerId;
                        gameStarted = room.gameStarted;
                    }).0;
                };

                return "Move completed";
            };
        };
    };

    // Skor durumu
    public func getScores(roomId: Text): async [Player] {
        let roomOpt = Trie.get(rooms, keyText(roomId), Text.equal);
        switch (roomOpt) {
            case null {
                return [];
            };
            case (?room) {
                return room.players;
            };
        };
    };

    func keyText(t: Text) : Trie.Key<Text> {
        { key = t; hash = Text.hash(t) }
    };

    public shared query (msg) func whoami() : async Principal {
        msg.caller
    };
};
