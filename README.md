# skills

Every byte4day agent skill, installed from one clone.

```bash
git clone https://github.com/byte4day/skills
cd skills
./install.sh
```

Run it again any time to update. Each skill lives in its own repository; the script clones it into `repos/` (or pulls it) and runs that repository's own installer. A skill whose requirements are missing is skipped with the reason, and the rest still install.

## What you get

| Skill | Needs | What it does |
|---|---|---|
| [nummode](https://github.com/byte4day/nummode) | git, python3 | Routes installed skills for big prompts; relays work to other agent CLIs |
| [deep-research](https://github.com/byte4day/deep-research) | git, python3 | Research skill and agent with a verified source ledger |
| [copycat](https://github.com/byte4day/Copycat) | git, node 20+, npm | Inspects a UI in a real browser and rebuilds it in your stack |
| [terminal-linux](https://github.com/byte4day/terminal-linux) | git, uv | A separate Linux desktop that agents can see and control |
| [devops](https://github.com/byte4day/devops-agent) | git, python3 | Deploy, debug and roll back apps from a coding agent |
| [quranflow](https://github.com/byte4day/quranflow) | git, python3 (mpv to play) | Qur'an recitation in the background while you code |
| [product-video](https://github.com/byte4day/claude-video-skill) | claude CLI | Claude Code plugin: product or game to a QA-gated promo video |
| [bite-watch](https://github.com/byte4day/bite-watch) | git | Gets you from "what should I watch?" to watching it |
| [makeup-guide](https://github.com/byte4day/Claude-makeup-skill) | git | Interview first, then researched makeup recommendations |

## Options

| Command | Effect |
|---|---|
| `./install.sh --list` | Show the skills and which requirements are missing on this machine |
| `./install.sh nummode copycat` | Install only these |
| `./install.sh --skip copycat,quranflow` | Install everything except these |
| `./install.sh --dry-run` | Show what would run; change nothing |
| `./install.sh --with-browser` | Also download Chromium for Copycat (about 150 MB) |

The script ends with a summary. Each skill's full output is in `logs/<skill>.log`. The exit code is 1 when any skill failed.

Restart Claude Code, Cursor or Codex after installing so it loads the new skills.

## Test

```bash
bash tests/test_install.sh /path/to/a/folder/of/skill/checkouts
```

Runs the installer in a throwaway home directory against local checkouts, with no network.

## License

MIT. Each skill keeps its own license in its repository.
