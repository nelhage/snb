package MITBot;
use strict;
use warnings;

use TOC::AIMUtils;
use TOC::Buddy;
use TOC::BuddyList;
use MIT::Session;
use MIT::UserDB;
use MIT;

use POE;
use POSIX qw(strftime);

use Text::ParseWords;
use Roman;

use vars qw($AUTOLOAD);


my $logFile;

#select($logFile);
sub writeLog {
    my $line = join("",@_);
    print $logFile strftime("%D %T ",localtime);
    print $logFile "$line\n";
    $logFile->flush;
}

sub new {
    my $proto = shift;
    my ($nick, $pass, $chat) = @_;
    my $class = ref($proto) || $proto;
    my $self = {
        NICK    => $nick,
        PASS    => $pass,
        CHAT    => $chat,
        CHATID  => undef,
        BLIST   => undef,
        CHATS   => {}
    };
    bless($self, $class);
    
    $self->{BLIST} = TOC::BuddyList->new($self);
    $self->{BLIST}->startSignon();
    
    return $self;
}

#Events called by the parent

sub connected
{
    my $self = shift;
    $self->{BLIST}->finishSignon();
    $self->{CONNECT} = time;
}

sub sendConfig
{
    my ($self, $config) = @_;
    my @autoinvite = $MIT::userDB->autoInvitees();
    my $group;
    my %buddies;
    foreach (split /\n/, $config) {
        $group = $1 if /^g:(.*)$/;
        push @{$buddies{$group}}, $1 if /^b:(.*)$/;
    }
    
    foreach $group (keys %buddies) {
        $poe_kernel->post(toc => remove_buddy => @{$buddies{$group}} => $group);
    }

    $poe_kernel->post(toc => new_buddies => @autoinvite);
}

#Dynamically reload the file containing the commands and real
#handlers, as well as various data files and such
sub load
{
    open($logFile, ">>", $MIT::config->val("Bot","Log") || "mit.log")
        unless $logFile;

    unless(do "MIT/Events.pm"){
        writeLog("Error reloading event handlers: $@");
    }

    my $file;
    unless(opendir COMMANDS, "commands") {
		writeLog("WARNING: no commands/ directory found.");
	} else {
		while($file = readdir(COMMANDS)) {
			if($file =~ /\.p[lm]$/) {
				unless(do "commands/$file") {
					writeLog("Error loading commands/$file: $@");
				}
			}
		}
	}

    #Reload the DB interface code
    do $INC{"MIT/UserDB.pm"};
    writeLog("Error loading UserDB.pm: $@") if $@;

    #Reload the session code
    do $INC{"MIT/Session.pm"};
    writeLog("Error loading Session.pm: $@") if $@;

    if (defined($MIT::userDB)) {
        $MIT::userDB->bootstrap();
    }

}

sub AUTOLOAD {
    #Since most things called on us are events, and it's non-fatal if
    #we don't reply, this is a safety net to try to keep going and not
    #crash if that happens (The next time Events.pm is reloaded
    #on a SIGHUP will hopefully fix things)
    warn "Undefined sub $AUTOLOAD";
}

sub DESTROY {
    #To stop AUTOLOAD from complaining about this
}

1;

     
