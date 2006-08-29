package SNB::User;
use base 'SNB::DBI';

use strict;
use warnings;

SNB::User->table('mit.users');
SNB::User->columns(All => qw/user_id screen_name formatted_sn real_name
							 location interests gender greeted
							 auto_invite preferred_chat dorm/);
SNB::User->sequence('mit.users_user_id_seq');
SNB::User->has_a(preferred_chat => 'SNB::Chat');

1;
