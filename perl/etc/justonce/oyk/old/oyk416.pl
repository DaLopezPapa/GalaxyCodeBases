#!/usr/bin/env perl
=pod
Author: Hu Xuesong @ BGI <huxuesong@genomics.org.cn>
Version: 1.0.0 @ 20180516
=cut
use strict;
use warnings;

use lib '.';

use Data::Dump qw(ddx);
use Text::NSP::Measures::2D::Fisher::twotailed;
use FGI::GetCPI;
#use Math::BigFloat;

our @Bases;
sub deBayes($) {
	my $p = $_[0];
	my %Dep;
	for my $i (1 .. $#$p) {
		$Dep{$i-1} = $p->[$i];
	}
	#ddx %Dep;
	my @dKeys = sort { $Dep{$b} <=> $Dep{$a} } keys %Dep;
	if ( @dKeys>1 and $Dep{$dKeys[1]} >= $Dep{$dKeys[0]} * 0.02) {	# 2%
		my @rKeys = sort {$a<=>$b} @dKeys[0,1];
		my $gt = join('/',$Bases[$rKeys[0]],$Bases[$rKeys[1]]);
		$p->[0] = $gt;
	} elsif (@dKeys>1 && ($Dep{$dKeys[1]} < $Dep{$dKeys[0]} * 0.02) && ($Dep{$dKeys[1]} > $Dep{$dKeys[0]} * 0.001)){
		$p->[0] = "NA";
	} elsif (@dKeys == 1 or ($Dep{$dKeys[1]} <= $Dep{$dKeys[0]} * 0.001)){
		my $gt = join('/',$Bases[$dKeys[0]],$Bases[$dKeys[0]]);
		$p->[0] = $gt;
	}
}
sub deBayes2($) {
	my $p = $_[0];
	my %Dep;
	for my $i (1 .. $#$p) {
		$Dep{$i-1} = $p->[$i];
	}
	#ddx %Dep;
	my @dKeys = sort { $Dep{$b} <=> $Dep{$a} } keys %Dep;
	if ( @dKeys>1 and $Dep{$dKeys[1]}  >= $Dep{$dKeys[0]} * 0.1 ) {	# 10%
		my @rKeys = sort {$a<=>$b} @dKeys[0,1];
		my $gt = join('/',$Bases[$rKeys[0]],$Bases[$rKeys[1]]);
		$p->[0] = $gt;
	}elsif (@dKeys>1 && ($Dep{$dKeys[1]}  > $Dep{$dKeys[0]} * 0.01) && ($Dep{$dKeys[1]}  < $Dep{$dKeys[0]} * 0.1)){
		$p->[0] = "NA";
	}
}

sub getBolsheviks(@) {
	my $type = shift;
	my @dat = map { [split /[;,]/,$_] } @_;
	if ($type) {
		deBayes($_) for @dat;
	} else {
		deBayes2($_) for @dat;
	}
	#ddx \@dat;

	my (%GT);
	for (@dat) {
		++$GT{$_->[0]};
	}
	if (defined $GT{NA}){
		return ["NA",0,"NA"];
	}
	my $Bolsheviks = (sort {$GT{$b} <=> $GT{$a}} keys %GT)[0];
	my @GTdep;
	for (@dat) {
		next if $_->[0] ne $Bolsheviks;
		for my $i (1 .. $#$_) {
			$GTdep[$i-1] += $_->[$i];
		}
	}
	my @GTs = split /[\/|]/,$Bolsheviks;
	my $Hom = 0;
	$Hom = 1 if $GTs[0] eq $GTs[1];
	#ddx $Bolsheviks,$Hom,\@GTdep,@dat if (keys %GT)>1;
	return [$Bolsheviks,$Hom,\@GTdep];
}

sub getequal(@) {
	my $type = shift;
	my @dat = map { [split /[;,]/,$_] } @_;
#ddx \@dat;
	if ($type) {
		deBayes($_) for @dat;
	} else {
		deBayes2($_) for @dat;
	}
	my (%GT);
	for (@dat) {
		++$GT{$_->[0]};
	}
	for (values %GT) {
		return 1 if $_ == 2;	# 两个样品GT一致
	}
	return 0;
}

my $mother=shift;
my $father=shift;
my $child=shift;
open FM,'<',$mother or die "[x]Mom: $!\n";
open FF,'<',$father or die "[x]Dad: $!\n";
open FC,'<',$child or die "[x]Child: $!\n";

my ($logcpi,$spe,$lFC,$lFF,$lFM)=(0,0);
print "# Order: M,F,C\n";

while (<FM>) {
	chomp;
	chomp($lFC = <FC>);
	chomp($lFF = <FF>);
	my @datM = split /\t/;
	my @datF = split /\t/,$lFF;
	my @datC = split /\t/,$lFC;
	#my ($chr,undef,$bases,$qual,@data) = split /\t/;
	next if $datM[3] < 100;
	next if $datF[3] < 100;
	next if $datC[3] < 100;
	die if $datM[0] ne $datC[0];
	my @tM = splice @datM,4;
	my @tF = splice @datF,4;
	my @tC = splice @datC,4;
	@Bases = split /,/,$datM[2];
	next if $Bases[1] eq '.';
	next if "@tM @tF @tC" =~ /\./;

	my $check_dep = 1;
	for (@tM){
		my @info = split /[;,]/,$_;
		my $sum;
		for my $i(1..scalar @info - 1){
			$sum += $info[$i];
		}
		if ($sum > 50){
			$check_dep *= 1;
		}else{
			$check_dep *= 0;
		}
	}
	for (@tF){
		my @info = split /[;,]/,$_;
		my $sum;
		for my $i(1..scalar @info - 1){
			$sum += $info[$i];
		}
		if ($sum > 50){
			$check_dep *= 1;
		}else{
			$check_dep *= 0;
		}
	}
	next if ($check_dep == 0);

	#T/T;6,2245      C/C;1698,0
	#print "> @tM , @tF , @tC\n@datM\n";
	my $retM = getBolsheviks(0,@tM);
	next unless $retM->[1];
	my $retF = getBolsheviks(0,@tF);
	next if ($retM->[0] eq "NA" or $retF->[0] eq "NA");
	#ddx $retM,$retF;
	my $xx = getequal(0,@tM);
	my $yy = getequal(0,@tF);
	my $zz = getequal(1,@tC);
	my $t=$xx*$yy*$zz;
	next unless $t;
	my @sdatC = map { [split /[;,]/,$_] } @tC;
	my @GTdepC;
	for (@sdatC) {
		for my $i (1 .. $#$_) {
			$GTdepC[$i-1] += $_->[$i];
		}
	}
	my %CntM;
	my @GTM = @{$retM->[2]};
	for my $i (0 .. $#GTM) {
		$CntM{$i} = $GTM[$i];
	}
	my ($x,$y) = sort { $CntM{$b} <=> $CntM{$a} } keys %CntM;
	#ddx [$x,$y,$Bases[$x],$Bases[$y]],\@sdatC,\@GTdepC;
	my ($n12,$n22);
	my $n11 = $retM->[2]->[$x];
	my $n21 = $GTdepC[$x];
	if (defined $y) {
		$n12 = $retM->[2]->[$y];
		$n22 = $GTdepC[$y];
	} else {
		$n12 = 0;
		$n22 = 0;
	}
	next unless defined $n22;
	next if ($n21+$n22) < 200;	# skip 500
	my $GTtC;
	my $twotailedFisher = -1;
	$GTtC = join('/',$Bases[$x],$Bases[$x]);
	my $Cdep = $n21 + $n22;
	#if ($n22 * 199 < $n21) {	# <0.5% = 1:200
#	if ($n22/$Cdep < 0.02 and $n22/$Cdep > 0.001) {	# 0.1% < minnor < 2%, skip ; depth<10
#		next;	# skip
#	} elsif ($n22/$Cdep <= 0.001) {
#		1;
#	} else {
#		my $n1p = $n11 + $n12;
#		my $np1 = $n11 + $n21;
#		my $npp = $n1p + $n21 + $n22;
#		$twotailedFisher = calculateStatistic(
#			n11 => $n11,
#			n1p => $n1p,
#			np1 => $np1,
#			npp => $npp,
#		);
#		if( (my $errorCode = getErrorCode()) ) {
#			die $errorCode, " - ", getErrorMessage();
#		} else {
#			my ($m,$n) = sort {$a<=>$b} ($x,$y);
#			$GTtC = join('/',$Bases[$m],$Bases[$n]);# if $twotailedFisher < 0.05 or $n22 * 49 >= $n21;	# (f0.05 and 0.5%~2%) or >2%
#		}
#	}
	my $retC = getBolsheviks(1,@tC);
	next if ($retC->[0] eq "NA");
	my @fgeno=split /\//,$retF->[0];
	my @mgeno=split /\//,$retM->[0];
	my @cgeno=split /\//,$retC->[0];
	#next if $fgeno[0] eq $fgeno[1] && ($fgeno[0] eq $mgeno[0] or $fgeno[0] eq $mgeno[1]);
	next if $mgeno[0] eq $mgeno[1] && $cgeno[0] eq $cgeno[1] && $mgeno[0] eq $cgeno[0];

	my @mnum=@{$retM->[2]};
	my @fnum=@{$retF->[2]};	
	my $resM = join(';',$retM->[0],join(',',@{$retM->[2]}));
	my $resF = join(';',$retF->[0],join(',',@{$retF->[2]}));
	my $resC = join(';',$retC->[0],join(',',@{$retC->[2]}));
#	my $resC = join(';',$GTtC,join(',',@GTdepC),$twotailedFisher,
#						$retC->[0],join(',',@{$retC->[2]})
#					);
	my $cret = getcpi(@datM,$resM,$resF,$resC);
	#ddx $cret;
	$logcpi += log($cret->[0]);
	$spe += log(1-$cret->[1]);
	print join("\t",@datM,$resM,$resF,$resC,@$cret,$logcpi/log(10),$spe/log(10)),"\n";
}

close FM; close FF; close FC;

print "# CPI: ",exp($logcpi),"\n";
print "# CPE: 1-1E(",$spe/log(10),")\n";

__END__

Order M,F,C

Canceled:
+放弃贝叶斯结果，2.5%以上就是杂合。双亲只保留多数结果。
x子代单个样品深度<1000的，整行扔掉。
x子代，both >0.5% and chi^2<0.05，才算杂合。

All the words below is provided by the client, original text:

1. 先读母亲和儿子的文件，只选map质量大于100，并且母亲是醇和snp的位点
我:
我:
2， 如果是多次测序，少数服从多数，并吧多数的加起来。把三个人的genotype定住
3. 确定基因型：（计算母亲与儿子snp的差异的卡方的pvalue，要求孩子的alt rate大于0.5%，并且卡方pvalue<0.05,则取与母亲不同的genotype，否则，取和母亲一致的genotype）

4，计算CPI
注意事项;1,母亲的genotype只用纯和的（以vcf结果为准），2，孩子的深度必须大于1000X
结果： snp位点  孩子genotype(合起来的#ref/合起来的#alt) 母亲genotype 父亲genotype
