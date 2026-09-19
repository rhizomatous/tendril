# A configured Ollama instance, for hosting local open models.
#
# A hook is configured to autolaunch Ollama, if it's not already running.
# If no models are installed, it will prompt the user with a set of
# sensible defaults.

{ pkgs }:
let
  models = [
    {
      id = "qwen3.5:0.8b";
      name = "Qwen 3.5 0.8B (tiny)";
    }
    {
      id = "qwen3.5:2b";
      name = "Qwen 3.5 2B (small)";
    }
    {
      id = "qwen3.5:4b";
      name = "Qwen 3.5 4B (recommended)";
    }
  ];

  opencodeModels = builtins.listToAttrs (
    map (model: {
      name = model.id;
      value = {
        inherit (model) name;
        limit = {
          context = 32768;
          output = 8192;
        };
      };
    }) models
  );

  startOllama = pkgs.writeShellApplication {
    name = "tendril-ollama-start";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.ollama
    ];
    text = ''
      if ! ollama list >/dev/null 2>&1; then
        state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/tendril"
        log_file="$state_dir/ollama.log"
        mkdir -p "$state_dir"

        echo "Starting Ollama (log: $log_file)..."
        nohup ollama serve >>"$log_file" 2>&1 &

        ready=0
        for _ in $(seq 1 60); do
          if ollama list >/dev/null 2>&1; then
            ready=1
            break
          fi
          sleep 0.25
        done

        if [ "$ready" -ne 1 ]; then
          echo "Ollama did not become ready; see $log_file." >&2
          exit 1
        fi

        echo "Ollama is ready."
      fi

      if [ -z "$(ollama list | tail -n +2 | head -n 1)" ]; then
        cat >&2 <<'EOF'
      No Ollama models are installed yet. Pull whichever size suits this machine:
        ollama pull qwen3.5:0.8b  # tiniest
        ollama pull qwen3.5:2b    # small
        ollama pull qwen3.5:4b    # recommended
      EOF
      fi
    '';
  };
in
{
  packages = [
    pkgs.ollama
    startOllama
  ];

  env = {
    OLLAMA_CONTEXT_LENGTH = "32768";
    OLLAMA_MAX_LOADED_MODELS = "1";
    OLLAMA_NUM_PARALLEL = "1";
    OPENCODE_CONFIG_CONTENT = builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";
      model = "ollama/qwen3.5:4b";
      small_model = "ollama/qwen3.5:0.8b";
      provider.ollama = {
        name = "Ollama (local)";
        npm = "@ai-sdk/openai-compatible";
        options.baseURL = "http://127.0.0.1:11434/v1";
        models = opencodeModels;
      };
    };
  };

  shellHook = ''
    if [ "''${TENDRIL_OLLAMA_SKIP_START:-0}" = "1" ]; then
      echo "Skipping automatic Ollama startup."
    else
      tendril-ollama-start
    fi

    echo "Local AI: OpenCode defaults to qwen3.5:4b; run 'ollama list' to see installed models."
  '';
}
