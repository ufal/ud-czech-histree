#!/usr/bin/env perl
# Reads a CoNLL-U file and writes a similar tab-separated-values file where
# each feature has its own column.
# Copyright © 2019 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

# Define the order of the features.
my @forder = qw(Gender Animacy Number Case PrepCase
VerbForm Aspect Mood Tense Voice Person PronType Poss Reflex Gender[psor] Number[psor]
Variant Degree Polarity
NumType NumForm NumValue
Foreign Abbr Hyph Style Typo
AdpType ConjType NameType);
my %forder;
for(my $i = 0; $i <= $#forder; $i++)
{
    $forder{$forder[$i]} = $i;
}
# Print column headers.
# We do not want the annotator to bother with XPOS. Move it further right out of our way.
print("COMMENT\tID\tFORM\tLEMMA\tUPOS\t".join("\t", @forder)."\tXPOS\tHEAD\tDEPREL\tDEPS\tMISC\n");
# Read CoNLL-U and print the table.
while(<>)
{
    if(m/^\d/)
    {
        my @f = split(/\t/, $_);
        # We do not want the annotator to bother with XPOS. Move it further right out of our way.
        my $xpos = $f[4];
        splice(@f, 4, 1);
        splice(@f, 5, 0, $xpos);
        # Split the FEATS column into individual features.
        my $features = $f[4]; # normally [5] but we have swapped its position with XPOS
        my @flist = map {''} (0..$#forder);
        unless($features eq '_')
        {
            my @fvpairs = split(/\|/, $features);
            my %feat;
            foreach my $fv (@fvpairs)
            {
                my ($f, $v) = split(/=/, $fv);
                # It will be easier for the annotator to navigate the file when
                # the single-value features are labeled by their name rather than 'Yes'.
                if($v eq 'Yes')
                {
                    $feat{$f} = $f;
                }
                else
                {
                    $feat{$f} = $v;
                }
            }
            @flist = map {$feat{$_}} (@forder);
        }
        splice(@f, 4, 1, @flist);
        $_ = join("\t", @f);
    }
    # Insert a cell for the annotator's comments in the beginning of every line.
    $_ = "\t$_";
    print;
}
