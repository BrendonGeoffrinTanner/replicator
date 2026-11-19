#!/usr/bin/env bash
# replicator.sh — Matérialise à la demande un projet Python (Nix flake) prêt à être poussé sur GitHub.
#
# Usage : ./replicator.sh [nom-du-projet]
#         ./replicator.sh -h | --help
set -euo pipefail

# Bash 5.2+ traite '&' comme « motif trouvé » dans le remplacement de ${var//a/b}.
# On désactive ce comportement pour que les valeurs saisies restent littérales.
shopt -u patsub_replacement 2>/dev/null || true

# ───────────────────────── Utilitaires ─────────────────────────
if [[ -t 1 && -t 2 ]]; then
  c_ok=$'\033[1;32m'; c_warn=$'\033[1;33m'; c_err=$'\033[1;31m'; c_off=$'\033[0m'
else
  c_ok=''; c_warn=''; c_err=''; c_off=''
fi
ok()   { printf '%s✔%s %s\n' "$c_ok" "$c_off" "$*"; }
warn() { printf '%s!%s %s\n' "$c_warn" "$c_off" "$*" >&2; }
die()  { printf '%s✘%s %s\n' "$c_err" "$c_off" "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
replicator.sh — Matérialise à la demande un projet Python (Nix flake) prêt à être poussé sur GitHub.

Usage :
  ./replicator.sh [nom-du-projet]
  ./replicator.sh -h | --help

Sans argument, le nom du projet est demandé de façon interactive.
EOF
}

# Échappe \ et " pour une chaîne entre guillemets (TOML, docstring Python).
esc_dq() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  printf '%s' "$s"
}

# Idem, plus « ${ » (interpolation Nix), pour une chaîne Nix entre guillemets.
esc_nix() {
  local s from='${' to='\${'
  s="$(esc_dq "$1")"
  s=${s//"$from"/$to}
  printf '%s' "$s"
}

# Remplace les marqueurs @XXX@ lus sur stdin par la valeur des variables.
# Les valeurs saisies par l'utilisateur sont substituées en dernier : le texte
# inséré n'est jamais ré-analysé (un « @NAME@ » dans une description reste intact).
render() {
  local content; content="$(cat)"
  content=${content//@NAME@/$NAME}
  content=${content//@PKG@/$PKG}
  content=${content//@YEAR@/$YEAR}
  content=${content//@AUTHOR_Q@/$AUTHOR_Q}
  content=${content//@AUTHOR@/$AUTHOR}
  content=${content//@DESC_Q@/$DESC_Q}
  content=${content//@DESC_NIX@/$DESC_NIX}
  content=${content//@DESC@/$DESC}
  printf '%s\n' "$content"
}

# Supprime le dossier à moitié généré si le script échoue pendant la génération.
PROJECT_DIR=""
GENERATED=0
cleanup() {
  if [[ "$GENERATED" -eq 0 && -n "$PROJECT_DIR" && -d "$PROJECT_DIR" ]]; then
    cd / && rm -rf -- "$PROJECT_DIR"
    warn "Génération interrompue : « $PROJECT_DIR » a été supprimé."
  fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  -*) usage >&2; die "Option inconnue : $1" ;;
esac

command -v git >/dev/null || die "git est introuvable (ajoute-le à ton environnement)."

# ───────────────────────── Questions ─────────────────────────
if [[ -n "${1:-}" ]]; then
  RAW_NAME="$1"
else
  read -r -p "Nom du projet : " RAW_NAME || die "Saisie interrompue."
fi
[[ -n "${RAW_NAME// /}" ]] || die "Le nom du projet ne peut pas être vide."

# Slug : minuscules, séparateurs → '-', sans tirets en bord (ex : "Mon Super Projet" → mon-super-projet)
# Les caractères accentués ne sont pas translittérés : ils sont traités comme des séparateurs.
NAME="$(printf '%s' "$RAW_NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
[[ -n "$NAME" ]] || die "Le nom ne contient aucun caractère exploitable (a-z, 0-9)."

# Nom de package Python : un identifiant valide (tirets → underscores, pas de chiffre initial)
PKG="${NAME//-/_}"
if [[ "$PKG" =~ ^[0-9] ]]; then PKG="p_${PKG}"; fi

read -r -p "Description courte (Entrée pour ignorer) : " DESC || DESC=""
DESC="${DESC:-Projet $NAME}"

AUTHOR="$(git config user.name 2>/dev/null || true)"
AUTHOR="${AUTHOR:-${USER:-auteur}}"
YEAR="$(date +%Y)"

# Variantes échappées pour les formats qui exigent des chaînes entre guillemets.
DESC_Q="$(esc_dq "$DESC")"
DESC_NIX="$(esc_nix "$DESC")"
AUTHOR_Q="$(esc_dq "$AUTHOR")"

[[ -e "$NAME" ]] && die "Le dossier « $NAME » existe déjà ici. Rien n'a été modifié."

# ───────────────────────── Arborescence ─────────────────────────
PROJECT_DIR="$PWD/$NAME"
mkdir -p "$NAME/src/$PKG" "$NAME/tests"
cd "$NAME"

# ── flake.nix : environnement de développement reproductible ──
render > flake.nix <<'EOF'
{
  description = "@DESC_NIX@";

  inputs = {
    # Branche stable. Remplace par "github:NixOS/nixpkgs/nixos-unstable" pour des versions plus récentes.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = { self, nixpkgs }:
    let
      # Note : x86_64-darwin n'est plus supporté à partir de nixpkgs 26.11.
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f:
        nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            (pkgs.python3.withPackages (ps: with ps; [
              # ── Dépendances Python du projet (à compléter) ──
              # requests
              # numpy

              # ── Outils de dev ──
              pytest
            ]))
            pkgs.ruff
          ];

          # Rend le package importable depuis src/ sans installation.
          shellHook = ''
            export PYTHONPATH="$PWD/src''${PYTHONPATH:+:$PYTHONPATH}"
            echo "🐍 @NAME@ — $(python --version)"
          '';
        };
      });
    };
}
EOF

# ── direnv : entrée automatique dans le shell Nix (optionnel) ──
printf 'use flake\n' > .envrc

# ── pyproject.toml ──
render > pyproject.toml <<'EOF'
[build-system]
requires = ["setuptools>=77"]
build-backend = "setuptools.build_meta"

[project]
name = "@NAME@"
version = "0.1.0"
description = "@DESC_Q@"
readme = "README.md"
requires-python = ">=3.10"
license = "MIT"
license-files = ["LICENSE"]
authors = [{ name = "@AUTHOR_Q@" }]
dependencies = [
    # À synchroniser avec flake.nix
]

[tool.setuptools.packages.find]
where = ["src"]

[tool.pytest.ini_options]
pythonpath = ["src"]
testpaths = ["tests"]

[tool.ruff]
line-length = 100
EOF

# ── Code source et test d'exemple ──
render > "src/$PKG/__init__.py" <<'EOF'
"""@DESC_Q@"""

__version__ = "0.1.0"
EOF

render > "src/$PKG/__main__.py" <<'EOF'
"""Point d'entrée : python -m @PKG@"""


def main() -> None:
    print("Bonjour depuis @NAME@ !")


if __name__ == "__main__":
    main()
EOF

render > tests/test_basic.py <<'EOF'
import @PKG@


def test_version():
    assert @PKG@.__version__ == "0.1.0"
EOF

# ── README.md ──
render > README.md <<'EOF'
# @NAME@

@DESC@

## Prérequis

- [Nix](https://nixos.org/) avec les flakes activés
- (optionnel) [direnv](https://direnv.net/) + [nix-direnv](https://github.com/nix-community/nix-direnv)

## Démarrage

```bash
nix develop            # ou : direnv allow
python -m @PKG@
pytest
```

## Ajouter une dépendance Python

Ajoute-la dans `flake.nix` (liste `python3.withPackages`) et dans `pyproject.toml`, puis relance `nix develop`.

## Licence

MIT — voir [LICENSE](LICENSE).
EOF

# ── LICENSE (MIT) ──
render > LICENSE <<'EOF'
MIT License

Copyright (c) @YEAR@ @AUTHOR@

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

# ── .gitignore ──
cat > .gitignore <<'EOF'
# Python
__pycache__/
*.py[cod]
*.egg-info/
build/
dist/
.pytest_cache/
.ruff_cache/
.mypy_cache/
.venv/
venv/

# Nix / direnv
.direnv/
result
result-*

# Secrets & environnement local
.env
.env.*

# Éditeurs / OS
.vscode/
.idea/
*.swp
.DS_Store
EOF

GENERATED=1
ok "Fichiers générés dans ./$NAME"

# ───────────────────────── Git + verrouillage Nix ─────────────────────────
git init -q
git symbolic-ref HEAD refs/heads/main   # équivalent de « git init -b main », compatible avec les vieux git
git add -A   # indispensable : un flake ne « voit » que les fichiers suivis par git

if command -v nix >/dev/null; then
  if nix --extra-experimental-features 'nix-command flakes' flake lock 2>/dev/null; then
    git add flake.lock
    ok "flake.lock généré (versions de nixpkgs figées)"
  else
    warn "Impossible de générer flake.lock (réseau ?). Lance « nix flake lock » plus tard."
  fi
else
  warn "nix introuvable : flake.lock non généré."
fi

COMMITTED=0
if git commit -q -m "Initial commit"; then
  COMMITTED=1
  ok "Commit initial créé sur la branche main"
else
  warn "Commit impossible (identité git non configurée ?). Les fichiers restent indexés."
fi

# ───────────────────────── Publication GitHub ─────────────────────────
print_manual_steps() {
  cat <<EOF

Pour publier sur GitHub :
  1. Crée un dépôt VIDE « $NAME » sur https://github.com/new (sans README ni licence)
  2. cd $NAME
     git remote add origin git@github.com:<ton-utilisateur>/$NAME.git
     git push -u origin main
EOF
}

if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  if [[ "$COMMITTED" -eq 1 ]]; then
    read -r -p "Créer et pousser le dépôt sur GitHub maintenant ? [p]ublic / p[r]ivé / [N]on : " CHOICE || CHOICE=""
    CHOICE="$(printf '%s' "$CHOICE" | tr '[:upper:]' '[:lower:]')"
    VIS=""
    case "$CHOICE" in
      p|public)                VIS="--public" ;;
      r|prive|privé|private)   VIS="--private" ;;
    esac
    if [[ -n "$VIS" ]]; then
      if gh repo create "$NAME" "$VIS" --source=. --remote=origin --description "$DESC" --push; then
        ok "Dépôt publié sur GitHub"
      else
        warn "Échec de gh repo create."
        print_manual_steps
      fi
    fi
  else
    warn "Pas de commit initial : publication GitHub ignorée."
    print_manual_steps
  fi
else
  print_manual_steps
fi

printf '\nTerminé. Engage : cd %s && nix develop\n' "$NAME"
