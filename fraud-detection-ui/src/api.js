const API_BASE_URL = "http://localhost:5000";

export const fetchFraudAlerts = async () => {
    const response = await fetch(`${API_BASE_URL}/fraud_alerts`);
    return response.json();
};