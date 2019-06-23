#!/usr/bin/env perl
# Reads CoNLL-U, erases any syntactic annotation and prints the result.
# Copyright © 2019 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

while(<>)
{
    if(m/^\d/)
    {
        my @f = split(/\t/, $_);
        $f[6] = 0;
        $f[7] = '_';
        $f[8] = '_';
        $_ = join("\t", @f);
    }
    print;
}
