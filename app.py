import pymysql, hashlib
import pymysql.cursors
import logging
from flask_cors import CORS
from flask import Flask, request, jsonify
from flask_httpauth import HTTPBasicAuth

app = Flask(__name__)
auth = HTTPBasicAuth()
CORS(app)

logging.basicConfig(filename='fraud_detection.log', level=logging.INFO, format='%(asctime)s - %(message)s')

def get_db_connection():
    return pymysql.connect(
        host="localhost",
        user="root",
        password="admin@123",
        database="fraud_detection",
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=True
    )

# Execute Queries
def execute_query(query, params=None, fetch=True):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(query, params)
            if fetch:
                return cursor.fetchall()
            conn.commit()
            return cursor.lastrowid
    finally:
        conn.close()

@app.route('/add_user', methods=['POST'])
def add_user():
    try:
        data = request.json
        name = data.get('name')
        email = data.get('email')
        password = data.get('password')
        role = data.get('role', 'user')

        if not name or not email or not password:
            return jsonify({"error": "Invalid input. Name, email, and password are required."}), 400

        if role not in ['admin', 'user']:
            return jsonify({"error": "Invalid role. Role must be 'admin' or 'user'."}), 400

        hashed_password = hashlib.sha256(password.encode()).hexdigest()

        query = "INSERT INTO Users (name, email, password_hash, role) VALUES (%s, %s, %s, %s)"
        execute_query(query, (name, email, hashed_password, role))

        return jsonify({"message": f"User {name} added successfully as {role}"}), 201

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/add_transaction', methods=['POST'])
def add_transaction():
    try:
        data = request.json
        user_id = data.get('user_id')
        amount = data.get('amount')
        location = data.get('location')

        user_exists = execute_query("SELECT user_id FROM Users WHERE user_id = %s", (user_id,))
        if not user_exists:
            return jsonify({"error": "User ID does not exist"}), 400

        txn_id = execute_query(
            "INSERT INTO Transactions (user_id, amount, location, status) VALUES (%s, %s, %s, 'Pending')",
            (user_id, amount, location),
            fetch=False
        )

        detect_fraud({"txn_id": txn_id, "user_id": user_id, "amount": amount, "location": location})

        return jsonify({"message": "Transaction recorded", "txn_id": txn_id}), 201

    except Exception as e:
        return jsonify({"error": str(e)}), 500


def get_user_average_spending(user_id):
    result = execute_query("SELECT AVG(amount) as avg_spend FROM Transactions WHERE user_id = %s", (user_id,))
    return result[0]['avg_spend'] if result[0]['avg_spend'] else 0

def is_unusual_location(user_id, location):
    result = execute_query("SELECT COUNT(*) as count FROM Transactions WHERE user_id = %s AND location = %s", (user_id, location))
    return result[0]['count'] == 0

def get_recent_transactions(user_id):
    return execute_query(
        "SELECT txn_id FROM Transactions WHERE user_id = %s AND timestamp >= NOW() - INTERVAL 10 MINUTE",
        (user_id,)
    )

def flag_transaction(txn_id, user_id, reasons):
    execute_query(
        "INSERT INTO FraudAlerts (txn_id, user_id, reason, status, user_confirmation) VALUES (%s, %s, %s, 'Flagged', 'Pending')",
        (txn_id, user_id, ", ".join(reasons)),
        fetch=False
    )

def detect_fraud(transaction):
    user_id = transaction["user_id"]
    amount = transaction["amount"]
    location = transaction["location"]

    flagged_reasons = []
    avg_spend = get_user_average_spending(user_id)

    if amount > avg_spend * 5:
        flagged_reasons.append("Unusually High Transaction Amount")
    if is_unusual_location(user_id, location):
        flagged_reasons.append("Transaction from Unusual Location")
    if len(get_recent_transactions(user_id)) >= 3:
        flagged_reasons.append("Multiple Rapid Transactions")

    if flagged_reasons:
        flag_transaction(transaction["txn_id"], user_id, flagged_reasons)
        logging.info(f"User {user_id} - ALERT: Suspicious transaction {transaction['txn_id']} flagged! Reason: {', '.join(flagged_reasons)}")


@app.route('/fraud_alerts', methods=['GET'])
def view_fraud_alerts():
    return jsonify({"fraud_alerts": execute_query("SELECT * FROM FraudAlerts")}), 200


@app.route('/user_confirm_transaction', methods=['POST'])
def user_confirm_transaction():
    data = request.json
    txn_id = data["txn_id"]
    response = data["response"].upper()

    if response == "YES":
        execute_query("UPDATE FraudAlerts SET user_confirmation = 'Approved' WHERE txn_id = %s", (txn_id,))
        return jsonify({"message": "Transaction approved by user."})
    elif response == "NO":
        execute_query("UPDATE FraudAlerts SET user_confirmation = 'Rejected' WHERE txn_id = %s", (txn_id,))
        return jsonify({"message": "Transaction rejected by user."})

    return jsonify({"error": "Invalid response"}), 400


@app.route('/admin_confirm_transaction', methods=['POST'])
def admin_confirm_transaction():
    data = request.json
    txn_id = data["txn_id"]
    response = data["response"].upper()
    admin_id = data.get("admin_id")  

    admin_check = execute_query("SELECT role FROM Users WHERE user_id = %s", (admin_id,))
    if not admin_check or admin_check[0]["role"] != "admin":
        return jsonify({"error": "Unauthorized. Only admins can approve/reject transactions."}), 403

    if response == "YES":
        execute_query("UPDATE FraudAlerts SET user_confirmation = 'Approved', status = 'Confirmed' WHERE txn_id = %s", (txn_id,))
        execute_query("UPDATE Transactions SET status = 'approved' WHERE txn_id = %s", (txn_id,))
        return jsonify({"message": "Transaction approved by admin and marked as approved in Transactions table."})
    
    elif response == "NO":
        execute_query("UPDATE FraudAlerts SET user_confirmation = 'Rejected', status = 'Blocked' WHERE txn_id = %s", (txn_id,))
        execute_query("UPDATE Transactions SET status = 'fraudulent' WHERE txn_id = %s", (txn_id,))
        return jsonify({"message": "Transaction blocked by admin and marked as fraudulent in Transactions table."})
    
    return jsonify({"error": "Invalid response"}), 400


@app.route('/update_transaction/<int:txn_id>', methods=['PUT'])
def update_transaction_status(txn_id):
    data = request.json
    new_status = data.get('status')

    if new_status not in ['approved', 'declined', 'fraudulent']:
        return jsonify({"error": "Invalid status"}), 400

    execute_query("UPDATE Transactions SET status = %s WHERE txn_id = %s", (new_status, txn_id))
    return jsonify({"message": f"Transaction {txn_id} updated to {new_status}"})

@app.route('/update_passwords', methods=['POST'])
def update_passwords():
    try:
        data = request.json
        for user in data:
            user_id = user.get('user_id')
            new_password = user.get('password')

            if not user_id or not new_password:
                continue 

            hashed_password = hashlib.sha256(new_password.encode()).hexdigest()
            execute_query("UPDATE Users SET password_hash = %s WHERE user_id = %s", (hashed_password, user_id))

        return jsonify({"message": "Passwords updated successfully"}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/')
def home():
    return jsonify({"message": "Fraud Detection API is running"}), 200

if __name__ == "__main__":
    app.run(debug=True)
