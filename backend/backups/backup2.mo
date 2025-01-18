import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { idlFactory, canisterId, createActor } from '../declarations/backend';
import Card from './Card';
import { GameView } from '../declarations/backend/backend.did';
import '../styles/MemoryGame.css';
import { useAuth } from '../context/AuthContext';

interface Card {
  id: number;
  symbol: string;
  isRevealed: boolean;
  isMatched: boolean;
}

const MemoryGame: React.FC = () => {
  const { gameId } = useParams<{ gameId: string }>();
  const navigate = useNavigate();
  const { logout } = useAuth();
  const [gameState, setGameState] = useState<GameView | null>(null);
  const [playerRole, setPlayerRole] = useState<'player1' | 'player2' | null>(null);
  const [isProcessingMove, setIsProcessingMove] = useState(false);
  
  const backend = createActor(canisterId, {
    agentOptions: {
      host: process.env.DFX_NETWORK === 'ic' ? 'https://ic0.app' : 'http://localhost:4943',
    },
  });

  useEffect(() => {
    const syncGameState = async () => {
      if (!gameId) return;
      
      try {
        const result = await backend.getGame(gameId);
        if ('ok' in result) {
          setGameState(result.ok);
          
          if (!playerRole) {
            const currentPlayer = await backend.whoami();
            const player1 = result.ok.player1?.toString();
            const player2 = result.ok.player2?.toString();
            
            if (currentPlayer.toString() === player1) {
              setPlayerRole('player1');
            } else if (currentPlayer.toString() === player2) {
              setPlayerRole('player2');
            }
          }
        }
      } catch (error) {
        console.error('Failed to sync game state:', error);
      }
    };

    syncGameState();
    const interval = setInterval(syncGameState, 500);
    return () => clearInterval(interval);
  }, [gameId]);

  const handleCardClick = async (cardId: number) => {
    if (!gameId || !gameState || !playerRole || isProcessingMove) return;
    
    const isMyTurn = (playerRole === 'player1' && 
      gameState.currentTurn.toString() === gameState.player1?.toString()) ||
      (playerRole === 'player2' && 
      gameState.currentTurn.toString() === gameState.player2?.toString());

    if (!isMyTurn) return;

    try {
      setIsProcessingMove(true);
      await backend.makeMove(gameId, BigInt(cardId));
      // Add delay to allow users to see the cards
      await new Promise(resolve => setTimeout(resolve, 1000));
    } catch (error) {
      console.error('Failed to make move:', error);
    } finally {
      setIsProcessingMove(false);
    }
  };

  const getTurnIndicator = () => {
    if (!gameState || !playerRole) return null;
    
    const isMyTurn = (playerRole === 'player1' && 
      gameState.currentTurn.toString() === gameState.player1?.toString()) ||
      (playerRole === 'player2' && 
      gameState.currentTurn.toString() === gameState.player2?.toString());

    return (
      <div className={`turn-indicator ${isMyTurn ? 'my-turn' : ''}`}>
        {isMyTurn ? "It's your turn!" : "Waiting for opponent's move..."}
      </div>
    );
  };

  if (!gameState?.player2) {
    return (
      <div className="waiting-screen">
        <h2>Waiting for Player 2</h2>
        <p>Share this game ID: {gameId}</p>
      </div>
    );
  }

  return (
    <div className="memory-game">
      <div className="game-info">
        <div>Player 1: {gameState.player1Score.toString()}</div>
        <div>Player 2: {gameState.player2Score.toString()}</div>
        {getTurnIndicator()}
      </div>

      <div className="game-board">
        {gameState.board.map((card) => (
          <Card
            key={card.id}
            card={{
              id: Number(card.id),
              symbol: card.symbol,
              isRevealed: card.isRevealed,
              isMatched: card.isMatched
            }}
            onClick={() => handleCardClick(Number(card.id))}
          />
        ))}
      </div>

      {gameState.isGameOver && (
        <div className="game-over">
          <h2>Game Over!</h2>
          <p>
            {gameState.player1Score === gameState.player2Score
              ? "It's a tie!"
              : `Winner: ${
                  gameState.player1Score > gameState.player2Score ? 'Player 1' : 'Player 2'
                } (Score: ${Math.max(
                  Number(gameState.player1Score),
                  Number(gameState.player2Score)
                )})`}
          </p>
          <button onClick={() => navigate('/')}>New Game</button>
        </div>
      )}
    </div>
  );
};

export default MemoryGame;