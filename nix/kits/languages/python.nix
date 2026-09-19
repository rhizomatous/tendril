# The Python dev environment.

{ pkgs }:
{
  packages = with pkgs; [
    python314 # interpreter
    uv # package & env manager
    pyright # language server
    ruff # formatter & linter
  ];

  # `UV_PYTHON_DOWNLOADS=never` pins `uv` to the Nix-provided `python` and
  # blocks it from silently fetching its own interpreter.
  env = {
    UV_PYTHON_DOWNLOADS = "never";
  };
}
