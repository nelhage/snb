package MITBot;

use strict;
use warnings;
use POE;
use POSIX qw(mktime strftime);

use MIT;
use MIT::Session;
use MIT::UserDB;
use TOC::AIMUtils;

no warnings 'redefine';

#send a message in response to a command
#uses the boolean $chat parameter to determine whether to send it
#in a chat or as a privmsg
sub sendMsg
{
    my ($self, $who, $chat, $msg) = @_;

    chomp($msg);
    $msg =~ s/\n/<br>/g;
    
    if ($msg =~ /^ACTION (.*)$/s) {
        $msg = "*$1*";
    }
    
    if ($chat) {
        $poe_kernel->post(toc => chat_send => $chat => $msg);
    } else {
        $poe_kernel->post(toc => send_im => $who => $msg);
    }
}

sub openSession 
{
    my ($self, $who) = @_;
    $MIT::userDB->update($who);
    unless ($self->{BLIST}->buddy($who)) {
        $self->{BLIST}->insertBuddy($who)
    }
    return $self->{BLIST}->buddy($who)->userInfo->{SESSION}
      if $self->{BLIST}->buddy($who)->userInfo->{SESSION};
    my $session = MIT::Session->new($who);
    $self->{BLIST}->buddy($who)->userInfo->{SESSION} = $session;
    return $session;
}

sub session
{
    my ($self, $who) = @_;
    $who = TOC::AIMUtils::normalize($who);
    my $buddy = $self->{BLIST}->buddy($who);
    if (!$buddy && -f "users/$who") {
        $buddy = $self->{BLIST}->insertBuddy($who); 
    }
    return unless $buddy;
    my $session = $buddy->userInfo->{SESSION};
    return $session;
}

sub findName {
    my ($self, $name) = @_;
    my $found;
    
    $found = $MIT::userDB->findName($name);
    
    return defined($found)?@$found:();
}

sub findChat {
    my ($self, $name) = @_;
    my ($chatid, $chat);
    keys %{$self->{CHATS}};     #Reset the `each' iterator
    while (($chatid, $chat) = each %{$self->{CHATS}}) {
        return $chatid if lc $chat->{NAME} eq lc $name;
    }
    return undef;   
}

#Convert a number of seconds into a string in the format "5d 10h 17m 6s"
sub dhms {
    my $time = shift;
    my ($days, $hours, $min, $sec) =
      (int ($time / (24*60*60)),
       int ($time / (60*60)) % 24,
       int ($time / 60) % 60,
       $time % 60);
    return "${days}d ${hours}h ${min}m ${sec}s";
}

1;
