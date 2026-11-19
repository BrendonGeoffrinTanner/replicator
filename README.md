# replicator

> *"Tea, Earl Grey, hot."* — Picard au réplicateur. Ici : un projet Python, Nix flake, Git et GitHub, à la demande.

Un script Bash — un réplicateur de projets, comme dans *Star Trek* — qui génère en quelques secondes un projet Python **reproductible** (environnement [Nix flake](https://nixos.wiki/wiki/Flakes)), initialisé avec Git et, si tu le souhaites, publié sur GitHub.

Tu réponds à deux questions (nom, description) ; le script crée l'arborescence, fige les versions de `nixpkgs`, fait le commit initial et peut créer le dépôt distant.

## Ce qui est généré

```text
mon-projet/
├── flake.nix            # shell de dev : Python, pytest, ruff
├── flake.lock           # versions figées de nixpkgs (si Nix est installé)
├── .envrc               # `use flake` pour direnv
├── pyproject.toml       # métadonnées, config pytest et ruff
├── src/mon_projet/
│   ├── __init__.py
│   └── __main__.py      # python -m mon_projet
├── tests/test_basic.py
├── README.md
├── LICENSE              # MIT, avec ton nom (git config user.name) et l'année
└── .gitignore
```

## Prérequis

| Outil | Rôle | Obligatoire |
|---|---|---|
| `bash` ≥ 3.2 | Exécuter le script (compatible macOS et Linux) | Oui |
| `git` | Initialiser le dépôt et faire le commit | Oui |
| [Nix](https://nixos.org/) avec flakes | Générer `flake.lock` et utiliser `nix develop` | Non, mais nécessaire pour utiliser le projet généré |
| [GitHub CLI (`gh`)](https://cli.github.com/) | Créer et pousser le dépôt automatiquement | Non (sinon, instructions manuelles affichées) |

## Utilisation

```bash
git clone https://github.com/<ton-utilisateur>/replicator.git
cd replicator
chmod +x replicator.sh   # si nécessaire

./replicator.sh                  # mode interactif
./replicator.sh "Mon Super Projet"   # nom passé en argument
./replicator.sh --help
```

Déroulé :

1. Le nom est converti en *slug* (`Mon Super Projet` → `mon-super-projet`) et en nom de package Python (`mon_super_projet`, préfixé par `p_` s'il commence par un chiffre).
2. Les fichiers sont générés dans `./<slug>`.
3. Le dépôt Git est initialisé sur la branche `main`, `flake.lock` est créé, puis le commit initial est fait.
4. Si `gh` est installé et authentifié (`gh auth login`), le script propose de créer le dépôt GitHub (public ou privé) et de pousser. Sinon, il affiche les commandes à exécuter à la main.

Ensuite :

```bash
cd mon-super-projet
nix develop        # ou : direnv allow
python -m mon_super_projet
pytest
```

## Comportement et garde-fous

- **Aucun écrasement** : si le dossier cible existe déjà, le script s'arrête sans rien modifier.
- **Nettoyage automatique** : si la génération échoue ou est interrompue (Ctrl-C), le dossier partiellement créé est supprimé.
- **Saisies sûres** : la description et le nom d'auteur peuvent contenir des guillemets, des `&`, des `\` ou des `${}` ; ils sont échappés selon le format cible (Nix, TOML, docstring Python).
- **Dégradation douce** : sans Nix, sans `gh` ou sans identité Git configurée, le script continue et indique ce qu'il reste à faire.

## Personnaliser les modèles

Chaque fichier généré est un *heredoc* dans `replicator.sh`. Les marqueurs suivants y sont remplacés :

| Marqueur | Valeur | Usage |
|---|---|---|
| `@NAME@` | slug du projet | noms, titres, textes |
| `@PKG@` | nom de package Python | imports |
| `@DESC@` | description brute | README, texte libre |
| `@DESC_Q@` | description échappée `\` et `"` | TOML, docstring Python |
| `@DESC_NIX@` | description échappée pour Nix | `flake.nix` |
| `@AUTHOR@` / `@AUTHOR_Q@` | auteur brut / échappé | LICENSE / TOML |
| `@YEAR@` | année courante | LICENSE |

Quelques réglages fréquents :

- **Version de nixpkgs** : modifie `nixpkgs.url` dans le modèle `flake.nix` (actuellement `nixos-26.05`). Une branche stable n'est maintenue que quelques mois : vérifie-la de temps en temps.
- **Dépendances de départ** : décommente ou ajoute-les dans la liste `python3.withPackages` du modèle, et dans `dependencies` de `pyproject.toml`.
- **Autre licence** : remplace le modèle `LICENSE` et le champ `license` de `pyproject.toml` (identifiant [SPDX](https://spdx.org/licenses/)).

## Dépannage

- **`flake.nix` introuvable par Nix** : un flake ne voit que les fichiers suivis par Git. Le script exécute `git add -A` avant `nix flake lock` ; si tu ajoutes un fichier plus tard, fais `git add` avant `nix develop`.
- **`flake.lock` non généré** : Nix est absent ou le réseau indisponible. Lance `nix flake lock` plus tard, puis commit le fichier.
- **Commit impossible** : configure ton identité (`git config --global user.name` et `user.email`), puis `git commit`.
- **Caractères accentués dans le nom** : ils ne sont pas translittérés (`Été` donne `t`). Choisis un nom en ASCII si tu veux un slug précis.
- **x86_64-darwin** : cette plateforme est conservée dans le `flake.nix` généré, mais nixpkgs 26.05 est la dernière version à la supporter.

## Contribuer

Les issues et pull requests sont bienvenues. Avant de proposer une modification, vérifie le script avec :

```bash
bash -n replicator.sh
shellcheck replicator.sh
```

## Licence

MIT. Ajoute un fichier `LICENSE` à la racine du dépôt (GitHub propose un modèle à la création).
