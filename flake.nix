{
  description = "This the first assignment for '1ZK40 Entrepreneurship in action: business development' course.";

  inputs = {

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";

    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs = {
        flake-compat.follows = "flake-compat";
        nixpkgs.follows = "nixpkgs";
      };
    };

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-utils,
      treefmt-nix,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        treefmtEval = treefmt-nix.lib.evalModule pkgs ./.config/treefmt.nix;
        pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run (import ./.config/pre-commit.nix pkgs);
      in
      rec {
        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Nix Develop ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

        devShells.default = pkgs.mkShell {
          extraShellHook = pre-commit-check.shellHook;
          buildInputs =
            pre-commit-check.enabledPackages
            ++ (with pkgs; [
              act # Run / check GitHub Actions locally.
              git # Pull, commit, and push changes.
              zathura # for live reloading of the PDF as you write it.
              texliveFull # compile the document
            ]);
        };

        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Nix Build ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

        packages = rec {
          default = document;
          document = pkgs.stdenv.mkDerivation rec {
            name = "assignment-1-document";
            src = ./src;

            buildInputs = with pkgs; [ texliveFull ];

            assignment = ./share/assignment.pdf;

            buildPhase = ''
              runHook preBuild

              echo "Using: $(pdflatex -version)"

              pdflatex --interaction=nonstopmode --file-line-error --output-directory=. ./main.tex \
                --draftmode 1> /dev/null || true

              pdflatex --interaction=nonstopmode --file-line-error --output-directory=. ./main.tex \
                --halt-on-error || true

              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall

              mkdir --parents $out/share/doc
              cp ./main.pdf $out/share/doc/deliverable.pdf
              cp ${assignment} $out/share/assignment.pdf

              runHook postInstall
            '';
          };
        };

        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Nix Flake Check ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

        checks = packages // {
          formatting = treefmtEval.config.build.check self;
          inherit pre-commit-check;
        };

        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Nix Fmt ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

        formatter = treefmtEval.config.build.wrapper;

        # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #
      }
    );
}
