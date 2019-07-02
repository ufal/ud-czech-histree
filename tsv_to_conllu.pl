#!/usr/bin/env perl
# Reads a tab-separated-values file (editable in spreadsheet processors, one feature value per column)
# and writes it as a standard CoNLL-U file.
# Copyright © 2019 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

# The first line contains the column headers. Read them but do not write them.
my $headers = <>;
$headers =~ s/\r?\n$//;
# Undo certain name changes that served better editing in Libre Office, e.g., XPolarity <--> Polarity.
my @headers = map {s/XPolarity/Polarity/; $_} (split(/\t/, $headers));
if($headers[0] ne 'COMMENT')
{
    die("Expected COMMENT as the first column");
}
shift(@headers); # We will deal with COMMENT extra.
while(<>)
{
    s/\r?\n$//;
    my @f = split(/\t/, $_);
    # Assume that the first column is always COMMENT.
    my $comment = shift(@f);
    # First column is a sentence-level comment? Ignore the other columns.
    if($f[0] =~ m/^\#/)
    {
        $_ = "$f[0]\n";
        if($comment ne '')
        {
            print STDERR ("WARNING: Non-empty annotator comment on a non-word line.\n");
        }
    }
    # First column is empty? Print the empty line that terminates a sentence.
    elsif($f[0] =~ m/^\s*$/)
    {
        $_ = "\n";
        if($comment ne '')
        {
            print STDERR ("WARNING: Non-empty annotator comment on a non-word line.\n");
        }
    }
    # Assume columns on all other lines.
    else
    {
        # Only check the number of columns here. For other lines it is possible
        # that split omitted the trailing empty columns.
        if(scalar(@f) != scalar(@headers))
        {
            my $e = scalar(@headers);
            my $f = scalar(@f);
            die("Unexpected number of columns. Expected $e, found $f");
        }
        my %col;
        my %feat;
        for(my $i = 0; $i <= $#headers; $i++)
        {
            if($headers[$i] =~ m/^(ID|FORM|LEMMA|UPOS|XPOS|HEAD|DEPREL|DEPS|MISC)$/)
            {
                $col{$headers[$i]} = $f[$i];
            }
            else
            {
                $feat{$headers[$i]} = $f[$i];
            }
        }
        my $fv = join('|', sort {lc($a) cmp lc($b)} (map {"$_=$feat{$_}"} (grep {$feat{$_} ne ''} (keys(%feat)))));
        $col{FEATS} = $fv eq '' ? '_' : $fv;
        if($comment ne '')
        {
            my $c2 = "Comment=$comment";
            if($col{MISC} eq '' || $col{MISC} eq '_')
            {
                $col{MISC} = $c2;
            }
            else
            {
                my @misc = split(/\|/, $col{MISC});
                push(@misc, $c2);
                $col{MISC} = join('|', @misc);
            }
        }
        $_ = join("\t", map {$col{$_}} (qw(ID FORM LEMMA UPOS XPOS FEATS HEAD DEPREL DEPS MISC)))."\n";
    }
    print;
}
# CSV files saved from Libre Office lack the final empty line that is required in CoNLL-U.
print("\n");
