package TOC::Buddy;

use warnings;
use strict;

use TOC::AIMUtils;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $targ = shift;
    my $sn = shift;
    my $formname = shift || $sn;
    my $self = {
        TARG                =>  $targ,
        HANDLE              =>  $sn,
        FORMATTED_HANDLE    =>  $sn,
        ONLINE              =>  0,
        WARNING             =>  0,
        SIGNON              =>  0,
        IDLE                =>  0,
        ON_AOL              =>  0,
        AWAY                =>  0,
        USER_INFO           =>  {}
    };
    return bless($self,$proto);
}

sub update {
    my ($self, $formatted, $online, $warn, $signon, $idle, $uc) = @_;
    $self->{FORMATTED_HANDLE} = $formatted;
    $online = $online eq "T";
    if($self->{ONLINE} != $online && $self->{TARG} &&
       $self->{TARG}->can("buddyOnline")) {
        $self->{TARG}->buddyOnline($self->{HANDLE},$online);
    }
    $self->{ONLINE} = $online;
    $self->{WARNING} = $warn;
    $self->{SIGNON} = $signon;
    $self->{IDLE} = $idle;
    $self->{ON_AOL} = $uc =~ /^A/;
    my $away = $uc =~ /^..U$/;
    if($self->{AWAY} != $away && $self->{TARG} &&
       $self->{TARG}->can("buddyAway")) {
        $self->{TARG}->buddyAway($self->{HANDLE},$away);
    }
    $self->{AWAY} = $away;
}

sub online {
    my $self = shift;
    return $self->{ONLINE};
}

sub handle {
    my $self = shift;
    return $self->{HANDLE};
}

sub formattedHandle {
    my $self = shift;
    return $self->{FORMATTED_HANDLE};
}

sub warningLevel {
    my $self = shift;
    return $self->{WARNING};
}

sub signonTime {
    my $self = shift;
    return $self->{SIGNON};
}

sub idleTime {
    my $self = shift;
    return $self->{IDLE};
}

sub onAOL {
    my $self = shift;
    return $self->{ON_AOL};
}

sub away {
    my $self = shift;
    return $self->{AWAY};
}

#A hash ref that can be used to store additional info
sub userInfo {
    my $self = shift;
    return $self->{USER_INFO};
}

1;
