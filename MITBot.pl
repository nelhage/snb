#!/usr/bin/perl
use warnings;
use strict;

use POSIX qw(setsid);

use POE;
use POE::Session;

use TOC::Client;

use Config::IniFiles;

use MITBot;
use MIT;

my $username;
my $password;
my $chat;

my $configFile;

my $daemon          = 1;

my $reconnectDelay      = 15;
use constant MAX_DELAY  => 960;
use constant TIMEOUT        => 180;

if(scalar @ARGV > 0 && ($ARGV[0] eq "--nodaemon" || $ARGV[0] eq "-n")) {
    $daemon = 0;
    shift;
}

#read user/password data
#Use a config file name passed on the command line, or else a default one.
$configFile = shift || "data/config.ini";

$MIT::config = Config::IniFiles->new(-file => $configFile) or 
    die("Unable to read config file $configFile.");

#Read info from the config file
$username = $MIT::config->val("AIM","User") or die("Couldn't read username.");
$password = $MIT::config->val("AIM","Password");
$chat = $MIT::config->val("AIM","Chat") or die("Couldn't read chat.");

#If there was no password found, prompt for it
unless($password)
{
    print "Enter password:";
    system("stty -echo");           #Disable input echoing
    chomp($password = <>);
    system("stty echo");            #Reenable echoing
    print "\n";
}

my $outlog = $MIT::config->val("Bot", "stdout") || "out.log";
my $errlog = $MIT::config->val("Bot", "stderr") || "err.log";


MITBot::load();

if($daemon) {
#detach from the console and daemonize
    open STDIN, '/dev/null'     or die "Can't read /dev/null: $!";
    open STDOUT, '>', $outlog       or die "Can't write to $outlog: $!";
    open STDERR, '>', $errlog       or die "Can't write to $errlog: $!";
    defined(my $pid = fork)     or die "Can't fork: $!";
    exit if $pid;
    setsid              or die "Can't start a new session: $!";
}

autoflush STDOUT;
autoflush STDERR;

open(PID,">","MITBot.pid");
print PID $$;
close(PID);

POE::Session->create(
    package_states => [
        main => [qw(_start send_config connected rejoin reload
                    disconnected connect toc_IM_IN2 toc_CHAT_JOIN 
                    toc_CHAT_LEFT toc_CHAT_IN toc_CHAT_UPDATE_BUDDY
                    toc_UPDATE_BUDDY2 toc_ERROR keep_alive  )]
    ]);

$poe_kernel->run();

sub _start {
    my ($kernel,$heap) = @_[KERNEL,HEAP];
    TOC::Client->new("toc",$_[SESSION], 1);
    $kernel->sig(HUP => "reload");
    $kernel->yield("connect");
}

sub send_config {
    my ($kernel, $heap, $cfg) = @_[KERNEL, HEAP, ARG0];
    $MIT::bot = MITBot->new($username, $password, $chat);
    $MIT::bot->connected();
    $MIT::bot->sendConfig($cfg);
    $kernel->post(toc => "config_done");
}

sub connected {
    my ($kernel,$heap) = @_[KERNEL, HEAP];
    $kernel->yield(rejoin => $chat);
    $reconnectDelay = 15;
}

sub disconnected {
    my ($kernel,$heap,$error) = @_[KERNEL, HEAP, ARG0];
    undef $MIT::bot if $MIT::bot;
    MITBot::writeLog("Disconnected, reconnecting in $reconnectDelay");
    $kernel->delay("connect",$reconnectDelay);
    $reconnectDelay *= 2 unless $reconnectDelay >= MAX_DELAY;
}

sub connect {
    my ($kernel,$heap) = @_[KERNEL, HEAP];
    $kernel->post(toc => connect => $username => $password);
    $MIT::userDB = MIT::UserDB->new();
}

sub rejoin {
    my ($kernel,$targ) = @_[KERNEL, ARG0];
    $kernel->post(toc => chat_join => $targ);
}

sub reload {
    my ($kernel, $heap) = @_[KERNEL, HEAP];
    MITBot::writeLog("Received SIGHUP, reloading data and commands...");
    MITBot::load();
    $kernel->sig_handled();
}


#Callbacks called by TOC::Client
sub toc_CHAT_JOIN {
    my ($kernel,$heap,$chatid,$chatname) = @_[KERNEL, HEAP, ARG0, ARG1];
    $kernel->yield("keep_alive");
    MITBot::writeLog("Joined chat.");
    $MIT::bot->joinedChat($chatname, $chatid)
        if $MIT::bot && $MIT::bot->can("update");
}

sub toc_IM_IN2 {
    my ($kernel,$heap, $who,$msg) = @_[KERNEL, HEAP, ARG0, ARG3];
    $kernel->yield("keep_alive");
    $MIT::bot->messageIn($who,$msg,undef)
        if $MIT::bot && $MIT::bot->can("messageIn");
}

sub toc_CHAT_LEFT {
    my ($kernel, $heap, $chatid) = @_[KERNEL, HEAP, ARG0];
    $kernel->yield("keep_alive");
    MITBot::writeLog("Left chat $chatid");
#   $kernel->yield("rejoin" => $MIT::bot->{CHATS}->{$chatid}->{NAME});
    $MIT::bot->leftChat($chatid)
        if $MIT::bot && $MIT::bot->can("leftChat");
}

sub toc_CHAT_IN {
    my ($kernel, $heap, $chatid, $who, $msg) = 
        @_[KERNEL, HEAP, ARG0, ARG1, ARG3];
    $kernel->yield("keep_alive");
    $MIT::bot->messageIn($who, $msg, $chatid)
        if $MIT::bot && $MIT::bot->can("messageIn");
}

sub toc_CHAT_UPDATE_BUDDY {
    my ($kernel, $heap, $chatid, $join, @users) = 
        @_[KERNEL,HEAP,ARG0, ARG1 .. $#_];
    $kernel->yield("keep_alive");
    return unless  $MIT::bot && $MIT::bot->can("screenNameJoined") &&
        $MIT::bot->can("screenNameParted");
    
    foreach my $user (@users) {
        if($join eq "T")
        {
            $MIT::bot->screenNameJoined($user, $chatid);
        } else {
            $MIT::bot->screenNameParted($user, $chatid);
        }
    }
}

sub toc_UPDATE_BUDDY2 {
    my ($kernel, $heap, $buddy, @args) = @_[KERNEL, HEAP, ARG0 .. $#_];
    $kernel->yield("keep_alive");
    $MIT::bot->update($buddy, @args)
        if $MIT::bot && $MIT::bot->can("update");
}

sub toc_ERROR {
    my ($kernel,@args) = @_[KERNEL,ARG0 .. $#_];
    $kernel->yield("keep_alive");
    MITBot::writeLog("ERROR: ", join(":",@args));
    if($args[0] == 950 || $args[0] == 951) {
        $kernel->delay("rejoin",30,$args[1]);
    } elsif($args[0] == 980) {
        MITBot::writeLog("Bad password");
        die("Bad password");
    }
    
}

sub keep_alive {
    my ($kernel) = $_[KERNEL];
    $kernel->delay("disconnected", TIMEOUT);
}
