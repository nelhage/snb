package MITBot;

use strict;
use warnings;
use POE;
use POSIX qw(mktime strftime);

use MIT;
use MIT::Session;
use MIT::UserDB;
use TOC::AIMUtils;

use MIT::Common;

sub rejoinChat {
    my ($self, $who, $chat, @args) = @_;

    $MIT::userDB->checkPerm($who, "channel join")
      or return "Error: permission denied (channel join)";
    
    my $chatname = $args[0] || $self->{CHAT};
    my $chatid = $self->findChat($args[0]);

    $poe_kernel->post(toc => chat_leave => $chatid) if($chatid);
    $poe_kernel->post(toc => chat_join => $chatname);
    return;
}

sub leaveChat {
    my ($self, $who, $chat, @args) = @_;
    
    my $chatid;
    
    if (!$chat || scalar @args > 0) {
        return "Usage: !part &lt;chat&gt;" unless @args;
        $chatid = $self->findChat($args[0])
          or return "No such chat: $args[0]";
    } else {
        $chatid = $chat;
    }

    $MIT::userDB->checkPerm($who, "channel part") or
      return "Error: Permission denied";

    #Sanity check
    return "I'm not in that chat" unless exists $self->{CHATS}->{$chatid};

    #Set a flag so we don't try to rejoin
    $self->{CHATS}->{$chatid}->{LEAVE} = 1;
    
    $poe_kernel->post(toc => chat_leave => $chatid);
    return;
}

sub listChats {
    my ($self, $who, $chat, @args) = @_;
    
    return if $chat;
    
    $MIT::userDB->checkPerm($who, "channel list") or
      return "Permission denied";

    return "I am in chats: " . join(", ", map{$_->{NAME}}
                                      values %{$self->{CHATS}});    
}

registerCommand("join"      =>  \&rejoinChat);
registerCommand("part"      =>  \&leaveChat);
registerCommand("list"      =>  \&listChats);

1;
