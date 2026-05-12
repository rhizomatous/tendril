# the python dev environment, expressed as a reusable `kit`.

{ pkgs }:
{
  # tools globally available on PATH inside the shell.
  #
  packages = with pkgs; [
    python314 # interpreter, pinned
    uv # package & env manager
    pyright # language server
    ruff # formatter & linter
  ];

  # `UV_PYTHON_DOWNLOADS=never` pins uv to the nix-provided python and
  # blocks it from silently fetching its own interpreter from astral's CDN.
  env = {
    UV_PYTHON_DOWNLOADS = "never";
  };
}
