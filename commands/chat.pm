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

sub genderList {
    my ($self, $who, $chat, @args) = @_;
    my @members;
    return "Must be used in a chat." unless $chat;
    
    @members = keys %{$self->{CHATS}->{$chat}->{MEMBERS}};
    
    my $male = scalar grep{$MIT::userDB->gender($_) == GEN_MALE} @members;
    my $female = scalar grep{$MIT::userDB->gender($_) == GEN_FEMALE} @members;
    my $unk = (scalar grep{$MIT::userDB->gender($_) == GEN_UNKNOWN} @members)
      - 1;
    
    return "Gender distribution: $male Males - $female Females - $unk Unknown";
}

sub topic {
    my ($self, $who, $chat, $args) = @_;

    my $chatname;
    
    my @args = split /\s+/,$args,2;

    unless($chat) {
        return "Usage: !topic <chatname> [new topic]" unless @args;
        $chatname = shift @args;
    } else {
        $chatname = $self->{CHATS}->{$chat}->{NAME};
    }

    if (@args) {
        return "Error: Permission denied"
          unless $MIT::userDB->checkPerm($who, "topic set");
        $MIT::userDB->setTopic($chatname, join(" ", @args), $who);
        return;
    } else {
        my ($topic, $sn, $time) = $MIT::userDB->topic($chatname);
        
        return "No topic set" unless $topic;
        return "Topic: " . $topic .
          " (Set by " . $MIT::userDB->displayName($sn) . " | " .
            strftime('%a %b %Y %H:%M:%S %Z',localtime($time)) . ")";
    }
}

registerCommand("genders"   =>  \&genderList);
registerCommand("topic"     =>  \&topic, 1);

1;
