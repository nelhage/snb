package TOC::FLAP;

use TOC::AIMUtils;

#This is a class that deals with the sending and receiving of TOC(2)
#FLAP packets Each instance of the class handles a connection, and
#returns packets as hashes with FRAMETYPE and DATA keys. See the
#document TOC.txt for more information

#Frametypes
our ($FT_SIGNON,
     $FT_DATA,
     $FT_ERROR,
     $FT_SIGNOFF,
     $FT_KEEP_ALIVE) = (1..5);

use constant HEADER_LENGTH => 6;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    $self->{IN_SEQUENCE}  = undef;
    $self->{OUT_SEQUENCE} = 0;
    $self->{BUFFER}       = "";
    $self->{HEADER}       = {};
    $self->{GOT_HEADER}   = 0;
    $self->{PACKETS}      = [];
    bless($self,$class);
    return $self;
}

sub addData
{
    my ($self,$data) = @_;
    $self->{BUFFER} .= $data;
    $self->processData();
}

sub processData
{
    my $self = shift;
    my $header = $self->{HEADER};
    while(1)
    {
        if(!$self->{GOT_HEADER})
        {
            if(length $self->{BUFFER} >= HEADER_LENGTH)
            {
                ($header->{STAR},
                 $header->{FRAMETYPE},
                 $header->{SEQUENCE},
                 $header->{LENGTH})
                    = unpack("aCnn",substr($self->{BUFFER},
                                           0,HEADER_LENGTH));
                $self->{BUFFER} = substr($self->{BUFFER},HEADER_LENGTH);
                $self->{GOT_HEADER} = 1;
                if($header->{STAR} ne '*')
                {
                    die "Got bad header: ",$header->{STAR};
                }
                if(!defined($self->{IN_SEQUENCE}))
                {
                    $self->{IN_SEQUENCE} = $header->{SEQUENCE};
                }
                else
                {
                    #Sequence values are 16-bit, so wrap at 65535
                    $self->{IN_SEQUENCE} = ++$self->{IN_SEQUENCE} % 65536;
                    if($header->{SEQUENCE} != $self->{IN_SEQUENCE})
                    {
                        warn "Sequence mismatch, got ",$header->{SEQUENCE},
                        " wanted ", $self->{IN_SEQUENCE};
                        $self->{IN_SEQUENCE} = $header->{SEQUENCE};
                    }
                }
            }
            else
            {
                return;
            }
        }
        elsif(length $self->{BUFFER} >= $header->{LENGTH})
        {
            push @{$self->{PACKETS}},
            {FRAMETYPE => $header->{FRAMETYPE},
             DATA => substr($self->{BUFFER}, 0,$header->{LENGTH})};
            $self->{BUFFER} = substr($self->{BUFFER},$header->{LENGTH});
            $self->{GOT_HEADER} = 0;
        }
        else
        {
            return;
        }
    }
}

sub nextPacket
{
    my $self = shift;
    return shift @{$self->{PACKETS}};
}

sub signonPacket
{
    my ($self,$sn) = @_;
    $sn = TOC::AIMUtils::normalize($sn);
    my $data = pack("Nnn/a*",1,1,$sn);
    return $self->packetWithRawData($data,$FT_SIGNON);
}

sub dataPacket
{
    my ($self,$msg) = @_;
    $msg .= "\0";               #Null terminate the message
    return $self->packetWithRawData($msg);
}

sub packetWithRawData
{
    my ($self,$data,$frametype) = @_;
    $frametype ||= $FT_DATA;
    $self->{OUT_SEQUENCE} = ++$self->{OUT_SEQUENCE} % 65536;
    #16-bit sequence numbers again
    my $packet = pack("aCnn/a*","*",$frametype,$self->{OUT_SEQUENCE},$data);
    return $packet;
}

1;
