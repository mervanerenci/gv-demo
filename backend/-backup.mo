import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Random "mo:base/Random";
import Int "mo:base/Int";
actor MemoryGame {
    // Types
    type Error = {
        #NotFound;
        #NotAuthorized;
        #GameFull;
        #InvalidMove;
        #GameOver;
    };

    type Card = {
        id: Nat;
        symbol: Text;
        isRevealed: Bool;
        isMatched: Bool;
    };

    type GameState = {
        gameId: Text;
        var player1: ?Principal;
        var player2: ?Principal;
        var currentTurn: Principal;
        var board: Buffer.Buffer<Card>;
        var selectedCards: Buffer.Buffer<Card>;
        var player1Score: Nat;
        var player2Score: Nat;
        var isGameOver: Bool;
        var lastUpdated: Int;
    };

    type GameView = {
        gameId: Text;
        player1: ?Principal;
        player2: ?Principal;
        currentTurn: Principal;
        board: [Card];
        player1Score: Nat;
        player2Score: Nat;
        isGameOver: Bool;
    };

    // State
    private stable var nextGameId: Nat = 0;
    private let games = HashMap.HashMap<Text, GameState>(
        0, Text.equal, Text.hash
    );

    // Helper Functions
    private func createBoard() : async [Card] {
        let symbols = ["🎮", "🎲", "🎯", "🎪", "🎨", "🎭", "🎪", "🎯", "🎸", "🎺"];
        var cards : [var Card] = Array.init<Card>(20, {
            id = 0;
            symbol = symbols[0];
            isRevealed = false;
            isMatched = false;
        });
        
        // Fill cards with pairs
        var index = 0;
        for (symbol in symbols.vals()) {
            cards[index] := {
                id = index;
                symbol = symbol;
                isRevealed = false;
                isMatched = false;
            };
            cards[index + 1] := {
                id = index + 1;
                symbol = symbol;
                isRevealed = false;
                isMatched = false;
            };
            index += 2;
        };

        // Fisher-Yates shuffle
        let size = cards.size();
        for (i in Iter.range(0, size - 2)) {
            let remaining = Nat.sub(size, i);
            let j = i + Int.abs(Time.now()) % remaining;
            let temp = cards[i];
            cards[i] := cards[j];
            cards[j] := temp;
        };
        
        Array.freeze(cards)
    };

    private func gameStateToView(state: GameState) : GameView {
        {
            gameId = state.gameId;
            player1 = state.player1;
            player2 = state.player2;
            currentTurn = state.currentTurn;
            board = Buffer.toArray(state.board);
            player1Score = state.player1Score;
            player2Score = state.player2Score;
            isGameOver = state.isGameOver;
        }
    };

    // Public Functions
    public shared({ caller }) func createGame() : async Result.Result<GameView, Error> {
        let gameId = Nat.toText(nextGameId);
        nextGameId += 1;

        let newGame : GameState = {
            gameId = gameId;
            var player1 = ?caller;
            var player2 = null;
            var currentTurn = caller;
            var board = Buffer.fromArray<Card>(await createBoard());
            var selectedCards = Buffer.Buffer<Card>(0);
            var player1Score = 0;
            var player2Score = 0;
            var isGameOver = false;
            var lastUpdated = Time.now();
        };

        games.put(gameId, newGame);
        #ok(gameStateToView(newGame))
    };

    public shared({ caller }) func joinGame(gameId: Text) : async Result.Result<GameView, Error> {
        switch (games.get(gameId)) {
            case (null) { #err(#NotFound) };
            case (?game) {
                switch (game.player2) {
                    case (?_) { #err(#GameFull) };
                    case (null) {
                        game.player2 := ?caller;
                        game.lastUpdated := Time.now();
                        #ok(gameStateToView(game))
                    };
                };
            };
        }
    };

    public shared({ caller }) func makeMove(gameId: Text, cardId: Nat) : async Result.Result<GameView, Error> {
        switch (games.get(gameId)) {
            case (null) { #err(#NotFound) };
            case (?game) {
                if (game.isGameOver) { return #err(#GameOver) };
                if (game.currentTurn != caller) { return #err(#NotAuthorized) };
                
                // Game logic
                let card = game.board.get(cardId);
                if (card.isMatched or card.isRevealed) {
                    return #err(#InvalidMove);
                };

                // Reveal card
                let updatedCard = {
                    id = card.id;
                    symbol = card.symbol;
                    isRevealed = true;
                    isMatched = card.isMatched;
                };
                game.board.put(cardId, updatedCard);
                game.selectedCards.add(updatedCard);

                // Check for match if two cards are selected
                if (game.selectedCards.size() == 2) {
                    let card1 = game.selectedCards.get(0);
                    let card2 = game.selectedCards.get(1);

                    if (card1.symbol == card2.symbol) {
                        // Match found
                        let matchedCard1 = {
                            id = card1.id;
                            symbol = card1.symbol;
                            isRevealed = true;
                            isMatched = true;
                        };
                        let matchedCard2 = {
                            id = card2.id;
                            symbol = card2.symbol;
                            isRevealed = true;
                            isMatched = true;
                        };
                        game.board.put(card1.id, matchedCard1);
                        game.board.put(card2.id, matchedCard2);

                        // Update score
                        if (caller == Option.get(game.player1, Principal.fromText("2vxsx-fae"))) {
                            game.player1Score += 1;
                        } else {
                            game.player2Score += 1;
                        };
                    } else {
                        // No match, hide cards after delay
                        let hiddenCard1 = {
                            id = card1.id;
                            symbol = card1.symbol;
                            isRevealed = false;
                            isMatched = false;
                        };
                        let hiddenCard2 = {
                            id = card2.id;
                            symbol = card2.symbol;
                            isRevealed = false;
                            isMatched = false;
                        };
                        game.board.put(card1.id, hiddenCard1);
                        game.board.put(card2.id, hiddenCard2);
                    };

                    game.selectedCards.clear();
                    game.currentTurn := if (caller == Option.get(game.player1, Principal.fromText("2vxsx-fae"))) {
                        Option.get(game.player2, Principal.fromText("2vxsx-fae"))
                    } else {
                        Option.get(game.player1, Principal.fromText("2vxsx-fae"))
                    };
                };

                // Check if game is over
                let allMatched = Array.filter<Card>(
                    Buffer.toArray(game.board), 
                    func(card: Card) : Bool { not card.isMatched }
                ).size() == 0;
                if (allMatched) {
                    game.isGameOver := true;
                };

                game.lastUpdated := Time.now();
                #ok(gameStateToView(game))
            };
        }
    };

    public query func getGame(gameId: Text) : async Result.Result<GameView, Error> {
        switch (games.get(gameId)) {
            case (null) { #err(#NotFound) };
            case (?game) { #ok(gameStateToView(game)) };
        }
    };

    public shared query (msg) func whoami() : async Principal {
    msg.caller
  };
}