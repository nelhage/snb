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


sub cheer
{
    my ($self, $who, $chat, @args) = @_;
    return if $chat;
    return ("Beaver: \n<i>I'm a beaver!</i>", <<CHEER);
All:<i>
    You're a Beaver!
We are Beavers all,
And when we get together, we do the beaver call!
e to the u, du dx, e to the x, dx;
cosine, secant, tangent, sine, 3.14159;
integral, radical, mu, dv;
slipstick, sliderule, MIT!

Go Tech!</i>
CHEER
}

sub photos {
    my ($self, $who, $chat, @args) = @_;
    return "Check out our photo gallery at http://mit09.com";
}

sub countdown {
    my $aug28 = mktime(0, 0, 0, 27, 7, 105);
    my $time = $aug28 - time;
    my $dhms = dhms($time);

    return "$dhms until August 28!";    
}

sub uptime {
    my $self = shift;
    my $ut = time - $self->{CONNECT};
    my $dhms = dhms($ut);
    return "Bot has been online for $dhms";
}


registerCommand("cheer"     =>  \&cheer);
#registerCommand("photos"    =>  \&photos);
registerCommand("countdown" =>  \&countdown);
registerCommand("uptime"    => \&uptime);

1;
