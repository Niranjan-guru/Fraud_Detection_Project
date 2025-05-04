-- After importing the fraud_detection.sql into your workbench please make sure to run this entire sql commands.

-- If there are any errors please create a issue in the repository I will definitely look into it

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
-- Please note the change in this function to avoid any operational errors in the api
CREATE TRIGGER before_insert_transactions
BEFORE INSERT ON transactions
FOR EACH ROW
BEGIN
    -- All DECLARE statements must come first
    DECLARE msg_text VARCHAR(255);
    DECLARE msg_id INT;

    IF NEW.amount > 50000 THEN
        SET msg_text = CONCAT('Transaction auto-flagged as fraudulent due to high amount: ₹', NEW.amount);

        -- Insert the message if not exists
        INSERT IGNORE INTO audit_messages (message_text) VALUES (msg_text);

        -- Get the message ID
        SELECT message_id INTO msg_id FROM audit_messages WHERE message_text = msg_text;

        -- Use message_id in auditlog
        INSERT INTO auditlog (txn_id, message_id) VALUES (NEW.txn_id, msg_id);

        SET NEW.status = 'fraudulent';
    END IF;
END$$

DELIMITER ;

DELIMITER $$

DELIMITER $$

-- Please note these changes made in this function to avoid any operational errors in api
CREATE TRIGGER after_update_transaction_status
AFTER UPDATE ON transactions
FOR EACH ROW
BEGIN
    -- Declare necessary variables first
    DECLARE msg_text VARCHAR(255);
    DECLARE msg_id INT;

    IF OLD.status <> NEW.status THEN
        -- Prepare the log message text
        SET msg_text = CONCAT('Status changed from ', OLD.status, ' to ', NEW.status);

        -- Insert the message text into audit_messages if not exists
        INSERT IGNORE INTO audit_messages (message_text) VALUES (msg_text);

        -- Retrieve the message_id corresponding to the message_text
        SELECT message_id INTO msg_id FROM audit_messages WHERE message_text = msg_text;

        -- Insert into AuditLog with the message_id
        INSERT INTO AuditLog (txn_id, message_id)
        VALUES (NEW.txn_id, msg_id);
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
-- This ensures no one else modifies that row until you finish
-- Session 1
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;
SELECT * FROM fraudalerts WHERE alert_id = 8 FOR UPDATE;

UPDATE fraudalerts
SET status = 'Blocked', user_confirmation = 'Rejected'
WHERE alert_id = 8;

UPDATE transactions
SET status = 'fraudulent'
WHERE txn_id = (SELECT txn_id FROM fraudalerts WHERE alert_id = 8);

INSERT INTO auditlog(txn_id, log_time, message_id) VALUES((SELECT txn_id FROM fraudalerts WHERE alert_id=8), CURRENT_TIMESTAMP, 9);

COMMIT;

-- SESSION 2: This will be blocked until SESSION 1 commits
START TRANSACTION;

-- Will wait because row is locked by Session 1
SELECT * FROM fraudalerts WHERE alert_id = 8 FOR UPDATE;

-- After Session 1 commits, this proceeds
UPDATE fraudalerts
SET status = 'Confirmed', user_confirmation = 'Approved'
WHERE alert_id = 8;

COMMIT;

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


