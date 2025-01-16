import Debug "mo:base/Debug";
import Array "mo:base/Array";
import Time "mo:base/Time";
import Trie "mo:base/Trie";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Int "mo:base/Int";
import Principal "mo:base/Principal";
import Option "mo:base/Option";
import Timer "mo:base/Timer";



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
    var pendingTimers: Trie.Trie<Text, Timer.TimerId> = Trie.empty();

    // Oda oluşturma
    public shared(msg) func createRoom(): async Text {
        let playerId = msg.caller;
        let roomId = "room_" # Nat.toText(Int.abs(Time.now()));
        let existingRoom = Trie.get(rooms, keyText(roomId), Text.equal);
        
        // Create initial game board with pairs of cards
        let symbols = ["🎮", "🎲", "🎯", "🎪", "🎨", "🎭", "🎸", "🎺"];
        var cards: [var Card] = Array.init<Card>(16, {
            id = 0;
            value = "";
            revealed = false;
        });
        
        // First, create pairs
        var index = 0;
        for (symbol in symbols.vals()) {
            cards[index] := {
                id = index;
                value = symbol;
                revealed = false;
            };
            cards[index + 1] := {
                id = index + 1;
                value = symbol;
                revealed = false;
            };
            index += 2;
        };
        
        // Simple array swap shuffle
        var i = cards.size();
        while (i > 1) {
            i -= 1;
            let temp = cards[i];
            cards[i] := cards[0];
            cards[0] := temp;
        };
        
        // Convert to immutable array
        let initialBoard = Array.tabulate<Card>(16, func(i) = cards[i]);
        
        switch (existingRoom) {
            case (?_) return "Bu oda zaten mevcut.";
            case null {
                let newRoom = {
                    players = [{ id = playerId; score = 0 }];
                    gameBoard = initialBoard;
                    currentPlayer = playerId;
                    gameStarted = true;
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
            case (?room) {
                // Count currently revealed cards
                let currentlyRevealed = Array.filter<Card>(room.gameBoard, func(c: Card) { c.revealed });

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

                // Update room with revealed card
                rooms := Trie.put(rooms, keyText(roomId), Text.equal, {
                    players = room.players;
                    gameBoard = updatedGameBoard;
                    currentPlayer = room.currentPlayer;
                    gameStarted = room.gameStarted;
                }).0;

                // If this is the second card
                if (currentlyRevealed.size() == 1) {
                    let firstCard = currentlyRevealed[0];
                    let secondCard = updatedGameBoard[cardIndex];
                    
                    if (firstCard.value != secondCard.value) {
                        let timerId = Timer.setTimer<system>(#seconds(2), func() : async () {
                            await hideCards(roomId, firstCard.id, secondCard.id);
                            
                            // Switch turn after hiding cards
                            let nextPlayer = if (room.players[0].id == playerId) {
                                room.players[1].id;
                            } else {
                                room.players[0].id;
                            };
                            
                            rooms := Trie.put(rooms, keyText(roomId), Text.equal, {
                                players = room.players;
                                gameBoard = room.gameBoard;
                                currentPlayer = nextPlayer;
                                gameStarted = room.gameStarted;
                            }).0;
                        });
                        pendingTimers := Trie.put(pendingTimers, keyText(roomId), Text.equal, timerId).0;
                    }
                };
                
                return "Move completed";
            };
            case null return "Room not found";
        };
    };

    // New helper function to hide cards
    private func hideCards(roomId: Text, card1Id: Nat, card2Id: Nat) : async () {
        let roomOpt = Trie.get(rooms, keyText(roomId), Text.equal);
        switch (roomOpt) {
            case (?room) {
                let updatedGameBoard = Array.tabulate<Card>(room.gameBoard.size(), func(i) {
                    if (i == card1Id or i == card2Id) {
                        {
                            id = room.gameBoard[i].id;
                            value = room.gameBoard[i].value;
                            revealed = false;
                        }
                    } else {
                        room.gameBoard[i]
                    }
                });
                
                rooms := Trie.put(rooms, keyText(roomId), Text.equal, {
                    players = room.players;
                    gameBoard = updatedGameBoard;
                    currentPlayer = room.currentPlayer;
                    gameStarted = room.gameStarted;
                }).0;
            };
            case null {};
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
