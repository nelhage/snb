package TOC::Session;

use POE;

use TOC::AIMUtils;

use strict;
use warnings;

use POSIX qw(strftime);

sub new
{
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $me = TOC::AIMUtils::normalize(shift); #Who are we talking to?
	my $self = {NICK => $me, STATES => [{}]};
	return bless($self,$class);
}

sub send {
	my ($self, $msg, $to) = @_;
	$poe_kernel->post(toc => send_im => $to || $self->{NICK} => $msg)
}

=head1 State Machine interface

The TOC::Session class provides an API to maintain persistent
interactive states with clients of a bot within a single thread. The
state machine works by maintaining a stack of currently active
states. Each state contains maintains a target method to call to
activate it, and a list of queries to the user that must be completed
before the state will be run. Additionally, a state can be made to
"persist", which means it must be explicitly ended, instead of
automatically being removed when it is run.

=cut

#########################################################
###########   State machine interface   #################
#########################################################

=head1 Methods

=over

=item messageIn($input)

Call this method with any new input from the user that this session is managing.

=cut

sub messageIn {
	my ($self, $in) = @_;
	if ($self->state()) {
		if ($self->state()->{QUERY}) {
			$self->query($self->state()->{QUERY}->{PARM},"",$in);
			$self->nextQuery();
		} else {
			$self->query("INPUT","",$in);
		}
		$self->processStates();
		return 1;
	}

	return 0;
}

=item newState($target[, $persists])

Create a new active state with a given $target method that will be called
on the object when the state is run. If $persist is true, the state will stay
until manually removed with $self->popState(); otherwise it will be removed
once it has been run once.

$target should accept a single argument, a hashref containing answers to all
the queries the state was passed. See query() for more information.

=cut

sub newState
{
	my ($self, $target, $persists) = @_;
	push @{$self->{STATES}}, { PARMS => {},
                               QUERY => undef,
                               PENDING => [],
                               TARGET => $target
                              };
	$self->state()->{PERSISTS} = 1 if($persists);
}

=item popState()

Remove the topmost state from the state stack

=cut

sub popState
{
	my $self = shift;
	pop @{$self->{STATES}};
}

=item query($parm, $prompt[, $value])

Request input that must be received from the user before the current
state can be run. When $self-run() is called, all outstanding queries
that have been created by this method will be processed sequentially,
by sending $prompt to the user, and storing the response under the key
$parm in the hash passed to the $target set in newState().

If $value is defined, the given $parm will be set to $value, and no
user interaction will take place for this state.

N.B. Under one circumstance, the args hash passed to $target will
contain a key other than those specified by various calls to
query(). If the topmost state is persistent, and has not specified any
more queries to run, it will be called whenever any message is
received from the user, with the user message in the INPUT key of the
hash.

=cut

sub query
{
	my ($self, $parm, $prompt, $value) = @_;
	if (defined($value)) {
		$self->state()->{PARMS}->{$parm} = $value;
	} else {
		push @{$self->state()->{PENDING}}, {PARM => $parm,
                                            PROMPT => $prompt};
	}
}

=item run()

Indicate that the program is done setting up states for now, and the state 
machine should start processing queries.

=back

=cut

sub run
{
	my ($self) = @_;
	
	$self->updateQueries();
	$self->processStates();
}

#########################################################
###########   State machine internals   #################
#########################################################
#Send the next query and update the states query queue
sub nextQuery {
	my ($self) = @_;

	my $query = shift @{$self->state()->{PENDING}};
	unless($query){
		delete $self->state()->{QUERY};
		return;
	}
	$self->send($query->{PROMPT});
	$self->state()->{QUERY} = $query;
}

#Run the next state if it has a target defined and no outstanding
#queries
sub processStates {
	my ($self) = @_;
	my $state = $self->state();
	
	if (!defined($state->{QUERY}) &&
          defined($state->{TARGET}) &&
			scalar keys %{$state->{PARMS}}) {
		my $targ = $state->{TARGET};
		my $args = $state->{PARMS};
		$self->popState() unless $state->{PERSISTS};
		$self->$targ($args);
		$self->updateQueries();
	}
}

sub updateQueries {
	my $self = shift;
	unless ($self->state()->{QUERY}) {
		$self->nextQuery();
	}
}

sub state {
	my $self = shift;
	return $self->{STATES}->[-1];
}
#End state internals

1;
