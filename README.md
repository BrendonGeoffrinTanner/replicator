# replicator

Projet replicator

## Prérequis

- [Nix](https://nixos.org/) avec les flakes activés
- (optionnel) [direnv](https://direnv.net/) + [nix-direnv](https://github.com/nix-community/nix-direnv)

## Démarrage

```bash
nix develop            # ou : direnv allow
python -m replicator
pytest
```

## Ajouter une dépendance Python

Ajoute-la dans `flake.nix` (liste `python3.withPackages`) et dans `pyproject.toml`, puis relance `nix develop`.

## Licence

MIT — voir [LICENSE](LICENSE).
