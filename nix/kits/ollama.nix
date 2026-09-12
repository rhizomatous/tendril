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

  modelIds = map (model: model.id) models;

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
      if ollama list >/dev/null 2>&1; then
        exit 0
      fi

      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/tendril"
      log_file="$state_dir/ollama.log"
      mkdir -p "$state_dir"

      echo "Starting Ollama (log: $log_file)..."
      nohup ollama serve >>"$log_file" 2>&1 &

      for _ in $(seq 1 60); do
        if ollama list >/dev/null 2>&1; then
          echo "Ollama is ready."
          exit 0
        fi
        sleep 0.25
      done

      echo "Ollama did not become ready; see $log_file." >&2
      exit 1
    '';
  };

  setupOllama = pkgs.writeShellApplication {
    name = "tendril-ollama-setup";
    runtimeInputs = [
      pkgs.ollama
      startOllama
    ];
    text = ''
      if ! tendril-ollama-start; then
        echo "Skipping model setup because Ollama is unavailable." >&2
        exit 0
      fi

      pull_failed=0
      for model in ${pkgs.lib.escapeShellArgs modelIds}; do
        if ollama show "$model" >/dev/null 2>&1; then
          continue
        fi

        echo "Pulling $model..."
        if ! ollama pull "$model"; then
          echo "Could not pull $model; run 'tendril-ollama-setup' to retry." >&2
          pull_failed=1
        fi
      done

      if [ "$pull_failed" -ne 0 ]; then
        echo "The shell is available, but one or more local models are missing." >&2
      else
        echo "Local AI models are ready."
      fi
    '';
  };
in
{
  packages = [
    pkgs.ollama
    startOllama
    setupOllama
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
    if [ "''${TENDRIL_OLLAMA_SKIP_SETUP:-0}" = "1" ]; then
      echo "Skipping automatic Ollama setup."
    else
      tendril-ollama-setup
    fi

    echo "Local AI: opencode uses qwen3.5:4b; run 'ollama list' to see all models."
  '';
}
