# the ide kit: the configured nvim derivation. composed into each
# tendril shell & image that opts in by `mkComposer`.
#
# shape: `{ nixvim } -> { pkgs } -> kit`. takes nixvim once at lib-init
# time, then `pkgs` per-system at composition time.
#
# the bulk of this file is `nixvimModule`: tendril's nvim configuration as
# a nixvim module. see https://nix-community.github.io/nixvim/ for option
# docs.

{ nixvim }:

{ pkgs }:
let
  # nixpkgs treats the unfree Copilot LSP as an unconditional runtime dependency of
  # Sidekick. We don't want that.
  sidekick = pkgs.vimPlugins.sidekick-nvim.overrideAttrs (_: {
    runtimeDeps = [ ];
  });

  nixvimModule = {
    colorschemes.dracula.enable = true;

    globals.mapleader = " ";

    # The pinned nixvim Sidekick module incorrectly checks
    # `settings.opts.nes.enabled`, but Sidekick expects `nes.enabled` at the
    # top level. So we have to register and configure it directly.
    extraPlugins = [ sidekick ];
    extraConfigLua = ''
      require("sidekick").setup({
        -- Next-edit suggestions require Copilot; tendril uses Sidekick only
        -- for its AI CLI integration.
        nes = { enabled = false },
        cli = {
          win = {
            layout = "right",
            split = { width = 72 },
          },
        },
      })
    '';

    opts = {
      number = true;
      relativenumber = true;
      expandtab = true;
      shiftwidth = 2;
      tabstop = 2;
      smartindent = true;
      wrap = false;
      swapfile = false;
      backup = false;
      undofile = true;
      hlsearch = true;
      incsearch = true;
      termguicolors = true;
      scrolloff = 8;
      signcolumn = "yes";
      updatetime = 50;
    };

    plugins = {
      # snacks.nvim: folke's swiss-army of QoL features (dashboard, picker,
      # notifier, indent guides, scope, statuscolumn, terminal).
      snacks = {
        enable = true;
        settings = {
          bigfile.enabled = true;
          dashboard = {
            enabled = true;
            # override the default key list. defaults included Config, which
            # opens `vim.fn.stdpath('config')`, which points at the user's
            # *system* nvim config.
            preset.keys = [
              {
                icon = " ";
                key = "f";
                desc = "Find File";
                action = ":lua Snacks.dashboard.pick('files')";
              }
              {
                icon = " ";
                key = "n";
                desc = "New File";
                action = ":ene | startinsert";
              }
              {
                icon = " ";
                key = "g";
                desc = "Find Text";
                action = ":lua Snacks.dashboard.pick('live_grep')";
              }
              {
                icon = " ";
                key = "r";
                desc = "Recent Files";
                action = ":lua Snacks.dashboard.pick('oldfiles')";
              }
              {
                icon = " ";
                key = "q";
                desc = "Quit";
                action = ":qa";
              }
            ];
            # snacks's default dashboard includes a `startup` section with
            # `require('lazy.stats')`, which fails because we're nix-managed
            # not lazy.nvim. so, drop that one.
            sections = [
              { section = "header"; }
              {
                section = "keys";
                gap = 1;
                padding = 1;
              }
              {
                icon = " ";
                title = "Recent Files";
                section = "recent_files";
                indent = 2;
                padding = 1;
              }
              {
                icon = " ";
                title = "Projects";
                section = "projects";
                indent = 2;
                padding = 1;
              }
            ];
          };
          indent.enabled = true;
          notifier.enabled = true;
          picker.enabled = true;
          scope.enabled = true;
          scroll.enabled = true;
          statuscolumn.enabled = true;
          terminal.enabled = true;
        };
      };

      # blink.cmp: rust-backed completion, much faster than nvim-cmp.
      blink-cmp.enable = true;

      treesitter = {
        enable = true;
        settings = {
          highlight.enable = true;
          indent.enable = true;
        };
      };

      # LSP auto-attach for the language servers tendril ships in its language
      # kits. servers only attach when the binary is on PATH. opening a
      # `.go` file in the typescript shell won't try to run gopls.
      lsp = {
        enable = true;
        servers = {
          gopls.enable = true;
          nil_ls.enable = true;
          pyright.enable = true;
          rust_analyzer = {
            enable = true;
            # rustc & cargo come from the rust language kit, on PATH. tell
            # nixvim not to bring its own copies into the closure.
            installCargo = false;
            installRustc = false;
          };
          ts_ls.enable = true;
        };
      };

      lualine.enable = true;
      gitsigns.enable = true;
      nvim-autopairs.enable = true;
      ts-autotag.enable = true;
      bufferline.enable = true;
      which-key.enable = true;
      web-devicons.enable = true;

      # conform.nvim: format-on-save with our shipped formatters.
      conform-nvim = {
        enable = true;
        settings = {
          formatters_by_ft = {
            nix = [ "nixfmt" ];
            go = [
              "goimports"
              "gofmt"
            ];
            python = [
              "ruff_organize_imports"
              "ruff_format"
            ];
            rust = [ "rustfmt" ];
            javascript = [ "prettier" ];
            typescript = [ "prettier" ];
            javascriptreact = [ "prettier" ];
            typescriptreact = [ "prettier" ];
          };
          format_on_save = {
            timeout_ms = 500;
            lsp_format = "fallback";
          };
        };
      };

      # mini.nvim: selected modules from echasnovski's curated bundle.
      mini = {
        enable = true;
        modules = {
          surround = { };
          comment = { };
          ai = { };
        };
      };
    };

    keymaps = [
      # snacks pickers
      {
        mode = "n";
        key = ";f";
        action = ":lua Snacks.picker.files()<CR>";
        options.desc = "find files";
      }
      {
        mode = "n";
        key = ";r";
        action = ":lua Snacks.picker.grep()<CR>";
        options.desc = "live grep";
      }
      {
        mode = "n";
        key = ";b";
        action = ":lua Snacks.picker.buffers()<CR>";
        options.desc = "buffers";
      }

      # sidekick / opencode
      {
        mode = [
          "n"
          "t"
          "i"
          "x"
        ];
        key = "<C-.>";
        action.__raw = ''function() require("sidekick.cli").focus() end'';
        options.desc = "focus sidekick";
      }
      {
        mode = "n";
        key = "<leader>aa";
        action.__raw = ''function() require("sidekick.cli").toggle({ name = "opencode", focus = true }) end'';
        options.desc = "toggle opencode";
      }
      {
        mode = "n";
        key = "<leader>as";
        action.__raw = ''function() require("sidekick.cli").select({ filter = { installed = true } }) end'';
        options.desc = "select AI CLI";
      }
      {
        mode = "n";
        key = "<leader>ad";
        action.__raw = ''function() require("sidekick.cli").close() end'';
        options.desc = "detach AI CLI session";
      }
      {
        mode = [
          "n"
          "x"
        ];
        key = "<leader>at";
        action.__raw = ''function() require("sidekick.cli").send({ msg = "{this}" }) end'';
        options.desc = "send this to AI CLI";
      }
      {
        mode = "n";
        key = "<leader>af";
        action.__raw = ''function() require("sidekick.cli").send({ msg = "{file}" }) end'';
        options.desc = "send file to AI CLI";
      }
      {
        mode = "x";
        key = "<leader>av";
        action.__raw = ''function() require("sidekick.cli").send({ msg = "{selection}" }) end'';
        options.desc = "send selection to AI CLI";
      }
      {
        mode = [
          "n"
          "x"
        ];
        key = "<leader>ap";
        action.__raw = ''function() require("sidekick.cli").prompt() end'';
        options.desc = "select AI prompt";
      }

      # bufferline cycling.
      {
        mode = "n";
        key = "<leader>bn";
        action = "<cmd>BufferLineCycleNext<cr>";
        options.desc = "next buffer";
      }
      {
        mode = "n";
        key = "<leader>bp";
        action = "<cmd>BufferLineCyclePrev<cr>";
        options.desc = "prev buffer";
      }

      # quick save / quit.
      {
        mode = "n";
        key = "<leader>w";
        action = "<cmd>w<cr>";
        options.desc = "save";
      }
      {
        mode = "n";
        key = "<leader>q";
        action = "<cmd>q<cr>";
        options.desc = "quit";
      }
    ];
  };

  nvim = nixvim.legacyPackages.${pkgs.system}.makeNixvimWithModule {
    inherit pkgs;
    module = nixvimModule;
  };
in
{
  packages = [ nvim ];
}
