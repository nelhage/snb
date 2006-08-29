CREATE SCHEMA mit;

CREATE TABLE mit.users (
	user_id serial PRIMARY KEY,
	screen_name varchar(16) UNIQUE,
	formatted_sn varchar UNIQUE,
	real_name varchar,
	location varchar,
	interests varchar,
	gender int DEFAULT 0,
	auto_invite integer, --REFERENCES mit.chats(chat_id) ON DELETE SET NULL,
	preferred_chat integer, --REFERENCES mit.chats(chat_id) ON DELETE SET NULL,
	greeted boolean DEFAULT FALSE,
    dorm varchar(100)
);

CREATE TABLE mit.chats (
	chat_id serial PRIMARY KEY,
	name varchar UNIQUE,
	topic varchar DEFAULT NULL,
	topic_user integer DEFAULT NULL REFERENCES mit.users(user_id)
                       ON DELETE SET NULL,
    topic_time timestamp,
	invite varchar
);

CREATE TABLE mit.permlist (
	perm_id serial PRIMARY KEY,
	perm_name varchar UNIQUE,
	allow_default boolean DEFAULT FALSE
);

CREATE TABLE mit.permissions (
	perm_id integer REFERENCES mit.permlist ON DELETE CASCADE,
	user_id integer REFERENCES mit.users ON DELETE CASCADE,
	allow boolean DEFAULT FALSE,
	UNIQUE(perm_id, user_id)
);

INSERT INTO mit.permlist(perm_id, perm_name, allow_default) VALUES(1, 'perm list',       'f');
INSERT INTO mit.permlist(perm_id, perm_name, allow_default) VALUES(2, 'perm grant',      'f');
INSERT INTO mit.permlist(perm_id, perm_name, allow_default) VALUES(3, 'perm revoke',     'f');
INSERT INTO mit.permlist(perm_id, perm_name, allow_default) VALUES(4, 'perm new',        'f');
INSERT INTO mit.permlist(perm_id, perm_name, allow_default) VALUES(5, 'channel join',    't');
INSERT INTO mit.permlist(perm_id, perm_name, allow_default) VALUES(6, 'channel part',    'f');
INSERT INTO mit.permlist(perm_id, perm_name, allow_default) VALUES(7, 'topic set',       't');
INSERT INTO mit.permlist(perm_id, perm_name, allow_default) VALUES(8, 'channel list',    'f');

