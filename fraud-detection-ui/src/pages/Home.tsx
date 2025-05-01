import React from "react";
import { Link } from "react-router-dom";

const Home: React.FC = () => {
  return (
    <div>
      <h1>Fraud Detection System</h1>
      <p>Welcome to the Fraud Detection System.</p>
      <Link to="/admin">
        <button>Go to Admin Dashboard</button>
      </Link>
    </div>
  );
};

export default Home;