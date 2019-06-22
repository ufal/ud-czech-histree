#!/usr/bin/env perl
# Reads a CoNLL-U file, removes all [square] and {curly} brackets (we used them
# to preserve certain XML markup which is now reflected in the MISC column) and
# prints the result. If there are any nodes that depend on the brackets, they
# will be reattached to the parent of the bracket.
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
    my $nlines = scalar(@sentence);
    for(my $i = 0; $i < $nlines; $i++)
    {
        # We currently remove curly brackets (foreign text segment) but we keep
        # square brackets around footnotes. (Footnotes may be inserted in the
        # middle of the main sentence and without the brackets they would appear
        # to distort the syntax structure.)
        if($sentence[$i] =~ m/^\d+\t[\{\}]\t/)
        {
            @sentence = delete_line($i, @sentence);
            $nlines--;
            $i--;
        }
        # We also must remove the curly brackets from the sentence text line.
        elsif($sentence[$i] =~ m/^\#\s*text\s*=/)
        {
            $sentence[$i] =~ s/[\{\}]//g;
        }
    }
    print(join('', @sentence));
}



sub delete_line
{
    my $iline = shift;
    my @sentence = @_;
    my @f = split(/\t/, $sentence[$iline]);
    my $id = $f[0];
    my $pid = $f[6];
    my $no_space_after = 0;
    $f[9] =~ s/\r?\n$//;
    $f[9] = '' if($f[9] eq '_');
    $no_space_after = grep {$_ eq 'SpaceAfter=No'} (split(/\|/, $f[9]));
    # Decrease ids of nodes that are after the deleted one.
    # Reattach children of the deleted node.
    # Assume that there are no enhanced dependencies, i.e., we do not have to take care of DEPS.
    foreach my $line (@sentence)
    {
        if($line =~ m/^\d+\t/)
        {
            $line =~ s/\r?\n$//;
            @f = split(/\t/, $line);
            if($f[0] > $id)
            {
                $f[0]--;
            }
            # The previous token should keep SpaceAfter=No only if the deleted
            # token had it, too. If there was a space on any side of the deleted
            # token, there will be now a space between the previous and the
            # following token. (In fact, we expect always a space on one side.
            # It was us who inserted the brackets.)
            elsif($f[0] == $id-1) ###!!! This will not work correctly if the previous node is part of a multiword token.
            {
                my @misc;
                unless($f[9] eq '_')
                {
                    @misc = split(/\|/, $f[9]);
                }
                my $prev_no_space_after = grep {$_ eq 'SpaceAfter=No'} (@misc);
                unless($prev_no_space_after && $no_space_after)
                {
                    @misc = grep {$_ ne 'SpaceAfter=No'} (@misc);
                }
                $f[9] = scalar(@misc) ? join('|', @misc) : '_';
            }
            if($f[6] > $id)
            {
                $f[6]--;
            }
            elsif($f[6] == $id)
            {
                $f[6] = $pid;
                if($pid == 0)
                {
                    $f[7] = 'root';
                    # Prevent subsequent orphans from also becoming roots.
                    # Redirect them to me.
                    $pid = $f[0];
                }
            }
            $line = join("\t", @f)."\n";
        }
        # Interval lines of multiword tokens should not include the deleted lines but at least warn if that happens.
        elsif($line =~ m/^(\d+)-(\d+)\t/)
        {
            my $id0 = $1;
            my $id1 = $2;
            if($id0 <= $id && $id1 >= $id)
            {
                print STDERR ("WARNING: Multiword token not expected to include a removed bracket.\n");
            }
            # However, if the whole interval lies after the deleted line, we must adjust it.
            elsif($id0 > $id)
            {
                my @f = split(/\t/, $line);
                $f[0] = ($id0-1).'-'.($id1-1);
                $line = join("\t", @f);
            }
        }
    }
    splice(@sentence, $iline, 1);
    return @sentence;
}
