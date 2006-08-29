package TOC::BuddyList;

use warnings;
use strict;
use POE;

use TOC::Buddy;
use TOC::AIMUtils;

our $blist;

sub new
{
    unless ($blist) {
        my $proto = shift;
        my $class = ref($proto) || $proto;
        my $targ = shift;
        my $self = {};
        $self->{BUDDIES} = {};
        $self->{TARG} = $targ;
        bless($self,$proto);
        $blist = $self;
    }
    return $blist;
}

sub update
{
    my ($self, $buddy, @args) = @_;
    $self->insertBuddy($buddy) unless $self->buddy($buddy);
    $self->buddy($buddy)->update($buddy, @args);
}

sub startSignon 
{
    my $self = shift;
    $self->{SIGNON} = 1;
}

sub finishSignon 
{
    my $self = shift;
    $self->{SIGNON} = 0;
#   $poe_kernel->post(toc => "new_buddies", keys %{$self->{BUDDIES}});
}

sub insertBuddy
{
    my ($self, $buddy) = @_;
    my $norm = TOC::AIMUtils::normalize($buddy);
    unless(exists($self->{BUDDIES}->{$norm})) {
        $self->{BUDDIES}->{$norm} =
            TOC::Buddy->new($self->{TARG},$norm, $buddy);
#       $poe_kernel->post(toc => new_buddies => $norm) unless $self->{SIGNON};
    }
    return $self->buddy($buddy);
}

sub buddy
{
    my ($self, $buddy) = @_;
    my $norm = TOC::AIMUtils::normalize($buddy);
    return $self->{BUDDIES}->{$norm};
}

#Convenience method to look up a buddy's display name
sub displayName
{
    my ($self, $who) = @_;
    return $self->buddy($who)->formattedHandle;
}

sub foreach
{
    my ($self, $sub) = @_;
    my $buddy;
    foreach $buddy (values %{$self->{BUDDIES}}) {
        $sub->($buddy);
    }
}

1;
