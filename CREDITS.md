# Crédits

## Dictionnaire du Punchliner

Quand tu écris ta propre fin de punchline, son dernier mot est vérifié dans une liste de mots français :
`GosloRecords/GosloRecords/Resources/french-words.txt`.

- Source : le paquet npm [`an-array-of-french-words`](https://github.com/words/an-array-of-french-words) 2.0.0
  (~336 000 mots, dérivé de la liste de mots de Letterpress), complété par quelques mots de rap
  (rappeur, punchline, flow, kiffe…).
- Licence : MIT — Copyright (c) 2016 Zeke Sikelianos. Le texte complet de la licence est livré avec l'app :
  `GosloRecords/GosloRecords/Resources/french-words-LICENSE.txt`.
- Transformation : mots mis en minuscules, sans accents, dédoublonnés et compressés (préfixes communs) par
  `Tools/Dictionary/build_dictionary.py`.
