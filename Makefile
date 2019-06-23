# Příprava českých textů z 19. století pro anotování Universal Dependencies.

# Konverze Jiráska z TEI XML do prostého textu (při zachování značek <note> pomocí hranatých a <foreign> pomocí složených závorek).
jirasek:
	perl tei_to_text.pl CS0016_1875JirasekSkalaci.xml > jirasek.txt

# Předzpracování pomocí UDPipe (segmentace na věty, tokenizace, morfologická a syntaktická analýza).
udpipe:
	udpipe --tokenize --tag --parse udpipe-models/czech-pdt-ud-2.4-190531.udpipe jirasek.txt --outfile=jirasek-udpipe-pdt.conllu
	udpipe --tokenize --tag --parse udpipe-models/czech-cac-ud-2.4-190531.udpipe jirasek.txt --outfile=jirasek-udpipe-cac.conllu
	udpipe --tokenize --tag --parse udpipe-models/czech-fictree-ud-2.4-190531.udpipe jirasek.txt --outfile=jirasek-udpipe-fictree.conllu
	fix_bracket_tokenization.pl < jirasek-udpipe-pdt.conllu | brackets_to_misc.pl | remove_brackets.pl > jirasek-udpipe-pdt-1.conllu
	fix_bracket_tokenization.pl < jirasek-udpipe-cac.conllu | brackets_to_misc.pl | remove_brackets.pl > jirasek-udpipe-cac-1.conllu
	fix_bracket_tokenization.pl < jirasek-udpipe-fictree.conllu | brackets_to_misc.pl | remove_brackets.pl > jirasek-udpipe-fictree-1.conllu

# Validace po UDPipe a po mých skriptech, stačí na úrovni 2, protože od UDPipe stejně nemůžeme očekávat,
# že nevygeneruje strom, který se odchyluje od anotačních pravidel.
validate:
	validate.py --level 2 --lang cs jirasek-udpipe-pdt-1.conllu
	validate.py --level 2 --lang cs jirasek-udpipe-cac-1.conllu
	validate.py --level 2 --lang cs jirasek-udpipe-fictree-1.conllu

