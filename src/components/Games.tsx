import React from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import '../styles/Games.css';

const Games: React.FC = () => {
  const navigate = useNavigate();
  const { isAuthenticated, login, logout } = useAuth();

  const games = [
    {
      id: 'memory',
      name: 'Memory Game',
      description: 'Test your memory by matching pairs of cards',
      icon: '🎴',
      category: 'Brain Training',
      players: '2 Players',
      difficulty: 'Medium',
    },
  ];

  if (!isAuthenticated) {
    return (
      <div className="auth-container">
        <div className="auth-card">
          <h1>Game Versus</h1>
          <p>Connect to browse games</p>
          <button className="auth-button" onClick={login}>
            Connect with Internet Identity
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="games-container">
      <header className="games-header">
        <h1>Game Versus</h1>
        <button className="logout-button" onClick={logout}>
          Disconnect
        </button>
      </header>
      <p className="subtitle">Choose your next challenge</p>

      <div className="featured-section">
        <h2>Featured Game</h2>
        <div className="featured-game" onClick={() => navigate('/play')}>
          <div className="featured-content">
            <div className="game-icon">{games[0].icon}</div>
            <div className="game-info">
              <h3>{games[0].name}</h3>
              <p>{games[0].description}</p>
              <div className="game-meta">
                <span className="category">{games[0].category}</span>
                <span className="players">{games[0].players}</span>
                <span className="difficulty">{games[0].difficulty}</span>
              </div>
            </div>
          </div>
          <button className="play-button">Play Now</button>
        </div>
      </div>

      <section className="games-section">
        <h2>All Games</h2>
        <div className="games-grid">
          {games.map((game) => (
            <div key={game.id} className="game-card" onClick={() => navigate('/play')}>
              <div className="game-icon">{game.icon}</div>
              <div className="game-details">
                <h3>{game.name}</h3>
                <p>{game.description}</p>
                <div className="game-meta">
                  <span className="category">{game.category}</span>
                  <span className="players">{game.players}</span>
                </div>
              </div>
              <button className="play-button">Play</button>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
};

export default Games;
