{
  description = "NAHO's disks managed with disko";

  inputs = {
    disko = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/disko";
    };

    flakeUtils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    preCommitHooks = {
      inputs = {
        flake-utils.follows = "flakeUtils";
        nixpkgs-stable.follows = "preCommitHooks/nixpkgs";
        nixpkgs.follows = "nixpkgs";
      };

      url = "github:cachix/pre-commit-hooks.nix";
    };
  };

  outputs = inputs:
    inputs.flakeUtils.lib.eachDefaultSystem (
      system: let
        pkgs = inputs.nixpkgs.legacyPackages.${system};
      in {
        checks =
          (
            pkgs.lib.attrsets.concatMapAttrs
            (k: v: {"${k}Package" = v;})
            (
              pkgs.lib.attrsets.filterAttrs
              (k: _: k != "default")
              inputs.self.packages.${system}
            )
          )
          // {
            preCommitHooks = inputs.preCommitHooks.lib.${system}.run {
              hooks = {
                alejandra.enable = true;
                typos.enable = true;
                yamllint.enable = true;
              };

              settings.alejandra.verbosity = "quiet";
              src = ./.;
            };
          };

        devShells.default = pkgs.mkShell {
          inherit (inputs.self.checks.${system}.preCommitHooks) shellHook;
        };

        packages = let
          confirm = pkgs.writeShellApplication {
            name = "confirm";

            text = ''
              printf \
                '%s\n' \
                "WARNING!" \
                "========" \
                "This will overwrite data on <DEVICE> irrecoverably." \
                ""

              read \
                -p "Are you sure? (Type 'yes' in capital letters): " \
                -r \
                confirmation

              if [[ "$confirmation" != "YES" ]]; then
                printf '%s\n' "Operation aborted."
                exit 1
              fi
            '';
          };

          disko = let
            disko = inputs.disko.packages.${system}.default;

            share = pkgs.stdenv.mkDerivation {
              installPhase = ''
                mkdir --parents "$out"
                cp --recursive ./disks ./lib "$out"
              '';

              name = name "share";
              src = ./.;
            };
          in
            pkgs.writeShellApplication {
              name = name "disko";
              runtimeInputs = [disko];
              text = ''cd "${share}" && ${disko.name} "$@"'';
            };

          name = name: "disks-${name}";
        in {
          inherit disko;

          default = inputs.self.packages.${system}.disko;

          format = pkgs.writeShellApplication {
            name = name "format";
            runtimeInputs = [confirm disko];

            text = ''
              ${confirm.name} || exit

              printf '%s\n' "Consider shredding <DEVICE>."

              read -p 'Enter passphrase for <DEVICE>: ' -rs password_1
              printf '%s\n' ""
              read -p 'Verify passphrase: ' -rs password_2
              printf '%s\n' ""

              if [[ "$password_1" != "$password_2" ]]; then
                printf '%s\n' "Passphrases do not match."
                exit 2
              fi

              password_file="$(mktemp)"
              trap 'rm --force "$password_file"' EXIT
              printf '%s' "$password_1" >"$password_file"

              ${disko.name} \
                "$@" \
                --argstr passwordFile "$password_file" \
                --mode disko
            '';
          };

          mount = pkgs.writeShellApplication {
            name = name "mount";
            runtimeInputs = [disko];

            text = ''
              read -p 'Enter passphrase for <DEVICE>: ' -rs password

              password_file="$(mktemp)"
              trap 'rm --force "$password_file"' EXIT
              printf '%s' "$password" >"$password_file"

              ${disko.name} \
                "$@" \
                --argstr passwordFile "$password_file" \
                --mode mount
            '';
          };

          shred = pkgs.writeShellApplication {
            name = name "shred";
            runtimeInputs = [confirm];

            text = ''
              ${confirm.name} || exit
              shred --iterations 1 --random-source /dev/urandom --verbose "$@"
            '';
          };
        };
      }
    );
}
