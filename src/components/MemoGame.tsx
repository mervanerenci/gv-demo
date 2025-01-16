import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { idlFactory, canisterId, createActor, backend } from '../declarations/backend';
import { useActor } from '@ic-reactor/react';
import Card from './Card';
import { useAuth } from '../context/AuthContext';
import '../styles/MemoGame.css';
import { Principal } from '@dfinity/principal';

interface Card {
  id: number;
  value: string;
  revealed: boolean;
}

interface GameState {
  gameBoard: Card[];
  currentPlayer: string;
  players: Array<{ id: string; score: number }>;
  gameStarted: boolean;
}

const MemoryGame: React.FC = () => {
  const { gameId } = useParams();
  const navigate = useNavigate();
  const { isAuthenticated, login, backendActor } = useAuth();
  const [gameState, setGameState] = useState<GameState | null>(null);
  const [error, setError] = useState<string>('');
  const [isProcessingMove, setIsProcessingMove] = useState(false);
  const [temporaryRevealedCards, setTemporaryRevealedCards] = useState<number[]>([]);
  const [currentPrincipal, setCurrentPrincipal] = useState<string | null>(null);

  // Get current principal on mount
  useEffect(() => {
    const getPrincipal = async () => {
      if (backendActor) {
        const principal = await backendActor.whoami();
        setCurrentPrincipal(principal.toString());
        console.log("current principal", currentPrincipal);
      }
    };
    getPrincipal();
  }, [backendActor]);

  const isMyTurn = useMemo(() => {
    if (!gameState || !currentPrincipal) return false;
    return gameState.currentPlayer === currentPrincipal;
  }, [gameState?.currentPlayer, currentPrincipal]);

  // Add logging to debug
  useEffect(() => {
    console.log("Authentication status:", isAuthenticated);
    console.log("Game ID:", gameId);
    console.log("Backend Actor:", backendActor);
  }, [isAuthenticated, gameId, backendActor]);

  // Move refreshGameState outside useEffect and make it a const function
  const refreshGameState = async () => {
    try {
      if (!gameId || !backendActor) return;
      const state = await backendActor.viewGame(gameId);
      setGameState({
        gameBoard: state.gameBoard.map((card: { id: bigint; value: string; revealed: boolean }) => ({
          ...card,
          id: Number(card.id)
        })),
        currentPlayer: state.currentPlayer.toString(),
        players: state.players.map((player: { id: Principal; score: bigint }) => ({
          id: player.id.toString(),
          score: Number(player.score)
        })),
        gameStarted: state.gameStarted
      });
    } catch (err) {
      console.error("Error fetching game state:", err);
      setError('Error fetching game state');
    }

    console.log("game state", gameState);
  };

  useEffect(() => {
    if (!isAuthenticated || !gameId || !backendActor) return;
    
    const pollInterval = setInterval(async () => {
        const newState = await backendActor.viewGame(gameId);
        setGameState({
            gameBoard: newState.gameBoard.map((card: { id: bigint; value: string; revealed: boolean }) => ({
                ...card,
                id: Number(card.id)
            })),
            currentPlayer: newState.currentPlayer.toString(),
            players: newState.players.map((player: { id: Principal; score: bigint }) => ({
                id: player.id.toString(),
                score: Number(player.score)
            })),
            gameStarted: newState.gameStarted
        });
    }, 500);

    return () => clearInterval(pollInterval);
  }, [isAuthenticated, gameId, backendActor]);

  const handleCardClick = async (cardIndex: number) => {
    try {
      if (!gameId || isProcessingMove) return;
      if (!gameState) return;

      if (gameState.gameBoard[cardIndex].revealed) {
        setError("This card is already revealed!");
        return;
      }

      setIsProcessingMove(true);
      setTemporaryRevealedCards(prev => [...prev, cardIndex]);

      // If this is the second card
      if (temporaryRevealedCards.length === 1) {
        await backendActor.move(gameId, BigInt(cardIndex));
        
        // Wait for animation before checking match
        setTimeout(async () => {
          const newState = await backendActor.viewGame(gameId);
          
          // If cards don't match, show second card briefly before hiding both
          if (!newState?.gameBoard[cardIndex].revealed) {
            // Keep both cards visible for a moment
            await new Promise(resolve => setTimeout(resolve, 1000));
            setTemporaryRevealedCards([]);
          } else {
            setTemporaryRevealedCards([]);
          }
          await refreshGameState();
          setIsProcessingMove(false);
        }, 500);
      } else {
        await backendActor.move(gameId, BigInt(cardIndex));
        setIsProcessingMove(false);
      }
    } catch (err) {
      setError('Error making move');
      console.error(err);
      setIsProcessingMove(false);
    }
  };

  if (!isAuthenticated) {
    return (
      <div className="login-screen">
        <h2>Please login to play</h2>
        <button className="login-button" onClick={login}>
          Login with Internet Identity
        </button>
      </div>
    );
  }

  if (!gameState) {
    return <div>Loading...</div>;
  }

  return (
    <div className="game-container">
      {error && (
        <div className="error-message" onClick={() => setError('')}>
          {error}
        </div>
      )}
      
      <div className="game-header">
        <div className="scores-container">
          <div className={`score ${isMyTurn ? 'active' : ''}`}>
            Player 1: {gameState?.players.find(p => p.id === currentPrincipal)?.score || 0}
          </div>
          <div className={`score ${!isMyTurn ? 'active' : ''}`}>
            Player 2: {gameState?.players.find(p => p.id !== currentPrincipal)?.score || 0}
          </div>
        </div>
        
        <div className="turn-indicator">
          {isMyTurn ? "Your Turn" : "Opponent's Turn"}
        </div>
      </div>

      <div className="game-board">
        {gameState?.gameBoard.map((card, index) => (
          <div
            key={card.id}
            className={`card ${card.revealed || temporaryRevealedCards.includes(index) ? 'flipped' : ''}`}
            onClick={() => handleCardClick(index)}
          >
            <div className="card-inner">
              <div className="card-front">
                ?
              </div>
              <div className="card-back">
                {card.value}
              </div>
            </div>
          </div>
        ))}
      </div>

      <button 
        className="back-button" 
        onClick={() => navigate('/')}
        disabled={isProcessingMove}
      >
        Back to Lobby
      </button>
    </div>
  );
};

export default MemoryGame;
