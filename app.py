from fastapi import FastAPI, HTTPException, Request, Body
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import pymysql
import hashlib
import logging
from typing import Optional, List

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

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

class UserCreate(BaseModel):
    name: str
    email: str
    password: str
    role: Optional[str] = "user"

class TransactionCreate(BaseModel):
    user_id: int
    amount: float
    location: str

class Confirmation(BaseModel):
    txn_id: int
    response: str

class AdminConfirmation(BaseModel):
    txn_id: int
    response: str
    admin_id: int

class PasswordUpdate(BaseModel):
    user_id: int
    password: str

class UserLogin(BaseModel):
    email: str
    password: str

class transactionstatusUpdate(BaseModel):
    status: str

@app.post("/add_user")
async def add_user(user: UserCreate):
    role_map = {'admin': 1, 'user': 2}
    if user.role not in role_map:
        raise HTTPException(status_code=400, detail="Invalid role. Must be 'admin' or 'user'.")

    role_id = role_map[user.role]
    hashed_password = hashlib.sha256(user.password.encode()).hexdigest()

    query = "INSERT INTO Users (name, email, password_hash, role_id) VALUES (%s, %s, %s, %s)"
    execute_query(query, (user.name, user.email, hashed_password, role_id), fetch=False)
    return {"message": f"User {user.name} added successfully as {user.role}"}

@app.post("/add_transaction")
async def add_transaction(txn: TransactionCreate):
    user_exists = execute_query("SELECT user_id FROM Users WHERE user_id = %s", (txn.user_id,))
    if not user_exists:
        raise HTTPException(status_code=400, detail="User ID does not exist")

    txn_id = execute_query(
        "INSERT INTO transactions (user_id, amount, location, status) VALUES (%s, %s, %s, 'under_review')",
        (txn.user_id, txn.amount, txn.location), fetch=False)

    detect_fraud({"txn_id": txn_id, "user_id": txn.user_id, "amount": txn.amount, "location": txn.location})

    return {"message": "Transaction recorded", "txn_id": txn_id}

def get_user_average_spending(user_id):
    result = execute_query("SELECT AVG(amount) as avg_spend FROM transactions WHERE user_id = %s", (user_id,))
    return result[0]['avg_spend'] if result[0]['avg_spend'] else 0

def is_unusual_location(user_id, location):
    result = execute_query("SELECT COUNT(*) as count FROM transactions WHERE user_id = %s AND location = %s", (user_id, location))
    return result[0]['count'] == 0

def get_recent_transactions(user_id):
    return execute_query("SELECT txn_id FROM transactions WHERE user_id = %s AND timestamp >= NOW() - INTERVAL 10 MINUTE", (user_id,))

def flag_transaction(txn_id, user_id, reasons):
    execute_query("INSERT INTO fraudalerts (txn_id, user_id, reason, status, user_confirmation) VALUES (%s, %s, %s, 'Flagged', 'Pending')",
                  (txn_id, user_id, ", ".join(reasons)), fetch=False)

def detect_fraud(transaction):
    user_id = transaction["user_id"]
    amount = transaction["amount"]
    location = transaction["location"]
    txn_id = transaction["txn_id"]

    flagged_reasons = []
    avg_spend = get_user_average_spending(user_id)

    if avg_spend > 0 and amount > avg_spend * 5:
        flagged_reasons.append("Unusually High Transaction Amount")
    if is_unusual_location(user_id, location):
        flagged_reasons.append("Transaction from Unusual Location")
    if len(get_recent_transactions(user_id)) >= 3:
        flagged_reasons.append("Multiple Rapid transactions")

    if flagged_reasons:
        flag_transaction(txn_id, user_id, flagged_reasons)

        execute_query("UPDATE transactions SET status = 'under_review' WHERE txn_id = %s", (txn_id,), fetch=False)

        logging.info(f"User {user_id} - ALERT: Suspicious transaction {txn_id} flagged! Reason: {', '.join(flagged_reasons)}")

@app.get("/fraud_alerts")
async def view_fraud_alerts():
    return {"fraud_alerts": execute_query("SELECT * FROM fraudalerts")}

@app.post("/user_confirm_transaction")
async def user_confirm_transaction(confirm: Confirmation):
    response = confirm.response.upper()
    if response == "YES":
        execute_query("UPDATE fraudalerts SET user_confirmation = 'Approved' WHERE txn_id = %s", (confirm.txn_id,), fetch=False)
        return {"message": "Transaction approved by user."}
    elif response == "NO":
        execute_query("UPDATE fraudalerts SET user_confirmation = 'Rejected' WHERE txn_id = %s", (confirm.txn_id,), fetch=False)
        return {"message": "Transaction rejected by user."}
    raise HTTPException(status_code=400, detail="Invalid response")

@app.post("/admin_confirm_transaction")
async def admin_confirm_transaction(confirm: AdminConfirmation):
    # Check if admin is authorized
    role_check = execute_query("SELECT role_id FROM users WHERE user_id = %s", (confirm.admin_id,))
    if not role_check or role_check[0]["role_id"] != 1:
        raise HTTPException(status_code=403, detail="Unauthorized. Only admins can confirm transactions.")

    # Fetch transaction details to determine its status logic
    txn = execute_query("SELECT amount, status FROM transactions WHERE txn_id = %s", (confirm.txn_id,))
    
    if not txn:
        raise HTTPException(status_code=404, detail="Transaction not found")
    
    # Extract transaction amount and current status
    amount = txn[0]["amount"]
    current_status = txn[0]["status"]

    # Default to current status if no change needed
    new_status = current_status

    # Check if the response is "YES" or "NO" and set appropriate logic
    if confirm.response.upper() == "YES":
        new_status = "approved"
    elif confirm.response.upper() == "NO":
        new_status = "fraudulent"

    # Automatic logic to update transaction status if needed
    if amount > 50000:
        new_status = "fraudulent"
    elif amount > 10000:
        new_status = "under_review"
    elif new_status == "approved":
        new_status = "approved"

    # Update the transaction status directly in the same route
    if current_status != new_status:
        execute_query("UPDATE transactions SET status = %s WHERE txn_id = %s", (new_status, confirm.txn_id), fetch=False)

        # Optionally, you could add additional actions based on the new status, such as logging or auditing.
        return {"message": f"Transaction {confirm.txn_id} updated to {new_status} by admin."}
    
    return {"message": f"Transaction {confirm.txn_id} already has status {current_status}"}

@app.post("/update_passwords")
async def update_passwords(passwords: List[PasswordUpdate]):
    for user in passwords:
        if not user.user_id or not user.password:
            continue
        hashed = hashlib.sha256(user.password.encode()).hexdigest()
        execute_query("UPDATE Users SET password_hash = %s WHERE user_id = %s", (hashed, user.user_id), fetch=False)
    return {"message": "Passwords updated successfully"}

@app.post("/login")
async def login(user: UserLogin):
    hashed_password = hashlib.sha256(user.password.encode()).hexdigest()
    
    query = "SELECT user_id, name, role_id FROM Users WHERE email = %s AND password_hash = %s"
    result = execute_query(query, (user.email, hashed_password))
    
    if not result:
        raise HTTPException(status_code=401, detail="Invalid email or password")
    
    user_data = result[0]
    
    # Get role name from Roles table
    role_result = execute_query("SELECT role_name FROM roles WHERE role_id = %s", (user_data["role_id"],))
    role_name = role_result[0]["role_name"] if role_result else "unknown"
    
    return {
        "message": "Login successful",
        "user_id": user_data["user_id"],
        "name": user_data["name"],
        "role": role_name
    }

@app.get("/")
async def home():
    return {"message": "Fraud Detection API with FastAPI is running!"}
