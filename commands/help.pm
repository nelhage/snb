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

my $helpText;

sub help {
    my ($self, $who, $chat, $msg) = @_;
    if ($msg =~ /^!?help$/) {
        $self->sendMsg($who, 0, $helpText);
        return 1;
    }
    return 0;
}

  
$helpText = "";

open(HELP, "<", "data/help");
while (<HELP>) {
    chomp;
    
    s/&/&amp;/g;
    s/</&lt;/g;
    s/>/&gt;/g;
    
    if (/^\[(.*)\]$/) {
        my $head = $1 . " Commands";
        my $pad = "-" x (30 - length($head));
        $helpText .= "$pad$head$pad<br>";
    } elsif (/^(.+) -- (.*)/) {
        $helpText .= "<b>$1</b>  -  $2<br>";
    } else {
        $helpText .= "$_<br>";
    }
}

close(HELP);

registerHandler("HELP" => \&help);

1;
