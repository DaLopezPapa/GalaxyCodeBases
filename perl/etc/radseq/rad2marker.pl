#!/usr/bin/env perl
=pod
Author: Hu Xuesong @ BIOPIC <galaxy001@gmail.com>
Version: 1.0.0 @ 20120720
=cut
use strict;
use warnings;
use Data::Dump qw(ddx);
use Galaxy::IO;
use Galaxy::IO::FASTAQ qw(readfq getQvaluesFQ);
use Galaxy::SeqTools;

die "Usage: $0 <ec list> <bcgv bcf> <out>\n" if @ARGV<2;
# no more "<sorted bam files>", use `samtools merge -r <out.bam> <in1.bam> <in2.bam> [...]` first !
my $eclst=shift;
my $bcfs=shift;
my $outfs=shift;

my $ReadLen = 101-5;
my $minOKalnLen = 30;
my $minAlignLen = int($ReadLen * 0.6);
$minAlignLen = $minOKalnLen if $minAlignLen < $minOKalnLen;
die if $ReadLen < $minOKalnLen;

my $Eseq="CTGCAG";
my $EseqLen = length $Eseq;
my $EcutAt=5;
my $EseqL="CTGCA";#substr $Eseq,0,$EcutAt;
my $EseqR="TGCAG";

my $EfwdTerm5=1-$EcutAt+1;	# -3
my $EfwdTerm3=1-$EcutAt+$ReadLen;	# 92
my $ErevTerm3=0;	# 0
my $ErevTerm5=$ErevTerm3-$ReadLen+1;	# -95
# 12008 -> [12005,12099],[11914,12008]
my $Rfwd2Ec = -$EfwdTerm5;	# 3
my $Rrev2Ec = -$ErevTerm3;	# 0

# C|TGCAG
my $PosLeft = -$EfwdTerm3;	# -92
my $PosRight = -$ErevTerm5;	# 95;
my $PosECsft = $Rfwd2Ec;	# 3;
# - [x-$PosLeft,x+$PosECsft], Len=96
# + [x,x+$PosRight], Len=96
# A [x-$PosLeft,x+$PosRight], Len=95+92+1=186

my %Stat;
my $t;
open O,'>',$outfs or die "Error opening $outfs : $!\n";
$t = "# EClst: [$eclst], Enzyme: [$Eseq], Cut after $EcutAt\n# Bams: [$bcfs]\n";
print O $t;
print $t;

my %Markers;
open L,'<',$eclst or die;
while (<L>) {
	next if /^(#|$)/;
	my ($chr,$pos,$strand,$mark,$count,$samples) = split /\t/;
#warn "$chr,$pos,$strand,$samples,$mark\n";
	next if $samples < 2;
	push @{$Markers{$chr}},[$pos,$strand]
}
close L;

my $th = openpipe('bcftools view',$bcfs);
my @Samples;
while (<$th>) {
	next if /^##/;
	my @data = split /\t/;
	if ($data[0] eq '#CHROM') {
		@Samples = map {my $t=(split /\//)[-1];$t=~s/_cut//g;$t=~s/-/./g; $_=join('_',(split /\./,$t)[-5,-6]);} splice @data,9;
		# ../5.bam_0000210210_merged/d1_4_merged.D4.JHH001.XTU.sort.rmdup.bam
		last;
	}
}
print O "# Samples: [",join('],[',@Samples),"]\n";
warn "Samples:\n[",join("]\n[",@Samples),"]\n";
=pod
Samples:
[JHH001_D4]
[GZXJ03_A1]
[GZXJ05_A3]
[GZXJ26_B1]
[GZXJ27_B2]
[GZXJ28_B3]
[GZXJ29_B4]
[GZXJ30_C1]
[GZXJ33_C4]
[BHX011_LSJ]
[BHX019_LSJ]
[GZXJ04_A2]
[GZXJ06_A4]
[GZXJ31_C2]
[GZXJ32_C3]
[GZXJ36_D1]
[GZXJ37_D2]
[GZXJ38_D3]
=cut
my ($lastChr) = ('');
my @items;
while (<$th>) {
	next if /^#/;
	my ($CHROM, $POS, $ID, $REF, $ALT, $QUAL, $FILTER, $INFO, $FORMAT, @data) = split /\t/;
	++$Stat{'VCF_In'};
	my @groups = split(/\s*;\s*/, $INFO);
	my (%INFO,$name);
	for my $group (@groups) {
		my ($tag,$value) = split /=/,$group;
		my @values = split /,/,$value;
		if (@values == 1) {
			$INFO{$tag}=$values[0];
		} else {
			$INFO{$tag}=\@values;
		}
	}
	my %GT;
	my @FMT = split /:/,$FORMAT;
	for my $s (@Samples) {
		my $dat = shift @data or die "Bam file error.";
		my @dat = split /:/,$dat;
		for my $i (@FMT) {
			$GT{$s}{$i} = shift @dat;
		}
	}
warn "$CHROM, $POS, $ID, $REF, $ALT, $QUAL, $FILTER\n";
ddx \%INFO;
ddx \%GT;
	if ($QUAL<20 or $INFO{'FQ'}<0 or $INFO{'DP'}<6) {
		++$Stat{'VCF_Skipped'};
		next;
	}
	unless ($CHROM eq $lastChr) {
		;
		@items = ();
		$lastChr = $CHROM;
	}
	push @items,[$POS, $REF, $ALT, $QUAL];
}