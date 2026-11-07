# AGENTS.md - _quarto-utils

## Role

- Seule brique de config partagee de la flotte d'enseignement : profils de rendu, themes, filtres, extensions, workflows reutilisables, gabarits de devcontainer. Un seul depot remplit ce role ; les cours ne dupliquent rien.
- Il est consomme par deux mecaniques distinctes : sous-module epingle par un commit dans chaque assemblage, et workflow reutilisable appele par les wrappers de rendu. Une modification peut etre vivante dans l'une et pas dans l'autre : les deux se verifient cote serveur.
- Le decoupage des fichiers de profil par defaut est partage : les cours pointent dessus par liens symboliques. Un cours ne materialise pas une copie de ces fichiers pour corriger un detail local.

## Regles de modification partagee

- Une modification partagee part d'une branche, est prouvee chez au moins un consommateur (rendu vert avec l'etage de publication execute, lu au niveau job), et seulement alors devient une version consommee. Un tag sans temoin consommateur n'est pas une version livree.
- Retirer ou renommer un input du workflow reutilisable sans vague couplee produit une panne de preparation du job, sans log ni annotation chez les consommateurs : l'absence de job n'est pas un succes.
- Les grands blocs de commande des workflows reutilisables ont une contrainte de longueur structurelle, imposee par le moteur d'orchestration et non par le gout : une garde, une condition supplementaire, ou un appel se place dans sa PROPRE etape, jamais dans un bloc deja volumineux. Le comptage se fait sur le fichier, pas de memoire.
- Un input dont la valeur par defaut ne publie pas est un piege de faux vert : la ligne de garde de publication doit etre verifiee dans tout wrapper que l'on touche.

## Validation avant "fait"

- Une version, un epinglement, une valeur de workflow ou d'image : lus sur la distante (`ls-remote`, API des refs), jamais deduits d'un document ni d'un souvenir de session.
- Un verdict de CI : lu au niveau job, jamais au niveau run.
- Une publication : prouvee par le corps de page et son horodatage. Un `404` prouve la non-publication ; un `200` ne prouve pas la fraicheur.
- Une affirmation d'un agent sur un commit, un tag ou une poussee est une hypothese jusqu'a relecture du fichier, de l'index et du serveur.
- Aucune poussee sans go-ahead humain individuel (ADR-04).

## Registre ADR (autorite, restaure 2026-11-05)

- ADR-01 : un owner formel unique par projet (regle, pas un constat).
- ADR-02 : les launch-prompts sont du contexte de session, jamais de l'etat date.
- ADR-03 : verification serveur avant tout claim (commit, push, tag, merge, ecriture, suppression).
- ADR-04 : go-ahead humain explicite par poussee; les approvals blanket n'autorisent aucun push.
- ADR-05 : gel flotte `v1.3.45`.
- ADR-06 : owner unique pour `_quarto-utils`.
- ADR-07 : timeouts bornes sur toute commande, fail-fast sur toute atteinte non verifiee.
- ADR-08 : une preuve durable vit dans un lieu durable (commit), pas dans un fichier non suivi.
- ADR-09 : eligibilite scrub - fence `{.bash}` + legende « Capture de l'atelier - commandes et sortie, non executees par le rendu : » + honnetete PAR DOCUMENT (verifier `execute:` / `eval:` du document avant toute formulation).
- ADR-10 : un `404` ne veut pas dire absent (contents API vs git tree).
- ADR-11 : bundle avant toute mutation git.
- ADR-12 : zsh ne decoupe pas les mots.
- ADR-13 : le journal `Teaching/AGENTS.md` est la source unique d'etat mutable; un fichier de doctrine par repo ne porte aucun fait date.
- ADR-14 : un projet ne publie pas son propre verdict.

## Invariant de verification des mounts

Un mount = intersection entre les entrees de `.gitmodules` et les repertoines reels a la racine du repo. Le total des gitlinks renvoye par un `git ls-tree` recursif N'EST PAS un nombre de mounts. Ne jamais enoncer un nombre de mounts dans un fichier de doctrine : le mesurer a la demande.

## Registre de session (zone ledger, hors Validation 5)

Fait date autorise ici uniquement ; la clause 5 de TEACHING-FLEET.md s'arrete a la ligne precedente.

### Identite

- Depot `ebpro/_quarto-utils`, branche `develop`, clone sous `teaching-repos/_quarto-utils` cree par la vague de transfert d'etat du 2026-11-07, en parite avec la distante a sa creation.
- Le present fichier est la PREMIERE version d'`AGENTS.md` de ce depot : il n'existait ni dans le clone ni dans `HEAD` avant ce commit. Le bloc `## Registre ADR` qui le precede est repris octet pour octet du gel de doctrine de la flotte (donneur : `notebook-git`), pour que la meme regle tienne dans tous les depots versionnes du corpus.
- Owner unique (ADR-06). La session owner precedente est declaree FINISHED par l'humain et ce depot est reassigne a la vague de transfert, en transfert d'etat seulement : ni contenu, ni CI, ni epinglement.

### Etat rendu (ancre sur refs durables)

- Tag de release le plus recent sur la distante, mesure par `git ls-remote --tags origin` a la creation du clone : `v1.3.45`, tag annote dont le peel est exactement le tip de `develop`, `fdeff101f58e9c1604e0e67b50f98aac0665423a`, fusion de la PR #56. Aucun ref `refs/tags/v1.3.46` n'existe sur la distante : c'est une mesure du 2026-11-07, pas une decision.
- Ce que porte la ligne `v1.3.45`, enonce en regles et non en numeros : les expressions d'interpolation sont sorties des grands blocs de commande vers des `env:` d'etape ; les unites de suivi de memoire et de surveillance de blocage vivent dans `scripts/render-sidecar.sh`, source en echec bruyant si le fichier manque ; l'affectation dynamique de l'etiquette de machine par input est conservee. La classe d'echec ainsi evitee est un rejet a la preparation du job, sans log et sans annotation.
- Mesure du 2026-11-05 sur le commit `fdeff101` : le plus grand bloc de commande du workflow reutilisable est l'etape de rendu dans `.github/workflows/render-quarto.yml`, a 20 129 caracteres pour une limite de 21 000 imposee par le moteur. Marge utile : 871 caracteres. Cette marge est la contrainte structurelle du depot : toute ligne ajoutee dans ce bloc est un risque pour tous les consommateurs a la fois, avant meme le premier job. La valeur se relit sur le fichier, elle ne se recopie pas, et la methode compte : le chiffre ci-dessus est le corps BRUT du bloc, indentation comprise, plus son saut de ligne final (comptage 20 129) ; un parseur qui dedente les blocs scalaires YAML trouve 16 918 et mesurerait donc une marge fausse.
- Preuve de cette contrainte, consignee au journal de corpus (section `2026-11-06`, dernier point) : une sonde qui ajoutait une ligne de garde DANS ce bloc a termine en zero job, `startup_failure`, log vide, la garde elle-meme devenue inobservable. La correction prescrite est une etape separee.
- Travail NON PUBLIE, preserve hors du depot : le generateur d'index de cours et son etape gardee n'existent qu'en un commit local, `71ac0fbd54396eba87a2c5db61aa208fbbaf43d5`, jamais pousse, jamais taggue. Chaine de preservation verifiee par execution le 2026-11-07 : le bundle complet se verifie, sa seule tete est `71ac0fb`, un fetch de test le materialise et `git cat-file -t` repond `commit`. Le clone de travail qui le portait sous le repertoire systeme temporaire n'est plus un depot exploitable (`.git/HEAD` et `.git/config` absents, arbre de travail reduit a quelques fichiers) : il n'est plus porteur de rien. verification executee : `git ls-remote --tags origin refs/tags/v1.3.46` repond vide, et dans le clone de reference `git merge-base --is-ancestor 71ac0fbd54396eba87a2c5db61aa208fbbaf43d5 HEAD` repond rc=1 (non ancetre). Le lieu nomme de preservation est le fichier bundle `quarto-utils-develop-full.bundle` sous le repertoire `REFRESH` du poste (relire par `git bundle verify` puis `git bundle list-heads` : sa seule tete doit etre `71ac0fb`) ; a l'interieur du clone, la trace observable est la ref locale `refs/test-bundle/develop` creee par ce fetch de test, et elle est ephemere : supprimee, il ne reste que le bundle.
- Deux corrections de durcissement sont DEJA dans ce commit local et prouvees par relecture de son contenu, pas par une claim : import paresseux de la dependance YAML (plus d'import inconditionnel au niveau module) et garde d'existence du manifest au niveau shell dans l'etape nouvelle. Elles ferment la classe de panne qui rougissait systematiquement tout consommateur sans manifest.

### Missions ouvertes

- Fin de vie du travail d'index de cours, HORS perimetre de cette vague : decider puis executer l'engagement de `71ac0fb` sur `develop`, son eventuel tag, son adoption par un canary consommateur, dans cet ordre et avec temoin de rendu vert lu au niveau job avant tout tag.
- Ce qui reste porte par ce commit, non verifie par cette vague, enumere par le journal : gate de drift `--check` engage dans la CI (le script l'offre, aucun appel ne le lance), P2 du generateur (appel redondant, evaluation d'un identifiant dans une fonction d'echec, commentaire perime), disposition de l'action `.github/actions/lecture-index/action.yml` que rien n'appelle, disposition de `scripts/__pycache__/`.
- Le registre ADR repris du gel de doctrine s'arrete a ADR-14 et enonce l'ADR-13 dans sa redaction anterieure : les regles ADR-16 et ADR-17 qui gouvernent le present fichier ne sont pas definies ici, elles le sont dans la section `2026-11-07 (late-16)` du journal de corpus. Cette zone ledger en est l'application ; une lecture de la regle complete se fait la, pas dans ce bloc fige.
- Hygiene mesuree le 2026-11-07 dans ce clone : `git check-ignore` repond hors regle (rc=1) pour `scripts/__pycache__` et `.github/actions/lecture-index/action.yml`, aucun de ces deux chemins n'existant dans ce clone, et `.gitignore` compte 12 lignes. Le defaut cite par le journal (aucune regle ignorant la sortie d'execution de l'outillage Python ni la zone `.github/actions/`) a ete mesure sur l'ancien clone de travail, pas sur celui-ci. La regle operative vaut dans tous les cas : jamais d'add global dans ce depot, uniquement des chemins explicites.
- Amendement a rendre a la Validation 5 de `TEACHING-FLEET.md` pour exclure la zone ledger definie par ADR-17 : sans lui, tout depot conforme rougit sa propre validation.
- Fait de gouvernance mesure le 2026-11-07 : `teaching-repos/TEACHING-FLEET.md` n'est versionne dans AUCUN depot du decoupage. La racine `teaching-repos/` n'est pas un depot git, et la recherche par `ls-files` repond vide dans les seize clones. Le seul fichier d'autorite flotte n'a donc ni historique, ni diff, ni revue : son amendement doit passer par une copie consignee, et sa mise en version est une decision du registre.
- Cette vague ne re-declenche aucune CI, ne bump aucun epinglement, ne cree aucun tag.

### Decisions humaines en attente

- Creer ou non une version `v1.3.46` et lancer une vague d'epinglage de flotte : decision explicite, individuelle, et hors de cette vague (gel ADR-05 en vigueur jusqu'a ordre contraire).
- Sortie du clone detruit sous repertoire temporaire : reparer, abandonner, ou considerer la preservation close par le bundle. Rien n'est repare ici.
- Repertoire d'essai de fumee cite par le journal (sous `li-smoke` dans le repertoire temporaire utilisateur) : la mesure du 2026-11-07 constate qu'il n'existe plus. Ce n'est plus un reste ; le journal doit le considerer clos, pas le recreer.
- Poussee du present commit : go-ahead humain individuel (ADR-04).

### Non negociables propres au depot

- Jamais tagguer une version sans temoin consommateur. L'ordre est : engagement, canary vert avec publication executee, puis tag, puis vague d'epinglage couplee (`uses:` et `utils-ref:` dans un meme commit, verification de la ligne de garde de publication, directive seo desactivee pour les consommateurs de profil slides), un canary a la fois.
- Ne pas confondre une panne de preparation (zero job) avec un rouge de contenu : la premiere ne produit aucun log et signe presque toujours un contrat d'input ou une longueur d'expression.
- Toute poussee : go-ahead humain individuel (ADR-04), portes fraiches avant (HEAD, `ls-remote`, avance/retard, ancetre), double lecture serveur apres, jamais `--force`, `-u`, `--tags`. Le champ de lecture d'une ref est `object.sha`, et une projection vide n'est pas une ref absente.
- Les lecons des cours ne se corrigent pas ici : ce depot ne contient que la brique partagee.

### Pointeurs

- `teaching-repos/TEACHING-FLEET.md` : regles de flotte et faits techniques stables, seule autorite.
- `Teaching/AGENTS.md` : journal d'audit, etat transverse date, preuves de bundle et de sonde, registres de decisions.
- Depuis ADR-16, le lieu durable du contexte de session de ce depot est le present fichier.
