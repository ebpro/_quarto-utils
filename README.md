# Quarto Utils - Shared Configuration Submodule

Submodule partagé pour projets Quarto avec configurations, extensions et ressources communes.

## 📦 Contenu

### Configurations Quarto
- `_quarto.yml` - Configuration de base (profiles, filtres, extensions)
- `_quarto-slides.yml` - Profile pour présentations Reveal.js
- `_quarto-notes.yml` - Profile pour documents HTML/PDF
- `_quarto-practice.yml` - Profile pour exercices pratiques

### Filtres Lua & Scripts
- `_include-tools.lua` - Injection automatique de snippets d'outils
- `_image-resolver.lua` - Résolution de slugs d'images (ex: `image: docker`)
- `move-slides.sh` - Post-processing pour déplacer slides vers `_output/_slides/`
- `scripts/gen-webp.sh` - Génération d'images WebP optimisées
- `scripts/check-images.sh` - Vérification de présence des images

### Ressources Partagées
- `MyMedia/images/optimized/` - Vignettes communes (thumbnails 400px/800px)
- `image-manifest.json` - Mappings slugs → fichiers images
- `_extensions/` - Extensions Quarto (clean, fontawesome, iconify, etc.)
- `snippets/` - Snippets réutilisables (bash, zsh, java)

### Styles & Templates
- `_variables.scss` - Variables CSS partagées
- `reveal-custom.css` - Styles pour présentations Reveal.js
- `gallery.ejs` - Template pour galeries
- `index-listing.yml` - Configuration de listings

## 🚀 Utilisation dans un nouveau projet (submodule + symlinks)

### Architecture avec submodule

Le système utilise un **submodule Git** avec des **liens symboliques** pour exposer les fichiers du submodule à la racine du projet :

```
projet/
├── .git/
├── .gitmodules                  # Configuration submodule
├── _quarto-utils/               # Submodule Git
│   ├── _quarto.yml
│   ├── _quarto-slides.yml
│   ├── _extensions/
│   └── MyMedia/
├── _quarto.yml         → _quarto-utils/_quarto.yml (symlink)
├── _quarto-slides.yml  → _quarto-utils/_quarto-slides.yml (symlink)
├── _quarto-notes.yml   → _quarto-utils/_quarto-notes.yml (symlink)
├── _extensions         → _quarto-utils/_extensions (symlink)
├── Content/
└── _output/
```

### Intégration automatique

#### 1. Ajouter le submodule et créer les symlinks

Depuis la racine de votre projet Git :

```bash
# Méthode automatique (recommandée)
bash <(curl -s https://raw.githubusercontent.com/ebpro/_quarto-utils/main/update_shared_unix.sh) \
  --repo https://github.com/ebpro/_quarto-utils.git

# OU télécharger puis exécuter
wget https://raw.githubusercontent.com/ebpro/_quarto-utils/main/update_shared_unix.sh
bash update_shared_unix.sh --repo https://github.com/ebpro/_quarto-utils.git
```

Le script effectue automatiquement :
1. `git submodule add https://github.com/ebpro/_quarto-utils.git _quarto-utils`
2. Création des liens symboliques vers :
   - `_quarto.yml`
   - `_quarto-slides.yml`
   - `_quarto-notes.yml`
   - `_extensions`
3. Backup automatique des fichiers existants (`.bak`)

#### 2. Vérifier l'installation

```bash
# Les symlinks doivent pointer vers le submodule
ls -la _quarto*.yml _extensions

# Exemple de sortie attendue :
# lrwxrwxrwx _quarto.yml -> _quarto-utils/_quarto.yml
# lrwxrwxrwx _quarto-slides.yml -> _quarto-utils/_quarto-slides.yml
# lrwxrwxrwx _extensions -> _quarto-utils/_extensions
```

#### 3. Personnaliser votre projet

Éditez les fichiers **dans le submodule** `_quarto-utils/` pour les projets avec métadonnées spécifiques, ou créez des overrides à la racine si nécessaire.

### Installation manuelle

Si vous préférez contrôler chaque étape :

```bash
# 1. Ajouter le submodule
git submodule add https://github.com/ebpro/_quarto-utils.git _quarto-utils
git submodule update --init --recursive

# 2. Créer les liens symboliques
ln -sf _quarto-utils/_quarto.yml _quarto.yml
ln -sf _quarto-utils/_quarto-slides.yml _quarto-slides.yml
ln -sf _quarto-utils/_quarto-notes.yml _quarto-notes.yml
ln -sf _quarto-utils/_extensions _extensions

# 3. Vérifier
ls -la _quarto*.yml _extensions
```

## 📸 Système de vignettes avec slugs

Les images peuvent être référencées par des slugs courts au lieu de chemins complets.

### Configuration dans le frontmatter

```yaml
---
title: "Introduction à Docker"
image: docker  # ← slug court
---
```

Au lieu de :
```yaml
image: _quarto-utils/MyMedia/images/optimized/ian-taylor-joqjbvo1p9g-unsplash-docker-400.webp
```

### Comment ça fonctionne

1. **Manifest explicite** (`image-manifest.json`) :
   ```json
   {
     "docker": {
       "400": "ian-taylor-joqjbvo1p9g-unsplash-docker-400.webp",
       "800": "ian-taylor-joqjbvo1p9g-unsplash-docker-800.webp"
     }
   }
   ```

2. **Patterns standards** : Si absent du manifest, résolution automatique :
   - `<slug>-400.webp` (prioritaire)
   - `<slug>.webp`
   - `<slug>-800.webp`

3. **Résolution Lua** : Le filtre `_image-resolver.lua` transforme le slug en chemin au moment du render.

### Ajouter une nouvelle vignette

```bash
# 1. Ajouter l'image source
cp mon-image.jpg _quarto-utils/MyMedia/images/

# 2. Générer les versions optimisées
./_quarto-utils/scripts/gen-webp.sh _quarto-utils/MyMedia/images

# 3. (Optionnel) Ajouter au manifest pour nom personnalisé
# Éditer _quarto-utils/image-manifest.json

# 4. Utiliser dans QMD
# ---
# image: mon-image
# ---
```

## 🔄 Mise à jour du submodule

### Mettre à jour vers la dernière version

```bash
# Méthode 1 : Utiliser le script
./_quarto-utils/update_shared_unix.sh --init-only

# Méthode 2 : Commandes Git manuelles
git submodule update --remote _quarto-utils
cd _quarto-utils && git pull origin main && cd ..

# Committer la nouvelle référence
git add _quarto-utils
git commit -m "Update _quarto-utils to latest version"
```

### Recréer les symlinks (si corrompus)

```bash
# Supprimer symlinks existants
rm -f _quarto.yml _quarto-slides.yml _quarto-notes.yml _extensions

# Recréer avec le script
./_quarto-utils/update_shared_unix.sh --init-only --mode link
```

### Cloner un projet avec submodules

Quand vous clonez un projet qui utilise ce submodule :

```bash
# Clone avec submodules
git clone --recursive https://github.com/vous/votre-projet.git

# OU si déjà cloné sans --recursive
git submodule update --init --recursive

# Les symlinks sont versionnés dans Git et recréés automatiquement
```

### Modifier le submodule

Si vous modifiez le contenu du submodule dans un projet :

```bash
cd _quarto-utils/
git add .
git commit -m "Update: description"
git push origin main

cd ..
git add _quarto-utils
git commit -m "Update submodule reference"
```

## 📋 Profiles disponibles

### `slides` (default)
Génère des présentations Reveal.js :
- Rend uniquement les fichiers `*_L_*.qmd`
- Slides déplacés vers `_output/_slides/`
- Format : `clean-revealjs`

```bash
quarto render --profile slides
```

### `notes`
Génère des documents HTML/PDF :
- Rend tous les fichiers QMD
- Format : HTML avec TOC, code highlighting

```bash
quarto render --profile notes
```

## 🛠️ Scripts utilitaires

### Génération d'images optimisées

```bash
# Convertir toutes les images d'un dossier
./_quarto-utils/scripts/gen-webp.sh path/to/images

# Vérifier que toutes les images ont leurs variantes optimisées
./_quarto-utils/scripts/check-images.sh path/to/images
```

### Injection de snippets d'outils

Le filtre `_include-tools.lua` injecte automatiquement des snippets selon le frontmatter :

```yaml
---
title: "Installation Docker"
tools:
  - docker
  - bash
---
```

Les snippets correspondants (`snippets/docker.qmd`, `snippets/bash.qmd`) sont automatiquement inclus.

## 📁 Structure des fichiers

```
_quarto-utils/          # Submodule Git
├── README.md           # Ce fichier
├── _quarto.yml         # Config partagée
├── _quarto-slides.yml  # Profile slides
├── _quarto-notes.yml   # Profile notes
├── _include-tools.lua  # Filtre injection snippets
├── _image-resolver.lua # Filtre résolution slugs
├── image-manifest.json # Mappings slugs
├── update_shared_unix.sh  # Script d'intégration
├── move-slides.sh      # Post-processing slides
├── _extensions/        # Extensions Quarto
│   ├── grantmcdermott/clean/
│   ├── quarto-ext/fontawesome/
│   └── ...
├── MyMedia/            # Images partagées
│   └── images/
│       ├── *.jpg       # Sources
│       └── optimized/  # WebP 400px & 800px
├── scripts/
│   ├── gen-webp.sh     # Génération images
│   └── check-images.sh # Vérification images
└── snippets/           # Snippets réutilisables
    ├── bash.qmd
    ├── zsh.qmd
    └── java.qmd
```

## ⚙️ Conventions

### Nommage des fichiers
- `*_L_*.qmd` : Lectures (slides)
- `*_T_*.qmd` : Tutoriels (notes)
- `*_D_*.qmd` : Démonstrations (notes)
- `*_C_*.qmd` : Chapitres (notes)

### Nommage des images
- Slugs : minuscules, traits d'union, pas de chiffres de taille
- Sources : `nom-descriptif_keyword.jpg`
- Optimisées : `nom-descriptif-keyword-400.webp`, `nom-descriptif-keyword-800.webp`

### Métadonnées YAML
Champs recommandés dans le frontmatter :
```yaml
---
title: "Titre du Document"
description: "Description courte"
date: last-modified
image: slug-vignette
categories: [docker, linux]
tools: [bash, docker]
---
```

## 🐛 Dépannage

### Le filtre ne résout pas les slugs

Vérifiez que le filtre est enregistré dans votre `_quarto.yml` parent :

```yaml
filters:
  - _quarto-utils/_include-tools.lua
  - _quarto-utils/_image-resolver.lua  # Si utilisé
```

### Images manquantes après render

```bash
# Vérifier que les ressources sont déclarées
grep -A5 "resources:" _quarto.yml

# Devrait inclure :
project:
  resources:
    - _quarto-utils/MyMedia/**
```

### Submodule non synchronisé

```bash
# Réinitialiser le submodule
git submodule deinit -f _quarto-utils
git submodule update --init --recursive _quarto-utils
```

## 📚 Ressources

- [Documentation Quarto](https://quarto.org/)
- [Lua Filters](https://quarto.org/docs/extensions/filters.html)
- [Reveal.js](https://revealjs.com/)
- [Git Submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules)

## 📄 Licence

CC BY-NC - Voir le fichier LICENSE du projet parent.
