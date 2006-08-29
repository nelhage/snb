package SNB::Chat;
use base 'SNB::DBI';

use strict;
use warnings;

SNB::Chat->table('mit.chats');
SNB::Chat->columns(All => qw/chat_id topic topic_user name invite topic_time/);
SNB::Chat->sequence('mit.chats_chat_id_seq');
SNB::Chat->has_a(topic_user => 'SNB::User');

1;
