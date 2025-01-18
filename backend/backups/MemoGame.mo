import Debug "mo:base/Debug";
import Array "mo:base/Array";
import Time "mo:base/Time";
import Trie "mo:base/Trie";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Int "mo:base/Int";
import Principal "mo:base/Principal";

func keyText(t: Text) : Trie.Key<Text> {
    { key = t; hash = Text.hash(t) }
};

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
        switch (existingRoom) {
            case (?_) return "Bu oda zaten mevcut.";
            case null {
                // Yeni bir oda oluştur
                let updatedPlayers = [{ id = playerId; score = 0 }];
                let updatedRoom = {
                    players = updatedPlayers;
                    gameBoard = [];
                    currentPlayer = Principal.fromText("");
                    gameStarted = false;
                };

                rooms := Trie.put(
                    rooms,
                    keyText(roomId),
                    Text.equal,
                    updatedRoom
                ).0;

                Debug.print("Oda oluşturuldu: " # roomId);
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
    public shared(msg) func viewGame(roomId: Text): async { gameBoard: [Card]; currentPlayer: Principal } {
        let playerId = msg.caller;
        let roomOpt = Trie.get(rooms, keyText(roomId), Text.equal);
        switch (roomOpt) {
            case null {
                return { gameBoard = []; currentPlayer = Principal.fromText("") };
            };
            case (?room) {
                switch (Array.find<Player>(room.players, func(p: Player) { p.id == playerId })) {
                    case null { return { gameBoard = []; currentPlayer = Principal.fromText("") } };
                    case _ {
                        return {
                            gameBoard = room.gameBoard;
                            currentPlayer = room.currentPlayer;
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
            case null {
                return "Oda bulunamadı.";
            };
            case (?room) {
                if (not room.gameStarted) return "Oyun henüz başlamadı.";
                if (room.currentPlayer != playerId) return "Sıra sizde değil.";
                if (cardIndex >= room.gameBoard.size()) return "Geçersiz kart seçimi.";

                let card = room.gameBoard[cardIndex];
                if (card.revealed) return "Bu kart zaten açılmış.";

                // Kartı aç ve kontrol et
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

                rooms := Trie.put(
                    rooms,
                    keyText(roomId),
                    Text.equal,
                    {
                        players = room.players;
                        gameBoard = updatedGameBoard;
                        currentPlayer = room.currentPlayer;
                        gameStarted = room.gameStarted;
                    }
                ).0;

                // Eşleşme kontrolü
                let revealedCards = Array.filter<Card>(room.gameBoard, func(c: Card) { c.revealed });
                if (revealedCards.size() % 2 == 0) {
                    let lastTwo = Array.tabulate<Card>(2, func(i) {
                        revealedCards[revealedCards.size() - 2 + i]
                    });
                    if (lastTwo[0].value == lastTwo[1].value) {
                        let updatedPlayers = Array.map<Player, Player>(room.players, func(p: Player): Player {
                            if (p.id == playerId) {
                                return { id = p.id; score = p.score + 1 };
                            };
                            return p;
                        });
                        rooms := Trie.put(
                            rooms,
                            keyText(roomId),
                            Text.equal,
                            {
                                players = updatedPlayers;
                                gameBoard = room.gameBoard;
                                currentPlayer = room.currentPlayer;
                                gameStarted = room.gameStarted;
                            }
                        ).0;
                    } else {
                        // Eşleşmediyse tekrar kapat
                        let updatedGameBoard = Array.tabulate<Card>(room.gameBoard.size(), func(i) {
                            if (i == lastTwo[0].id or i == lastTwo[1].id) {
                                {
                                    id = room.gameBoard[i].id;
                                    value = room.gameBoard[i].value;
                                    revealed = false;
                                }
                            } else {
                                room.gameBoard[i]
                            }
                        });

                        rooms := Trie.put(
                            rooms,
                            keyText(roomId),
                            Text.equal,
                            {
                                players = room.players;
                                gameBoard = updatedGameBoard;
                                currentPlayer = room.currentPlayer;
                                gameStarted = room.gameStarted;
                            }
                        ).0;
                    };
                    // Sırayı değiştir
                    let nextPlayer = Array.find<Player>(room.players, func(p: Player) { p.id != playerId });
                    switch (nextPlayer) {
                        case (?p) {
                            rooms := Trie.put(
                                rooms,
                                keyText(roomId),
                                Text.equal,
                                {
                                    players = room.players;
                                    gameBoard = room.gameBoard;
                                    currentPlayer = p.id;
                                    gameStarted = room.gameStarted;
                                }
                            ).0;
                        };
                        case null {};
                    };
                };

                rooms := Trie.put(
                    rooms,
                    keyText(roomId),
                    Text.equal,
                    room
                ).0;
                return "Hamle yapıldı.";
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

    public shared query (msg) func whoami() : async Principal {
    msg.caller
  };
};
