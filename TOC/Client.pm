package TOC::Client;

use strict;
use warnings;

use TOC::FLAP;
use TOC::AIMUtils;

use POE;
use POE::Wheel::ReadWrite;
use POE::Wheel::SocketFactory;
use POE::Filter::Stream;

my $host="toc.oscar.aol.com";
my $auth_host="login.oscar.aol.com";
my $port=5190;

use constant WANT_FLAP_SIGNON   =>  0;
use constant WANT_SIGNON        =>  1;
use constant WANT_CONFIG        =>  2;
use constant GOT_CONFIG         =>  3;
use constant CONNECTED          =>  4;

my %numArgs = (IM_IN            =>  3,
               IM_IN2           =>  4,
               CHAT_IN          =>  4,
               CHAT_INVITE      =>  4);

=head1 Methods

=over

=item new($alias, $parent)

Create a new TOC::Client session object with the POE alias
$alias. This object will invoke POE states on the session $parent of
the form toc_<NAME>, where NAME is one of the TOC server commands laid
out in TOC.txt. Args to the state call will be the same as sent by the
server.

=cut

sub new
{
    my ($proto, $alias, $parent, $debug) = @_;
    my $pack = ref($proto) || $proto;
    my $self = {ALIAS => $alias, PARENT => $parent, QUEUE => [], 
                DEBUG => $debug};
    bless($self,$proto);

    POE::Session->create(
        object_states   => [
            $self => [qw(_start connect connected
                         connect_error config_done
                         input toc_packet_in) ]
           ]
       );

    return $self;
}

sub _start
{
    my ($kernel, $self) = @_[KERNEL, OBJECT];
    $kernel->alias_set($self->{ALIAS});
    $self->register_commands($kernel);
}

=item connect($screename, $password)

Attempts to connect to the TOC server using the specified screen name
and password.  This will invoke send_config on the parent session,
which should send the TOC::Client object a config_done after sending
config data (buddy list + privacy preferences), within 30
seconds. Once config_done has been returned, invokes "connected" on
the parent session.

=cut
    
sub connect
{
    my ($kernel, $self, $handle, $password) = @_[KERNEL, OBJECT, ARG0, ARG1];
    $self->{HANDLE} = TOC::AIMUtils::normalize($handle);
    $self->{PASSWORD} = $password;
    if ($self->{server}) {
        $self->{server}->shutdown_input;
        $self->{server}->shutdown_output;
    }
    $self->{FACTORY} = POE::Wheel::SocketFactory->new (
        RemoteAddress   =>  $host,
        RemotePort      =>  $port,

        SuccessEvent    => "connected",
        FailureEvent    => "connect_error"
       );
}

sub connected
{
    my ($kernel,$self,$socket) = @_[KERNEL, OBJECT, ARG0];

    $self->{server} = POE::Wheel::ReadWrite->new(
        Handle          => $socket,
        Filter          => POE::Filter::Stream->new(),
        InputEvent      => "input",
        ErrorEvent      => "connect_error"
       );

    $self->{FLAP} = TOC::FLAP->new;
    $self->{STATE} = WANT_FLAP_SIGNON;
    $self->{server}->put("FLAPON\r\n\r\n");
    print "Sent FLAPON\n" if $self->{DEBUG};
}

sub connect_error
{
    my ($kernel, $self, $error) = @_[KERNEL, OBJECT, ARG0];
    delete $self->{SERVER};
    $kernel->post($self->{PARENT}, "disconnected", $error);
}

sub input
{
    my ($kernel,$self,$input) = @_[KERNEL, OBJECT, ARG0];
    $self->{FLAP}->addData($input);
    my $packet;
    while ($packet = $self->{FLAP}->nextPacket)
    {
        $kernel->yield("toc_packet_in",$packet);
    }
}

sub toc_packet_in
{
    my ($kernel,$self,$packet) = @_[KERNEL, OBJECT, ARG0];
    if ($packet->{FRAMETYPE} == $TOC::FLAP::FT_SIGNON)
    {
        die "Got unexpected FLAP signon" unless
            $self->{STATE} == WANT_FLAP_SIGNON;
        my $flap_version = unpack("N",$packet->{DATA});
        die "Bad FLAP version: $flap_version" unless $flap_version == 1;
        $self->{server}->put($self->{FLAP}->signonPacket($self->{HANDLE}));
        #       $self->send_command("toc_signon",$auth_host,$port,$self->{HANDLE},
        #                               roast($self->{PASSWORD}),
        #                               "english", "TOC.pl v0.2");
        $self->send_command("toc2_signon",$auth_host, $port, $self->{HANDLE},
                            roast($self->{PASSWORD}),
                            "english",
                            "TIC:TOC.pl v0.3",
                            160,
                            $self->signonCode());

        print "Sent signon\n"  if $self->{DEBUG};
        $self->{STATE} = WANT_SIGNON;
    }
    elsif ($packet->{FRAMETYPE} == $TOC::FLAP::FT_KEEP_ALIVE)
    {
        $kernel->post($self->{PARENT},"keep_alive");
    }
    else
    {
        if ($packet->{FRAMETYPE} != $TOC::FLAP::FT_DATA) {
            print "Odd frametype: $packet->{FRAMETYPE}\n";
            return;
        }
        my ($cmd,$args) = split /:/, $packet->{DATA},2;
        if ($cmd eq "SIGN_ON")
        {
            return unless $self->{STATE} == WANT_SIGNON;
            $self->{STATE} = WANT_CONFIG;
            print "Got SIGN_ON: ", $args, "\n"  if $self->{DEBUG};
        }
        elsif ($cmd eq "CONFIG2")
        {
            die("Unexpected CONFIG") unless $self->{STATE} == WANT_CONFIG;
            $self->{STATE} = GOT_CONFIG;

            print "Got configuration: $args\n"  if $self->{DEBUG};
            #Add ourself to our list, since AIM won't log us on unless we add
            #at least one buddy
            $self->send_command("toc_new_buddies",$self->{HANDLE});
            $kernel->post($self->{PARENT},"send_config" => $args);
        }
        else
        {
            my $nargs = $numArgs{$cmd} || 0;
            my @args = split /:/, $args, $nargs;
            print "RECV: $packet->{DATA}\n"  if $self->{DEBUG};
            $kernel->post($self->{PARENT},"toc_$cmd",@args);
        }
    }

}

sub config_done
{
    my ($kernel, $self) = @_[KERNEL, OBJECT];
    die("Config already sent!") unless $self->{STATE} == GOT_CONFIG;
    $self->send_command("toc_init_done");
    $self->{STATE} = CONNECTED;
    $kernel->post($self->{PARENT},"connected");
}

#Argument formatters
sub one_sn_arg
{
    return (TOC::AIMUtils::normalize(shift),);
}

sub many_sns_arg
{
    return map {TOC::AIMUtils::normalize($_)} @_;
}

sub one_arg
{
    return (shift,);
}

sub two_args
{
    return (shift, shift);
}

sub no_arg
{
}

sub new_buddies_arg 
{
    my @args = @_;
    my $str;

    if (ref($args[0]) eq "HASH") {
        my $groups = shift;
        $str = join("\n", 
                    map{"g:$_\n".
                            join("",map{"b:$_\n"} @{$groups->{$_}})
                        } keys %$groups);
    } else {
        $str = "g:Buddies\n" . 
            join("", map{"b:$_\n"} @args);
    }
    return "$str";
}

#This is an array that defines the TOC commands we can send out
#Creating a new TOC object assigns the POE event to an appropriate handler
my  @toc_commands = (
    #Event Name,        handler func
    ["get_status",      \&one_sn_arg],
    ["add_buddy",       \&many_sns_arg],
    #       ["remove_buddy",    \&many_sns_arg],
    ["evil",            sub {
         (TOC::AIMUtils::normalize(shift),
          (shift)?"anon":"norm")
     }],
    ["add_permit",      \&many_sns_arg],
    ["add_deny",        \&many_sns_arg],
    ["chat_join",       sub {(4, shift)} ],
    ["chat_send",       \&two_args],
    ["chat_whisper",    sub {
         (shift, TOC::AIMUtils::normalize(shift),
          shift)
     }],
    ["chat_invite", sub {
         (shift, shift, many_sns_arg(@_))
     }],
    ["chat_leave",      \&one_arg],
    ["chat_accept",     \&one_arg],
    ["get_info",        \&one_sn_arg],
    ["set_info",        \&one_arg],
    ["set_away",        \&one_arg],
    ["set_idle",        \&one_arg],
    ["format_nickname", \&one_arg]
   );
        
my @toc2_commands = (
    ["new_buddies",    \&new_buddies_arg],
    ["remove_buddy",   sub { my $group = pop;
                             (many_sns_arg(@_), $group)}],
    ["new_group",      \&one_arg],
    ["del_group",      \&one_arg],
    ["send_im",            sub {
         (TOC::AIMUtils::normalize(shift),
          shift, (shift)?"auto":"")
     }],
   );
        
=over

=head1 Server interaction

TOC::Client sessions define states for each command defined in the TOC
protocol, with the same name, less "toc_". Arguments are the same as
defined in the standard.  For convenience, screen names will be
normalized if necessary, and argument quoting is done for
you. Additionally, boolean parameters ("auto","anon") will behave as
expected if passed any true/false value. Also, chat_join does not need
an exchange.  If the exchange parameter ever comes to mean anything,
maybe I'll think about letting users specify it.

=head3 Examples

    Assuming a TOC::Client session has been created with the alias "toc":
    $poe_kernel->post(toc => send_im => "hanjithearcher" => "Hello Nelson.");
    #Note no exchange is needed when joining chats.
    $poe_kernel->post(toc => chat_join => "MIT2009");
    
=cut

    #Dynamically register states with the kernel, according to the
    #above table For each command, create a state with the name, that
    #sends a command named toc_<COMMAND>, after passing arguments
    #through the "filter" function listed in the table.
    sub register_commands
{
    my ($self, $kernel) = @_;
    my $cmd;
    for $cmd (@toc_commands)
    {
        $kernel->state($cmd->[0],sub {
                           $self->send_command("toc_".$cmd->[0],
                                               $cmd->[1]->(@_[ARG0..$#_]))
                       });
    }

    for $cmd (@toc2_commands)
    {
        $kernel->state($cmd->[0],sub {
                           $self->send_command("toc2_".$cmd->[0],
                                               $cmd->[1]->(@_[ARG0..$#_]))
                       });
    }
}

#internals

#Send a command and arguments to the server, encoding and quoting
#arguments as needed.
sub send_command
{
    my $self = shift;
    my $cmd = shift;
    my $arg;
    foreach $arg (@_)
    {
        $cmd .= " " . encodeArg($arg);
    }

    #   push @{$self->{QUEUE}}, $cmd
    $self->{server}->put($self->{FLAP}->dataPacket($cmd));
    print "SEND: $cmd\n"  if $self->{DEBUG};
}

#returns a TOC2 signon code
sub signonCode
{
    my $self = shift;
    my $sn = ord($self->{HANDLE}) - 96;
    my $pw = ord($self->{PASSWORD}) - 96;
    #I don't know if AOL was trying to be be clever or what, but algorithm from
    #http://www.firestuff.org/projects/firetalk/doc/toc2.txt
    my $a = $sn * 7696 + 738816;
    my $b = $sn * 746512;
    my $c = $pw * $a;
    return $c - $a + $b + 71665152;
}

#"Roast" a password string for sending, according to the protocol spec
sub roast
{
    my $password = shift;
    my $roastString = substr("Tic/Toc" x 10,0,length $password);
    $password ^= $roastString;
    return "0x" . unpack("H*",$password);
}

#Quote and encode an argument for sending to the server:
#-Backslash all instances of brackets, parentheses, backslashes, dollar signs,
#and single or double quotes
#-Surround the string in "quotes"
sub encodeArg
{
    my $arg = shift || "";
    #Escape various characters
    $arg =~ s/([\[\]{}()\\\$'"])/\\$1/g; #'#Goddamn editors again
    $arg = '"' . $arg . '"';
    return $arg;
}

1;
