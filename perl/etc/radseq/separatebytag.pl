#!/usr/bin/env perl
=pod
Author: Hu Xuesong @ BIOPIC <galaxy001@gmail.com>
Version: 1.0.0 @ 20120627
=cut
use strict;
use warnings;
#use Data::Dump qw(ddx);
use Galaxy::IO::FASTAQ qw(readfq getQvaluesFQ);
use Galaxy::IO;

die "Usage: $0 <tag list> <6 num for (N,Cross,nonCross) by (bar,ec)> <fq1> <fq2> <out prefix>\n" if @ARGV<5;
my $tagf=shift;
my @maxMis=split //,shift;
my $fq1f=shift;
my $fq2f=shift;
my $outp=shift;

my $EseqR="TGCAG";
my $EseqLen = length $EseqR;

my (%BarSeq2idn,@BarSeq,@BarSeqs);
open L,'<',$tagf or die "Error opening $tagf:$!\n";
while (<L>) {
	chomp;
	my ($seq,$id,$name)=split /\t/;
	next unless $name;
	$seq = uc $seq;
	$seq .= $EseqR;
	push @BarSeq,$seq;
	push @BarSeqs,[split //,$seq];
	$BarSeq2idn{$seq} = [$id,$name,0,0,0,0];	# [id name outfh1 outfh2 PairsCnt PE_BaseCnt]
}
$BarSeq2idn{'N'} = ['NA','Unknown',0,0,0,0];
my $BARLEN = length $BarSeq[0];
#ddx \@BarSeq;
#ddx \%BarSeq2idn;
die if $BARLEN != length $BarSeq[-1];
my $EseqAfter = $BARLEN - $EseqLen -1;	# starts from 0

die "Max Barcode or EC length are 9 !\n" if $BARLEN > 18 or $EseqLen > 9;

open LOG,'>',"${outp}.log" or die "Error opening $outp.log:$!\n";
print LOG "From [$fq1f]&[$fq2f] with [$tagf][",join(',',@maxMis),"] to [$outp.*]\n";

for my $k (keys %BarSeq2idn) {
	my $fname = join('.',$outp,$BarSeq2idn{$k}->[0],$BarSeq2idn{$k}->[1],'1.fq.gz');
	my ($fha,$fhb);
	open $fha,'|-',"gzip -9c >$fname" or die "Error opening output $fname:$!\n";
	$fname = join('.',$outp,$BarSeq2idn{$k}->[0],$BarSeq2idn{$k}->[1],'2.fq.gz');
	open $fhb,'|-',"gzip -9c >$fname" or die "Error opening output $fname:$!\n";
	($BarSeq2idn{$k}->[2],$BarSeq2idn{$k}->[3]) = ($fha,$fhb);
}
#open $UNKNOWN,'|-',"gzip -9c >$outp.NA.Unknown.fq.gz" or die "Error opening output file:$!\n";

sub CmpBarSeq($$$) {
	my ($barseq,$maxmark,$barQ)=@_;
	return [$BarSeq2idn{$barseq},'1;000000,0'] if (exists $BarSeq2idn{$barseq});
	my $ret = [$BarSeq2idn{'N'},''];
	my @seqss = split //,$barseq;
	#my @seqQ = @{getQvaluesFQ($barQ)};
	my ($minmark,$mismark,$i,%mark2i,%marks,$ratio)=(999999);
	my %thisMarkC;
	if ( scalar @seqss < $BARLEN ) {
		$ret->[1] = -1 * scalar @seqss;
		return $ret;
	}
	for ($i=0; $i <= $#BarSeq; ++$i) {
		$mismark = 0;
		my @thisMarks=(0,0,0,0,0,0);	# (N,Cross[AC,GT],nonCross) by (bar,ec)
		my $tmp;
		for (my $j=0; $j <= $EseqAfter; ++$j) {
			if ($seqss[$j] eq $BarSeqs[$i][$j]) {
				next;	# [1-err]
			} elsif ($seqss[$j] eq 'N') {
				++$mismark;	# [1/4]
				++$thisMarks[0];
			} elsif ( $tmp = $seqss[$j].$BarSeqs[$i][$j] and ($tmp eq 'AC' or $tmp eq 'CA' or $tmp eq 'GT' or $tmp eq 'TG') ) {
				$mismark += 10;
				++$thisMarks[1];
			} else {
				#my $rateT = 10^($seqQ[$i]/10);	# 1/err   Q=-10*lg(err), err = 10^(-Q/10)      [err*1/3]
				$mismark += 100;
				++$thisMarks[2];
			}
		}
		for (my $j=$EseqAfter+1; $j <= $#seqss; ++$j) {
			if ($seqss[$j] eq $BarSeqs[$i][$j]) {
				next;
			} elsif ($seqss[$j] eq 'N') {
				$mismark += 0.001;
				++$thisMarks[3];
			} elsif ( $tmp = $seqss[$j].$BarSeqs[$i][$j] and ($tmp eq 'AC' or $tmp eq 'CA' or $tmp eq 'GT' or $tmp eq 'TG') ) {
				$mismark += 0.01;
				++$thisMarks[4];
			} else {
				#my $rateTp = 10^(($seqQ[$i]/10)-2);
				$mismark += 0.1;
				++$thisMarks[5];
			}
		}
		$mark2i{$mismark} = $i;
		$thisMarkC{$mismark} = \@thisMarks;
		++$marks{$mismark};
		$minmark = $mismark if $minmark > $mismark;
	}
	my @thisMarks = @{$thisMarkC{$minmark}};
	my $misStr = join('',@thisMarks);
	$ret->[1] = "$marks{$minmark};$misStr,$minmark";	# Well, string is also scalar to print.
	if ($marks{$minmark} == 1) {
		my $flag = 0;
		for my $i (0 .. $#thisMarks) {
			if ($thisMarks[$i] > $$maxmark[$i]) {
				$flag = 1;
				last;
			}
		}
		unless ($flag) {	# $flag == 0
			$ret = [$BarSeq2idn{$BarSeq[$mark2i{$minmark}]},"1;$misStr,$minmark"];
		}
	}
	return $ret;
}

my $fha=openfile($fq1f);
my $fhb=openfile($fq2f);
my (@aux1,@aux2);
my ($Count1,$Count2,$CountPairs)=(0,0,0);
my ($dat1,$dat2,$qbar);
my %Ret1Stat;
while (1) {
	$dat1 = readfq($fha, \@aux1);	# [$name, $comment, $seq, $qual]
	$dat2 = readfq($fhb, \@aux2);
	if ($dat1 && $dat2) {
		$$dat1[1] = (split / \|/,$$dat1[1])[0];
		$$dat2[1] = (split / \|/,$$dat2[1])[0];
		my $bar = substr $$dat1[2],0,$BARLEN;
		#$qbar = substr $$dat1[3],0,$BARLEN;
		my ($kret,$themark) = @{CmpBarSeq($bar,\@maxMis,$qbar)};
		++$Ret1Stat{$themark};
		my $fha = $kret->[2];
		my $fhb = $kret->[3];
		print $fha '@',join("\n",
			join(' ',@$dat1[0,1],"|",$kret->[0],$themark,$kret->[1]),
			$$dat1[2],'+',$$dat1[3]),"\n";
		print $fhb '@',join("\n",
			join(' ',@$dat2[0,1],"|",$kret->[0],$kret->[1]),
			$$dat2[2],'+',$$dat2[3]),"\n";
		++$kret->[4];
		$kret->[5] += length($$dat2[2]) + length($$dat2[2]);
		++$CountPairs;
	} elsif ($dat1) {
		++$Count1;
		print "1-",join('|',@$dat1),"\n";
	} elsif ($dat2) {
		++$Count2;
		print "2-",join('|',@$dat2),"\n";
	} else {
		last;
	}
}
close $fha;
close $fhb;

my $str = "Out Pairs: $CountPairs\nFQ1 over hang: $Count1\nFQ2 over hang: $Count2\n
BarSeq\tID\tName\tRead_Pairs\tPE_Bases\tRatio\n";
print $str;
print LOG $str;

for my $k (sort 
	{ if ($a eq 'N') { return 1; } elsif ($b eq 'N') { return -1; } else { return $BarSeq2idn{$a}[0] cmp $BarSeq2idn{$b}[0]; } 
	} keys %BarSeq2idn) {
	close $BarSeq2idn{$k}->[2];
	close $BarSeq2idn{$k}->[3];
	$str = join("\t",$k,@{$BarSeq2idn{$k}}[0,1,4,5],$BarSeq2idn{$k}->[4]/$CountPairs)."\n";
	print STDOUT $str;
	print LOG $str;
}

print LOG "\nTypes\n";
my @order = sort {
(split /;/,$a)[0] <=> (split /;/,$b)[0]
	||
$Ret1Stat{$b} <=> $Ret1Stat{$a}
} keys %Ret1Stat;
my $Sum = 0;
for my $k (@order) {
	print LOG join("\t",$k,$Ret1Stat{$k},$Ret1Stat{$k}/$CountPairs),"\n";
	$Sum += $Ret1Stat{$k} if (split /;/,$k)[0] eq '1';
}
my $t = join('',"\nUnique_Ratio: $Sum / $CountPairs = ",$Sum/$CountPairs,"\n");
print $t;
print LOG $t;
close LOG;
