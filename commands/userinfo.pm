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

sub whois {
    my ($self, $who, $chat, $search) = @_;
    my $sn = TOC::AIMUtils::normalize($search);

    my $desc = $MIT::userDB->description($sn);
    if($sn eq TOC::AIMUtils::normalize($desc)) {
        my @found = $self->findName($search);
        if(scalar @found == 0) {
            return "I don't know who &lt;$search&gt; is";
        } elsif(scalar @found == 1) {
            $sn = $found[0];
        } elsif(scalar @found > 1 && scalar @found <= 5) {
            return ("Found multiple results for &lt;$search&gt;:",
                    join(", ", @found));
        } else {
            return "Found too many results to list.";
        }
    }
    
    my $gender = $MIT::userDB->gender($sn) || GEN_UNKNOWN;

    my @out;
    push @out, "$sn is " . $MIT::userDB->description($sn);
    my $pref = ($gender == GEN_MALE) ? "His" :
      (($gender == GEN_FEMALE) ? "Her" : "His/Her");
    my $interests = $MIT::userDB->interests($sn);
    push @out, "$pref interests are $interests" if $interests;
    my $dorm = $MIT::userDB->dorm($sn);
    $pref = (($gender == GEN_MALE) ? "He" :
               ($gender == GEN_FEMALE) ? "She" : "(S)he");
    push @out, "$pref will be living in $dorm" if $dorm;
    return @out;
}

sub whoami {
    my ($self, $who, $chat, @args) = @_;
    
    my @out;
    push @out, "You are " . $MIT::userDB->description($who);
    my $interests = $MIT::userDB->interests($who);
    push @out, "Your interests are $interests " if $interests;
    my $dorm = $MIT::userDB->dorm($who);
    push @out, "You will be living in $dorm" if $dorm;
    return @out;
}

sub finduser {
    my ($self, $who, $chat, $query) = @_;
    return unless $query;
    my @found = $self->findName($query);
    my $count = @found && scalar @found;
    unless($count) {
        return "Couldn't find '$query'";
    } elsif ($count > 5) {
        return "Found $count results, too many to list.";
    } else {
        return map{"$_ is " . $MIT::userDB->description($_)} @found;
    }
}

registerCommand(whois => \&whois, 1);
registerCommand(wi => \&whois, 1);
registerCommand(find => \&finduser, 1);
registerCommand(whoami => \&whoami);

1;
