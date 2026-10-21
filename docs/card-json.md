# `card.json` — producteur de fragment JSON-LD (catalogue Phase 1)

## Principe

Chaque dépôt qui rend un site via le workflow réutilisable
`.github/workflows/render-quarto.yml` publie, **à côté de son site**, un
fichier `card.json` : un **fragment de données JSON-LD** (vocabulaire
**schema.org**, aucun schéma maison) situé à la racine du site déployé :

    https://bruno.univ-tln.fr/teaching-material/<repo>/<branch>/card.json

Le fichier est émis par l'étape **`Emit card.json (JSON-LD)`** du job
`deploy-static`, insérée entre « Compute target path » (qui exporte
`REPO`/`SUBPATH`) et le rsync du site. Zéro input nouveau, zéro modification
des wrappers ou des consommateurs.

## Règle de propriété (producteur vs centre)

| Qui | Possède | Champs / décisions |
|---|---|---|
| **Producteur** (le render de chaque dépôt, via cette étape) | Vérité locale | `name`, `description`, `dateModified`, `url`/`identifier`, `inLanguage`, `keywords` (topics bruts), `codeRepository`, `@type` heuristique |
| **Central** (`teaching-catalog`) | Composition | classification (`area-*`), viveté (`site_live`), ordonnancement, regroupements formation/filière, descriptions manquantes rattrapées — le catalogue **SURCHANGE (override)** le card.json par ses propres autorités quand elles existent |

Le card.json n'est **jamais** une autorité finale : c'est un transport de
faits locaux qui évite au catalogue d'aller les gratter. Absence de
`card.json` = le catalogue retombe sur son scraping actuel (topics API),
sans erreur.

## Émission fail-soft

L'étape ne peut ** jamais** faire échouer un déploiement :
`set +e` + `trap 'exit 0' EXIT` + `continue-on-error: true`. Un défaut du
card (JSON invalide détecté par la validation jq/python3, `mv` impossible,
payload absent) produit un `::warning::` et aucun fichier ; le site se
déploie normalement.

## Champs émis

| Champ JSON-LD | Source (contextes GitHub déjà disponibles) | Dégradation |
|---|---|---|
| `@context` | Literal compact `{"@version": 1.1, "@vocab": "https://schema.org/"}` (épinglé par la ruling @version-drift) | — |
| `@type` | **Préfixe du nom du dépôt** (tableau ci-dessous) | — |
| `name` | `github.event.repository.description`, sinon nom du dépôt | nom du dépôt |
| `description` | `github.event.repository.description` (porté par les événements push) | chaîne vide |
| `identifier` / `url` | URL du site déployé : `${TEACHING_BASE_URL}/<repo>/<subpath>/` (même formule que la cible rsync ; fallback base publique `https://bruno.univ-tln.fr/teaching-material`) | — |
| `dateModified` | `github.event.repository.pushed_at` | mtime de `index.html` du site construit, sinon horodatage courant |
| `keywords` | `github.event.repository.topics[].name` joints par `", "` | omis si absent/null |
| `inLanguage` | `grep '<html lang="' index.html` du site construit | omis si absent |
| `learningResourceType` | Literal `"Notebook"` — **seulement si `@type: LearningResource`** | — |
| `codeRepository` | `github.server_url`/`github.repository` — **seulement si `@type: SoftwareSourceCode`** | — |

## Mapping préfixe → `@type`

| Préfixe du dépôt | `@type` schema.org | Extras |
|---|---|---|
| `lecture-*` | `Course` | |
| `notebook-*` | `LearningResource` | `"learningResourceType": "Notebook"` |
| `sample-*`, `demo-*` | `SoftwareSourceCode` | `"codeRepository": "<github repo URL>"` |
| autre | `CreativeWork` | |

## Contrat de validation (Phase 2, côté catalogue)

Le `@type` émis est une **heuristique de nom**, pas une classification.
En Phase 2, `catalog.py` **croisera** le `@type` du card.json avec les
topics `area-*` du dépôt via l'API GitHub et **préférera le topic** en cas
de divergence (le topic est l'autorité centrale, cf. règle de propriété).
Mapping attendu côté topics : `area-lecture`→`Course`,
`area-notebook`→`LearningResource`, `area-sample`→`SoftwareSourceCode`,
`area-standard`/`area-demo`→`SoftwareSourceCode`, autres→`CreativeWork`.
Une divergence card/topic est un signal de reclassement (ou de renommage),
pas une erreur bloquante.

## Non-objectifs explicites (hors Phase 1)

- **Pas de JSON-LD par leçon** — uniquement la carte du dépôt entier.
- **Pas d'injection `<script type="application/ld+json">` dans le `<head>`**
  des pages — envisagé Phase 2.5, après validation de la consommation du
  fichier standalone par les moteurs/le catalogue.
- **Pas de champ `provider`** — il est ajouté centralement par le catalogue
  (autorité organisationnelle, pas locale).
- Pas de nouveau input du workflow réutilisable, pas de modification des
  wrappers consommateurs.

## Limites connues

- `deploy-static` est réservé aux événements `push`/`delete` (gate du job)
  et les runs PR ne le reçoivent jamais : l'étape n'est **exercée que sur
  les vrais déploiements** (merge + tag + premier rendu consommateur sur
  ce tag).
- Sur les payloads push rares sans `repository.description`/`topics`, les
  champs se dégradent proprement (vide/omis), jamais d'échec.
