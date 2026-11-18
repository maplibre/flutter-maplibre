#!/usr/bin/env python3
"""Writes llms.txt, llms-full.txt and a Markdown copy of every page.

Run after `zensical build` from the repository root. It reads the nav of
`mkdocs.yml` and writes into the built site (`site/` by default):

- `<page>.md`: the Markdown source of each page, with relative links made
  absolute, next to its HTML page.
- `llms.txt`: an index of the docs with a link to each Markdown copy, as
  proposed on https://llmstxt.org.
- `llms-full.txt`: the getting started pages, guides, the current migration
  guides and the contributor docs in one file.
"""

from __future__ import annotations

import posixpath
import re
import sys
from dataclasses import dataclass
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]

# Nav sections and pages listed under "Optional" in llms.txt and left out of
# llms-full.txt: guides for old versions and the comparison with other
# packages. The landing page is left out of both.
OPTIONAL_SECTIONS = {"Older versions"}
OPTIONAL_PAGES = {"compare/index.md"}
EXCLUDED_PAGES = {"index.md"}

INTRO = """\
`maplibre` is a Flutter package for interactive vector maps on Android, iOS,
macOS, Windows, Linux and web. Apps import only `package:maplibre`; it renders
through Flutter's `Texture` widget on every platform except web, which uses
MapLibre GL JS.

Notes for writing code with `maplibre` 0.4:

- 0.4 has breaking changes against 0.3 and older. Code that uses
  `featuresAtPoint`, `MapOptions(initCenter: …)`, `setStyle`, string styles
  or the `maplibre_android`, `maplibre_ios` or webview packages is outdated;
  see the migration guide.
- Annotation layers (`CircleLayer`, `MarkerLayer`, `PolylineLayer`,
  `PolygonLayer`) and `MapLibreMap` parameters are declarative: change them
  with `setState()`. Style layers and sources are imperative: add and change
  them through `StyleController` (`style.layers`, `style.sources`), for
  example in `onStyleLoaded`.
- Variants are sealed classes with named constructors: `MapStyle.url`,
  `CameraUpdate.position`, `CameraAnimation.fly`, `QueryGeometry.point`,
  `GeoJsonData.featureCollection`, `MarkerIcon.asset` and others.
- Style layer properties and filters are typed `Expression<T>` values.
- Geographic types come from `geobase` (`Geographic`, `GeoBox`, `Feature`),
  re-exported by `maplibre`.
"""


@dataclass
class Page:
    title: str
    path: str  # relative to docs_dir, e.g. "docs/map.md"
    section: str


class _Loader(yaml.SafeLoader):
    """Reads mkdocs.yml, ignoring its `!!python/…` tags."""


_Loader.add_multi_constructor("tag:yaml.org,2002:python/", lambda *_: None)


def _walk(nav: list, section: str, pages: list[Page]) -> None:
    for item in nav:
        if isinstance(item, str):
            pages.append(Page(item, item, section))
            continue
        for title, value in item.items():
            if isinstance(value, list):
                _walk(value, title, pages)
            elif isinstance(value, str) and value.endswith(".md"):
                pages.append(Page(title, value, section))


def _split_front_matter(text: str) -> tuple[dict, str]:
    if text.startswith("---\n"):
        end = text.find("\n---\n", 4)
        if end != -1:
            meta = yaml.safe_load(text[4:end]) or {}
            return meta, text[end + 5 :].lstrip("\n")
    return {}, text


_LINK = re.compile(r"(\]\()([^)\s]+)(\))")


def _absolute_links(body: str, page_path: str, site_url: str) -> str:
    base = posixpath.dirname(page_path)

    def replace(match: re.Match) -> str:
        target = match.group(2)
        if re.match(r"^[a-z][a-z0-9+.-]*:|^#|^/", target):
            return match.group(0)
        path, _, anchor = target.partition("#")
        resolved = posixpath.normpath(posixpath.join(base, path))
        if path.endswith("/") and not resolved.endswith("/"):
            resolved += "/"
        url = site_url + resolved + (f"#{anchor}" if anchor else "")
        return match.group(1) + url + match.group(3)

    return _LINK.sub(replace, body)


def _description(meta: dict, body: str) -> str:
    """The front matter description, or else the first paragraph of prose."""
    if meta.get("description"):
        return str(meta["description"])
    prose = re.sub(r"^```.*?^```", "", body, flags=re.M | re.S)
    for paragraph in re.split(r"\n\s*\n", prose):
        if not paragraph.strip() or paragraph[0].isspace():
            continue  # empty, or the body of an admonition or a tab
        if paragraph[0] in "#!|<-*>[=" or paragraph.startswith("???"):
            continue  # heading, admonition, table, HTML, list or image
        text = " ".join(paragraph.split())
        text = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", text)
        return text if len(text) <= 200 else text[:197].rsplit(" ", 1)[0] + "…"
    return ""


def main() -> None:
    site_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "site"
    config = yaml.load((ROOT / "mkdocs.yml").read_text(), Loader=_Loader)
    docs_dir = ROOT / config.get("docs_dir", "docs")
    site_url = config["site_url"].rstrip("/") + "/"

    pages: list[Page] = []
    _walk(config["nav"], "", pages)

    index = [f"# {config['site_name']}", "", f"> {config['site_description']}", "", INTRO]
    full = [f"# {config['site_name']}", "", f"> {config['site_description']}", "", INTRO]
    sections: dict[str, list[str]] = {}
    optional: list[str] = []

    for page in pages:
        if page.path in EXCLUDED_PAGES:
            continue
        meta, body = _split_front_matter((docs_dir / page.path).read_text())
        body = _absolute_links(body, page.path, site_url)
        out = site_dir / page.path
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(body)

        url = site_url + page.path
        description = _description(meta, body)
        entry = f"- [{page.title}]({url})" + (f": {description}" if description else "")
        if page.section in OPTIONAL_SECTIONS or page.path in OPTIONAL_PAGES:
            optional.append(entry)
            continue
        sections.setdefault(page.section or "More", []).append(entry)
        full += ["", "---", "", f"Source: {url}", "", body.rstrip()]

    for section, entries in sections.items():
        index += [f"## {section}", "", *entries, ""]
    index += [
        "## API reference",
        "",
        "- [maplibre on pub.dev](https://pub.dev/documentation/maplibre/latest/maplibre/):"
        " the dartdoc of every public class and member.",
        f"- [llms-full.txt]({site_url}llms-full.txt): every page above in one file.",
        "",
        "## Optional",
        "",
        *optional,
        "",
    ]

    (site_dir / "llms.txt").write_text("\n".join(index))
    (site_dir / "llms-full.txt").write_text("\n".join(full) + "\n")
    print(f"Wrote llms.txt and llms-full.txt for {len(pages)} pages to {site_dir}")


if __name__ == "__main__":
    main()
