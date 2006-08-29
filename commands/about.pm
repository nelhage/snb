package MITBot;

use strict;
use warnings;
use POE;
use POSIX qw(mktime strftime);

use MIT;
use MIT::Session;
use MIT::UserDB;
use TOC::AIMUtils;

my $license;

sub source
{
    my ($self, $who, $chat, @args) = @_;
    return <<'SOURCE';
Perl source to the bot is available at
http://web.mit.edu/nelhage/Public/snb.tgz
Bug Nelson (AIM: hanjithearcher, snb@mit.edu) if it's out of date.
SOURCE
}

sub license {
    my ($self, $who, $chat, @args) = @_;
    return ($license,"Type '!source' to learn how to obtain ".
              "a copy of my source code.");
}

sub credits
{
    return ("SexyNerdBot was programmed by Nelson Elhage " .
              "(AIM: hanjithearcher)\n".
                "Source to the bot is available under the " .
                  "GNU General Public License -- ".
                    "Type ``!source'' for more information");
}

open(LICENSE,"<","LICENSE");
$license =join("",<LICENSE>);
close(LICENSE);

registerCommand(source => \&source);
registerCommand(license => \&license);
registerCommand(credits => \&credits);

1;
