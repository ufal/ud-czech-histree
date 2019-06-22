#!/usr/bin/env perl
# Reads a CoNLL-U file and looks for word sequences enclosed in [square] or
# {curly} brackets. We have used these brackets to push certain markup from
# the original XML via plain text through UDPipe. All words inside the brackets
# will now receive a special attribute in the MISC column. Note that UDPipe may
# have introduced a sentence break inside the brackets.
# Copyright © 2019 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

# It is guaranteed that the text did not contain [square] or {curly} brackets
# before we introduced them; it is also guaranteed that brackets of the same
# type are not nested recursively. We will therefore only remember whether we
# are inside or outside of each bracket type.
my $square = 0;
my $curly = 0;
my $lineno = 0;
while(<>)
{
    $lineno++;
    if(m/^\d+\t/)
    {
        my @f = split(/\t/, $_);
        ###!!! UDPipe may have decided to keep the bracket in one token with
        ###!!! neighboring characters. Then the code here will break because we
        ###!!! assume that the bracket is the single character of its token.
        ###!!! (The CAC UDPipe model currently does this.)
        ###!!! To fix it, we would have to write another script that enforces
        ###!!! our tokenization around brackets.
        if($f[1] eq '[')
        {
            if($square)
            {
                print STDERR ("WARNING: Nested square brackets (line $lineno).\n");
            }
            $square = 1;
        }
        elsif($f[1] eq ']')
        {
            if(!$square)
            {
                print STDERR ("WARNING: Unmatched square brackets (line $lineno).\n");
            }
            $square = 0;
        }
        elsif($f[1] eq '{')
        {
            if($curly)
            {
                print STDERR ("WARNING: Nested curly brackets (line $lineno).\n");
            }
            $curly = 1;
        }
        elsif($f[1] eq '}')
        {
            if(!$curly)
            {
                print STDERR ("WARNING: Unmatched curly brackets (line $lineno).\n");
            }
            $curly = 0;
        }
        else
        {
            if($square || $curly)
            {
                my $misc = $f[9];
                $misc =~ s/\r?\n$//;
                $misc = '' if($misc eq '_');
                my @misc = split(/\|/, $misc);
                if($square)
                {
                    push(@misc, 'Note=Yes');
                }
                if($curly)
                {
                    push(@misc, 'Foreign=Yes');
                }
                $f[9] = $misc = join('|', @misc)."\n";
            }
        }
        $_ = join("\t", @f);
    }
    print;
}
