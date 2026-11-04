# Artémis — l'agent IA qui utilise ton téléphone

Adaptation mobile de [google/artemis](https://github.com/google/artemis) (Apache 2.0) : le moteur de lecture d'écran
et de gestes du helper Android d'Artemis (`HierarchyDumper`, `A11yNode`, `GestureController`, `DisplayUtils`, `XmlUtils`)
est repris tel quel, et la boucle d'agent « Flash » (observer → décider → agir) est réécrite pour tourner **sur le téléphone**,
sans PC ni ADB, avec l'API Claude.

Différences avec l'original : bulle flottante utilisable partout, routines en un toucher, questions/confirmations
avant toute action engageante, lecture texte d'abord (capture seulement si utile, donc moins cher).

Licence d'origine : voir `LICENSE-artemis`.
