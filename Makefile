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

# Připravit anotaci morfologie a větné segmentace do tabulkového procesoru.
# Vyrobený soubor se otevře v LibreOffice, tam se upraví šířky sloupců, ztuční se nadpisy a ukotví se příčky za 1. řádkem a za 3. sloupcem.
# Pak se to uloží jako .ods nebo jako .xlsx a předá anotátorům.
table:
	perl conllu_to_tsv.pl < davka01.conllu > davka01.csv

# Ručně anotovanou tabulku uložit opět jako .csv (pokud jsme si ji mezitím převedli do .ods nebo .xlsx).
# Zkontrolovat: kódování Unicode UTF-8, oddělovač polí je tabulátor, oddělovač textu žádný (vymazat ty automaticky nabízené uvozovky).
fromtable:
	perl tsv_to_conllu.pl < davka01-dan.csv > davka01-dan-morpho.conllu

# TO DO
# - Provést úpravy segmentace a tokenizace na základě komentářů v MISC.
# - Vyhodnotit úspěšnost jednotlivých modelů UDPipe.
# - Zkontrolovat, že každý slovní druh má takové rysy, které by měl mít.

