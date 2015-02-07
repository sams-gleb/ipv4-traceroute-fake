#!/usr/bin/perl -w
#
use strict;
use nfqueue;
use NetPacket::IP qw(:ALL);
use NetPacket::ICMP qw(:ALL);
use NetPacket::UDP qw(:ALL);
use NetPacket::TCP qw(:ALL);
use Socket qw(AF_INET AF_INET6);
use Net::RawSock; # http://www.hsc.fr/ressources/outils/rawsock/index.html.en
use Data::Dumper;
use Time::HiRes qw(gettimeofday usleep);

my $DEBUG = 0;
my $DELAY = 240;

my (@hops,@our_net_hops,$hop,$now);

my $ip_for_traceroute = shift;
 
if (defined $ip_for_traceroute)
{
	create_config($ip_for_traceroute);
}
else
{
	print "Can't create config for traceroute.pl\n";
	exit;
}

print "hops:\n", map { "\t" . $_->{ip} . "\t(" . $_->{ms} . " ms)\n" } @hops;
unshift @hops, undef;
my $q;

sub create_config
{
    my $local_ip = shift;
    $local_ip =~ s/\.\d+$/\.1/;
    my @hosts = `traceroute -n $local_ip -m 20`;
    foreach my $line (@hosts) {
        my @a = split(' ', $line);
        my $hop = $a[0] if $a[0] =~ m/\d+/;
        my $ip = $a[1] if $a[1] =~ m/\d+\.\d+\.\d+\.\d+/;
        my $ms = $a[2] if $a[2] =~ m/\d+/;
        if ($ip && $hop && $ms)
        {
		  if (!($ip =~ /10.100./))
		  {
                	push @hops, { ip => $ip, ms => $ms };
		  }
		  else
		  {
					push @our_net_hops, { ip => $ip, ms => $ms };
		  }
        }
        elsif ($a[1] eq  '*')
        {
                push @hops, { ip => '0.0.0.0', ms => '120' };
        }
    }
    unshift @hops, { ip => $our_net_hops[-1]{'ip'}, ms =>  $our_net_hops[-1]{'ms'} };
    unshift @hops, { ip => '0.0.0.0', ms => '120' };
    push @hops, { ip => '0.0.0.0', ms => '120' };
}

sub cleanup()
{
        $q->unbind(AF_INET);
        $q->close();
}

sub cb()
{
        my ($dummy,$payload) = @_;
        if ($payload) {
        my $ip_obj = NetPacket::IP->decode($payload->get_data());
		#for icmp ping
		if ($ip_obj->{ttl} > 40)
        {
		        if ($ip_obj->{proto} == '1')
        		{
		        	my $icmp_obj = NetPacket::ICMP->decode($ip_obj->{data});
			        if (($icmp_obj->{type} == '8') && ($icmp_obj->{data} =~ '01234567'))
         			{
		                	#ping delay
	                		print "ICMP ping reply\n" if $DEBUG;
			                my $ms = $DELAY * 1000;
	                		usleep($ms);
			                $payload->set_verdict($nfqueue::NF_ACCEPT);
			                return;
         			}
		        }
                        return;
                }

				if ($ip_obj->{len} == 0)
                {
                        return;
                }

                $now = gettimeofday;

                $hop = $hops[ $ip_obj->{ttl} ];
                $ip_obj->{ttl} = sprintf "%2d", $ip_obj->{ttl};

                unless ($hop) 
                {
						print "Traceroute end $ip_obj->{src_ip}, ttl $ip_obj->{ttl} from $ip_obj->{dest_ip}\n" if $DEBUG;
						my $ms = $DELAY * 1000;
                		usleep($ms);
                        $payload->set_verdict($nfqueue::NF_ACCEPT);
                        return;
                }

		if ($hop->{ip} ne '0.0.0.0') 
		{
				print "Traceroute proto $ip_obj->{proto} answer to $ip_obj->{src_ip}, ttl $ip_obj->{ttl} from $hop->{ip}\n" if $DEBUG;
                my $ipout = NetPacket::IP->decode;
                $ipout->{ver}           = IP_VERSION_IPv4;
                $ipout->{hlen}          = 5;
                $ipout->{tos}           = 0xC0;
                $ipout->{len}           = 0;
                $ipout->{id}            = int rand(0xFFFF);
                $ipout->{foffset}       = 0;
                $ipout->{proto}         = IP_PROTO_ICMP;
                $ipout->{src_ip}        = $hop->{ip};
                $ipout->{dest_ip}       = $ip_obj->{src_ip};
                $ipout->{options}       = "";
                $ipout->{flags}         = oct("0b" . "010");
                $ipout->{ttl}           = 255+1 - $ip_obj->{ttl};
                my $icmp = NetPacket::ICMP->decode;
                $icmp->{type}           = ICMP_TIMXCEED;
                $icmp->{code}           = 0;
                $icmp->{data}           = "\0"x4 . substr($ip_obj->encode, 0, $ip_obj->{hlen}*4+8);
                $ipout->{data}  = $icmp->encode;

				if ($ip_obj->{proto} == '17') 
				{
						my $ms = $hop->{ms} * 100;
                        print "Set delay $ms ms for current hop\n" if $DEBUG;
                        usleep($ms);
				}
				else
				{
			    		my $ms = $hop->{ms} * 1000;
			    		print "Set delay $ms ms for current hop\n" if $DEBUG;
	       				usleep($ms);
		        }
                Net::RawSock::write_ip($ipout->encode);
                $payload->set_verdict($nfqueue::NF_DROP);
                return;
		}
		else
		{
			print "Traceroute delay\n" if $DEBUG;
			#my $ms = $hop->{ms} * 10;
        	#usleep($ms);
			$payload->set_verdict($nfqueue::NF_DROP);
                	return;
		}
        }
}

$q = new nfqueue::queue();
$SIG{INT} = "cleanup";
$q->set_callback(\&cb);
$q->fast_open(0,AF_INET);
$q->set_queue_maxlen(5000);
$q->try_run();
