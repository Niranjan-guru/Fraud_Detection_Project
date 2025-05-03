SELECT u.name, u.email, t.amount, t.timestamp, t.status
FROM Users u
INNER JOIN Transactions t ON u.user_id = t.txn_id
WHERE t.status = 'Fraudulent';

SELECT user_id, amount
FROM Transactions 
WHERE amount > (SELECT AVG(amount) FROM Transactions);

select * from transactions;

CREATE VIEW Fraud_Transactions AS
SELECT txn_id, user_id, amount, timestamp
FROM transactions
WHERE status = 'Fraudulent';


CREATE TABLE AuditLog (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    txn_id INT NOT NULL,
    log_message TEXT NOT NULL,
    log_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (txn_id) REFERENCES transactions(txn_id) ON DELETE CASCADE
);

DELIMITER $$

CREATE PROCEDURE ProcessFraudTransactions()
BEGIN
    DECLARE txn_id INT;
    DECLARE user_id INT;
    DECLARE done INT DEFAULT FALSE;
    DECLARE fraud_cursor CURSOR FOR
    SELECT txn_id, user_id FROM transactions WHERE status = 'fraudulent';
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    OPEN fraud_cursor;
    read_loop: LOOP
        FETCH fraud_cursor INTO txn_id, user_id;
        
        IF done THEN 
            LEAVE read_loop;
        END IF;
        IF txn_id IS NOT NULL THEN
          INSERT INTO auditlog (txn_id, log_message)
          VALUES (txn_id, CONCAT('Fraud detected for Transaction ID: ', txn_id, ', User ID: ', user_id));
		END IF;
    END LOOP;
    
    CLOSE fraud_cursor;
END$$
DELIMITER ;


DELIMITER $$

CREATE TRIGGER before_insert_transactions
BEFORE INSERT ON transactions
FOR EACH ROW
BEGIN
    IF NEW.amount > 50000 THEN
        SET NEW.status = 'Fraudulent';
        
        INSERT INTO auditlog (txn_id, log_message)
        VALUES (NEW.txn_id, CONCAT('Transaction auto-flagged as fraudulent due to high amount: ₹', NEW.amount));
    END IF;
END$$

DELIMITER ;


DELIMITER $$

CREATE TRIGGER after_update_transaction_status
AFTER UPDATE ON transactions
FOR EACH ROW
BEGIN
    IF OLD.status <> 'Fraudulent' AND NEW.status = 'Fraudulent' THEN
        INSERT INTO AuditLog (txn_id, log_message)
        VALUES (NEW.txn_id, CONCAT('Transaction marked as Fraudulent. User ID: ', NEW.user_id));
    END IF;
END$$  

DELIMITER ;


DELIMITER $$

CREATE TRIGGER after_delete_user
AFTER DELETE ON users
FOR EACH ROW
BEGIN
    INSERT INTO AuditLog (txn_id, log_message)
    VALUES (
        NULL, 
        CONCAT('User ID ', OLD.user_id, ' - ', OLD.name, ' has been deleted from the system.')
    );
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS ProcessFraudTransactions;
use fraud_detection;
CALL ProcessFraudTransactions();
show tables;
select * from fraudalerts;
select * from users;


DELIMITER $$

DELIMITER $$

CREATE TRIGGER after_delete_transaction
AFTER DELETE ON transactions
FOR EACH ROW
BEGIN
    INSERT INTO AuditLog (txn_id, log_message)
    VALUES (
        OLD.txn_id,
        CONCAT('Transaction ID ', OLD.txn_id, ' (Amount: ₹', OLD.amount, ') was deleted.')
    );
END$$

DELIMITER ;

-- Applying Transaction and Concurrency control
-- _________________________________________________/*

-- Update fraudalerts and related transactions and insert into auditlog safely
-- START TRANSACTION;

-- -- 1. Lock the fraudalert row for update
-- SELECT * FROM fraudalerts WHERE alert_id = 6 FOR UPDATE;

-- -- 2. Update fraudalerts
-- UPDATE fraudalerts
-- SET status = 'Blocked', user_confirmation = 'Rejected'
-- WHERE alert_id = 6;

-- -- 3. Update the associated transaction status
-- UPDATE transactions
-- SET status = 'fraudulent'
-- WHERE txn_id = (SELECT txn_id FROM fraudalerts WHERE alert_id = 6);

-- -- 4. Log the change into auditlog
-- INSERT INTO auditlog (txn_id, log_time, message_id)
-- VALUES (
--   (SELECT txn_id FROM fraudalerts WHERE alert_id = 6),
--   CURRENT_TIMESTAMP,
--   9 -- Assuming this message_id = "Transaction marked suspicious"
-- );

-- COMMIT;
-- If anything fails use "ROLLBACK;"

-- Row Level Locking
-- This ensures no one else modifies that row until you finish
-- 
START TRANSACTION;
SELECT * FROM fraudalerts WHERE alert_id = 8 FOR UPDATE;
-- Do your updates here...
COMMIT;                     

-- Set Isolation level
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;
-- Your queries here
COMMIT;

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
-- Stricted form to avoid phantom reads
-- Example Stored Procedure

DELIMITER $$

CREATE PROCEDURE BlockFraudAlert(IN p_alert_id INT, IN p_message_id INT)
BEGIN
  DECLARE v_txn_id INT;

  START TRANSACTION;

  -- Lock and get txn_id
  SELECT txn_id INTO v_txn_id
  FROM fraudalerts
  WHERE alert_id = p_alert_id
  FOR UPDATE;

  -- Update fraudalert
  UPDATE fraudalerts
  SET status = 'Blocked', user_confirmation = 'Rejected'
  WHERE alert_id = p_alert_id;

  -- Update related transaction
  UPDATE transactions
  SET status = 'fraudulent'
  WHERE txn_id = v_txn_id;

  -- Insert audit log
  INSERT INTO auditlog (txn_id, log_time, message_id)
  VALUES (v_txn_id, CURRENT_TIMESTAMP, p_message_id);

  COMMIT;
END $$

DELIMITER ;

-- Add these lines at the end after executing all other command in either mysql command shell or workbench before executing the backend code
ALTER TABLE users ADD COLUMN is_deleted BOOLEAN DEFAULT FALSE;
ALTER TABLE transactions ADD COLUMN is_deleted BOOLEAN DEFAULT FALSE;
ALTER TABLE fraudalerts ADD COLUMN is_deleted BOOLEAN DEFAULT FALSE;


