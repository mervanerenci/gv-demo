import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { idlFactory, canisterId, createActor, backend } from '../declarations/backend';
import { useAuth } from '../context/AuthContext';
import {AuthClient} from "@dfinity/auth-client"
import {HttpAgent} from "@dfinity/agent";
import '../styles/Play.css';

const Play: React.FC = () => {
  const navigate = useNavigate();
  const { isAuthenticated, login, logout, backendActor } = useAuth();
  const [gameIdToJoin, setGameIdToJoin] = useState('');
  const [isCreating, setIsCreating] = useState(false);
  const [isJoining, setIsJoining] = useState(false);

  const handleCreate = async () => {
    try {
      setIsCreating(true);
      const result = await backendActor.createRoom();
      navigate(`/game/${result}`);
    } catch (error) {
      console.error('Failed to create game:', error);
    } finally {
      setIsCreating(false);
    }
  };

  const handleJoin = async () => {
    if (!gameIdToJoin.trim()) return;
    try {
      setIsJoining(true);
      await backendActor.joinRoom(gameIdToJoin);
      navigate(`/game/${gameIdToJoin}`);
    } catch (error) {
      console.error('Failed to join game:', error);
    } finally {
      setIsJoining(false);
    }
  };

  if (!isAuthenticated) {
    return (
      <div className="auth-container">
        <div className="auth-card">
          <h1>Memory Game</h1>
          <p>Connect to start playing</p>
          <button className="auth-button" onClick={login}>
            Connect with Internet Identity
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="play-container">
      <div className="nav-header">
        <h1>Memory Game</h1>
        <button className="logout-button" onClick={logout}>
          Disconnect
        </button>
      </div>

      <div className="play-options">
        <div className="option-card create-game">
          <h2>Create New Game</h2>
          <p>Start a new game and invite a friend</p>
          <button 
            className="create-button"
            onClick={handleCreate}
            disabled={isCreating}
          >
            {isCreating ? 'Creating...' : 'Create Game'}
          </button>
        </div>

        <div className="option-card join-game">
          <h2>Join Game</h2>
          <p>Enter a game ID to join an existing game</p>
          <div className="join-input-group">
            <input
              type="text"
              placeholder="Enter Game ID"
              value={gameIdToJoin}
              onChange={(e) => setGameIdToJoin(e.target.value)}
            />
            <button 
              className="join-button"
              onClick={handleJoin}
              disabled={isJoining || !gameIdToJoin.trim()}
            >
              {isJoining ? 'Joining...' : 'Join Game'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Play; 