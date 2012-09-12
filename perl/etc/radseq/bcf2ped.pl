#!/usr/bin/env perl
=pod
Author: Hu Xuesong @ BIOPIC <galaxy001@gmail.com>
Version: 1.0.0 @ 20120720
Purpose: Read bcf, get tped for p-link
Notes: rad2marker is deprecated.
=cut
use strict;
use warnings;
use Data::Dump qw(ddx);
use Galaxy::IO;
use Galaxy::SeqTools;
use Data::Dumper;

die "Usage: $0 <tfam file> <bcgv bcf> <out>\n" if @ARGV<3;
my $tfamfs=shift;
my $bcfs=shift;
my $outfs=shift;

my (%Stat,$t);
open OP,'>',$outfs.'.tped' or die "Error opening $outfs.tped : $!\n";
open OPA,'>',$outfs.'.case.tped' or die $!;
open OPO,'>',$outfs.'.control.tped' or die $!;

open OM,'>',$outfs.'.MinorAllele' or die "Error opening $outfs.MinorAllele : $!\n";
open OD,'>',$outfs.'.dict' or die "Error opening $outfs.dict : $!\n";
if ($tfamfs ne $outfs.'.tfam') {
	open OF,'>',$outfs.'.tfam' or die "Error opening $outfs.tfam : $!\n";
	open OFA,'>',$outfs.'.case.tfam' or die $!;
	open OFO,'>',$outfs.'.control.tfam' or die $!;
} else {die;}
open O,'>',$outfs.'.bcf2pedlog' or die "Error opening $outfs.bcf2pedlog : $!\n";
$t = "# In: [$bcfs], Out: [$outfs]\n";
print O $t;
print $t;

my (%Pheno,@tfamSamples,%tfamDat,%tfamSampleFlag);
open L,'<',$tfamfs or die;
while (<L>) {
	next if /^(#|$)/;
	#print OF $_;
	chomp;
	my ($family,$ind,$P,$M,$sex,$pho) = split /\t/;
	$tfamDat{$ind} = $_."\n";
	if ($ind =~ s/^~//) {
		$tfamSampleFlag{$ind} = 0;
	} elsif ($pho == 1 or $pho == 2) {
		$tfamSampleFlag{$ind} = $pho;
	} else { die; }	# $pho can only be 1 or 2
	push @tfamSamples,$ind;
	$Pheno{$ind} = $pho;	# disease phenotype (1=unaff/ctl, 2=aff/case, 0=miss)
}
for my $ind (@tfamSamples) {
	if ($tfamSampleFlag{$ind} == 0) {
		next;
	} elsif ($tfamSampleFlag{$ind} == 1) {
		print OFO $tfamDat{$ind};
	} elsif ($tfamSampleFlag{$ind} == 2) {
		print OFA $tfamDat{$ind};
	} else { die; }
	print OF $tfamDat{$ind};
}
close L;
close OF;
close OFA;
close OFO;

my $th = openpipe('bcftools view -I',$bcfs);	# -I	skip indels
my (@Samples,@Parents);
while (<$th>) {
	next if /^##/;
	chomp;
	my @data = split /\t/;
	if ($data[0] eq '#CHROM') {
		@Samples = map {
			if (/^(\w+)_all\.bam$/) {
				$_ = $1;
			} else {
				my $t=(split /\//)[-1];$t=~s/_cut//g;$t=~s/-/./g; $_=join('_',(split /\./,$t)[-5,-6]);
			}
		} splice @data,9;
		# ../5.bam_0000210210_merged/d1_4_merged.D4.JHH001.XTU.sort.rmdup.bam
		@Parents = grep(!/^GZXJ/,@Samples);
		last;
	}
}

die "Sample Count in tfam and bcf not match !\n" if @tfamSamples != @Samples;
my @res;
for (my $i = 0; $i < @Samples; $i++) {
	push @res,join(',',$tfamSamples[$i],$tfamSampleFlag{$Samples[$i]});
	die "Samples in tfam and bcf not match !\n" if $tfamSamples[$i] ne $Samples[$i];
}	# http://stackoverflow.com/questions/2591747/how-can-i-compare-arrays-in-perl
print O "# Samples: [",join('],[',@res),"]\t# 1=control, 2=case, 0=drop\n# Parents: [",join('],[',@Parents),"]\n";
warn "Samples: (1=control, 2=case, 0=drop)\n[",join("]\n[",@res),"]\nParents: [",join('],[',@Parents),"]\n";

while (<$th>) {
	next if /^#/;
	chomp;
	my ($CHROM, $POS, $ID, $REF, $ALT, $QUAL, $FILTER, $INFO, $FORMAT, @data) = split /\t/;
	++$Stat{'VCF_In'};	# also as rs#
	my @Bases = split /\s*,\s*/,"$REF, $ALT";
	my @groups = split(/\s*;\s*/, $INFO);
	my (%INFO,$name);
#	if ($groups[0] eq 'INDEL') {
#		$INFO{'Type'} = 'INDEL';
#		shift @groups;
#	} else {
#		$INFO{'Type'} = 'SNP';
#	}
	for my $group (@groups) {
		my ($tag,$value) = split /=/,$group;
#warn "- $group -> $tag,$value\n";
		my @values = split /,/,$value;
		if (@values == 1) {
			$INFO{$tag}=$values[0];
		} else {
			$INFO{$tag}=\@values;
		}
	}
	my (%GT,%GTcnt);
	my @FMT = split /:/,$FORMAT;
	for my $s (@Samples) {
		my $dat = shift @data or die "bcf file error.";
		my @dat = split /:/,$dat;
		for my $i (@FMT) {
			$GT{$s}{$i} = shift @dat;
		}
	}
	my $SPcnt = 0;
	my (%GTitemCnt,$Mut,@plinkGT);
	for (@Samples) {
		if ($GT{$_}{'DP'} > 0 and $GT{$_}{'GQ'} >= 20) {
			my $gt = $GT{$_}{'GT'};
			++$GTcnt{$gt};
			my @GT = split /[\/|]/,$gt;
			++$SPcnt;
			if ($Pheno{$_} == 2) {
				++$GTitemCnt{$_} for @GT;
			}
			$GT{$_}{'GTp'} = join ' ',map($Bases[$_], @GT);
			#$GT{$_}{'O_K'} = 1;
		} else {
			$GT{$_}{'GTp'} = '0 0';
			#$GT{$_}{'O_K'} = 0;
		}
		push @plinkGT,$GT{$_}{'GTp'};
	}
	($Mut) = sort { $GTitemCnt{$b} <=> $GTitemCnt{$a} } keys %GTitemCnt;
	unless (defined $Mut) {
		++$Stat{'VCF_noAffInd_Skipped'};
		next;
	}
	unless ($Mut) {
		++$Stat{'VCF_noMUT_Count'};
		#next;
	}
	#$Mut = $Bases[$Mut];
=pod
++$Stat{'GTcnt'}{$INFO{'FQ'} <=> 0}{scalar(keys %GTcnt)};
ddx $Stat{'GTcnt'};
ddx $CHROM, $POS, $ID, $REF, $ALT, $QUAL, $FILTER, $INFO,\%INFO,\%GT if scalar(keys %GTcnt) > 1 and $INFO{'FQ'} < 0 and $SPcnt>2;
# rad2marker.pl:135: {
#   -1 => { 1 => 2850, 2 => 526, 3 => 37 },
#   1  => { 1 => 8, 2 => 2507, 3 => 1792 },
# }
=cut
#warn "$CHROM, $POS, $ID, $REF, $ALT, $QUAL, $FILTER, $INFO\n";
#ddx $CHROM, $POS, $ID, $REF, $ALT, $QUAL, $FILTER, $INFO,\%GTcnt,\%INFO,\%GT,\%GTitemCnt,$Mut;
	if ($QUAL<20 or $INFO{'FQ'}<=0 or scalar(keys %GTcnt)<2 or $SPcnt<16) {
		++$Stat{'VCF_Skipped'};
		next;
	}
	$Mut = $Bases[$Mut];
	my $SNPid = "r".$Stat{'VCF_In'};
	$CHROM =~ /(\d+)/;
	#print OP join("\t",$1,$SNPid,0,$POS,@plinkGT),"\n";
	print OM join("\t",$SNPid,$Mut),"\n";
	print OD join("\t",${CHROM},${POS},$SNPid),"\n";
	my (@GTall,@GTcase,@GTcontrol);
	for my $i (0 .. $#tfamSamples) {
		my $ind = $tfamSamples[$i];
		if ($tfamSampleFlag{$ind} == 0) {
			next;
		} else {
			push @GTall,$plinkGT[$i];
			if ($tfamSampleFlag{$ind} == 1) {
				push @GTcontrol,$plinkGT[$i];
			} elsif ($tfamSampleFlag{$ind} == 2) {
				push @GTcase,$plinkGT[$i];
			} else { die; }
		}
	}
	print OP join("\t",$1,$SNPid,0,$POS,@GTall),"\n";
	print OPA join("\t",$1,$SNPid,0,$POS,@GTcase),"\n";
	print OPO join("\t",$1,$SNPid,0,$POS,@GTcontrol),"\n";
}
close $th;

close OP;
close OPA;
close OPO;
close OM;
close OD;

print O Dumper(%Stat);
close O;

ddx \%Stat;

print "[Prepare $outfs.phe.] And then:\np-link --tfile $outfs --reference-allele $outfs.MinorAllele --fisher --out ${outfs}P --model --cell 0\n--pheno $outfs.phe --all-pheno [screen log will be saved by p-link itselt]\n";
__END__
grep -hv \# radseq.gt > radseq.tfam

./bcf2bed.pl radseq.tfam radseq.bcgv.bcf radseq 2>&1 | tee radseq.pedlog

grep REC radseq.p.snow.model > radseq.p.snow.model.REC
grep DOM radseq.p.snow.model > radseq.p.snow.model.DOM
sort -nk8 radseq.p.snow.model.REC > radseq.p.snow.model.REC.sortnk8 &
sort -nk8 radseq.p.snow.model.DOM > radseq.p.snow.model.DOM.sortnk8 &
bcftools view -I radseq.bcgv.bcf |grep -v \# |cat -n > radseq.bcgv.bcf.rs &

bcftools view tigers.bcgv.bcf|grep -v \## > tigers.bcgv.vcf &

join -1 3 -2 2 <(sort -k3 radall.dict) <(sort -k2 radallP.model) > tmp &
#sed -n '75,380 p' tmp.s.REC.nk3.scaffold75

cat tmp.s.REC|perl -lane '@a=split /\//,"$F[7]/$F[8]";$sum=$a[0]+$a[1]+$a[2]+$a[3];
$theta=($a[1]+$a[2])/($sum*2);
$p=((1-$theta)**(2*$sum-($a[1]+$a[2])))*($theta**($a[1]+$a[2]))/(0.5**(2*$sum));
$LOD=int(0.5+log($p)*1000/log(10))/1000;
print join("\t",@F,$sum,int(0.5+$theta*100000)/100000,int($LOD),$LOD)' > rec.pa

sort -nk13 -k2 -nk3  rec.pa > rec.pas

grep -P "scaffold75\t" rec.pas > scaffold75.pas
sort -nk3 scaffold75.pas > scaffold75.pas.nk3
perl -lane 'print if $F[10]>16' scaffold75.pas.nk3 > scaffold75.pas.nk3.16

grep -P "scaffold1458\t" rec.pas > scaffold1458.pas
sort -nk3 scaffold1458.pas > scaffold1458.pas.nk3
perl -lane 'print if $F[10]>16' scaffold1458.pas.nk3 > scaffold1458.pas.nk3.16

-------------------

./cat/dojoin.pl radall.dict 3 radallP.model.REC 3 tmp.REC

awk '{print $3" "$1" "$2" "$4" "$6" "$7" "$8" "$9" "$10" "$11}' tmp.REC.out > tmp.REC.out.j

cat tmp.REC.out.j|perl -lane '@a=split /\//,"$F[7]/$F[8]";$sum=$a[0]+$a[1]+$a[2]+$a[3];
$theta=($a[1]+$a[2])/($sum*2);
$p=((1-$theta)**(2*$sum-($a[1]+$a[2])))*($theta**($a[1]+$a[2]))/(0.5**(2*$sum));
$LOD=int(0.5+log($p)*1000/log(10))/1000;
print join("\t",@F,$sum,int(0.5+$theta*100000)/100000,int($LOD),$LOD)' |sort -k2,2 -k3,3n > rec.npa

sort -k13,13n -k2,2 -k3,3n  rec.npa > rec.npas
