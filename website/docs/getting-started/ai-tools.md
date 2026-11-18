---
title: 'AI tools'
description: 'Give AI coding assistants the current maplibre docs through llms.txt and llms-full.txt.'
icon: lucide/bot
---

# Using with AI tools

AI coding assistants often know only older versions of `maplibre`, or mix it
up with `maplibre_gl`, and suggest code that no longer compiles. This website
offers its docs as plain text for them, following the
[llms.txt](https://llmstxt.org) proposal. The files are built from these pages
every time the website is built, so they always match the docs.

| File                                                                          | Content                                                                                   |
|-------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------|
| [`llms.txt`](https://maplibre.org/flutter-maplibre/llms.txt)                  | A short summary of the API and an index of every page, with links to their Markdown.       |
| [`llms-full.txt`](https://maplibre.org/flutter-maplibre/llms-full.txt)        | Every guide, the migration guides and the contributor docs in one file.                   |
| `<page>.md`                                                                   | The Markdown of a single page: replace the trailing `/` of its URL with `.md`, for example [`docs/map.md`](https://maplibre.org/flutter-maplibre/docs/map.md). |

`llms-full.txt` is large. Assistants that fetch pages on their own work best
with `llms.txt`, from which they open only the pages they need.

## Add the docs to your assistant

Most assistants read a rules file in your project, such as `AGENTS.md`,
`CLAUDE.md`, `.cursor/rules` or `.github/copilot-instructions.md`. Add a line
that points them to the docs:

```markdown
This app uses the Flutter package `maplibre` 0.4. Before writing map code,
read https://maplibre.org/flutter-maplibre/llms.txt. Its API differs from
older versions and from maplibre_gl.
```

Assistants with a docs index, such as Cursor's `@Docs`, can also index
`https://maplibre.org/flutter-maplibre/llms-full.txt` directly.

## Migration skill

The [`maplibre-migrate`](https://github.com/maplibre/flutter-maplibre/tree/main/skills/maplibre-migrate)
skill moves an app to `maplibre` 0.4: from 0.3 or older, `maplibre_gl`,
`flutter_map`, `google_maps_flutter` or `mapbox_maps_flutter`. It tells the
assistant which [migration guide](../migrate/upgrade-from-v0.3.x.md) to read,
what to search for, and to run `dart analyze` until the code is clean.

It follows the [Agent Skills](https://agentskills.io) format. Copy the
`maplibre-migrate` folder into the skills folder of your assistant, for
example `.claude/skills/` of your project for Claude Code, and ask it to
migrate the app. The skill is also served at
[`skills/maplibre-migrate/SKILL.md`](https://maplibre.org/flutter-maplibre/skills/maplibre-migrate/SKILL.md)
for assistants that fetch it themselves.

## Tips

- Name the version you use. Code with `featuresAtPoint`, `initCenter`,
  `setStyle` or the `maplibre_android` and `maplibre_ios` packages is from 0.3
  or older; point the assistant to the
  [migration guide](../migrate/upgrade-from-v0.3.x.md).
- The [API reference](https://pub.dev/documentation/maplibre/latest/maplibre/)
  on pub.dev has every class and parameter.
- The [API guidelines](../contributing/api-guidelines.md) explain why the API
  looks the way it does, which helps when an assistant extends it or writes a
  plugin.
