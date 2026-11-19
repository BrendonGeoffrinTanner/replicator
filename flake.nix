{
  description = "Projet replicator";

  inputs = {
    # Branche stable : remplace par "github:NixOS/nixpkgs/nixos-unstable" pour des versions plus récentes.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs }:
    let
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
            echo "🐍 replicator — $(python --version)"
          '';
        };
      });
    };
}
