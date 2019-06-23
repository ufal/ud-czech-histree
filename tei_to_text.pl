#!/usr/bin/env perl
# Converts a TEI XML document to plain text. The TEI XML annotation goes down
# to paragraphs. There may be additional markup inside paragraphs, marking
# things like footnotes etc. But sentence boundaries are not marked and the
# text is not tokenized. In the output text, each paragraph is on a separate
# line.
# Copyright © 2019 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use XML::Twig;

if(scalar(@ARGV))
{
    my $filename = shift(@ARGV);
    my $twig = XML::Twig->new();
    # Define what the Twig XML parser does with particular XML elements.
    $twig->setTwigRoots
    ({
        # <head>...</head> is used for some headings, e.g. "Kniha první."
        # <p>...</p> is a paragraph
        # <l>...</l> is a verse line; we tentatively treat it as a paragraph
        # https://tei-c.org/release/doc/tei-p5-doc/en/html/ref-head.html
        # https://tei-c.org/release/doc/tei-p5-doc/en/html/ref-p.html
        # https://tei-c.org/release/doc/tei-p5-doc/en/html/ref-l.html
        'head' => \&process_paragraph,
        'p' => \&process_paragraph,
        'l' => \&process_paragraph
    });
    # The parser is ready, now parse the file.
    $twig->parsefile($filename);
}



sub process_paragraph
{
    my $twig = shift;
    my $paragraph = shift; # twig element
    # The paragraph element may have children other than #PCDATA.
    # Part of the text may be enclosed in <hi>...</hi>, meaning "highlighted",
    # i.e., boldface, italics etc. We will discard this markup.
    # Page break <pb> occurs both between paragraphs and inside a paragraph:
    #     stará lípa, <pb n="11"/> pod níž
    # If it occurs inside a paragraph and we skip it, we will have two
    # consecutive spaces. We merge them into one space in the code below.
    # Finally, there can be <foreign>...</foreign> and <note>...</note> (not
    # necessarilly coming together as they do here:
    #     že <foreign>crimen laesae Majestatis</foreign> <note>Zločin uražení Veličenstva.</note> spáchal
    # We do not anticipate any grandchildren.
    my $paragraph_text = '';
    my @children = $paragraph->children();
    foreach my $child (@children)
    {
        my $tag = $child->tag();
        my $text = $child->text();
        if($text =~ m/[\[\]\{\}]/)
        {
            print STDERR ("WARNING: Text '$text' contains bracket types that we use to mark foreign text and footnotes.\n");
        }
        if($tag eq 'note')
        {
            $paragraph_text .= "[$text]";
        }
        elsif($tag eq 'foreign')
        {
            $paragraph_text .= "{$text}";
        }
        else
        {
            $paragraph_text .= $text;
        }
    }
    $paragraph_text =~ s/^\s+//;
    $paragraph_text =~ s/\s+$//;
    # Merge spaces around page breaks. This will also normalize other whitespace characters
    # (tabs, line breaks) if they occur in the text.
    $paragraph_text =~ s/\s+/ /g;
    # In the source text, opening quotation marks are correct but
    # closing marks are sometimes replaced with the unidirectional
    # ASCII quotes: „Stavení!"
    $paragraph_text =~ s/"/“/g; # "
    # ASCII apostrof občas nahrazuje vypuštěné hlásky (např. "řek'"), ale často
    # se také používá místo koncové jednoduché uvozovky. Neumíme oba případy
    # automaticky odlišit, ale kvůli té uvozovce bychom ho měli nahradit
    # typografickou variantou stejně jako u dvojitých uvozovek. Zkusíme tedy
    # alespoň vyjmenovat případy, o kterých víme, že apostrof má zůstat
    # apostrofem.
    $paragraph_text =~ s/'/‘/g; # '
    $paragraph_text =~ s/(la?|že|kde)‘(s)/$1'$2/ig; # '
    $paragraph_text =~ s/(d)‘([ha-e])/$1'$2/ig; # '
    $paragraph_text =~ s/(neřek)‘/$1'/ig; # '
    # Generate an empty line after every paragraph. UDPipe may recognize it
    # as a paragraph boundary that also terminates a sentence.
    print("$paragraph_text\n\n") unless($paragraph_text eq '');
    # Delete all elements that have been completely parsed so far.
    $twig->purge();
    # Tell the parser that subsequent handlers shall also be called.
    return 1;
}
