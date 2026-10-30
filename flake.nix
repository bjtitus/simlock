{
  description = "Simlock leases iOS simulators, Android emulators and enrolled phones to coding agents";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAll (pkgs: rec {
        simlock = pkgs.callPackage ./nix/package.nix { };
        default = simlock;
      });

      apps = forAll (pkgs: rec {
        simlock = {
          type = "app";
          program = "${self.packages.${pkgs.system}.simlock}/bin/simlock";
        };
        default = simlock;
      });

      # why: the checkout's own toolchain, for anyone who hacks on Simlock from a Nix shell;
      # the package above wraps the npm release and never builds this tree.
      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.nodejs_22
            pkgs.pnpm_11
            pkgs.jq
          ];
        };
      });
    };
}
