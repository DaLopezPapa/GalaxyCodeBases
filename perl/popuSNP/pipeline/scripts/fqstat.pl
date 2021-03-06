#!/bin/env perl
use strict;
use warnings;

unless (@ARGV){
	print "perl $0 <fq file>\n";
	exit;
}

my $fq;

my ($maxreadlen,$copyedreads,$inbp,$outbp,$readlen)=(0);

my $read_num = 0;

my @files=@ARGV;
while ($fq = shift) {
	if ($fq =~ /\.gz$/) {
		open( FQ,'-|',"gzip -dc $fq") or die "[x]Error on $fq: $!\n";
	} elsif ($fq =~ /\.bz2$/) {
		open( FQ,'-|',"bzip2 -dc $fq") or die "[x]Error on $fq: $!\n";
	} else {open( FQ,'<',$fq) or die "[x]Error on $fq: $!\n";}

	while (my $line1=<FQ>) {
		#chomp $line1;
		my $line2 = <FQ>;
		chomp $line2;
		$readlen=length $line2;
		$maxreadlen = $readlen if $maxreadlen < $readlen;
		$inbp += $readlen;
		my $line3 = <FQ>;
		#chomp $line3;
		my $line4 = <FQ>;
		#chomp $line4;
		#my ($read_name) = $line1=~ /^\@(FC.*)/;
		++$read_num;
		++$copyedreads;
		$outbp += $readlen;
		print "$line1$line2\n$line3$line4";
	}
	close FQ;
}
warn "$read_num parsed in [@files]
Using [NULL], No Adapter List used.
MaxReadLen\t$maxreadlen
InReads\t$read_num
InBPs\t$inbp
FiltedReads\t0
CopyedReads\t$copyedreads
OutReads\t$copyedreads
OutBP\t$outbp
All done !\n";
