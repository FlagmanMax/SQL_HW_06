USE lesson_04;
/*
Создайте процедуру, которая выберет для одного пользователя 5
пользователей в случайной комбинации, которые удовлетворяют хотя бы одному
критерию: 
1) из одного города; 
2) состоят в одной группе; 
3) друзья друзей.
*/

DROP PROCEDURE IF EXISTS friend_list;
DELIMITER //
CREATE PROCEDURE friend_list(user_id_request INT)
BEGIN
	WITH friends AS
	(
		(SELECT initiator_user_id AS id
		FROM friend_requests 
        WHERE status = "approved" AND user_id_request = target_user_id)
        UNION
        (SELECT target_user_id 
		FROM friend_requests
        WHERE status = "approved" AND user_id_request = initiator_user_id)
	)

	SELECT p2.user_id 
    FROM profiles p1
    JOIN profiles p2 ON p1.hometown=p2.hometown
    WHERE p1.user_id = user_id_request AND p2.user_id <> user_id_request
    
    UNION
    SELECT u2.user_id 
    FROM users_communities u1
    JOIN users_communities u2 ON u1.community_id=u2.community_id
    WHERE u1.user_id = user_id_request AND u2.user_id <> user_id_request
    
    UNION
    SELECT fr2.target_user_id 
    FROM friends fr1
    JOIN friend_requests fr2 ON fr2.initiator_user_id = fr1.id
	WHERE fr2.target_user_id <> user_id_request AND fr2.status = "approved"
    
    UNION
    SELECT fr2.initiator_user_id 
    FROM friends fr1
    JOIN friend_requests fr2 ON fr2.target_user_id = fr1.id
	WHERE fr2.initiator_user_id <> user_id_request AND fr2.status = "approved"
    
    ORDER BY RAND()
    LIMIT 5;
END//
DELIMITER ;

CALL friend_list(1);

/*
Задача 2. Создание функции, вычисляющей
коэффициент популярности пользователя
(по заявкам на дружбу – таблица friend_requests)
*/
DROP FUNCTION IF EXISTS friends_get_ratio;

DELIMITER //
CREATE FUNCTION friends_get_ratio(user_id INT)
RETURNS FLOAT READS SQL DATA
BEGIN
	DECLARE requests_to INT;
    DECLARE requests_from INT;
	
	SET requests_to = 
	(
		SELECT COUNT(*) 
		FROM friend_requests
		WHERE target_user_id = user_id
	);
    
	SELECT COUNT(*) 
    INTO requests_from
	FROM friend_requests
	WHERE initiator_user_id = user_id;
	
	SET @res = ( IF (requests_from<>0, requests_to/requests_from, NULL) );
    
	RETURN @res;#requests_to/requests_from;
END//
DELIMITER ;

SELECT friends_get_ratio(1);

# HW_06_01
/*
Создайте таблицу users_old, аналогичную таблице users. Создайте процедуру, с
помощью которой можно переместить любого (одного) пользователя из таблицы
users в таблицу users_old. (использование транзакции с выбором commit или rollback
– обязательно).
*/

/*Создать таблицу без данных*/
CREATE TABLE users_old AS SELECT * FROM users WHERE 1=0;

DROP PROCEDURE IF EXISTS move_to_user_old;

DELIMITER //
CREATE PROCEDURE move_to_user_old(move_id INT)
BEGIN
	START TRANSACTION;
			
            INSERT INTO users_old (id,firstname, lastname, email)
			(
				SELECT id,firstname, lastname, email
				FROM users 
				WHERE id = move_id
            );
            
            DELETE
            FROM users
            WHERE id = move_id;

    COMMIT; -- применить изменения
END//
DELIMITER ;

CALL move_to_user_old(2);
SELECT * 
FROM users_old;

# HW_06_02
/* 2. Создайте хранимую функцию hello(), которая будет возвращать приветствие, в зависимости от текущего времени суток. С 6:00 до 12:00 функция должна возвращать фразу "Доброе утро", с 12:00 до 18:00 функция должна возвращать фразу "Добрый день", с 18:00 до 00:00 — "Добрый вечер", с 00:00 до 6:00 — "Доброй ночи". */
DROP FUNCTION IF EXISTS hello_test;
DELIMITER //
CREATE FUNCTION hello_test(timeCheck TIME)
	RETURNS VARCHAR(15) NO SQL
BEGIN
	DECLARE str VARCHAR(15);

    IF (timeCheck>='06:00:00' AND timeCheck<'12:00:00') THEN
		SET str = 'Доброе утро';
	ELSEIF (timeCheck>='12:00:00' AND timeCheck<'18:00:00') THEN
		SET str = 'Добрый день';
    ELSEIF (timeCheck>='18:00:00' AND timeCheck<='23:59:59') THEN
		SET str = 'Добрый вечер'; 
	ELSE
		 SET str = 'Доброй ночи';
	END IF;
		
    RETURN str;    
END//
DELIMITER ;
SELECT hello_test('19:00:00');

DROP FUNCTION IF EXISTS hello;
DELIMITER //
CREATE FUNCTION hello()
	RETURNS VARCHAR(15) NO SQL
BEGIN
	DECLARE str VARCHAR(15);
	DECLARE timeCheck TIME;
    SET timeCheck = now();
    IF (timeCheck>='06:00:00' AND timeCheck<'12:00:00') THEN
		SET str = 'Доброе утро';
	ELSEIF (timeCheck>='12:00:00' AND timeCheck<'18:00:00') THEN
		SET str = 'Добрый день';
    ELSEIF (timeCheck>='18:00:00' AND timeCheck<='23:59:59') THEN
		SET str = 'Добрый вечер'; 
	ELSE
		 SET str = 'Доброй ночи';
	END IF;
		
    RETURN str;    
END//
DELIMITER ;
SELECT hello();

# HW_06_03
/*
3. (по желанию)* Создайте таблицу logs типа Archive. Пусть при каждом создании
записи в таблицах users, communities и messages в таблицу logs помещается время и
дата создания записи, название таблицы, идентификатор первичного ключа.
*/

/* USERS */
DROP TABLE IF EXISTS logs;
CREATE TABLE logs
(
	created_at datetime DEFAULT NOW(), 
	table_name varchar(45) NOT NULL, 
	str_id INT UNSIGNED NOT NULL
) engine=ARCHIVE;

DROP TRIGGER IF EXISTS log_users;
delimiter //
CREATE TRIGGER log_users AFTER INSERT ON users
FOR EACH ROW
BEGIN
	INSERT INTO logs (created_at, table_name, str_id)
	VALUES (NOW(), 'users', NEW.id);
END //
delimiter ;

/*COMMUNITIES*/
DROP TRIGGER IF EXISTS log_communities;
delimiter //
CREATE TRIGGER log_communities AFTER INSERT ON communities
FOR EACH ROW
BEGIN
	INSERT INTO logs (created_at, table_name, str_id)
	VALUES (NOW(), 'communities', NEW.id);
END //
delimiter ;

/*MESSAGES*/
DROP TRIGGER IF EXISTS log_messages;
delimiter //
CREATE TRIGGER log_messages AFTER INSERT ON messages
FOR EACH ROW
BEGIN
	INSERT INTO logs (created_at, table_name, str_id)
	VALUES (NOW(), 'messages', NEW.id);
END //
delimiter ;

/* Test for USERS*/
SELECT * FROM users;
SELECT * FROM logs;
INSERT INTO users (id, firstname, lastname, email) VALUES 
(13, 'Smax', 'Spain', 'SmaxSpain@example.com');
SELECT * FROM users;
SELECT * FROM logs;
	