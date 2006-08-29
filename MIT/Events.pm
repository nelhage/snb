package MITBot;

use strict;
use warnings;
use POE;
use POSIX qw(mktime strftime);

use MIT;
use MIT::Session;
use MIT::UserDB;
use TOC::AIMUtils;

do "MIT/Common.pm";
die $@ if $@;

my %commands = ();
my %actions = ();
my %handlers = ();

use constant JOIN_WAIT => 5;

#This file gets reloaded when the bot is running to let us
#update commands on the fly, so prevent perl from warning us
#about redefining things
no warnings 'redefine';

sub joinedChat
{
    my $self = shift;
    my $name = shift;
    my $id = shift;
    
    my $chat = {NAME        =>  $name,
                MEMBERS     =>  {},
                JOINTIME    =>  time,
            };
    $self->{CHATID} = $id if lc $name eq lc $self->{CHAT};
    $self->{CHATS}->{$id} = $chat;

    $MIT::userDB->joinChat($name);
}

sub leftChat
{
    my $self = shift;
    my $id = shift;

    unless ($self->{CHATS}->{$id}->{LEAVE}) {
        $poe_kernel->post(toc => chat_join => $self->{CHATS}->{$id}->{NAME});
    }
    delete $self->{CHATID} if $id == $self->{CHATID};
    delete $self->{CHATS}->{$id};
}

sub screenNameJoined
{
    my ($self, $sn, $id) = @_;
    my $session;
    
    $self->{CHATS}->{$id}->{MEMBERS}->{TOC::AIMUtils::normalize($sn)} = 
      $self->{BLIST}->insertBuddy($sn);
    return if TOC::AIMUtils::normalize($sn) eq
      TOC::AIMUtils::normalize($self->{NICK});
    
    $MIT::userDB->update($sn, $self->{CHATS}->{$id}->{NAME});
    
    if (time - $self->{CHATS}->{$id}->{JOINTIME} >= JOIN_WAIT) {
        $self->sendMsg("", $id, "Welcome " .
                         ($MIT::userDB->greeted($sn)?"back":"to the chat") .
                           ", " . $MIT::userDB->description($sn) . "!");
    }

    unless($MIT::userDB->greeted($sn)) {
        $session = $self->openSession($sn);
        $session->greet();
    }
}

sub screenNameParted
{
    my ($self, $sn, $id) = @_;
    delete $self->{CHATS}->{$id}->{MEMBERS}->{TOC::AIMUtils::normalize($sn)};
}

sub update
{
    my ($self, $sn, @args) = @_;
    $self->{BLIST}->update($sn, @args);
}

sub buddyOnline
{
    my ($self, $sn, $online) = @_;
    if ($online) {
#         my $auto = $MIT::userDB->autoInvite($sn);
#         my $autoid = $self->findChat($auto);
#         if (time - $self->{CONNECT} >= JOIN_WAIT &&
#               $auto && $autoid) {
#             $poe_kernel->post(toc => chat_invite => $autoid =>
#                                 $MIT::userDB->getField($auto, "INVITE") => $sn);
#         }
    } else {
        my $sess = $self->session($sn);
        $sess->reset() if $sess;
    }
}

sub messageIn
{
    my ($self, $who, $msg, $chat) = @_;
    my $cmd;

    return if(TOC::AIMUtils::normalize($who) eq
        TOC::AIMUtils::normalize($self->{NICK}));

    #Strip HTML
    $msg =~ s/<[\/\w][^>]*>//g;
    $msg =~ s/&quot;/"/g;   
    $msg =~ s/&apos;/'/g;  
    $msg =~ s/&lt;/</g;
    $msg =~ s/&gt;/>/g;

    #Handle actions
    if ($msg =~ m/^(\*|::)(.*)\1$/ || $msg=~ m!(^/me\s+)(.*)$!i) {
        $self->action($who, $2, $chat);
        return;
    }

    my ($name, $handler, $ret);
    keys %handlers;
    while(($name, $handler) = each %handlers) {
        $ret = 0;
        eval {
            $ret = $self->$handler($who, $chat, $msg)
        };
        writeLog("Error executing handler $name: $@") if $@;
        return if $ret;
    }

    #If this isn't a !-command...
    if (substr($msg,0,1) ne "!") {
        if (!$chat) {
            #Pass it off to the session handler in PM
            eval {
                $self->openSession($who);
                $self->session($who)->messageIn($msg);
            };
            writeLog("Error executing $msg: $@") if $@;
        }
        return;
    }
    
    #Strip the leading '!'
    $msg = substr($msg, 1);
    ($cmd, $msg) = split /\s+/, $msg, 2;
    $cmd = lc $cmd;

    $self->doBangCommand($cmd, $msg, $who, $chat);
}

sub doBangCommand
{
    my ($self, $cmd, $msg, $who, $chat) = @_;
    my (@args, @reply, $method);
    my $rawargs = 0;
    
    unless (defined($method = $commands{$cmd})) {
        writeLog("Bad command: '$cmd'");
        return;
    }
    
    if (ref($method) eq "ARRAY") {
        ($method, $rawargs) = @$method;
    }
    
    unless ($rawargs) {
        @args = parse_line(qr/\s+/, 0, $msg);
    } else {
        @args = ($msg);
    }

    #Catch exceptions raised by command handlers and handle them gracefully
    eval {
        @reply = $self->$method($who, $chat, @args);
        foreach my $out (@reply) {
            $self->sendMsg($who, $chat, $out);
        }
    };
    
    writeLog("Error executing ``$cmd'': $@") if $@;
}

sub action {
    my ($self, $who, $msg, $chat) = @_;

    my ($act, $rest) = split /\s+/, $msg, 2;
    my $method = $actions{$act};
    return unless defined($method);
    eval {
        my @reply = $self->$method($who, $chat, $rest);
        foreach my $out (@reply) {
            $self->sendMsg($who, $chat, $out);
        }
    };

    writeLog("Error executing action ``$act'': $@") if $@;
}

sub registerCommand {
    my ($command, $method, $raw) = @_;
    if(defined($raw)) {
        $commands{$command} = [$method, $raw];
    } else {
        $commands{$command} = $method;
    }
}

sub registerAction {
    my ($action, $method) = @_;
    $actions{$action} = $method;
}

sub registerHandler {
    my ($name, $method) = @_;
    $handlers{$name} = $method;
}

1;
