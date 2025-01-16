import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { idlFactory, canisterId, createActor, backend } from '../declarations/backend';
import { useAuth } from '../context/AuthContext';
import {AuthClient} from "@dfinity/auth-client"
import {HttpAgent} from "@dfinity/agent";

const Play: React.FC = () => {
  const [playerName, setPlayerName] = useState('');
  const [opponentName, setOpponentName] = useState('');
  const [gameIdToJoin, setGameIdToJoin] = useState('');
  const navigate = useNavigate();
  const { isAuthenticated, login, logout, backendActor } = useAuth();


  

  const loginWithInternetIdentity = async () => {
    // create an auth client
    let authClient = await AuthClient.create();

    // start the login process and wait for it to finish
    await new Promise((resolve) => {
        authClient.login({
            identityProvider: process.env.II_URL,
            onSuccess: resolve,
        });
    });

    // At this point we're authenticated, and we can get the identity from the auth client:
    const identity = authClient.getIdentity();
    // Using the identity obtained from the auth client, we can create an agent to interact with the IC.
    const agent = new HttpAgent({identity});
    // Using the interface description of our webapp, we create an actor that we use to call the service methods.
    let abackendActor = createActor(canisterId, {
        agent,
    });
    return abackendActor;
  };

  if (!isAuthenticated) {
    return (
      <div className="login-screen">
        <h1>Memory Game</h1>
        <button className="login-button" onClick={login}>
          Login with Internet Identity
        </button>
      </div>
    );
  }

  const handleCreate = async () => {
    try {
      const result = await backendActor.createRoom();
      navigate(`/game/${result}`);
    } catch (error) {
      console.error('Failed to create game:', error);
    }
  };

  const handleJoin = async () => {
    try {
      const result = await backendActor.joinRoom(gameIdToJoin);
      navigate(`/game/${gameIdToJoin}`);
    } catch (error) {
      console.error('Failed to join game:', error);
    }
  };

  return (
    <div className="play-screen">
      <div className="header">
        <h1>Memory Game</h1>
        <button className="logout-button" onClick={logout}>Logout</button>
      </div>
      <div className="play-form">
        <input
          type="text"
          placeholder="Your name"
          value={playerName}
          onChange={(e) => setPlayerName(e.target.value)}
        />
        <input
          type="text"
          placeholder="Opponent's name (optional)"
          value={opponentName}
          onChange={(e) => setOpponentName(e.target.value)}
        />
        <button onClick={handleCreate}>Create New Game</button>
        
        <div className="join-game">
          <input
            type="text"
            placeholder="Enter Game ID to join"
            value={gameIdToJoin}
            onChange={(e) => setGameIdToJoin(e.target.value)}
          />
          <button onClick={handleJoin}>Join Game</button>
        </div>
      </div>
    </div>
  );
};

export default Play; 