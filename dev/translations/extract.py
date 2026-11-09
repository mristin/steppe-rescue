#!/usr/bin/env python3

"""
Collect the translatable messages of the game into translations/messages.pot,
and update the translations (translations/<language>.po) with them.

The messages come from the ``tr("...")`` and ``tr("...", "context")`` calls in
the GDScripts. A comment line starting with ``# TRANSLATORS:`` right above a
call is passed on to the translators.

The existing translations are kept. A new message gets an empty translation,
and a message which is not used any more is marked as obsolete. With --check,
nothing is written and the script fails if the files are out of date.
"""

import argparse
import json
import pathlib
import re
import sys
from typing import Dict, List, Optional, Tuple

import polib

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent.parent

TRANSLATIONS_DIR = REPO_ROOT / "translations"

SOURCE_LANGUAGE = "en"


def _read_languages() -> List[str]:
    """Read the codes of the languages besides the source language (English)."""
    path = TRANSLATIONS_DIR / "languages.json"
    codes = [language["code"] for language in json.loads(path.read_text(encoding="utf-8"))]
    return [code for code in codes if code != SOURCE_LANGUAGE]


#: The languages besides English, from translations/languages.json, which lists
#: every language of the game. A new language needs only a new entry there; this
#: script then creates its .po file.
LANGUAGES = _read_languages()

_STRING = r'"((?:[^"\\]|\\.)*)"'
TR_RE = re.compile(r"\btr\(\s*" + _STRING + r"(?:\s*,\s*" + _STRING + r")?\s*\)", re.DOTALL)

TRANSLATORS_RE = re.compile(r"#\s*TRANSLATORS:\s*(.*)$")

#: (context, message id)
Key = Tuple[str, str]


def _unescape(text: str) -> str:
    return text.encode("utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8")


def _add(
    entries: Dict[Key, polib.POEntry],
    msgid: str,
    context: str,
    relative: str,
    comment: Optional[str],
) -> None:
    key = (context, msgid)
    entry = entries.get(key)
    if entry is None:
        entry = polib.POEntry(msgid=msgid, msgstr="")
        if context:
            entry.msgctxt = context
        entries[key] = entry
    # NOTE (mristin):
    # We record only the file, not the line, so that the translation files do
    # not change whenever the code moves.
    if (relative, "") not in entry.occurrences:
        entry.occurrences.append((relative, ""))
    if comment and comment not in (entry.comment or ""):
        entry.comment = (entry.comment + "\n" if entry.comment else "") + comment


def collect_messages() -> Dict[Key, polib.POEntry]:
    """Collect the messages of all the GDScripts and the data, in a stable order."""
    entries: Dict[Key, polib.POEntry] = {}
    for path in sorted((REPO_ROOT / "scenes").rglob("*.gd")):
        text = path.read_text(encoding="utf-8")
        relative = path.relative_to(REPO_ROOT).as_posix()
        lines = text.splitlines()

        found = [(m.start(), m.group(1), m.group(2)) for m in TR_RE.finditer(text)]
        for start, raw_msgid, raw_context in sorted(found, key=lambda f: f[0]):
            msgid = _unescape(raw_msgid)
            if msgid == "":
                continue
            context = _unescape(raw_context) if raw_context is not None else ""
            line = text.count("\n", 0, start) + 1

            comment = None
            for previous in reversed(lines[: line - 1]):
                translators = TRANSLATORS_RE.search(previous.strip())
                if translators:
                    comment = translators.group(1)
                    break
                if previous.strip() and not previous.strip().startswith("#"):
                    break

            _add(entries, msgid, context, relative, comment)

    return entries


def _key(entry: polib.POEntry) -> Key:
    return (entry.msgctxt or "", entry.msgid)


def make_template(entries: Dict[Key, polib.POEntry]) -> polib.POFile:
    template = polib.POFile(wrapwidth=100)
    template.metadata = {
        "Project-Id-Version": "The Steppe Rescue",
        "MIME-Version": "1.0",
        "Content-Type": "text/plain; charset=UTF-8",
        "Content-Transfer-Encoding": "8bit",
    }
    for entry in entries.values():
        template.append(entry)
    return template


def merge(template: polib.POFile, existing: Optional[polib.POFile], language: str) -> polib.POFile:
    """Make the translation of the template, keeping the existing translations."""
    old: Dict[Key, polib.POEntry] = {}
    if existing is not None:
        old = {_key(entry): entry for entry in existing}

    result = polib.POFile(wrapwidth=100)
    result.metadata = dict(template.metadata)
    result.metadata["Language"] = language
    if existing is not None:
        for name in ("Last-Translator", "Language-Team", "Plural-Forms"):
            if name in existing.metadata:
                result.metadata[name] = existing.metadata[name]

    used = set()
    for entry in template:
        merged = polib.POEntry(
            msgid=entry.msgid,
            msgctxt=entry.msgctxt,
            msgstr="",
            occurrences=list(entry.occurrences),
            comment=entry.comment,
        )
        previous = old.get(_key(entry))
        if previous is not None:
            used.add(_key(entry))
            merged.msgstr = previous.msgstr
            merged.flags = [flag for flag in previous.flags if flag != "obsolete"]
            merged.tcomment = previous.tcomment
        result.append(merged)

    # NOTE (mristin):
    # We keep the unused translations as obsolete, so that a message which comes
    # back does not have to be translated again.
    for key, previous in old.items():
        if key not in used and previous.msgstr:
            previous.obsolete = True
            result.append(previous)

    return result


def _render(po: polib.POFile) -> str:
    return str(po)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="Do not write anything; fail if the translation files are out of date.",
    )
    args = parser.parse_args()

    entries = collect_messages()
    template = make_template(entries)

    outputs: List[Tuple[pathlib.Path, str]] = [
        (TRANSLATIONS_DIR / "messages.pot", _render(template))
    ]
    for language in LANGUAGES:
        path = TRANSLATIONS_DIR / f"{language}.po"
        existing = polib.pofile(str(path), wrapwidth=100) if path.exists() else None
        outputs.append((path, _render(merge(template, existing, language))))

    stale = [path for path, text in outputs if not path.exists() or path.read_text("utf-8") != text]
    if args.check:
        for path in stale:
            print(
                f"{path.relative_to(REPO_ROOT)} is out of date; "
                f"run dev/translations/extract.py",
                file=sys.stderr,
            )
        return 1 if stale else 0

    TRANSLATIONS_DIR.mkdir(exist_ok=True)
    for path, text in outputs:
        if path in stale:
            path.write_text(text, encoding="utf-8")
            print(f"Wrote {path.relative_to(REPO_ROOT)}")
    print(f"{len(template)} message(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
