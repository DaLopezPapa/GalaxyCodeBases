#!/usr/bin/env perl
=pod
Author: Hu Xuesong @ BIOPIC <galaxy001@gmail.com>
Version: 1.0.0 @ 20120720
=cut
use strict;
use warnings;
use Vcf;
#use GTF;
use Data::Dump qw(ddx);
use Galaxy::IO::FASTAQ;
use Galaxy::SeqTools qw(translate revcom);

die "Usage: $0 <vcf.gz with tabix indexed> <out> <regions> (eg.: scaffold75:924209-5441687)\n" if @ARGV<2;
my $fafs='/bak/seqdata/2012/tiger/120512_TigerRefGenome/bychr/scaffold75.fa';
my $gtfs = 'scaffold75.gtf';
my $vcfs = shift;
my $outfs = shift;
my $regions = shift;

warn "From [$vcfs][$gtfs][$fafs] to [$outfs]\n";
warn "Regions:[$regions]\n" if $regions;

my $code=<<Ecode;
    AAs  = FFLLSSSSYY**CC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG
  Starts = ---M---------------M---------------M----------------------------
  Base1  = TTTTTTTTTTTTTTTTCCCCCCCCCCCCCCCCAAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGG
  Base2  = TTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGG
  Base3  = TCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAG
Ecode
my @t=split /\n/,$code;
my (%t,%gen_code,%start_codes);
map {s/\s//g;@_=split /=/;$t{$_[0]}=[split //,$_[1]]} @t;
#ddx \%t;
for (@{$t{AAs}}) {
#	my $aa=$_;
#	my @bases;
#	map {my $t=shift @{$t{$_}};push @bases,$t} qw/Base1 Base2 Base3/;
#	my $base=join('',@bases);
	my $base=(shift @{$t{Base1}}).(shift @{$t{Base2}}).(shift @{$t{Base3}});
#print "$base";
	my $start=shift @{$t{Starts}};
	++$start_codes{$base} if $start eq 'M';
	$gen_code{$base}=$_;
#print " -> [$_]\n";
}
#ddx [\@t,\%gen_code,\%start_codes];
print "Codon Table:\n$code\n";

my %GeneDat;
open GTF,'<',$gtfs or dir $!;
while(my $in_line = <GTF>){
	next if ($in_line =~ /^\s*\#/);
	chomp $in_line;
	#remove leading whitespace and get comments
	my $comments = "";	  
	while($in_line =~ /^(.*)\#(.*)$/){
	$in_line = $1;
	$comments = $2.$comments;
	}
	if($in_line =~ /^\s+(.*)$/){
	$in_line = $1;
	}
	my @data = split /\s+/,$in_line;
	#verify line is correct length
	next if ($#data < 8);
	my %feature = map {s/\s*;$//; s/\"//g; $_;} splice @data,8;
#ddx [\@data,\%feature];
	if ($data[2] eq 'transcript') {
		die "[$feature{gene_type}]" if $feature{gene_type} ne 'protein_coding';
		$GeneDat{$data[0]}{$feature{gene_id}}=[$feature{gene_name},$data[6],[],$data[3]];
	} elsif ($data[2] eq 'CDS' or $data[2] eq 'stop_codon') {
		push @{$GeneDat{$data[0]}{$feature{gene_id}}->[2]},[$data[3],$data[4]];
	}
}
close GTF;
for my $chr (keys %GeneDat) {
	for my $id (keys %{$GeneDat{$chr}}) {
		my ($gene,$strand,$cdsA) = @{$GeneDat{$chr}{$id}};
		if ($strand eq '+') {
			$cdsA = [ sort {$a->[0] <=> $b->[0]} @$cdsA ];
		} elsif ($strand eq '-') {
			$cdsA = [ sort {$b->[0] <=> $a->[0]} @$cdsA ];
		} else { die; }
		$GeneDat{$chr}{$id}->[2] = $cdsA;
	}
}
warn "GTF loaded.\n";
ddx \%GeneDat;

my $fafh;
my %RefSeq;
open $fafh,'<',$fafs or die "$!";
my @aux = undef;
my ($name, $comment, $seq, $ret);
my ($n, $len) = (0, 0);
while ( $ret = &readfq($fafh, \@aux) ) {
	($name, $comment, $seq) = @$ret;
	++$n;
	$len = length($seq);
	print "$n: ",join("\t", $name, $comment, $len), "\n";
	$RefSeq{$name} = $seq;
}
close $fafh;

my (%cDNA,%Protein);
open OUTCDNA,'>',"$outfs.cDNA.fa" or die $!;
open OUTPT,'>',"$outfs.protein.fa" or die $!;
for my $chr (sort keys %GeneDat) {
	for my $id (sort { $GeneDat{$chr}{$a}->[3] <=> $GeneDat{$chr}{$b}->[3] } keys %{$GeneDat{$chr}}) {
		my ($gene,$strand,$cdsA,$st) = @{$GeneDat{$chr}{$id}};
		print OUTCDNA ">${gene}_$id $chr:$strand:$st";
		print OUTPT ">${gene}_$id $chr:$strand:$st";
		my ($len,$seq,$tmpseq,$AA)=(0);
		for (@$cdsA) {
			my ($s,$e) = @$_;
			print OUTCDNA ",$s-$e";
			$len += $e-$s+1;
			$tmpseq = substr $RefSeq{$chr},$s-1,$e-$s+1;
			$tmpseq = revcom($tmpseq) if $strand eq '-';
			$seq .= $tmpseq."\n";
		}
		print OUTCDNA " =$len ",int($len*10/3)/10,"\n$seq\n";
		$seq =~ s/\s//g;
		$AA = translate($seq,\%gen_code);
		print OUTPT " $len ",int($len*10/3)/10,"\n$AA\n";
		$cDNA{$id} = $seq;
		$Protein{$id} = $AA;
	}
}
close OUTCDNA;
close OUTPT;

my $vcf = Vcf->new(file=>$vcfs,region=>$regions);
$vcf->parse_header();
my (@samples) = $vcf->get_samples();
ddx \@samples;

while (my $x=$vcf->next_data_hash()) { 
	next if $$x{QUAL} < 20;
	my ($flag,%GTs,$gtREC)=(0);
	for my $gt (keys %GTs) {
		my ($a1,$a2,$a3) = $vcf->split_gt($gt);
		if ($a3 or ($a1 != $a2)) {
			$flag = 1;
		}
	}
	ddx [\%GTs,$x] if $flag;
	#print $vcf->format_line($x);
}
