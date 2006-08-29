package MITBot;

use strict;
use warnings;

use MIT;
use MIT::UserDB;
use TOC::AIMUtils;

sub invite
{
    my ($self, $who, $chat, @args) = @_;
    return unless defined($self->{CHATID});
    
    my ($username, $chatname);
    my $targuser;
    my $targchat;
    
    if (scalar @args == 0) {
        $targuser = $who;
        $targchat = $chat
          || $self->findChat($MIT::userDB->preferredChat($who))
            || $self->{CHATID};
        unless(defined($targchat)){
            return "I'm not in the chat right now.";
        }
    } elsif (scalar @args == 1) {
        if ($chat) {
            $username = $args[0];
            $targchat = $chat;
        } else {
            $targuser = $who;
            $chatname = $args[0];
        }
    } else {
        $username = $args[0];
        $chatname = $args[1];
    }

    if ($chatname) {
        $targchat = $self->findChat($chatname) or
          return "I'm not in chat $chatname.";
    } else {
        $chatname = $self->{CHATS}->{$targchat}->{NAME};
    }
    
    if ($username) {
        my @buddies = $self->findName($username);
        if (scalar @buddies > 1) {
            return "Found multiple results for &lt;$username&gt;: \n" .
              ((scalar @buddies < 5) ? join("\n",@buddies) :
                 "&lt;Too many to list&gt;");
        } elsif (scalar @buddies == 1) {
            $targuser = $buddies[0];
        } else {
            #No users found, assume we've been given a screen name
            $targuser = $username;
        }
    }
    
    $poe_kernel->post(toc => chat_invite => $targchat =>
                        $MIT::userDB->getField($chatname, "INVITE")
                          => $targuser);
    return;
}

registerCommand(invite => \&invite);

1;
