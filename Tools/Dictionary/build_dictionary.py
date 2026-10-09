#!/usr/bin/env python3
"""Builds GosloRecords/GosloRecords/Resources/french-words.txt, the dictionary of the Punchliner.

Source: the npm package `an-array-of-french-words` 2.0.0 (MIT, (c) 2016 Zeke Sikelianos, derived from the
Letterpress word list), plus a few rap / slang words it lacks (EXTRA below).

    curl -sSLO https://registry.npmjs.org/an-array-of-french-words/-/an-array-of-french-words-2.0.0.tgz
    tar xzf an-array-of-french-words-2.0.0.tgz
    python3 -I Tools/Dictionary/build_dictionary.py package/index.json GosloRecords/GosloRecords/Resources/french-words.txt

Words are normalised like `FrenchDictionary.normalize`: lowercase, accents removed, œ -> oe, æ -> ae,
hyphens and apostrophes dropped. Sorted, deduplicated, then front-coded to stay small (~1.3 MB):
each line is one character giving how many leading letters are shared with the previous word
('0'…'9' then 'A'…'Z' for 10…35), followed by the rest of the word.
"""
import json
import sys
import unicodedata

EXTRA = """
rap rappe rappes rappent rapper rappeur rappeurs rappeuse rappeuses rappait rappais rappaient rappé
flow flows punchline punchlines clash clasher clashe clashes clashent beatmaker beatmakers beatbox
kiffe kiffes kiffent kiffer kiffé kif wesh meuf meufs daron darons daronne daronnes bling zwin khoya khti
wakha wallah frérot frérots reuf reufs miskine mytho mythos bendo bendos tieks tess
chelou relou ouf vénère vener seum oseille gova bigo gadjo gadji poto potos posse crew
freestyle freestyles feat feats featuring hit hits clip clips sample samples studio drill trap
boom bap skeud skeuds instru instrus mixtape mixtapes stream streams streamer streamé
""".split()


def normalize(word):
    word = word.lower().replace("œ", "oe").replace("æ", "ae")
    word = "".join(c for c in unicodedata.normalize("NFD", word) if unicodedata.category(c) != "Mn")
    return "".join(c for c in word if c not in "-'’ ")


def code(n):
    return str(n) if n < 10 else chr(ord("A") + n - 10)


def main(source, target):
    words = json.load(open(source, encoding="utf-8")) + EXTRA
    clean = sorted({w for w in map(normalize, words) if w and all("a" <= c <= "z" for c in w)})
    previous = ""
    with open(target, "w", encoding="ascii", newline="\n") as out:
        for word in clean:
            shared = 0
            while shared < min(len(previous), len(word), 35) and previous[shared] == word[shared]:
                shared += 1
            out.write(code(shared) + word[shared:] + "\n")
            previous = word
    print(f"{len(clean)} mots -> {target}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
