Fake traceroute (ipv4)
=====================

This script will allow you to replace a traceroute output. 

Install:
--------
install nfqueue and NetPacket modules:
	sudo apt-get install nfqueue-bindings-perl libnetpacket-perl
install Net::RawSock from the sources:
	 http://www.hsc.fr/ressources/outils/rawsock/index.html.en
and route needed protocols to nfqueue
	-A INPUT -p icmp -j NFQUEUE --queue-num 0
	-A INPUT -p udplite -j NFQUEUE --queue-num 0
	-A INPUT -p udp -j NFQUEUE --queue-num 0

Example:
--------
specify the ip, which will be used for creating config to fake traceroute:
 host2:~# perl traceroute.pl 98.139.183.24

and test traceroute path from second host:
 host1:~# traceroute host2
 traceroute to host2, 30 hops max, 60 byte packets
  1  * * *
  2  * * *
  3  * * *
  4  * * *
  5  * exchange-cust1.dc2.equinix.net (206.126.236.16)  18.036 ms  33.963 ms
  6  ae-4-0.pat1.nyc.yahoo.com (216.115.104.121)  53.996 ms  55.727 ms  59.957 ms
  7  ae-2.pat1.bfz.yahoo.com (216.115.100.26)  57.398 ms  55.005 ms  52.492 ms
  8  ae-4.msr1.bf1.yahoo.com (216.115.100.25)  52.382 ms  52.170 ms  51.944 ms
  9  UNKNOWN-98-139-232-X.yahoo.com (98.139.232.107)  51.909 ms  51.792 ms  51.706 ms
 10  et17-1.fab7-1-sat.bf1.yahoo.com (98.139.128.89)  52.059 ms  52.326 ms  52.674 ms
 11  po-12.bas1-7-prd.bf1.yahoo.com (98.139.129.193)  52.403 ms  52.383 ms  52.290 ms
 12  ir25.fp.bf1.yahoo.com (98.139.183.1)  52.159 ms  51.937 ms  51.678 ms
 13  * * *
