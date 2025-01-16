import React from 'react';
import '../styles/MemoGame.css';

interface CardProps {
  card: {
    id: number;
    value: string;
    revealed: boolean;
  };
  onClick: () => void;
  disabled?: boolean;
}

const Card: React.FC<CardProps> = ({ card, onClick, disabled }) => {
  return (
    <div
      className={`card ${card.revealed ? 'flipped' : ''} ${disabled ? 'disabled' : ''}`}
      onClick={() => !disabled && onClick()}
    >
      <div className="card-inner">
        <div className="card-front">?</div>
        <div className="card-back">{card.value}</div>
      </div>
    </div>
  );
};

export default Card;