# UD treebank of old Czech texts.

Pro začátek: Alois Jirásek (1875): Skaláci.
Zdrojový korpus převzat z projektu ELTeC (https://github.com/COST-ELTeC/ELTeC-cze/tree/master/level1).

## To do

Vyčlenit relativně krátkou úvodní pasáž Skaláků a začít anotovat, abychom si ujasnili, jak to bude probíhat.
Vybrat jednu ze tří anotací UDPipem, která vypadá nejrozumněji.

Kromě oprav morfologie potřebujeme domluvit značky, které umožní později automaticky rozdělit nebo spojit věty nebo slova.

Pro další pasáže, které budeme anotovat později, zkusit přichystat lepší model UDPipe.
Např. Milan (mail 22.6.2019) popisuje způsob, jak natrénovat model, který bude vědět o slovníku z Morphodity.
Taky bych to mohl natrénovat na všech třech českých treebancích, čarovat s word embeddings atd.
A případně použít UDPipe future.

## První zkušební soubor

Předzpracovaný UDPipem s modelem z PDT, tedy jirasek-udpipe-pdt-1.conllu.
Prvních 100 vět, akorát to končí na hranici odstavce (po opravě těch vět bude míň, protože na několika místech je věta rozdělená omylem).
Celé je to jen část první kapitoly (ale včetně úvodních informací před první kapitolou).

VerbForm Aspect Mood Tense Voice
Gender Animacy Number Case PrepCase
Degree Polarity Variant
PronType NumType Poss Reflex Person Gender[psor] Number[psor]
Abbr AdpType ConjType Foreign Hyph NameType NumForm NumValue Style Typo

Návrh pořadí:
Gender Animacy Number Case PrepCase
VerbForm Aspect Mood Tense Voice Person PronType Poss Reflex Gender[psor] Number[psor]
Variant Degree Polarity
NumType NumForm NumValue
Foreign Abbr Hyph Style Typo
AdpType ConjType NameType


## Relevantní odkazy na web

* http://ufal.mff.cuni.cz/tred/
* https://universaldependencies.org/
* https://universaldependencies.org/cs/index.html
* https://universaldependencies.org/cs/pos/index.html
* https://universaldependencies.org/cs/feat/index.html
* https://universaldependencies.org/cs/dep/index.html
