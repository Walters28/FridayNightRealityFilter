# Friday Night Reality Filter

Local chat filter for the WoW Forever Classic beta. Version **0.1.25-beta** targets addon interface **16001**.

It filters English General and Trade channel messages about real-world politics, religion, gender-topic arguments, selected streamer chatter, and profanity. The rules are finite phrases and context checks. Game lore, ordinary trade, group recruitment, and ambiguous chat generally remain visible. An allow phrase overrides a built-in rule.

## Install

Extract the release ZIP so `FridayNightRealityFilter` sits inside `World of Warcraft/_classic_beta_/Interface/AddOns/`. It contains only `FridayNightRealityFilter.lua` and `FridayNightRealityFilter.toc`. Enable the addon and use `/reload` after updating it.

## Commands

| Command | Effect |
| --- | --- |
| `/fnrf on` / `/fnrf off` | Enable or pause filtering. |
| `/fnrf status` | Show version, state, and callback counts. |
| `/fnrf test <message>` | Classify a local example without posting it. |
| `/fnrf allow add <phrase>` / `remove <phrase>` / `list` | Manage phrases that remain visible. |
| `/fnrf block add <phrase>` / `remove <phrase>` / `list` | Manage additional phrases to hide. |
| `/fnrf review [1-10]` / `/fnrf show <number>` | Inspect hidden-message log entries locally. |
| `/fnrf capture status|start|stop|export` | Manage one local 100-message review batch. |
| `/fnrf clear` | Clear the hidden-message log. |

The log and capture are per-character SavedVariables. The capture keeps at most 100 sanitized General/Trade messages and is stored locally. No messages are sent to an external service. The addon does not post, report, or automate gameplay. SavedVariables and chat captures are not part of this repository or release ZIP.

See [CHANGELOG.md](CHANGELOG.md) for the release summary.
