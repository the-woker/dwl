{
  description = "Custom DWL fork";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};

    moldStdenv = pkgs.stdenvAdapters.useMoldLinker pkgs.stdenv;
  in {
    packages.${system}.default = (pkgs.dwl.override {stdenv = moldStdenv;}).overrideAttrs (oldAttrs: {
      pname = "dwl";
      src = ./.;
      patches = [];
    });

    devShells.${system}.default = pkgs.mkShell.override {stdenv = moldStdenv;} {
      inputsFrom = [pkgs.dwl];

      packages = with pkgs; [
        clang-tools
        bear
      ];

      shellHook = ''
        if [ ! -s compile_commands.json ] || ! grep -q "dwl.c" compile_commands.json; then
          make clean
          bear -- make && rm -f dwl *.o
        fi

        printf "CompileFlags:\n  Add:\n    - \"-DWLR_USE_UNSTABLE\"\n    - \"-I.\"\n" > .clangd
        for flag in $(pkg-config --cflags wayland-server xkbcommon libinput wlroots-0.20); do
          printf "    - \"%s\"\n" "$flag" >> .clangd
        done
        $CC -E -x c - -v < /dev/null 2>&1 \
          | awk '/#include <...> search starts here:/{flag=1;next}/End of search list./{flag=0}flag' \
          | sed 's/^ *//' \
          | while read -r dir; do
              printf "    - \"-isystem\"\n    - \"%s\"\n" "$dir" >> .clangd
            done

        printf '\n---\nIf:\n  PathMatch: .*config(\\.def)?\\.h\nDiagnostics:\n  Suppress: "*"\n' >> .clangd
      '';
    };
  };
}
