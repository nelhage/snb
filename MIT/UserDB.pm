package MIT::UserDB;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = (GEN_MALE, GEN_FEMALE, GEN_UNKNOWN);

use strict;
use warnings;
no warnings 'redefine';

use constant GEN_UNKNOWN => 0;
use constant GEN_MALE => 1;
use constant GEN_FEMALE => 2;

use DBI;

use TOC::AIMUtils;
use MIT;

my $driver = "Pg";
my $host;
my $user;
my $pass;
my $database;

sub new {
	my $obj = shift;
	my $proto = ref($obj) || $obj;
	my $self = {};

	$host = $MIT::config->val("Database","Host") || "localhost";
	$user = $MIT::config->val("Database","User") || $ENV{user};
	$pass = $MIT::config->val("Database","Password") || "";
	$database = $MIT::config->val("Database","Database") || $user;
	
	$self->{DBH} = DBI->connect("DBI:$driver:dbname=$database;host=$host",
                                $user,$pass, 
		{RaiseError => 0, AutoCommit => 1})
		or die("Unable to connect to database " .
                 "$database on $host: $DBI::errstr");
		
	$self->{FIND_QUERY} = $self->{DBH}->prepare(
        "SELECT screen_name FROM mit.users WHERE real_name ILIKE ?");

    $self->{GET_QUERY} = $self->{DBH}->prepare(
        "SELECT formatted_sn, real_name, location, interests, " .
          "gender, auto_invite, greeted " .
            "FROM mit.users WHERE screen_name = ?");

    $self->{UPDATE_QUERY} = $self->{DBH}->prepare(
        "UPDATE mit.users SET formatted_sn = ? WHERE screen_name = ?");
    
	$self->{INSERT_QUERY} = $self->{DBH}->prepare(
        "INSERT INTO mit.users (formatted_sn, screen_name) VALUES (?,?)");

	$self->{INSERT_PERM_QUERY} = $self->{DBH}->prepare(
        "INSERT INTO mit.permissions (allow,user_id, perm_id) ".
          "(SELECT ?, user_id, perm_id FROM mit.users, mit.permlist ".
            "WHERE screen_name=? AND perm_name=?)");

	$self->{UPDATE_PERM_QUERY} = $self->{DBH}->prepare(
        "UPDATE mit.permissions SET ALLOW=? WHERE ".
          "user_id=(SELECT user_id FROM mit.users WHERE screen_name=?) AND ".
            "perm_id=(SELECT perm_id FROM mit.permlist WHERE perm_name=?)");

	$self->{CHECK_PERM_QUERY} = $self->{DBH}->prepare(
        "SELECT allow OR (allow IS NULL AND allow_default) " .
          "FROM mit.permlist LEFT OUTER JOIN mit.permissions ON " .
            "( mit.permissions.perm_id=mit.permlist.perm_id AND ".
              "mit.permissions.user_id=" .
                "(SELECT user_id FROM mit.users WHERE screen_name=?)) WHERE ".
                  "perm_name=?");

	$self->{NEW_PERM_QUERY} = $self->{DBH}->prepare(
        "INSERT INTO mit.permlist (perm_name, allow_default) VALUES (?, ?)");

	$self->{INVITEES_QUERY} = $self->{DBH}->prepare(
        "SELECT screen_name FROM mit.users WHERE auto_invite IS NOT NULL");
		
	$self->{NEW_CHAT_QUERY} = $self->{DBH}->prepare(
        "INSERT INTO mit.chats (name) VALUES (?)");
    
	$self->{TOPIC_QUERY} = $self->{DBH}->prepare(
        "SELECT topic, screen_name, EXTRACT(EPOCH FROM topic_time) ".
          "FROM mit.users, mit.chats " .
            "WHERE topic_user=user_id ".
              "AND lower(name)=lower(?)");
    
	$self->{TOPIC_SET_QUERY} = $self->{DBH}->prepare(
        "UPDATE mit.chats SET topic=?, topic_user=".
          "(SELECT user_id FROM mit.users WHERE screen_name=?), " .
            "topic_time=NOW() WHERE lower(name)=lower(?)");
	
	for my $field ("real_name","location","interests",
                   "gender", "greeted", "formatted_sn", "dorm") {
		$self->{GET_QUERIES}{uc $field} = $self->{DBH}->prepare(
            "SELECT $field FROM mit.users WHERE screen_name = ?");
        
		$self->{SET_QUERIES}{uc $field} = $self->{DBH}->prepare(
            "UPDATE mit.users SET $field = ? WHERE screen_name = ?");
	}

	for my $field ("auto_invite", "preferred_chat") {
		$self->{GET_QUERIES}->{uc $field} = $self->{DBH}->prepare(
            "SELECT name FROM mit.chats, mit.users ".
              "WHERE screen_name=? AND chat_id=$field");
        
		$self->{SET_QUERIES}->{uc $field} = $self->{DBH}->prepare(
            "UPDATE mit.users SET $field = ".
              "(SELECT chat_id FROM mit.chats WHERE lower(name)=lower(?)) ".
                "WHERE screen_name=?");
	}

	$self->{GET_QUERIES}->{INVITE} = $self->{DBH}->prepare(
        "SELECT invite FROM mit.chats WHERE name=lower(?)");

	return bless($self, $proto);
}

sub bootstrap {
	my $self = shift;
}

sub getField {
	my ($self, $sn, $field) = @_;
	$sn = TOC::AIMUtils::normalize($sn);
	
	my $sth = $self->{GET_QUERIES}{uc $field} or return undef;
	
	$sth->execute($sn);
	my $val = $sth->fetchrow_arrayref;
	$sth->finish;
	
	return $val->[0];
}

sub displayName {
	my $self = shift;
	my $sn = shift;
	return $self->getField($sn, "REAL_NAME") ||
      $self->getField($sn, "FORMATTED_SN") || $sn;
}

sub location {
	return getField(shift, shift, "location");
}

sub gender {
	return getField(shift, shift, "gender");
}

sub autoInvite {
	return getField(shift, shift, "auto_invite");
}

sub preferredChat {
	return getField(shift, shift, "preferred_chat");
}

sub interests {
	return getField(shift, shift, "interests");
}

sub greeted {
	return getField(shift, shift, "greeted");
}

sub dorm {
    return getField(shift, shift, "dorm");
}

sub description {
	my $self = shift;
	my $sn = shift;
	my $desc = $self->displayName($sn);
	my $loc = $self->location($sn);
	
	$desc .= " from $loc" if $loc;
	return $desc;	
}

sub findName {
	my $self = shift;
	my $name = shift;
	
	$self->{FIND_QUERY}->execute("%$name%");
	
	my $found;
	my $row;
	
	while($row = $self->{FIND_QUERY}->fetchrow_arrayref) {
		push @$found, $row->[0];
	}
	
	$self->{FIND_QUERY}->finish;
	
	return $found;
}

sub getUser {
	my $self = shift;
	my $sn = TOC::AIMUtils::normalize(shift);
	
	$self->{GET_QUERY}->execute($sn);
	
	my $user = $self->{GET_QUERY}->fetchrow_hashref;

	$self->{GET_QUERY}->finish;
	return $user;
}

sub setField {
	my ($self, $sn, $field, $val) = @_;
	$sn = TOC::AIMUtils::normalize($sn);

	return $self->{SET_QUERIES}{uc $field}->execute($val, $sn);
}

sub update {
	my $self = shift;
	my $sn = shift;
	my $chat = shift;
	
	if($self->{UPDATE_QUERY}->execute($sn,
                                      TOC::AIMUtils::normalize($sn)) > 0) {
	} else {
		$self->{INSERT_QUERY}->execute($sn, TOC::AIMUtils::normalize($sn));
		$self->setField($sn, PREFERRED_CHAT => $chat);
	}
}

sub checkPerm {
	my ($self, $user, $perm) = @_;
	
	$self->{CHECK_PERM_QUERY}->execute(
        TOC::AIMUtils::normalize($user), $perm);

	my $allowed = $self->{CHECK_PERM_QUERY}->fetchrow_arrayref;

	$self->{CHECK_PERM_QUERY}->finish;

	return ($allowed && $allowed->[0]);
}

sub newPerm {
	my ($self, $perm, $default) = @_;

	$self->{NEW_PERM_QUERY}->execute($perm, $default?"TRUE":"FALSE");
}

sub alterPerm {
	my ($self, $user, $perm, $allow) = @_;
	$user = TOC::AIMUtils::normalize($user);
	$allow = defined $allow ? ($allow?"TRUE":"FALSE") : "NULL";

	($self->{UPDATE_PERM_QUERY}->execute($allow, $user, $perm) > 0) ||
		$self->{INSERT_PERM_QUERY}->execute($allow, $user, $perm);
}

sub autoInvitees {
	my $self = shift;
	my @users;
	my $user;

	$self->{INVITEES_QUERY}->execute();

	while($user = $self->{INVITEES_QUERY}->fetchrow_arrayref) {
		push @users, $user->[0];
	}

	return @users;
}

sub joinChat {
	my ($self, $chat) = @_;
	$self->{NEW_CHAT_QUERY}->execute(lc $chat);
}

sub topic {
	my ($self, $chat) = @_;
	$self->{TOPIC_QUERY}->execute($chat);

	return $self->{TOPIC_QUERY}->fetchrow_array;
}

sub setTopic {
	my ($self, $chat, $topic, $who) = @_;
	$who = TOC::AIMUtils::normalize($who);
	
	$self->{TOPIC_SET_QUERY}->execute($topic, $who, $chat);
}

sub ping {
	my $self = shift;
	return $self->{DBH}->ping;
}

1;

