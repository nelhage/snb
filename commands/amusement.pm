package MITBot;

use strict;
use warnings;
use POE;
use POSIX qw(mktime strftime);

use MIT;
use MIT::Session;
use MIT::UserDB;
use TOC::AIMUtils;

my @oracularReplies;

sub fortune
{
    my ($self, $who, $chat, @args) = @_;
    my $command = "fortune -s";
    return join("",`$command`);
}

sub oracle
{
    my ($self, $who, $chat, @args) = @_;
    return unless @args;
    return $oracularReplies[int(rand($#oracularReplies+1))];
}

sub spin {
    my ($self, $who, $chat, @args) = @_;
    unless($chat) {
        return "Lonely much? This only works in the chat!";
    }
    
    my $kissee;
    my $me = TOC::AIMUtils::normalize($self->{NICK});
    my $gender = $MIT::userDB->gender($who);
    my $g;
    my @others;
    if ($gender == GEN_UNKNOWN) {
        return "Sorry, but I have to know your gender for you to play.";
    }

    $g = ($gender == GEN_MALE ? GEN_FEMALE : GEN_MALE);
    @others = grep {$MIT::userDB->gender($_) == $g} 
      keys %{$self->{CHATS}->{$chat}->{MEMBERS}};
    
    unless(scalar @others >=1) {
        return "Sorry, there's no one eligible around.";
    }

    unless(scalar @others >=2) {
        return "Shame on you, " . $MIT::userDB->displayName($who) .
          ", trying to take advantage of " .
            $MIT::userDB->displayName($others[0]) . " like that!";
    }
    
    
    $kissee = $others[int rand($#others+1)];
    return ($MIT::userDB->displayName($who) . " spins the bottle ...",
            "and it lands on " . $MIT::userDB->displayName($kissee));
}

sub hug {
    my ($self, $who, $chat, $rest) = @_;

    if ($rest =~ /(sexy\s*nerd(\s*bot)?)/i) {
        return "ACTION hugs " . $MIT::userDB->displayName($who);
    } elsif ($rest =~ /katie|kates|stanchak/i) {
        if($who eq "kates1422") {
            return "Hawt.";
        } else {
            return "Aww, I'm jealous.";
        }
    }
    return undef;
}


open(ORACLE,"<","data/oracle");
@oracularReplies = <ORACLE>;
close(ORACLE);

registerCommand(fortune => \&fortune);
registerCommand("8ball" => \&oracle);
registerCommand("spinthebottle" => \&spin);
registerCommand("dance" => sub {"ACTION Does a little jig"});
registerAction("hugs" => \&hug);

1;
