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

    // Room information
    type Room = {
        players: [Player];
        gameBoard: [Card];
        currentPlayer: Principal;
        gameStarted: Bool;
    };

    // Player information
    type Player = {
        id: Principal;
        score: Nat;
    };

    // Card information
    type Card = {
        id: Nat;
        value: Text;
        revealed: Bool;
        matched: Bool;
    };

    // All rooms map
    var rooms: Trie.Trie<Text, Room> = Trie.empty();
    var pendingTimers: Trie.Trie<Text, Timer.TimerId> = Trie.empty();

    // Create room
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
            matched = false;
        });
        
        // First, create pairs
        var index = 0;
        for (symbol in symbols.vals()) {
            cards[index] := {
                id = index;
                value = symbol;
                revealed = false;
                matched = false;
            };
            cards[index + 1] := {
                id = index + 1;
                value = symbol;
                revealed = false;
                matched = false;
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

    // Join room
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

    // Start game
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

    // View game state
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

    // Player moves a card
    public shared(msg) func move(roomId: Text, cardIndex: Nat): async Text {
        let playerId = msg.caller;
        let roomOpt = Trie.get(rooms, keyText(roomId), Text.equal);
        
        switch (roomOpt) {
            case (?room) {
                if (room.currentPlayer != playerId) {
                    return "Not your turn";
                };

                // Don't allow clicking already revealed cards
                if (room.gameBoard[cardIndex].revealed) {
                    return "Card already revealed";
                };

                // Count currently revealed non-matching cards before revealing new card
                let currentlyRevealed = Array.filter<Card>(room.gameBoard, func(c: Card) { 
                    c.revealed and not c.matched 
                });

                // If two non-matching cards are already revealed, don't allow a new move
                if (currentlyRevealed.size() >= 2) {
                    return "Wait for cards to be hidden";
                };

                // Reveal the new card
                let updatedGameBoard = Array.tabulate<Card>(room.gameBoard.size(), func(i) {
                    if (i == cardIndex) {
                        {
                            id = room.gameBoard[i].id;
                            value = room.gameBoard[i].value;
                            revealed = true;
                            matched = room.gameBoard[i].matched;
                        }
                    } else {
                        room.gameBoard[i]
                    }
                });

                // Get currently revealed unmatched cards AFTER revealing the new card
                let revealedCards = Array.filter<Card>(updatedGameBoard, func(c: Card) { 
                    c.revealed and not c.matched 
                });

                // First update the board with the newly revealed card
                rooms := Trie.put(rooms, keyText(roomId), Text.equal, {
                    players = room.players;
                    gameBoard = updatedGameBoard;
                    currentPlayer = room.currentPlayer;
                    gameStarted = room.gameStarted;
                }).0;

                // If this is the second card
                if (revealedCards.size() == 2) {
                    let firstCard = revealedCards[0];
                    let secondCard = revealedCards[1];
                    
                    Debug.print("Checking match between: " # firstCard.value # " and " # secondCard.value);

                    if (firstCard.value == secondCard.value) {
                        Debug.print("Match found!");
                        // Match found - update score and mark cards as matched
                        let updatedPlayers = Array.map<Player, Player>(room.players, func(p: Player): Player {
                            if (p.id == playerId) {
                                { id = p.id; score = p.score + 1 }
                            } else {
                                p
                            }
                        });

                        let matchedGameBoard = Array.tabulate<Card>(updatedGameBoard.size(), func(i) {
                            let card = updatedGameBoard[i];
                            if (card.revealed and (card.value == firstCard.value)) {
                                {
                                    id = card.id;
                                    value = card.value;
                                    revealed = true;
                                    matched = true;
                                }
                            } else {
                                card
                            }
                        });

                        let nextPlayer = if (room.players[0].id == playerId) {
                            room.players[1].id
                        } else {
                            room.players[0].id
                        };
                        
                        rooms := Trie.put(rooms, keyText(roomId), Text.equal, {
                            players = updatedPlayers;
                            gameBoard = matchedGameBoard;
                            currentPlayer = nextPlayer;
                            gameStarted = room.gameStarted;
                        }).0;
                    } else {
                        Debug.print("No match - hiding cards");
                        // No match - hide both cards after delay
                        let timerId = Timer.setTimer<system>(#seconds(1), func() : async () {
                            let nextPlayer = if (room.players[0].id == playerId) {
                                room.players[1].id
                            } else {
                                room.players[0].id
                            };
                            
                            // Hide both cards that are revealed but not matched
                            let finalGameBoard = Array.tabulate<Card>(updatedGameBoard.size(), func(i) {
                                let card = updatedGameBoard[i];
                                if (card.revealed and not card.matched) {
                                    {
                                        id = card.id;
                                        value = card.value;
                                        revealed = false;
                                        matched = false;
                                    }
                                } else {
                                    card
                                }
                            });
                            
                            rooms := Trie.put(rooms, keyText(roomId), Text.equal, {
                                players = room.players;
                                gameBoard = finalGameBoard;
                                currentPlayer = nextPlayer;
                                gameStarted = room.gameStarted;
                            }).0;
                        });
                    };
                };
                
                return "Move completed";
            };
            case null return "Room not found";
        };
    };

    // Score status
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
