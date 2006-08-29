package MITBot;

use Roman;
use strict;
use warnings;
use POE;
use POSIX qw(mktime strftime);

use MIT;
use MIT::Session;
use MIT::UserDB;
use TOC::AIMUtils;

my %courses;

sub course
{
    my ($self, $who, $chat, @args) = @_;
    return unless @args;
    my $num = uc shift @args;
    my $name;
    if ($name = $courses{isroman($num)?arabic($num):$num}) {
        my $msg = "Course $num is '$name'";
        return $msg;
    } else {
        return "I don't know course $num.";
    }
}


sub whatis
{
    my ($self, $who, $chat, $find) = @_;
    return unless $find;
    my $msg = "";
    my ($num, $name);
    while (($num, $name) = each(%courses)) {
        if ($name =~ /\Q$find\E/i) {
            $msg .= "$name is Course $num.\n";
        }
    }
    
    $msg = "Couldn't find '$find'." unless $msg;
    return $msg;
}

open(COURSES,"<","data/courses");

my ($line,$number,$name);

while ($line = <COURSES>) {
    chomp $line;
    ($number, $name) = ($1,$2) if $line =~ /^(.*)\t(.*)$/;
    $courses{$number} = $name;
}
close(COURSES);

registerCommand(course => \&course);
registerCommand(whatis => \&whatis, 1);

1;
