import React from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import Play from './components/Play';
import MemoGame from './components/MemoGame';
import Games from './components/Games';
import { AuthProvider } from './context/AuthContext';

const App: React.FC = () => {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<Games />} />
          <Route path="/play" element={<Play />} />
          <Route path="/game/:gameId" element={<MemoGame />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
};

export default App;