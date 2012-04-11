#!/usr/bin/perl -w

# Muninwalk 
# MIT License
# Mar 5, 2012
my $VERSION = '0.0.1';
# version 0.0.1 Masahito Zembutsu
# add 'list'
# add multipul query

use strict;
use warnings;
use IO::Socket;

# flush after every write
$| = 1;

my $DEBUG = 0;
my $option;

# check args
my $argl = pop(@ARGV);
if ($argl && $argl =~ /(\-)(\w)/) {
	$option = $2;
	if ($argl eq '-d') {
		$DEBUG = 1;
		undef $option;
		undef $argl;
	}
	#print "option exec: $2,$option,$argl\n";
} else {
	push(@ARGV,$argl);
#	undef $option;
}

#print "debug=$DEBUG,$option\n";

# initialize
my %Munin;
$Munin{PORT} = '4949';
$Munin{HOST} = shift(@ARGV);
($Munin{HOST}, $Munin{PORT}) = split(/\:/, $Munin{HOST}, 2) if($Munin{HOST} && $Munin{HOST} =~ /(\:)(\d+)/);

my $delimiter = ' = ';

#	#if($Munin{HOST} =~ /(:)(\d+)/){
#if($Munin{HOST} &&  $Munin{HOST} =~ /(\:)(\.*)/){
#	($Munin{HOST}, $Munin{PORT}) = split(/(:)/, $Munin{HOST}, 2); 
#}

$Munin{COMMAND} = $ARGV[0]; 
#$Munin{COMMAND} = shift(@ARGV); 
$Munin{COMMAND} = 'list' if (!$Munin{COMMAND});

#$delimiter = ',' if ($option eq 'c' && $option);

if ($option) {
#if ($option =~ /(v|h)/) {
#	print "[1:$option]";
	if ($option eq 'v') {
		&dispVersion;
		exit;
	} elsif ($option eq 'h') {
		&dispUsage;
		exit;
	} elsif ($option eq 'c') {
		$delimiter = ',';
	}
}

if (!($Munin{HOST} && $Munin{PORT} && $Munin{COMMAND})) {
#	print "[2]";
	print "No hostname specified.\n";
	&dispUsage();
} elsif ($Munin{COMMAND} eq 'walk') {
	print "## WALKMODE ##\n";
	my $list =&muninCommand('list','no');
	#print "list=$list";
	my @list = split(/\s/, $list);
	&muninFetch(@list);

} elsif ($Munin{COMMAND} =~ /(list|cap|nodes|version)/  ) {
#	print "[3]";
#	print "COMMAND $1\n";
	&muninCommand($1);
} else {
#	print "[4]";
	#&muninFetch($Munin{COMMAND});
	&muninFetch(@ARGV);
}

exit;

### subroutines 

sub muninFetch {

	print "### sub muninFetch args=@_\n" if($DEBUG); 
	#print "arg=$_[0]\n" if($DEBUG);
	print "host,port = $Munin{HOST}, $Munin{PORT}\n" if($DEBUG);			
	## use Net::Telnet
	my $SOCKET = IO::Socket::INET -> new (  PeerAddr => $Munin{HOST},
						PeerPort => $Munin{PORT},
						Proto	=> 'tcp',
						Timeout	=> '10',
						Type	=> SOCK_STREAM,
					) or die "Cannot create socket - $@\n";
	print "### TCP Connection success.\n" if ($DEBUG);
	print "Created a socket of type ".ref($SOCKET)."\n" if($DEBUG);
	my $tmp = <$SOCKET>;
	while (my $fetch = shift(@_)) {
		print "--- fetch $fetch\n" if ($DEBUG);
		my $obj = '';
		#($fetch, $obj) = split(/\./, $fetch, 2);
		if ($fetch =~ /^(\w+)(\.)(\w+)$/ ) {
			print "---- check pont: $1, $3\n" if($DEBUG);
			$fetch = $1;
			$obj = $3;
		}
		print "--- fetch $fetch, object = $obj\n" if($DEBUG);

		$SOCKET->print("fetch $fetch\n");
		select($SOCKET);
		select(STDOUT);
		print "--- tmp=$tmp\n" if($DEBUG);
		while (<$SOCKET> ) {
			chomp;
			print "--- - $_\n" if ($DEBUG);
			$_ =~ s/(.value)//;
			if ($_ =~ /^(.*)(\s)(.+)$/) {
				if (($1 eq '# Unknown') or ($1 eq '# Bad')) {
					print $Munin{HOST}."::".$fetch.$delimiter.'NULL'."\n";
#				} elsif ($obj) {
#					print "----- cp: $fetch, object: $obj\n" if($DEBUG);
#					print $Munin{HOST}."::".$fetch.".".$1.$delimiter.$3."\n" if ($1 eq $obj);
				} else {
					print "----- cp: $fetch\n" if ($DEBUG);
					print $Munin{HOST}."::".$fetch.".".$1.$delimiter.$3."\n" if(!$obj or ($1 eq $obj));
				}
			} else {
				last;
			}	
		}
	}
	$SOCKET->print("quit\n");
	$SOCKET->close();


#	if ($buf) {
#		print "buffer=$buf\n";
#		#print "$SOCKET\n";
#		foreach my $line (<SOCKET>) {
#			print "$line";
#		}
#	} else {
#		print "[DEBUG] no response\n";
#	}
	return;
}

sub muninCommand {

#	print "### sub muninCommand\n";
	my $SOCKET = IO::Socket::INET -> new (  PeerAddr => $Munin{HOST},
						PeerPort => $Munin{PORT},
						Proto   => 'tcp',
						Timeout => '10',
						Type    => SOCK_STREAM,
					) or die "Cannot create socket - $@\n";
        $SOCKET->print("$_[0]\n");
        select($SOCKET);
        select(STDOUT);
        my $tmp = <$SOCKET>;
	my $list = <$SOCKET>;
	$SOCKET->print("quit\n");
	$SOCKET->close();
	print $list if(!$_[1]);

	return($list);
}

sub dispVersion {
	print "muninwalk version $VERSION\n";
}

sub dispUsage {

#	print "No hostname specified.\n";
	print "USAGE: muninwalk <HOSTNAME[:PORT]> COMMAND [COMMAND...] [OPTION]\n";
	print "\n";
	print "  Version: $VERSION\n";
	print "  Github:  http://github.com/zembutsu/\n";
	print "  Web:     http://pocketstudio.jp/\n";
	print "  Email:   zem\@pocketstudio.jp\n";
	print "\n";
	print "COMMAND:\n";
	print "  list                display node enable plugins\n";
	print "  nodes               dispaly nodes\n";
	print "  <plugins names>     fetch data\n";
	print "  version             display munin-node's version\n";
	print "  walk                walkmode (fetch all plugins data)\n";
	print "\n";
	print "OPTION:\n";
	print "  -c[char]            change delimiter \n";
	print "  -d                  debug mode\n";
	print "  -h                  display this help message\n";
	print "  -v                  version\n";
	print "\n";
	return;
}

1;
