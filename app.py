from fastapi import FastAPI, HTTPException, Request, Body
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import pymysql
import hashlib
import logging
from typing import Optional, List, Dict

from jose import JWTError, jwt
from datetime import datetime, timedelta
from fastapi.security import OAuth2PasswordBearer
from fastapi import Depends

import os
from datetime import datetime, timedelta
from jose import JWTError, jwt
from passlib.context import CryptContext


app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

logging.basicConfig(filename='fraud_detection.log', level=logging.INFO, format='%(asctime)s - %(message)s')

# JWT settings
SECRET_KEY = "4cb4b1ab187bbab706d085e79a3b3b1fb76dd78a4703754e19d2e5e3f40b4c81"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login")

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def create_access_token(data: dict, expires_delta: timedelta = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)):
    to_encode = data.copy()
    expire = datetime.utcnow() + expires_delta
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

# To verify a password
def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

# To hash a password
def get_password_hash(password):
    return pwd_context.hash(password)

# To decode the JWT token
def decode_jwt_token(token: str):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        return None

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

def create_access_token(data: Dict[str,str], expires_delta: timedelta = None):
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def get_current_user(token: str = Depends(oauth2_scheme)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("user_id")
        role = payload.get("role")
        if user_id is None or role is None:
            raise HTTPException(status_code=401, detail="Invalid token")
        return {"user_id": user_id, "role": role}
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")



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
    
    status = determine_transaction_status(txn.amount)
    txn_id = execute_query(
        "INSERT INTO transactions (user_id, amount, location, status) VALUES (%s, %s, %s, 'under_review')",
        (txn.user_id, txn.amount, txn.location), fetch=False)

    detect_fraud({"txn_id": txn_id, "user_id": txn.user_id, "amount": txn.amount, "location": txn.location})

    return {"message": "Transaction recorded", "txn_id": txn_id}

def get_user_average_spending(user_id):
    result = execute_query("SELECT AVG(amount) as avg_spend FROM transactions WHERE user_id = %s AND is_deleted = FALSE", (user_id,))
    return result[0]['avg_spend'] if result[0]['avg_spend'] else 0

def is_unusual_location(user_id, location):
    result = execute_query("SELECT COUNT(*) as count FROM transactions WHERE user_id = %s AND location = %s AND is_deleted = FALSE", (user_id, location))
    return result[0]['count'] == 0

def get_recent_transactions(user_id):
    return execute_query("SELECT txn_id FROM transactions WHERE user_id = %s AND timestamp >= NOW() - INTERVAL 10 MINUTE AND is_deleted = FALSE", (user_id,))

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

        log_audit(txn_id, f"Transaction flagged: {', '.join(flagged_reasons)}")
        # Update transaction status to 'under_review'
        execute_query("UPDATE transactions SET status = 'under_review' WHERE txn_id = %s", (txn_id,), fetch=False)

        logging.info(f"User {user_id} - ALERT: Suspicious transaction {txn_id} flagged! Reason: {', '.join(flagged_reasons)}")

def log_audit(txn_id: int, message_text: str):
    # Step 1: Insert message into audit_messages if not exists
    insert_msg_query = """
        INSERT IGNORE INTO audit_messages (message_text)
        VALUES (%s)
    """
    execute_query(insert_msg_query, (message_text,), fetch=False)

    # Step 2: Retrieve message_id
    select_msg_id_query = """
        SELECT message_id FROM audit_messages WHERE message_text = %s
    """
    result = execute_query(select_msg_id_query, (message_text,))
    if not result:
        return  # Exit if something went wrong
    message_id = result[0]['message_id']

    # Step 3: Insert into auditlog
    insert_log_query = """
        INSERT INTO auditlog (txn_id, message_id) VALUES (%s, %s)
    """
    execute_query(insert_log_query, (txn_id, message_id), fetch=False)

def determine_transaction_status(amount: float, user_response: Optional[str] = None, admin_response: Optional[str] = None) -> str:
    if amount > 50000:
        return "fraudulent"
    elif amount > 10000:
        return "under_review"
    elif admin_response and admin_response.upper() == "NO":
        return "fraudulent"
    elif user_response and user_response.upper() == "NO":
        return "fraudulent"
    return "approved"

@app.delete("/soft_delete/{table}/{record_id}")
async def soft_delete_record(table: str, record_id: int):
    valid_tables = {
        "users": "user_id",
        "transactions": "txn_id",
        "fraudalerts": "alert_id"
    }
    
    if table not in valid_tables:
        raise HTTPException(status_code=400, detail="Invalid table")

    id_field = valid_tables[table]
    query = f"UPDATE {table} SET is_deleted = TRUE WHERE {id_field} = %s"
    execute_query(query, (record_id,), fetch=False)
    
    return {"message": f"{table} record {record_id} soft-deleted successfully."}

@app.get("/fraud_alerts")
async def view_fraud_alerts():
    return {"fraud_alerts": execute_query("SELECT * FROM fraudalerts WHERE is_deleted = FALSE")}

@app.post("/user_confirm_transaction")
async def user_confirm_transaction(confirm: Confirmation):
    response = confirm.response.upper()
    if response == "YES":
        execute_query("UPDATE fraudalerts SET user_confirmation = 'Approved' WHERE txn_id = %s", (confirm.txn_id,), fetch=False)
        log_audit(confirm.txn_id, "User approved transaction")
        return {"message": "Transaction approved by user."}
    elif response == "NO":
        execute_query("UPDATE fraudalerts SET user_confirmation = 'Rejected' WHERE txn_id = %s", (confirm.txn_id,), fetch=False)
        log_audit(confirm.txn_id, "User rejected transaction")
        return {"message": "Transaction rejected by user."}
    raise HTTPException(status_code=400, detail="Invalid response")

@app.post("/admin_confirm_transaction")
async def admin_confirm_transaction(confirm: AdminConfirmation, user=Depends(get_current_user)):
    # Check if admin is authorized
    if user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Unauthorized. Only admins can confirm transactions.")
    # Fetch transaction details to determine its status logic
    txn = execute_query("SELECT amount, status FROM transactions WHERE txn_id = %s AND is_deleted = FALSE", (confirm.txn_id,))
    
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

    new_status = determine_transaction_status(amount, admin_response=confirm.response)

    # Update the transaction status directly in the same route
    if current_status != new_status:
        execute_query("UPDATE transactions SET status = %s WHERE txn_id = %s AND is_deleted = FALSE", (new_status, confirm.txn_id), fetch=False)
        log_audit(confirm.txn_id, f"Admin {confirm.user_id} confirmed transaction as {new_status}")

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
    
    query = "SELECT user_id, name, role_id FROM Users WHERE email = %s AND password_hash = %s AND is_deleted = FALSE"
    result = execute_query(query, (user.email, hashed_password))
    
    if not result:
        raise HTTPException(status_code=401, detail="Invalid email or password")
    
    user_data = result[0]
    
    # Get role name from Roles table
    role_result = execute_query("SELECT role_name FROM roles WHERE role_id = %s", (user_data["role_id"],))
    role_name = role_result[0]["role_name"] if role_result else "unknown"
    
    access_token = create_access_token(data={"user_id": user_data["user_id"], "role": role_name})
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user_id": user_data["user_id"],
        "name": user_data["name"],
        "role": role_name
    }

@app.get("/dashboard_summary")
async def dashboard_summary():
    total_users = execute_query("SELECT COUNT(*) as count FROM Users WHERE is_deleted = FALSE")[0]["count"]
    total_txns = execute_query("SELECT COUNT(*) as count FROM transactions WHERE is_deleted = FALSE")[0]["count"]
    flagged_txns = execute_query("SELECT COUNT(*) as count FROM fraudalerts")[0]["count"]
    
    return {
        "total_users": total_users,
        "total_transactions": total_txns,
        "flagged_transactions": flagged_txns
    }

@app.get("/dashboard/user/{user_id}")
async def user_dashboard(user_id: int):
    total_txns = execute_query("SELECT COUNT(*) as count FROM transactions WHERE user_id = %s AND is_deleted = FALSE", (user_id,))[0]["count"]
    flagged_txns = execute_query("SELECT COUNT(*) as count FROM fraudalerts WHERE user_id = %s", (user_id,))[0]["count"]
    
    return {
        "user_id": user_id,
        "total_transactions": total_txns,
        "flagged_transactions": flagged_txns
    }

@app.get("/dashboard/fraud_statistics")
async def fraud_stats():
    reasons = execute_query("SELECT reason, COUNT(*) as count FROM fraudalerts GROUP BY reason")
    return {"fraud_reasons": reasons}

@app.get("/transaction_summary")
async def transaction_summary():
    # Total transactions
    total_transactions = execute_query("SELECT COUNT(*) as total FROM transactions WHERE is_deleted = 0")[0]["total"]

    # Flagged transactions
    flagged_transactions = execute_query("SELECT COUNT(*) as flagged FROM fraudalerts WHERE status = 'Flagged' AND is_deleted = 0")[0]["flagged"]

    # Under review transactions
    under_review_transactions = execute_query("SELECT COUNT(*) as under_review FROM transactions WHERE status = 'under_review' AND is_deleted = 0")[0]["under_review"]

    return {
        "total_transactions": total_transactions,
        "flagged_transactions": flagged_transactions,
        "under_review_transactions": under_review_transactions
    }

@app.get("/user_summary")
async def user_summary():
    # Total users
    total_users = execute_query("SELECT COUNT(*) as total FROM users WHERE is_deleted = 0")[0]["total"]

    # Admin users
    total_admins = execute_query("SELECT COUNT(*) as total FROM users WHERE role_id = 1 AND is_deleted = 0")[0]["total"]

    # Regular users
    total_regular_users = execute_query("SELECT COUNT(*) as total FROM users WHERE role_id = 2 AND is_deleted = 0")[0]["total"]

    return {
        "total_users": total_users,
        "total_admins": total_admins,
        "total_regular_users": total_regular_users
    }

@app.get("/fraud_alert_summary")
async def fraud_alert_summary():
    # Pending fraud alerts
    pending_alerts = execute_query("SELECT COUNT(*) as pending FROM fraudalerts WHERE user_confirmation = 'Pending' AND is_deleted = 0")[0]["pending"]

    # Approved fraud alerts
    approved_alerts = execute_query("SELECT COUNT(*) as approved FROM fraudalerts WHERE user_confirmation = 'Approved' AND is_deleted = 0")[0]["approved"]

    # Rejected fraud alerts
    rejected_alerts = execute_query("SELECT COUNT(*) as rejected FROM fraudalerts WHERE user_confirmation = 'Rejected' AND is_deleted = 0")[0]["rejected"]

    return {
        "pending_alerts": pending_alerts,
        "approved_alerts": approved_alerts,
        "rejected_alerts": rejected_alerts
    }

@app.get("/")
async def home():
    return {"message": "Fraud Detection API with FastAPI is running!"}
