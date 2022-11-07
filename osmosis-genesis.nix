{pkgs}:
pkgs.fetchgit {
  url = "https://github.com/osmosis-labs/networks";
  sha256 = "sha256-8ezmc3j9rgOYf6S9PaLzPCgYUzbZX5Kd/xUmZws3Vgo=";
  fetchLFS = true;
}
