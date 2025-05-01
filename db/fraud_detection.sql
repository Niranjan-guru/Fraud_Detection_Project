CREATE DATABASE  IF NOT EXISTS `fraud_detection` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;
USE `fraud_detection`;
-- MySQL dump 10.13  Distrib 8.0.40, for Win64 (x86_64)
--
-- Host: localhost    Database: fraud_detection
-- ------------------------------------------------------
-- Server version	8.0.40

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `alert_reasons`
--

DROP TABLE IF EXISTS `alert_reasons`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `alert_reasons` (
  `reason_id` int NOT NULL AUTO_INCREMENT,
  `reason_text` varchar(255) NOT NULL,
  PRIMARY KEY (`reason_id`),
  UNIQUE KEY `reason_text` (`reason_text`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `alert_reasons`
--

LOCK TABLES `alert_reasons` WRITE;
/*!40000 ALTER TABLE `alert_reasons` DISABLE KEYS */;
INSERT INTO `alert_reasons` VALUES (4,'High transaction amount detected'),(9,'Mismatch in location and registered city'),(5,'Multiple failed attempts detected'),(6,'Suspicious login from new device'),(1,'Suspicious transaction'),(8,'Transaction flagged by security team'),(7,'Unusual spending pattern'),(3,'Unusual transaction location'),(2,'Unusually High Transaction Amount, Multiple Rapid Transactions');
/*!40000 ALTER TABLE `alert_reasons` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `audit_messages`
--

DROP TABLE IF EXISTS `audit_messages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `audit_messages` (
  `message_id` int NOT NULL AUTO_INCREMENT,
  `message_text` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`message_id`),
  UNIQUE KEY `message_text` (`message_text`)
) ENGINE=InnoDB AUTO_INCREMENT=22 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `audit_messages`
--

LOCK TABLES `audit_messages` WRITE;
/*!40000 ALTER TABLE `audit_messages` DISABLE KEYS */;
INSERT INTO `audit_messages` VALUES (4,'Customer location matched device IP.'),(13,'Device fingerprint mismatch detected.'),(19,'Flagged by rules engine for audit.'),(14,'Geo-velocity rule triggered.'),(7,'High amount triggered secondary scan.'),(16,'IP address linked to prior fraud attempt.'),(2,'Location verified successfully.'),(5,'Low-risk transaction flagged for review.'),(17,'Merchant verification in progress.'),(20,'Multiple failed attempts before success.'),(8,'Repeated transactions from new device.'),(1,'Transaction automatically approved.'),(21,'Transaction bypassed normal thresholds.'),(6,'Transaction logged at ATM.'),(9,'Transaction marked suspicious.'),(15,'Transaction matched known safe pattern.'),(3,'Transaction passed velocity checks.'),(11,'Transaction pending due to OTP mismatch.'),(12,'Transaction reviewed by AI engine.'),(18,'Unusual access time logged.'),(10,'User confirmed transaction manually.');
/*!40000 ALTER TABLE `audit_messages` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `auditlog`
--

DROP TABLE IF EXISTS `auditlog`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `auditlog` (
  `log_id` int NOT NULL AUTO_INCREMENT,
  `txn_id` int NOT NULL,
  `log_time` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `message_id` int DEFAULT NULL,
  PRIMARY KEY (`log_id`),
  KEY `txn_id` (`txn_id`),
  KEY `fk_message_id` (`message_id`),
  CONSTRAINT `auditlog_ibfk_1` FOREIGN KEY (`txn_id`) REFERENCES `transactions` (`txn_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_message_id` FOREIGN KEY (`message_id`) REFERENCES `audit_messages` (`message_id`)
) ENGINE=InnoDB AUTO_INCREMENT=66 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `auditlog`
--

LOCK TABLES `auditlog` WRITE;
/*!40000 ALTER TABLE `auditlog` DISABLE KEYS */;
INSERT INTO `auditlog` VALUES (45,2,'2025-04-15 15:41:19',1),(46,3,'2025-04-15 15:41:19',2),(47,4,'2025-04-15 15:41:19',3),(48,5,'2025-04-15 15:41:19',4),(49,6,'2025-04-15 15:41:19',5),(50,7,'2025-04-15 15:41:19',6),(51,8,'2025-04-15 15:41:19',7),(52,9,'2025-04-15 15:41:19',8),(53,10,'2025-04-15 15:41:19',9),(54,11,'2025-04-15 15:41:19',10),(55,12,'2025-04-15 15:41:19',11),(56,13,'2025-04-15 15:41:19',12),(57,14,'2025-04-15 15:41:19',13),(58,15,'2025-04-15 15:41:19',14),(59,16,'2025-04-15 15:41:19',15),(60,17,'2025-04-15 15:41:19',16),(61,18,'2025-04-15 15:41:19',17),(62,19,'2025-04-15 15:41:19',18),(63,20,'2025-04-15 15:41:19',19),(64,21,'2025-04-15 15:41:19',20),(65,22,'2025-04-15 15:41:19',21);
/*!40000 ALTER TABLE `auditlog` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Temporary view structure for view `fraud_transactions`
--

DROP TABLE IF EXISTS `fraud_transactions`;
/*!50001 DROP VIEW IF EXISTS `fraud_transactions`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `fraud_transactions` AS SELECT 
 1 AS `txn_id`,
 1 AS `user_id`,
 1 AS `amount`,
 1 AS `timestamp`*/;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `fraudalerts`
--

DROP TABLE IF EXISTS `fraudalerts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `fraudalerts` (
  `alert_id` int NOT NULL AUTO_INCREMENT,
  `txn_id` int DEFAULT NULL,
  `user_id` int DEFAULT NULL,
  `flagged_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `status` enum('Flagged','Confirmed','Blocked') DEFAULT 'Flagged',
  `user_confirmation` enum('Pending','Approved','Rejected') DEFAULT 'Pending',
  `reason_id` int DEFAULT NULL,
  PRIMARY KEY (`alert_id`),
  KEY `txn_id` (`txn_id`),
  KEY `user_id` (`user_id`),
  KEY `fk_reason_id` (`reason_id`),
  CONSTRAINT `fk_reason_id` FOREIGN KEY (`reason_id`) REFERENCES `alert_reasons` (`reason_id`),
  CONSTRAINT `fraudalerts_ibfk_1` FOREIGN KEY (`txn_id`) REFERENCES `transactions` (`txn_id`),
  CONSTRAINT `fraudalerts_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `fraudalerts`
--

LOCK TABLES `fraudalerts` WRITE;
/*!40000 ALTER TABLE `fraudalerts` DISABLE KEYS */;
INSERT INTO `fraudalerts` VALUES (1,2,1,'2025-03-06 14:13:18','Confirmed','Approved',1),(2,3,1,'2025-03-06 17:17:54','Flagged','Pending',1),(3,4,1,'2025-03-06 18:10:11','Flagged','Pending',1),(4,7,1,'2025-03-10 11:49:51','Flagged','Pending',2),(5,3,3,'2025-03-22 18:19:09','Flagged','Pending',3),(6,5,5,'2025-03-22 18:19:09','Blocked','Rejected',4),(7,10,10,'2025-03-22 18:19:09','Blocked','Rejected',5),(8,12,2,'2025-03-22 18:19:09','Flagged','Pending',6),(9,15,5,'2025-03-22 18:19:09','Confirmed','Approved',7),(10,9,9,'2025-03-22 18:19:09','Flagged','Pending',8),(11,7,7,'2025-03-22 18:19:09','Blocked','Rejected',9);
/*!40000 ALTER TABLE `fraudalerts` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `roles`
--

DROP TABLE IF EXISTS `roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `roles` (
  `role_id` int NOT NULL AUTO_INCREMENT,
  `role_name` varchar(50) NOT NULL,
  PRIMARY KEY (`role_id`),
  UNIQUE KEY `role_name` (`role_name`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `roles`
--

LOCK TABLES `roles` WRITE;
/*!40000 ALTER TABLE `roles` DISABLE KEYS */;
INSERT INTO `roles` VALUES (1,'admin'),(2,'user');
/*!40000 ALTER TABLE `roles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `transactions`
--

DROP TABLE IF EXISTS `transactions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `transactions` (
  `txn_id` int NOT NULL AUTO_INCREMENT,
  `user_id` int DEFAULT NULL,
  `amount` decimal(10,2) DEFAULT NULL,
  `timestamp` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `location` varchar(100) DEFAULT NULL,
  `status` enum('approved','declined','fraudulent') DEFAULT 'approved',
  PRIMARY KEY (`txn_id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `transactions_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=23 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `transactions`
--

LOCK TABLES `transactions` WRITE;
/*!40000 ALTER TABLE `transactions` DISABLE KEYS */;
INSERT INTO `transactions` VALUES (2,1,1500.00,'2025-03-06 14:08:42','Russia','approved'),(3,1,2000.00,'2025-03-06 17:17:32','India','approved'),(4,1,2000.00,'2025-03-06 18:09:27','India','approved'),(5,1,10000.00,'2025-03-10 11:44:43','New York','approved'),(6,1,10000.00,'2025-03-10 11:44:45','New York','approved'),(7,1,1000000.00,'2025-03-10 11:49:51','New York','approved'),(8,1,5000.00,'2025-03-22 18:19:03','New York','approved'),(9,2,2000.00,'2025-03-22 18:19:03','Los Angeles','declined'),(10,3,3000.00,'2025-03-22 18:19:03','Chicago','fraudulent'),(11,4,2500.00,'2025-03-22 18:19:03','San Francisco','approved'),(12,5,10000.00,'2025-03-22 18:19:03','Las Vegas','fraudulent'),(13,6,750.00,'2025-03-22 18:19:03','Houston','approved'),(14,7,1800.00,'2025-03-22 18:19:03','Miami','declined'),(15,8,6000.00,'2025-03-22 18:19:03','Dallas','approved'),(16,9,1500.00,'2025-03-22 18:19:03','Seattle','approved'),(17,10,8000.00,'2025-03-22 18:19:03','San Diego','fraudulent'),(18,1,2300.00,'2025-03-22 18:19:03','Denver','declined'),(19,2,9200.00,'2025-03-22 18:19:03','Boston','fraudulent'),(20,3,4500.00,'2025-03-22 18:19:03','Atlanta','approved'),(21,4,6200.00,'2025-03-22 18:19:03','Detroit','declined'),(22,5,3000.00,'2025-03-22 18:19:03','Austin','approved');
/*!40000 ALTER TABLE `transactions` ENABLE KEYS */;
UNLOCK TABLES;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `before_insert_transactions` BEFORE INSERT ON `transactions` FOR EACH ROW BEGIN
    IF NEW.amount > 50000 THEN
        SET NEW.status = 'Fraudulent';
        
        INSERT INTO AuditLog (txn_id, log_message)
        VALUES (NEW.txn_id, CONCAT('Transaction auto-flagged as fraudulent due to high amount: ₹', NEW.amount));
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `after_update_transaction_status` AFTER UPDATE ON `transactions` FOR EACH ROW BEGIN
    IF OLD.status <> 'Fraudulent' AND NEW.status = 'Fraudulent' THEN
        INSERT INTO AuditLog (txn_id, log_message)
        VALUES (NEW.txn_id, CONCAT('Transaction marked as Fraudulent. User ID: ', NEW.user_id));
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `after_delete_transaction` AFTER DELETE ON `transactions` FOR EACH ROW BEGIN
    INSERT INTO AuditLog (txn_id, log_message)
    VALUES (
        OLD.txn_id,
        CONCAT('Transaction ID ', OLD.txn_id, ' (Amount: ₹', OLD.amount, ') was deleted.')
    );
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `user_emails`
--

DROP TABLE IF EXISTS `user_emails`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_emails` (
  `user_id` int DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  KEY `user_id` (`user_id`),
  CONSTRAINT `user_emails_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_emails`
--

LOCK TABLES `user_emails` WRITE;
/*!40000 ALTER TABLE `user_emails` DISABLE KEYS */;
INSERT INTO `user_emails` VALUES (3,'admin@example.com'),(4,'alice@gmail.com'),(5,'bob@gmail.com'),(6,'charlie@gmail.com'),(7,'david@gmail.com'),(8,'eva@gmail.com'),(9,'frank@gmail.com'),(10,'grace@gmail.com'),(11,'henry@gmail.com'),(12,'ivy@gmail.com'),(13,'jack@gmail.com'),(1,'john@example.com'),(2,'newuser@example.com');
/*!40000 ALTER TABLE `user_emails` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `user_id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(100) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `password_hash` varchar(255) DEFAULT NULL,
  `role_id` int DEFAULT NULL,
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `email` (`email`),
  KEY `fk_role_id` (`role_id`),
  CONSTRAINT `fk_role_id` FOREIGN KEY (`role_id`) REFERENCES `roles` (`role_id`)
) ENGINE=InnoDB AUTO_INCREMENT=14 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES (1,'John Doe','john@example.com','ab23111cbs',2),(2,'New User','newuser@example.com','fbb4a8a163ffa958b4f02bf9cabb30cfefb40de803f2c4c346a9d39b3be1b544',2),(3,'Admin User','admin@example.com','7676aaafb027c825bd9abab78b234070e702752f625b752e55e55b48e607e358',1),(4,'Alice Johnson','alice@gmail.com','cdfaf379d5fa7c81e95399e2e9e0fbaa210e586e157e6b962f35fff09c830483',2),(5,'Bob Williams','bob@gmail.com','d4008aa16ff36fc05875333c994d448858bd5edf8996bdc773932d6f9a7dd0a6',2),(6,'Charlie Brown','charlie@gmail.com','2c2748ebbdcec0b2c7aa2151e55d0d51d5f10c5db5954a552a3daa5dadf1b0a5',2),(7,'David Smith','david@gmail.com','7cc41c818935a5f7a1d0ac08eaa705b661c5714a7f4c0199da2dc8b2063aed12',2),(8,'Eva Adams','eva@gmail.com','98e0f289d9397fbe31fd033a282680cb42fb6636295170ba298dcd3eb6eef085',2),(9,'Frank White','frank@gmail.com','1ff1cf4ccec0f6d230b40a2c5be505c82eddf0907fa668e9891053e409d28a6c',2),(10,'Grace Lee','grace@gmail.com','0e2b091f430dc1adcc0ad686c74f4e6e76b47fb4a0b5d13f3980324e969facbc',2),(11,'Henry Ford','henry@gmail.com','0720096739a442f043ee79d2e21ec8afe63d60b99ee73503a32fd7cf2c2ece3c',2),(12,'Ivy Carter','ivy@gmail.com','887387b372b9ddca2bfd98ec5e107a688c72ed17734376ae4a4432d50a3c6f03',2),(13,'Jack Black','jack@gmail.com','a8cf72e488b47e792f25930dd3817956c9ab407c682c61bc7792b69a94794574',1);
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `after_delete_user` AFTER DELETE ON `users` FOR EACH ROW BEGIN
    INSERT INTO AuditLog (txn_id, log_message)
    VALUES (
        NULL, 
        CONCAT('User ID ', OLD.user_id, ' - ', OLD.name, ' has been deleted from the system.')
    );
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Dumping routines for database 'fraud_detection'
--
/*!50003 DROP PROCEDURE IF EXISTS `BlockFraudAlert` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `BlockFraudAlert`(IN p_alert_id INT, IN p_message_id INT)
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
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `ProcessFraudTransactions` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `ProcessFraudTransactions`()
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
          INSERT INTO AuditLog (txn_id, log_message)
          VALUES (txn_id, CONCAT('Fraud detected for Transaction ID: ', txn_id, ', User ID: ', user_id));
		END IF;
    END LOOP;
    
    CLOSE fraud_cursor;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Final view structure for view `fraud_transactions`
--

/*!50001 DROP VIEW IF EXISTS `fraud_transactions`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `fraud_transactions` AS select `transactions`.`txn_id` AS `txn_id`,`transactions`.`user_id` AS `user_id`,`transactions`.`amount` AS `amount`,`transactions`.`timestamp` AS `timestamp` from `transactions` where (`transactions`.`status` = 'Fraudulent') */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2025-05-01 12:00:14
