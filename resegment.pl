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

my $last_sentence;
my @sentence;
while(<>)
{
    push(@sentence, $_);
    if(m/^\s*$/)
    {
        $last_sentence = process_sentence($last_sentence, @sentence) unless(scalar(@sentence)==0);
        @sentence = ();
    }
}
$last_sentence = process_sentence(@sentence) unless(scalar(@sentence)==0);
if(defined($last_sentence) && scalar(@{$last_sentence}) > 0)
{
    print(join('', @{$last_sentence}));
}



#------------------------------------------------------------------------------
# Processes the sentence that has just been read.
#------------------------------------------------------------------------------
sub process_sentence
{
    my $last_sentence = shift;
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
            my @misc = grep {!m/^Comment=/} (@misc);
            $f[9] = scalar(@misc)==0 ? '_' : join('|', @misc);
            $sentence[$i] = join("\t", @f)."\n";
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
                elsif($comment =~ m/^Comment=splitword\s+(\S+)\s+(\S+)$/)
                {
                    my $w1 = $1;
                    my $w2 = $2;
                    @sentence = split_word($i, $w1, $w2, @sentence);
                    $nlines++;
                    $i++;
                }
                else
                {
                    print STDERR ("WARNING: Unprocessed comment '$comment'\n");
                }
            }
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
    # Join the (first part of the) current sentence with the previous one if desirable.
    if($join_with_prev)
    {
        if(!defined($last_sentence) || scalar(@{$last_sentence}) == 0)
        {
            die("Cannot join. No previous sentence");
        }
        my $s0 = join_sentences($last_sentence, $sentences[0]);
        $sentences[0] = $s0;
    }
    elsif(defined($last_sentence) && scalar(@{$last_sentence}) > 0)
    {
        unshift(@sentences, $last_sentence);
    }
    # We can now print all sentences except the last one. We must keep the last
    # one until the next time because the next sentence may want to join this one.
    $last_sentence = pop(@sentences);
    foreach my $sentence (@sentences)
    {
        print(join('', @{$sentence}));
    }
    return $last_sentence;
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
    # Note that this does not guarantee that the ids are unique across the file.
    # But we would have to collect all ids first if we wanted to ensure this.
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
# Joins two sentences into one. Takes two arrayrefs and returns one.
#------------------------------------------------------------------------------
sub join_sentences
{
    my $s1 = shift; # arrayref
    my $s2 = shift; # arrayref
    my @s1 = @{$s1};
    my @s2 = @{$s2};
    # Remove the empty line that terminates the first sentence.
    pop(@s1);
    # Remove the comment lines in the beginning of the second sentence.
    @s2 = grep {!m/^\#/} (@s2);
    # Find the ID of the root of the first sentence. We will need it when joining the trees.
    my $root;
    foreach my $line (@s1)
    {
        if($line =~ m/^\d+\t/)
        {
            my @f = split(/\t/, $line);
            if($f[6]==0)
            {
                $root = $f[0];
                last;
            }
        }
    }
    if(!defined($root))
    {
        die("Cannot find the independent root node");
    }
    # The ID of the last token in the first sentence is the offset by which we will increase node ids.
    if($s1[-1] !~ m/^(\d+)\t/)
    {
        print STDERR ($s1[-1]);
        die("The penultimate line is not a token line");
    }
    my $offset = $1;
    # Renumber the nodes in the second sentence.
    # If a node in the second sentence is attached to a node in the first sentence, re-attach it to the root.
    foreach my $line (@s2)
    {
        if($line =~ m/^\d/)
        {
            my @f = split(/\t/, $line);
            if($f[0] =~ m/^(\d+)-(\d+)$/)
            {
                my $id0 = $1+$offset;
                my $id1 = $2+$offset;
                $f[0] = "$id0-$id1";
            }
            elsif($f[0] =~ m/^\d+$/)
            {
                $f[0] += $offset;
                if($f[6] == 0)
                {
                    $f[6] = $root;
                    $f[7] = $f[3] eq 'PUNCT' ? 'punct' : 'parataxis';
                }
                else
                {
                    $f[6] += $offset;
                }
            }
            $line = join("\t", @f);
        }
    }
    my @s0 = (@s1, @s2);
    # Modify the sentence text.
    my $text = get_sentence_text(@s0);
    foreach my $line (@s0)
    {
        if($line =~ s/^\#\s*text\s*=\s*.*/\# text = $text/)
        {
            last;
        }
    }
    return \@s0;
}



#------------------------------------------------------------------------------
# Splits a word into two. Renumbers subsequent words and HEAD references that
# point to them.
#------------------------------------------------------------------------------
sub split_word
{
    my $iline = shift;
    my $w1 = shift;
    my $w2 = shift;
    my @sentence = @_;
    # Remember the ID of the node.
    if($sentence[$iline] !~ m/^(\d+)\t/)
    {
        print STDERR ($sentence[$iline]);
        die("The line of word split is not a word line");
    }
    my $id = $1;
    # Renumber the nodes.
    foreach my $line (@sentence)
    {
        if($line =~ m/^\d/)
        {
            my @f = split(/\t/, $line);
            if($f[0] =~ m/^(\d+)-(\d+)$/)
            {
                my $id0 = $1;
                my $id1 = $2;
                $id0++ if($id0 > $id);
                $id1++ if($id1 > $id);
                $f[0] = "$id0-$id1";
            }
            elsif($f[0] =~ m/^\d+$/)
            {
                $f[0]++ if($f[0] > $id);
                $f[6]++ if($f[6] > $id);
            }
            $line = join("\t", @f);
        }
    }
    # Duplicate the line and adjust the values.
    my $splitline = $sentence[$iline];
    splice(@sentence, $iline, 1, $splitline, $splitline);
    my @f = split(/\t/, $sentence[$iline]);
    if($f[1] ne $w1.$w2)
    {
        die("Invalid split word comment: '$f[1]' cannot be split to '$w1' + '$w2'");
    }
    $f[2] = $w1 if($f[2] eq $f[1]); # will work for punctuation
    $f[1] = $w1;
    $f[9] =~ s/\r?\n$//;
    my @misc;
    @misc = split(/\|/, $f[9]) unless($f[9] eq '_');
    unless(grep {m/^SpaceAfter=No$/} (@misc))
    {
        push(@misc, 'SpaceAfter=No');
    }
    $f[9] = join('|', @misc)."\n";
    $sentence[$iline] = join("\t", @f);
    @f = split(/\t/, $sentence[$iline+1]);
    $f[0]++;
    $f[2] = $w2 if($f[2] eq $f[1]); # will work for punctuation
    $f[1] = $w2;
    $sentence[$iline+1] = join("\t", @f);
    return @sentence;
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
