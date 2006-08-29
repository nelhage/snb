package MIT::Session;
use strict;
use warnings;

use MIT::UserDB;
use TOC::Session;
use base qw(TOC::Session);
use Text::ParseWords;

use POE;

no warnings 'redefine';

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);
    bless($self, $class);
    $self->reset();
    
    return $self;
}

sub reset {
    my $self = shift;
    $self->popState() while $self->state();
    $self->newState(\&handleInput,1);
}

sub displayName {
    my $self = shift;
    return $MIT::userDB->displayName($self->{NICK});
}

sub description {
    my $self = shift;
    return $MIT::userDB->description($self->{NICK});
}

sub autoInvite {
    my $self = shift;
    return $MIT::userDB->autoInvite($self->{NICK});
}

sub gender {
    my $self = shift;
    return $MIT::userDB->gender($self->{NICK}) || 0;
}

sub location {
    my $self = shift;
    return $MIT::userDB->location($self->{NICK});
}

sub interests {
    my $self = shift;
    return $MIT::userDB->interests($self->{NICK});
}

sub dorm {
    my $self = shift;
    return $MIT::userDB->dorm($self->{NICK});
}

sub checkPerm {
    my $self = shift;
    my $perm = shift;
    return $MIT::userDB->checkPerm($self->{NICK}, $perm);
}

sub greet {
    my $self = shift;
    return if $MIT::userDB->greeted($self->{NICK});
    $self->send("Hello, " . $self->displayName .
                  ". I'm a bot set up to help maintain the " .
                    "chatroom for future members of MIT class of 2009. \n" .
                      "I haven't seen you around before. " .
                        "Type 'help' to learn how to let me know ".
                          "who you are, or ignore me and I won't bother " .
                            "you again.");
    $MIT::userDB->setField($self->{NICK}, GREETED => 1);
}

sub match
{
    my ($cmd,$in) = @_;
    #   return $cmd =~ /^\Q$in\E/;
    return lc $cmd eq lc $in;
}

sub oldval
{
    my ($self, $parm) = @_;
    my $val = $MIT::userDB->getField($self->{NICK}, $parm);
    return " (Was '$val')" if $val;
    return "";
}

#States

sub handleInput {
    my ($self, $args) = @_;
    
    my ($cmd,$arg) = split(/\s+/,$args->{INPUT},2);
    $cmd = lc $cmd;
    
    if (match("info",$cmd)) {
        my $msg = <<EOM;
I will now ask you a series of questions. For each one, you can answer,
or else type '-' or 'none' to leave it blank, and 'default' or '+' to keep
the previous value.
EOM

        $self->send($msg);
        
        $self->newState(\&getInfo);
        $self->query("REAL_NAME","What is your name?" .
                       $self->oldval("REAL_NAME"));
        $self->query("LOCATION","Where are you from?" .
                       $self->oldval("LOCATION"));
        $self->query("INTERESTS","Briefly, what are your interests?" .
                       $self->oldval("INTERESTS"));
        
        $self->newState(\&setGender);
        $self->query("GENDER","Male/female? Guy/girl?");
        $self->run();
    } elsif (match("name",$cmd)) {
        $self->newState(\&setVar);
        $self->query("VAR","","REAL_NAME");
        $self->query("REAL_NAME","What is your name?" .
                       $self->oldval("REAL_NAME"),$arg);
        $self->run();
    } elsif (match("location",$cmd)) {
        $self->newState(\&setVar);
        $self->query("VAR","","LOCATION");
        $self->query("LOCATION","Where are you from?" .
                       $self->oldval("LOCATION"), $arg);
        $self->run();
    } elsif (match("interests",$cmd)) {
        $self->newState(\&setVar);
        $self->query("VAR","","INTERESTS");
        $self->query("INTERESTS","Briefly, what are your interests?" .
                       $self->oldval("INTERESTS"), $arg);
        $self->run();
    } elsif (match("dorm", $cmd)) {
        $self->newState(\&setVar);
        $self->query("VAR","","DORM");
        $self->query("DORM", "What dorm (optionally, room) " .
                       "are you in at MIT?" . $self->oldval("DORM"), $arg);
        $self->run();
    } elsif (match("autoinvite",$cmd)) {
        $self->newState(\&setAutoInvite);
        $self->query("INVITE","Which chat should I invite you to " .
                       "when you sign on (none for none)?", $arg);
        $self->run();
    } elsif (match("chat",$cmd)) {
        $self->newState(\&setChat);
        $self->query("CHAT","Which chat should I set as your default chat?",
                     $arg);
        $self->run();
    } elsif (match("gender",$cmd)) {
        $self->newState(\&setGender);
        $self->query("GENDER","Male/female? Guy/girl?", $arg);
        $self->run();
    } elsif (match("perm", $cmd)) {
        $self->doPerm($arg);
    } else {
        $self->send("Command not recognized (Try 'help').");
    }
}

sub getInfo {
    my ($self, $args) = @_;
    my $val;
    foreach my $key ("REAL_NAME", "LOCATION", "INTERESTS") {
        $val = $args->{$key};
        next if $val =~ /^(\s+)|default|\+$/;
        $val = undef if $val =~ /^none|-$/;
        $MIT::userDB->setField($self->{NICK}, $key, $val);
    }
    $self->send("Thank you, " . $self->displayName . ".");
}

sub setGender {
    my ($self, $args) = @_;
    my $str = $args->{GENDER};
    my $gender;
    if ($str =~ /(\bmale)|guy|dude|(^M$)/i) {
        $gender = GEN_MALE;
        $self->send("OK, so you're a dude.");
    } elsif ($str =~ /female|gal|girl|chick|lady|(^F$)/i) {
        $gender = GEN_FEMALE;
        $self->send("Alright, a girl! We'll try not to scare you off.");
    } else {
        $gender = GEN_UNKNOWN;
        $self->send("Sorry, I couldn't understand what you said, " .
                      "leaving it blank for now.");
    }
    $MIT::userDB->setField($self->{NICK}, GENDER => $gender);
}

sub setVar {
    my ($self, $args) = @_;
    $MIT::userDB->setField($self->{NICK}, $args->{VAR} =>
                             $args->{$args->{VAR}});
    $self->send("Your information has been updated.");
}

sub setAutoInvite {
    my ($self, $args) = @_;
    my $auto = $args->{INVITE};
    undef $auto if $auto =~ /none/i;
    unless ($MIT::userDB->setField($self->{NICK}, AUTO_INVITE => $auto)) {
        $self->send("Error setting autoinvite preference; " .
                      "Are you sure I know about that chat?");
    }
    if (defined($auto)) {
        $self->send("I will invite you to $auto " .
                      "whenever you sign on, if I'm in it.");
        $poe_kernel->post(toc => new_buddies => $self->{NICK});
    } else {
        $self->send("I won't invite you to a chat when you sign on.");
        $poe_kernel->post(toc => new_buddies => $self->{NICK}
                            => "buddies");
    }
}

sub setChat {
    my ($self, $args) = @_;
    my $chat = $args->{CHAT};
    unless ($MIT::userDB->setField($self->{NICK},
                                   PREFERRED_CHAT => $chat)) {
        $self->send("Error setting $chat -- " .
                      "are you sure I know about it?");
    } else {
        $self->send("Set your preferred chat to $chat.");
    }
}

sub doPerm {
    my ($self, $arg) = @_;
    my ($cmd, @args) = parse_line(qr/\s+/, 0, $arg);
    $cmd = lc $cmd;

    $self->checkPerm("perm $cmd") or
      return $self->send("Error: Permission denied (perm $cmd).");

    if ($cmd eq "new") {
        scalar @args == 2 or return
          $self->send("Wrong number of arguments; need 2, got " .
                        (scalar @args));
        $MIT::userDB->newPerm(@args);
    } elsif ($cmd eq "grant") {
        scalar @args == 2 or return
          $self->send("Wrong number of arguments; need 2, got " .
                        (scalar @args));
        $MIT::userDB->alterPerm(@args, 1);
    } elsif ($cmd eq "revoke") {
        scalar @args == 2 or return
          $self->send("Wrong number of arguments; need 2, got " .
                        (scalar @args));
        $MIT::userDB->alterPerm(@args, 0);
    }
}

1;
