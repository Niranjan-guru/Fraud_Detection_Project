import React, { useEffect, useState } from "react";
import axios from "axios";

const AdminDashboard: React.FC = () => {
  const [alerts, setAlerts] = useState<
    {
      alert_id: number;
      flagged_at: string;
      reason: string;
      status: string;
      txn_id: number;
      user_confirmation: string;
      user_id: number;            
    }[]
  >([]);

  useEffect(() => {
    console.log("Fetching fraud alerts..."); // Debugging log
    axios
      .get("http://127.0.0.1:5000/fraud_alerts")
      .then((response) => {
        console.log("Received data:", response.data); // Debugging log
        if(response.data && Array.isArray(response.data.fraud_alerts)){
          setAlerts(response.data.fraud_alerts);
        }
        else{
          console.error("Unexpected API response format:", response.data);
          
        }
      })
      .catch((error) => console.error("Error fetching alerts:", error));
  }, []);

  return (
    <div>
      <h1>Admin Dashboard</h1>
      <h2>Fraud Alerts</h2>
      <ul>
        {alerts.map((alert) => (
          <li key={alert.alert_id}>
            <strong>Transaction ID:</strong> {alert.txn_id} <br />
            <strong>Reason:</strong> {alert.reason} <br />
            <strong>Status:</strong> {alert.status} <br />
            <strong>User Confirmation:</strong> {alert.user_confirmation} <br />
            <strong>Flagged At:</strong> {alert.flagged_at} <br />
            <hr />
          </li>
        ))}
      </ul>
    </div>
  );
};

export default AdminDashboard;
