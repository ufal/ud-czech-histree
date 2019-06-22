#!/usr/bin/env perl
# Reads a CoNLL-U file, makes sure that every [square] and {curly} bracket
# constitutes a token of its own, and prints the result. We use these brackets
# to preserve certain XML markup through UDPipe and we will later remove them.
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
        # An opening bracket may be joined with the following word.
        if($sentence[$i] =~ m/^\d+\t([\[\{])[^\t]+/)
        {
            my $bracket = $1;
            @sentence = duplicate_line($i, @sentence);
            $sentence[$i] =~ s/\r?\n$//;
            my @f = split(/\t/, $sentence[$i]);
            $f[1] = $f[2] = $bracket;
            my @misc;
            @misc = grep {$_ ne 'SpaceAfter=No'} (split(/\|/, $f[9])) unless($f[9] eq '_');
            push(@misc, 'SpaceAfter=No');
            $f[9] = join('|', @misc);
            $sentence[$i] = join("\t", @f)."\n";
            @f = split(/\t/, $sentence[$i+1]);
            $f[1] =~ s/^[\[\{](.+)$/$1/;
            $f[2] =~ s/^[\[\{](.+)$/$1/;
            $sentence[$i+1] = join("\t", @f);
            $nlines++;
            $i++;
        }
        # A closing bracket may be joined with the preceding word.
        elsif($sentence[$i] =~ m/^\d+\t[^\t]+([\]\}])/)
        {
            my $bracket = $1;
            @sentence = duplicate_line($i, @sentence);
            $sentence[$i] =~ s/\r?\n$//;
            my @f = split(/\t/, $sentence[$i]);
            $f[1] =~ s/^(.+)[\]\}]$/$1/;
            $f[2] =~ s/^(.+)[\]\}]$/$1/;
            my @misc;
            @misc = grep {$_ ne 'SpaceAfter=No'} (split(/\|/, $f[9])) unless($f[9] eq '_');
            push(@misc, 'SpaceAfter=No');
            $f[9] = join('|', @misc);
            $sentence[$i] = join("\t", @f)."\n";
            @f = split(/\t/, $sentence[$i+1]);
            $f[1] = $f[2] = $bracket;
            $sentence[$i+1] = join("\t", @f);
            $nlines++;
            $i++;
        }
    }
    print(join('', @sentence));
}



sub duplicate_line
{
    my $iline = shift;
    my @sentence = @_;
    my @f = split(/\t/, $sentence[$iline]);
    my $id = $f[0];
    # Increase ids of nodes that are after the duplicated one.
    # Assume that there are no enhanced dependencies, i.e., we do not have to take care of DEPS.
    foreach my $line (@sentence)
    {
        if($line =~ m/^\d+\t/)
        {
            $line =~ s/\r?\n$//;
            @f = split(/\t/, $line);
            if($f[0] > $id)
            {
                $f[0]++;
            }
            if($f[6] > $id)
            {
                $f[6]++;
            }
            $line = join("\t", @f)."\n";
        }
        # Interval lines of multiword tokens should not include the duplicated lines but at least warn if that happens.
        elsif($line =~ m/^(\d+)-(\d+)\t/)
        {
            my $id0 = $1;
            my $id1 = $2;
            if($id0 <= $id && $id1 >= $id)
            {
                print STDERR ("WARNING: Multiword token not expected to include a removed bracket.\n");
            }
            # However, if the whole interval lies after the inserted line, we must adjust it.
            elsif($id0 > $id)
            {
                my @f = split(/\t/, $line);
                $f[0] = ($id0+1).'-'.($id1+1);
                $line = join("\t", @f);
            }
        }
    }
    @f = split(/\t/, $sentence[$iline]);
    $f[0] = $id+1;
    # If the duplicated node is attached as root, the duplicate should not be
    # root because there should be only one root.
    if($f[6] == 0)
    {
        $f[6] = $id;
        $f[7] = 'dep';
    }
    my $line_to_insert = join("\t", @f);
    splice(@sentence, $iline+1, 0, $line_to_insert);
    return @sentence;
}
