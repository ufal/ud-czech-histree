#!/usr/bin/env perl
# Compares two CoNLL-U files with same underlying raw text but potentially different tokenization, sentence segmentation, and morphology.
###!!! Nestačilo by použít evaluační skript ze shared tasku CoNLL 2018? Ovšem problém nastane, až budu chtít spočítat třeba Cohenovo kappa.
# Copyright © 2019 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use Getopt::Long;

my %konfig;
GetOptions
(
    'lastsid=s' => \$konfig{lastsid} # ignore sentence ids after this id
);

my $a1 = shift(@ARGV);
my $a2 = shift(@ARGV);
if(!defined($a1) || !defined($a2))
{
    die("Expected two arguments: CoNLL-U files by two annotators");
}
my $doc1 = read_file($a1);
my $doc2 = read_file($a2);
# Identify sentence ids that only appear in one of the files.
my %in1not2;
my %in2not1;
# Compare sentences that have the same id.
my @sequence1 = @{$doc1->{'__SEQ__'}};
foreach my $sid (@sequence1)
{
    if(exists($doc2->{$sid}))
    {
        compare_sentences($sid, $doc1->{$sid}, $doc2->{$sid});
    }
}
print("$stats{comparedwords} compared words.\n");
printf("$stats{badlemma} unmatched lemmas. Agreement %d%%.\n", 100-$stats{badlemma}/$stats{comparedwords}*100+0.5);
printf("$stats{badupos} unmatched UPOS tags. Agreement %d%%.\n", 100-$stats{badupos}/$stats{comparedwords}*100+0.5);
printf("$stats{badfeats} unmatched feature sets. Agreement %d%%.\n", 100-$stats{badfeats}/$stats{comparedwords}*100+0.5);
# Identify extra sentences in either file.
foreach my $sid (keys(%{$doc1}))
{
    if(!exists($doc2->{$sid}))
    {
        $in1not2{$sid}++;
    }
}
foreach my $sid (keys(%{$doc2}))
{
    if(!exists($doc1->{$sid}))
    {
        $in2not1{$sid}++;
    }
}
my $n12 = scalar(keys(%in1not2));
my $n21 = scalar(keys(%in2not1));
print("$n12 sentence ids from first file not found in second file.\n") if($n12);
print("$n21 sentence ids from second file not found in first file.\n") if($n21);



#------------------------------------------------------------------------------
# Reads all sentences from a file.
#------------------------------------------------------------------------------
sub read_file
{
    my $filename = shift;
    my %doc;
    my @sequence;
    open(FILE, $filename) or die("Cannot read $filename: $!");
    while(1)
    {
        my $s = read_sentence(FILE);
        last if(scalar(@{$s})==0);
        my $sid = get_sentence_id($s);
        push(@sequence, $sid);
        $doc{$sid} = $s;
        last if(defined($konfig{lastsid}) && $sid eq $konfig{lastsid});
    }
    close(FILE);
    $doc{'__SEQ__'} = \@sequence;
    return \%doc;
}



#------------------------------------------------------------------------------
# Reads a sentence from an open file. If we are at the end of the file, returns
# an empty array.
#------------------------------------------------------------------------------
sub read_sentence
{
    my $fh = shift; # file handle
    my @sentence;
    while(<$fh>)
    {
        s/\r?\n$//;
        push(@sentence, $_);
        last if(m/^\s*$/);
    }
    return \@sentence;
}



#------------------------------------------------------------------------------
# Returns the id of a sentence.
#------------------------------------------------------------------------------
sub get_sentence_id
{
    my $sentence = shift;
    my @sentence = @{$sentence};
    my $sid;
    my @sidlines = grep {m/^\#\s*sent_id\s*=\s*\S+/} (@sentence);
    if(scalar(@sidlines) > 0)
    {
        $sidlines[0] =~ m/^\#\s*sent_id\s*=\s*(\S+)/;
        $sid = $1;
    }
    return $sid;
}



#------------------------------------------------------------------------------
# Compares two sentences with the same id.
#------------------------------------------------------------------------------
sub compare_sentences
{
    my $sid = shift;
    my $s1 = shift;
    my $s2 = shift;
    my @s1 = grep {m/^\d+\t/} (@{$s1});
    my @s2 = grep {m/^\d+\t/} (@{$s2});
    my $n1 = scalar(@s1);
    my $n2 = scalar(@s2);
    if($n1 != $n2)
    {
        print("Unmatched number of words in sentence '$sid': $n1 vs. $n2\n");
    }
    else
    {
        for(my $i = 0; $i < $n1; $i++)
        {
            $stats{comparedwords}++;
            my @f1 = split(/\t/, $s1[$i]);
            my @f2 = split(/\t/, $s2[$i]);
            # Compare lemmas.
            if($f1[2] ne $f2[2])
            {
                print("Unmatched lemma of '$f1[1]' ($sid/$f1[0]): '$f1[2]' vs. '$f2[2]'\n");
                $stats{badlemma}++;
            }
            # Compare UPOS tags.
            if($f1[3] ne $f2[3])
            {
                print("Unmatched UPOS of '$f1[1]' ($sid/$f1[0]): '$f1[3]' vs. '$f2[3]'\n");
                $stats{badupos}++;
            }
            # Compare features.
            if($f1[5] ne $f2[5])
            {
                # Only print features that differ.
                my @feats1 = split(/\|/, $f1[5]);
                my @feats2 = split(/\|/, $f2[5]);
                my %feats1; map {$feats1{$_}++} (@feats1);
                my %feats2; map {$feats2{$_}++} (@feats2);
                @feats1 = grep {!exists($feats2{$_})} (@feats1);
                @feats2 = grep {!exists($feats1{$_})} (@feats2);
                my $feats1 = join('|', @feats1);
                my $feats2 = join('|', @feats2);
                print("Unmatched features of '$f1[1]' ($sid/$f1[0]): '$feats1' vs. '$feats2'\n");
                $stats{badfeats}++;
            }
        }
    }
}
