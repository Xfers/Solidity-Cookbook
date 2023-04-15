{ pkgs ? import <nixpkgs> {} }:

let
  nodejs = pkgs.nodejs-19_x;
in
pkgs.mkShell {
  buildInputs = [
    pkgs.nodejs-19_x
    pkgs.python3
    pkgs.gnumake
    pkgs.gcc
    pkgs.git
    pkgs.curl
    pkgs.nodePackages.ganache
  ];

  shellHook = ''
    export PATH="$PATH:${nodejs}/bin"
    export GANACHE_PORT=7545
    export GANACHE_DB_PATH=./tmp/ganache_data
    export GANACHE_MNEMONIC="diesel sunset host claim much rack hurdle want obscure slab auto member"
    export GANACHE_NETWORK_ID=5777

    mkdir -p "$GANACHE_DB_PATH"

    ganache_start() {
      ganache-cli --port="$GANACHE_PORT" --db="$GANACHE_DB_PATH" --mnemonic="$GANACHE_MNEMONIC" --networkId="$GANACHE_NETWORK_ID"
    }
  '';
}
