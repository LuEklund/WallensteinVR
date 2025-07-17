{
  description = "Nix devenv";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        # `nix develop`
        devShells.default = pkgs.mkShell rec {
          buildInputs = with pkgs; [
            pkg-config
            zig
            zls

            vulkan-loader
            openxr-loader
            # vulkan-validation-layers
            # vulkan-tools-lunarg
          ];

          LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath buildInputs}";
          VK_LAYER_PATH = "${pkgs.vulkan-validation-layers}/share/vulkan/explicit_layer.d";
        };
      }
    );
}
