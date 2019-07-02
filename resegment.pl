#!/usr/bin/env perl
# Reads a CoNLL-U file, resegments sentences according to MISC comments, and
# writes the result to STDOUT.
# Copyright © 2019 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my @sentence;
while(<>)
{
    push(@sentence, $_);
    if(m/^\s*$/)
    {
        process_sentence(@sentence) unless(scalar(@sentence)==0);
        @sentence = ();
    }
}
process_sentence(@sentence) unless(scalar(@sentence)==0);



sub process_sentence
{
    my @sentence = @_;
    my @splits; # indices of lines where the sentence shall be split
    my $join_with_prev = 0; # should we merge the sentence with the previous one?
    my $nlines = scalar(@sentence);
    for(my $i = 0; $i < $nlines; $i++)
    {
        if($sentence[$i] =~ m/^\d/)
        {
            $sentence[$i] =~ s/\r?\n$//;
            my @f = split(/\t/, $sentence[$i]);
            my @misc;
            unless($f[9] eq '_')
            {
                @misc = split(/\|/, $f[9]);
            }
            my @comments = grep {m/^Comment=/} (@misc);
            foreach my $comment (@comments)
            {
                if($comment eq 'Comment=newsent')
                {
                    push(@splits, $i);
                }
                elsif($comment eq 'Comment=joinsent')
                {
                    $join_with_prev = 1;
                }
                else # Comment=splitword ! “ ... to ještě budu muset nějak vyřešit!
                {
                    print STDERR ("WARNING: Unprocessed comment '$comment'\n");
                }
            }
            my @misc = grep {!m/^Comment=/} (@misc);
            $f[9] = scalar(@misc)==0 ? '_' : join('|', @misc);
            $sentence[$i] = join("\t", @f)."\n";
        }
    }
    # Perform all splits in reverse order (so that the line indices stay valid until we use them).
    my @sentences = (\@sentence);
    for(my $i = $#splits; $i >= 0; $i--)
    {
        my $s0 = shift(@sentences);
        my ($s1, $s2) = split_sentence($splits[$i], $s0);
        unshift(@sentences, $s2);
        unshift(@sentences, $s1);
    }
    foreach my $sentence (@sentences)
    {
        print(join('', @{$sentence}));
    }
    # We cannot print the sentence now. We must wait to see whether the following
    # sentence wants to join this one.
    @last_sentence = @sentence;
    #print(join('', @sentence));
}



#------------------------------------------------------------------------------
# Splits a sentence into two. Takes arrayref and index of the line that should
# start a new sentence, returns two arrayrefs.
#------------------------------------------------------------------------------
sub split_sentence
{
    my $iline = shift;
    my $sentence = shift; # arrayref
    my @sentence = @{$sentence};
    # The split line must be a non-first token line, not a comment line.
    if($iline < 0 || $iline > $#sentence)
    {
        die("\$iline '$iline' out of range");
    }
    elsif($sentence[$iline] !~ m/^\d/)
    {
        die("\$iline '$iline' is not a token line");
    }
    elsif($sentence[$iline] =~ m/^1(-|\t)/)
    {
        die("\$iline '$iline' points to the first token of a sentence");
    }
    # Check that the split is not inside a multiword token.
    elsif($sentence[$iline] =~ m/^(\d+)\t/)
    {
        my $splitid = $1;
        for(my $i = 0; $i < $iline; $i++)
        {
            if($sentence[$i] =~ m/^(\d+)-(\d+)\t/)
            {
                my $id0 = $1;
                my $id1 = $2;
                my $i1 = $i+$id1-$id0+1;
                if($iline <= $i1)
                {
                    die("\$iline '$iline' is inside the multiword token '$id0-$id1'");
                }
            }
        }
    }
    # Find the ID of the current root. We will need it when splitting the tree.
    my $old_root;
    foreach my $line (@sentence)
    {
        if($line =~ m/^\d+\t/)
        {
            my @f = split(/\t/, $line);
            if($f[6]==0)
            {
                $old_root = $f[0];
                last;
            }
        }
    }
    if(!defined($old_root))
    {
        die("Cannot find the independent root node");
    }
    # Find the current sentence id. We will derive the ids of the new sentences from it.
    my $old_sent_id;
    foreach my $line (@sentence)
    {
        if($line =~ m/^\#\s*sent_id\s*=\s*(\S+)/)
        {
            $old_sent_id = $1;
            last;
        }
    }
    if(!defined($old_sent_id))
    {
        die("Cannot find the sentence id");
    }
    # Split the sentence.
    my @s1 = @sentence[0..($iline-1)];
    my @s2 = @sentence[$iline..$#sentence];
    # The second sentence is already terminated by an empty line but the first one is not.
    push(@s1, "\n");
    # The ID of the first token in the second sentence is the offset by which we will decrease node ids.
    if($s2[0] !~ m/^(\d+)(-\d+)?\t/)
    {
        print STDERR ($s2[0]);
        die("The first line after split is not a token line");
    }
    my $offset = $1;
    # Copy the sentence-level comments to the second sentence.
    my @comments = grep {m/^\#/} (@s1);
    @s2 = (@comments, @s2);
    # Modify the sentence ids.
    my $new_sent_id = $old_sent_id.'a';
    foreach my $line (@s1)
    {
        if($line =~ s/^\#\s*sent_id\s*=\s*\S+.*/\# sent_id = $new_sent_id/)
        {
            last;
        }
    }
    $new_sent_id = $old_sent_id.'b';
    foreach my $line (@s2)
    {
        if($line =~ s/^\#\s*sent_id\s*=\s*\S+.*/\# sent_id = $new_sent_id/)
        {
            last;
        }
    }
    # If a node in the first half is attached to a node in the second half, re-attach it to the root.
    my $new_root;
    foreach my $line (@s1)
    {
        if($line =~ m/^\d+\t/)
        {
            my @f = split(/\t/, $line);
            if($f[6] >= $offset)
            {
                if($old_root < $offset)
                {
                    $f[6] = $old_root;
                }
                elsif(defined($new_root))
                {
                    $f[6] = $new_root;
                }
                else
                {
                    $f[6] = 0;
                    $f[7] = 'root';
                    $new_root = $f[0];
                }
            }
            $line = join("\t", @f);
        }
    }
    # Renumber the nodes in the second sentence.
    # If a node in the second sentence is attached to a node in the first sentence, re-attach it to the root.
    $new_root = undef;
    foreach my $line (@s2)
    {
        if($line =~ m/^\d/)
        {
            my @f = split(/\t/, $line);
            if($f[0] =~ m/^(\d+)-(\d+)$/)
            {
                my $id0 = $1-$offset+1;
                my $id1 = $2-$offset+1;
                $f[0] = "$id0-$id1";
            }
            elsif($f[0] =~ m/^\d+$/)
            {
                $f[0] -= $offset-1;
                if($f[6] < $offset)
                {
                    if($old_root >= $offset)
                    {
                        $f[6] = $old_root;
                    }
                    elsif(defined($new_root))
                    {
                        $f[6] = $new_root;
                    }
                    else
                    {
                        $f[6] = 0;
                        $f[7] = 'root';
                        $new_root = $f[0];
                    }
                }
                else
                {
                    $f[6] -= $offset-1;
                }
            }
            $line = join("\t", @f);
        }
    }
    # Modify the sentence texts.
    my $s1_text = get_sentence_text(@s1);
    foreach my $line (@s1)
    {
        if($line =~ s/^\#\s*text\s*=\s*.*/\# text = $s1_text/)
        {
            last;
        }
    }
    my $s2_text = get_sentence_text(@s2);
    foreach my $line (@s2)
    {
        if($line =~ s/^\#\s*text\s*=\s*.*/\# text = $s2_text/)
        {
            last;
        }
    }
    return (\@s1, \@s2);
}



#------------------------------------------------------------------------------
# Collects the sentence text based on word forms and SpaceAfter=No.
#------------------------------------------------------------------------------
sub get_sentence_text
{
    my @sentence = @_;
    my $text;
    foreach my $line (@sentence)
    {
        if($line =~ m/^\d/)
        {
            my @f = split(/\t/, $line);
            $text .= $f[1];
            $f[9] =~ s/\r?\n$//;
            my @misc = split(/\|/, $f[9]);
            unless(grep {m/^SpaceAfter=No$/} (@misc))
            {
                $text .= ' ';
            }
        }
    }
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    $text =~ s/\s+/ /g;
    return $text;
}
