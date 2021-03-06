#!/usr/bin/perl 

#1. Filter contaminants
#2. Select families conserved in >10% of birds
##   --print to GFF
#3. Create Heatmaps
#4. Analyse repeated/pseudogene families
#     --"calibrate" with tRNAscan predictions
#     

#split the tRNAs out. 

use warnings;
use strict;
use Getopt::Long;
#use Statistics::Descriptive;


my ($gffsDir, $outDir, $rDir) = ("data/merged-annotations","data/conserved-merged-annotations", "data/R");

my ($verbose, $help);
&GetOptions( 
    "gd|gffDir=s"         => \$gffsDir,
    "od|outDir"           => \$outDir,
    "rd|rDir"             => \$rDir,
    "v|verbose"           => \$verbose,
    "h|help"              => \$help
    );

my @gffs = glob("$gffsDir/*gff"); 

if( $help ) {
    &help();
    exit(1);
}
elsif ((not defined($gffsDir)) or (@gffs)==0){
    print "FATAL: no gff files given\n";
    &help();
    exit(1);
}

my %whitelist; 
if (-s "$rDir/allRNA.dat"){
    open(W, "< $rDir/allRNA.dat");
    while(my $w=<W>){
	chomp($w);
	my @w=split(/\t/, $w);
	my $w=pop(@w);
	$whitelist{$w}=1;
    }
    close(W);
}
my @whiteList=qw(SNORD34
DLEU2_1 DLEU2_2 DLEU2_3 DLEU2_4 DLEU2_5 DLEU2_6 HOXA11-AS1_1 HOXA11-AS1_2 HOXA11-AS1_3 HOXA11-AS1_4 HOXA11-AS1_5 HOXA11-AS1_6 mir-15_1 mir-15_2 mir-15_3 mir-16_1 mir-16_2 mir-16_3 NBR2 PCA3_1 PCA3_2 RMST_1 RMST_10 RMST_2 RMST_3 RMST_4 RMST_5 RMST_6 RMST_7 RMST_8 RMST_9 Six3os1_1 Six3os1_2 Six3os1_3 Six3os1_4 Six3os1_5 Six3os1_6 Six3os1_7 SNORD93 SOX2OT_exon1 SOX2OT_exon2 SOX2OT_exon3 SOX2OT_exon4 ST7-OT3_1 ST7-OT3_2 ST7-OT3_3 ST7-OT3_4
Metazoa_SRP RNase_MRP RNaseP_nuc Telomerase-vert U1 U11 U12 U2 U4 U4atac U5 U6 U6atac Vault
PART1_1 PART1_2 PART1_3
); 

foreach my $wl (@whiteList){
    $whitelist{$wl}=1;
}

#replace with a family2type hash:
my %lncRNAlist;
if (-s "data/rfam11_lncRNAs.txt"){
    open(W, "< data/rfam11_lncRNAs.txt");    
    while(my $w=<W>){
	chomp($w);
	$lncRNAlist{$w}=1;
    }
    close(W);
}

my %rfam2type;
if (-s "data/rfam2type.txt"){
    open(W, "< data/rfam2type.txt");    
    while(my $w=<W>){
	chomp($w);
	$rfam2type{$w}=1;
    }
    close(W);
}


my %blacklist=(
    mraW=>1,    
    );


print "Reading GFFs\n" if (defined($verbose));
my (%HoHspeciesRfamCount, %familiesSpeciesCounts, %familiesTotalCounts, %statistics, @bitscores, %tRNA, %tRNAfamilies); 
foreach my $f (@gffs){

    print "$f\n" if(defined($verbose));
    my $species;
    if ($f=~/$gffsDir\/(\S+?_\S+?)\.gff/){
	$species=$1; 
    }
    else{
	print "WARNING: no species name parsed from [$f], skipping!\n";
	next;
    }
    
    open(GFF, "< $f");
    open(OUT, "> $outDir/$species\.gff");
    while(my $g=<GFF>){
	chomp($g);
	my @g=split(/\t/, $g);
	my $family; 
	if($g[8]=~/rfam-id=(\S+);evalue/ or $g[8]=~/Alias=(\S+);Note/){#Rfam
	    $family=$1;
	    
#push(@bitscores, $g[5]) if (defined($whitelist{$family}) && $g[5]=~/^\d+\.\d+$/); 
	}
	elsif($g[8]=~/ID=(\S+)\_\d+/){#miRBase
	    $family=$1;
	}
	elsif($g[1]=~/MFASTA/){#Stadler snoRNAs
	    $family="$g[8]";
	}
	elsif($g[8]=~/type=Pseudo;/){#tRNAscan
	    $family="tRNA-pseudogene";
	    $tRNA{$species}{"Pseudo"}=0 if(not defined($tRNA{$species}{"Pseudo"}));
	    $tRNA{$species}{"Pseudo"}++;
	    $tRNAfamilies{"Pseudo"}=0 if(not defined($tRNAfamilies{"Pseudo"}));
	    $tRNAfamilies{"Pseudo"}++;
	    #print "$g[8]\n";
	}
	elsif($g[8]=~/type=(\S+?);/){#tRNAscan
	    $family="tRNA";
	    $tRNA{$species}{$1}=0 if(not defined($tRNA{$species}{$1}));
	    $tRNA{$species}{$1}++;
	    $tRNAfamilies{$1}=0 if(not defined($tRNAfamilies{$1}));
	    $tRNAfamilies{$1}++;
	    #print "$g[8]\n";
	}
	else{#WTF?
	    $family=$g[2];
	    #print "$g[2]\n";
	}
	
	print "$species\t$family\n" if defined($verbose);
	if ( not defined($HoHspeciesRfamCount{$species}{$family}) ){
	    $HoHspeciesRfamCount{$species}{$family}=0;
	    $familiesSpeciesCounts{$family}=0 if (not defined($familiesSpeciesCounts{$family}));
	    $familiesSpeciesCounts{$family}++;
	}
	$familiesTotalCounts{$family}=0 if (not defined($familiesTotalCounts{$family}));
	$familiesTotalCounts{$family}++;
	$HoHspeciesRfamCount{$species}{$family}++;
	print OUT "$g\n" if (defined($whitelist{$family}));
    }
    close(GFF);
    close(OUT);
}

#slurp species in phylogenetic order:
my (@speciesPhyloOrder,@speciesCommonPhyloOrder); 
open(SPC, "< data/species_list-phyloOrder.txt");
while(my $s=<SPC>){
    if($s=~/^(\S+)\t(\S+)/){
	push(@speciesPhyloOrder,$1); 
	push(@speciesCommonPhyloOrder,$2); 
    }
}
close(SPC); 

print "Printing R-dat headers\n" if (defined($verbose));
foreach my $ut (("$rDir/snoRNA.dat", "$rDir/miRNA.dat", "$rDir/RNA.dat", "$rDir/allRNA.dat", "$rDir/tRNA.dat", "$rDir/lncRNA.dat")){
    open(UT, "> $ut");
    my $cnt=0;
    foreach my $species (@speciesCommonPhyloOrder){#@speciesPhyloOrder ) {
	print UT "$species\t";
	#print "$species\t$statistics{$speciesPhyloOrder[$cnt]}" if ($ut=~/all/);
	$cnt++;
    }
    print UT "family\n";
    close(UT);
}

my $cnt=0;

print "Sorting family IDs\n" if (defined($verbose));
my @family = sort {
    if($a=~/^mir\-\d+$/ && $b=~/^mir\-\d+$/){
	(my $num_a = $a) =~ s/^mir\-(\d+)$/$1/;
	(my $num_b = $b) =~ s/^mir\-(\d+)$/$1/;
	return $num_a <=> $num_b;
    }
    if($a=~/^mir\-\d+\_\d+$/ && $b=~/^mir\-\d+\_\d+$/){
	(my $num_a = $a) =~ s/^mir\-(\d+)\_\d+$/$1/;
	(my $num_b = $b) =~ s/^mir\-(\d+)\_\d+$/$1/;
	return $num_a <=> $num_b;
    }
    elsif($a=~/^MIR\d+$/ && $b=~/^MIR\d+$/){
	(my $num_a = $a) =~ s/^MIR(\d+)$/$1/;
	(my $num_b = $b) =~ s/^MIR(\d+)$/$1/;
	return $num_a <=> $num_b;
    }
    elsif($a=~/^MIR\d+\_\d+$/ && $b=~/^MIR\d+\_\d+$/){
	(my $num_a = $a) =~ s/^MIR(\d+)\_\d+/$1/;
	(my $num_b = $b) =~ s/^MIR(\d+)\_\d+/$1/;
	return $num_a <=> $num_b;
    }
    elsif($a=~/^SNORA\d+$/ && $b=~/^SNORA\d+$/){
	(my $num_a = $a) =~ s/^SNORA(\d+)$/$1/;
	(my $num_b = $b) =~ s/^SNORA(\d+)$/$1/;
	return $num_a <=> $num_b;
    }
    elsif($a=~/^SNORD\d+$/ && $b=~/^SNORD\d+$/){
	(my $num_a = $a) =~ s/^SNORD(\d+)$/$1/;
	(my $num_b = $b) =~ s/^SNORD(\d+)$/$1/;
	return $num_a <=> $num_b;
    }
    elsif($a=~/^SCARNA\d+$/ && $b=~/^SCARNA\d+$/){
    	(my $num_a = $a) =~ s/^SCARNA(\d+)$/$1/;
    	(my $num_b = $b) =~ s/^SCARNA(\d+)$/$1/;
    	return $num_a <=> $num_b;
    }
    elsif($a=~/^snoZ\d+$/ && $b=~/^snoZ\d+$/){
    	(my $num_a = $a) =~ s/^snoZ(\d+)$/$1/;
    	(my $num_b = $b) =~ s/^snoZ(\d+)$/$1/;
    	return $num_a <=> $num_b;
    }
    elsif($a=~/^snoU\d+$/ && $b=~/^snoU\d+$/){
    	(my $num_a = $a) =~ s/^snoU(\d+)$/$1/;
    	(my $num_b = $b) =~ s/^snoU(\d+)$/$1/;
    	return $num_a <=> $num_b;
    }
    elsif($a=~/^U\d+/ && $b=~/^U\d+/){
    	(my $num_a = $a) =~ s/^U(\d+)\w*/$1/;
    	(my $num_b = $b) =~ s/^U(\d+)\w*/$1/;
    	return $num_a <=> $num_b;
    }
    else { 
	return lc($a) cmp lc($b); 
    } 
} (keys %familiesTotalCounts);  #{ $HoHspeciesRfamCount{$speciesPhyloOrder[0]} } );

my @tRNAfamily = sort {
    lc($a) cmp lc($b); 
}(keys %tRNAfamilies);

print "Printing R-dat files\n" if (defined($verbose));
my %exceptions = (SNORD34 => 1);
foreach my $family ( @family ) {
    
    #print "$family\n";# if ($family=~/Pseudo/i);
    
    #Family must be found in >10% of all species
    #printf "$family: $familiesSpeciesCounts{$family}/%d %0.2f\n", scalar(@speciesPhyloOrder), $familiesSpeciesCounts{$family}/scalar(@family) if($family=~/RNase_MRP/);
    next if( ($familiesSpeciesCounts{$family}/scalar(@speciesPhyloOrder)) < 0.1 and not defined($whitelist{$family}));
    next if(defined($blacklist{$family}));
    open(AL, ">> $rDir/allRNA.dat");
    if ($family=~/^sno/i or $family=~/^SCA/ or $family=~/^ACA/){
	next if( (($familiesSpeciesCounts{$family}/scalar(@speciesPhyloOrder)) < 0.10 or $familiesTotalCounts{$family}<5) and not defined($exceptions{$family}) );
	open(UT, ">> $rDir/snoRNA.dat");
    }
    elsif ($family=~/^mir/i or $family=~/^let-7/ or $family=~/^lin-4/ ){
	next if( ($familiesSpeciesCounts{$family}/scalar(@speciesPhyloOrder)) < 0.10 or $familiesTotalCounts{$family}<5);
	open(UT, ">> $rDir/miRNA.dat");
    }
    elsif(defined($lncRNAlist{$family})){
	open(UT, ">> $rDir/lncRNA.dat");
    }
    else{
	open(UT, ">> $rDir/RNA.dat");
    }
    
    foreach my $species ( @speciesPhyloOrder ) {
	if(defined($HoHspeciesRfamCount{$species}{$family})){
	    print UT "$HoHspeciesRfamCount{$species}{$family}\t";
	    print AL "$HoHspeciesRfamCount{$species}{$family}\t";
	}
	else {
	    print UT "0\t";
	    print AL "0\t";
	}
    }
    print UT "$family\n";
    print AL "$family\n";
    close(UT);
    close(AL);
    $cnt++;
}

print "Printing tRNA R-dat files\n" if (defined($verbose));
open(TR, ">> $rDir/tRNA.dat");
foreach my $family ( @tRNAfamily ) {
    foreach my $species ( @speciesPhyloOrder ) {

	if(defined($tRNA{$species}{$family})){
	    print TR "$tRNA{$species}{$family}\t";
	}
	else {
	    print TR "0\t";
	}
    }
    print TR "$family\n";
}
close(TR);

print "System calls: creating [$rDir/snoRNA-human-yeast-correspondences.dat] & running R script\n" if (defined($verbose));

#egrep '^snoR38;|SNORA13;|SNORA16;|SNORA2;|SNORA21;|SNORA26;|SNORA27;|SNORA28;|SNORA3;|SNORA36;|SNORA4;|SNORA44;|SNORA48;|SNORA5;|SNORA50;|SNORA52;|SNORA56;|SNORA58;|SNORA62;|SNORA64;|SNORA65;|SNORA66;|SNORA69;|SNORA7;|SNORA74;|SNORA76;|SNORA8;|SNORA9;|SNORD12;|SNORD14;|SNORD15;|SNORD16;|SNORD17;|SNORD18;|SNORD2;|SNORD24;|SNORD27;|SNORD29;|SNORD31;|SNORD33;|SNORD34;|SNORD35;|SNORD36;|SNORD38;|SNORD41;|SNORD43;|SNORD46;|SNORD51;|SNORD52;|SNORD57;|SNORD59;|SNORD60;|SNORD62;|SNORD65;|SNORD74;|SNORD77;|SNORD88;|SNORND104;|snosnR60_Z15' clans_competed/*gff | perl -lane 'if(/\/(\S+?)\-.*gff:(\S+).*\-id=(\S+);eval/ or /\/(\S+?)\-.*gff:(\S+).*Alias=(\S+);Not/){print "$1\t$2\t$3\t$F[6]"}'
#GAS5 snoRNAs: \|SNORD81\$\|SNORD47\$\|SNORD80\$\|SNORD79\$\|SNORD78\$\|SNORD44\$\|SNORD77\$\|SNORD76\$\|SNORD75\$\|SNORD74\$
#DAMN THIS IS NASTY!
system("egrep \47^human\|snoR38\$\|SNORA13\$\|SNORA16\$\|SNORA2\$\|SNORA21\$\|SNORA26\$\|SNORA27\$\|SNORA28\$\|SNORA3\$\|SNORA36\$\|SNORA4\$\|SNORA44\$\|SNORA48\$\|SNORA5\$\|SNORA50\$\|SNORA52\$\|SNORA56\$\|SNORA58\$\|SNORA62\$\|SNORA64\$\|SNORA65\$\|SNORA66\$\|SNORA69\$\|SNORA7\$\|SNORA74\$\|SNORA76\$\|SNORA8\$\|SNORA9\$\|SNORD12\$\|SNORD14\$\|SNORD15\$\|SNORD16\$\|SNORD17\$\|SNORD18\$\|SNORD2\$\|SNORD24\$\|SNORD27\$\|SNORD29\$\|SNORD31\$\|SNORD33\$\|SNORD34\$\|SNORD35\$\|SNORD36\$\|SNORD38\$\|SNORD41\$\|SNORD43\$\|SNORD46\$\|SNORD51\$\|SNORD52\$\|SNORD57\$\|SNORD59\$\|SNORD60\$\|SNORD62\$\|SNORD65\$\|SNORD74\$\|SNORD77\$\|SNORD88\$\|SNORND104\$\|snosnR60_Z15\$\47 $rDir/snoRNA.dat > $rDir/snoRNA-human-yeast-correspondences.dat");

my @divFams = qw(
5_8S_rRNA 5S_rRNA 7SK let−7
Metazoa_SRP RNase_MRP RNaseP_nuc Telomerase-vert U1 U2 U4 U5 U6 U11 U12 U4atac U6atac Vault Y_RNA
tRNA-pseudogene tRNA);
system("head -n 1 $rDir/allRNA.dat | perl -lane \47" .  's/_\d+X\t/\t/g; print' . "\47 > $rDir/diverged.dat");
foreach my $fm7 ( @divFams ){
    system("egrep \47$fm7\$\47 $rDir/allRNA.dat >> $rDir/diverged.dat");
}
system("egrep \47SeC\47 $rDir/tRNA.dat >> $rDir/diverged.dat");

#DLEU2_1 DLEU2_2 DLEU2_3 DLEU2_4 
#RMST_1 RMST_2 RMST_3 RMST_4 RMST_5  RMST_10 
#Six3os1_1 Six3os1_2 Six3os1_3 Six3os1_4 
#ST7-OT3_1  ST7-OT3_3 ST7-OT3_4
my @unConFams = qw(DLEU2_5 DLEU2_6 HOXA11-AS1_1 HOXA11-AS1_2 HOXA11-AS1_3 HOXA11-AS1_4 HOXA11-AS1_5 HOXA11-AS1_6 mir-15 mir-16 NBR2 PART1_1 PART1_2 PART1_3 PCA3_1 PCA3_2 RMST_6 RMST_7 RMST_8 RMST_9 Six3os1_5 Six3os1_6 Six3os1_7 SNORD93 SOX2OT_exon1 SOX2OT_exon2 SOX2OT_exon3 SOX2OT_exon4 ST7-OT3_2);
system("head -n 1 $rDir/allRNA.dat | perl -lane \47" .  's/_\d+X\t/\t/g; print' . "\47 > $rDir/unusual-conserved.dat");
foreach my $fm8 (@unConFams){
    system("egrep \47$fm8\$\47 $rDir/allRNA.dat >> $rDir/unusual-conserved.dat");
}

#grep human data/R/allRNA.dat && cat blah* | cut -f 1 | sort -d | uniq -c | sort -nr | nl | head -n 31 | awk '{print $3}' | sort -d | perl -lane 'print "grep $_\$ data/R/allRNA.dat"' | sh
my @hiCopyFams = qw(5S_rRNA 7SK Histone3 let-7 Metazoa_SRP mir-130 mir-133 mir-135 mir-146 mir-15 mir-16 mir-181 mir-19 mir-196 mir-204 mir-2985 mir-30 mir-302 mir-34 mir-449 mir-9 RSV_RNA tRNA U1 U4 U5 U6 U6atac U7 uc_338 Y_RNA);
system("head -n 1 $rDir/allRNA.dat | perl -lane \47" .  's/_\d+X\t/\t/g; print' . "\47 > $rDir/high-copy-numbers.dat");
foreach my $fm9 (@unConFams){
    system("egrep \47$fm9\$\47 $rDir/allRNA.dat >> $rDir/high-copy-numbers.dat");
}

system("grep \47Alias=U6;Note\47 $outDir/Homo_sapiens.gff | cut -f 6 | sort -nr > $rDir/U6-human-bitscores.dat");
system("grep \47Alias=U6;Note\47 $outDir/Gallus_gallus.gff | cut -f 6 | sort -nr > $rDir/U6-chicken-bitscores.dat");
system("grep \47Alias=Metazoa_SRP;Note\47 $outDir/Homo_sapiens.gff | cut -f 6 | sort -nr > $rDir/SRP-human-bitscores.dat");
system("grep \47Alias=Metazoa_SRP;Note\47 $outDir/Gallus_gallus.gff | cut -f 6 | sort -nr > $rDir/SRP-chicken-bitscores.dat");
system("grep \47Alias=Y_RNA;Note\47 $outDir/Homo_sapiens.gff | cut -f 6 | sort -nr > $rDir/Y_RNA-human-bitscores.dat");
system("grep \47Alias=Y_RNA;Note\47 $outDir/Gallus_gallus.gff | cut -f 6 | sort -nr > $rDir/Y_RNA-chicken-bitscores.dat");



system("R CMD BATCH --no-save scripts/heatmaps.R");

print "Finished!\n" if (defined($verbose));

exit(0);

######################################################################
sub sortFamilies {
    #my ($a,$b)=@_;
    if($a=~/^mir\-\d+/ && $b=~/^mir\-\d+/){
	(my $num_a = $a) =~ s/^mir\-(\d+)/$1/;
	(my $num_b = $b) =~ s/^mir\-(\d+)/$1/;
	return $num_a <=> $num_b;
    }
    elsif($a=~/^SNORA\d+/ && $b=~/^SNORA\d+/){
	(my $num_a = $a) =~ s/^SNORA(\d+)/$1/;
	(my $num_b = $b) =~ s/^SNORA(\d+)/$1/;
	return $num_a <=> $num_b;
    }
    elsif($a=~/^SNORD\d+/ && $b=~/^SNORD\d+/){
	(my $num_a = $a) =~ s/^SNORD(\d+)/$1/;
	(my $num_b = $b) =~ s/^SNORD(\d+)/$1/;
	return $num_a <=> $num_b;
    }
    elsif(/^SCARNA\d+/){
    	(my $num_a = $a) =~ s/^SCARNA(\d+)/$1/;
    	(my $num_b = $b) =~ s/^SCARNA(\d+)/$1/;
    	return $num_a <=> $num_b;
    }
    elsif(/^SNORD\d+/){
    	(my $num_a = $a) =~ s/^SNORD(\d+)/$1/;
    	(my $num_b = $b) =~ s/^SNORD(\d+)/$1/;
    	return $num_a <=> $num_b;
    }
    elsif(/^snoZ\d+/){
    	(my $num_a = $a) =~ s/^snoZ(\d+)/$1/;
    	(my $num_b = $b) =~ s/^snoZ(\d+)/$1/;
    	return $num_a <=> $num_b;
    }
    elsif(/^snoU\d+/){
    	(my $num_a = $a) =~ s/^snoU(\d+)/$1/;
    	(my $num_b = $b) =~ s/^snoU(\d+)/$1/;
    	return $num_a <=> $num_b;
    }
    elsif(/^U\d+/){
    	(my $num_a = $a) =~ s/^U(\d+)/$1/;
    	(my $num_b = $b) =~ s/^U(\d+)/$1/;
    	return $num_a <=> $num_b;
    }
    else {
    	return lc $a cmp lc $b;
    }
}


######################################################################
sub help {
    print STDERR <<EOF;

gffs2heatmaps.pl: 1. Select families conserved in >10% of birds
                   --print to GFF & to R "dat" files
                  2. Create Heatmaps with R-scripts

Usage:   gffs2heatmaps.pl 
Options:       -h|--help                     Show this help.
               -v|--verbose                  Print lots of stuff.

               -gd|--gffDir <dir>            Directory contain gffs of ncRNA annotation [default:data/merged-annotations]
               -od|--outDir <dir>            Output directory, print gffs of conserved ncRNAs there [default:data/conserved-merged-annotations]
	       -rd|--rDir   <dir>            Output directory, print R-data files there [default:data/R]
	       
EOF
}
