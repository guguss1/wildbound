"""Checks that tools/studio-fresh-runner.luau has an explicit invocation for every Studio suite.

Every tests/Wildbound*_Test.luau needs either a SPECS entry (its argument builders) or a SKIP entry
(a reason it is not run). A SPECS entry must pass exactly as many arguments as the suite's
`return function(...)` signature takes, and every module or script it names must be a deployed
Studio name in tools/deploy_manifest.py, so a typo cannot silently become a missing argument.
"""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RUNNER = ROOT / "tools" / "studio-fresh-runner.luau"
TESTS = ROOT / "tests"
MANIFEST = ROOT / "tools" / "deploy_manifest.py"

TOKEN = re.compile(r'"(mod|src|inst|tuning):([^"]*)"')
SPEC_START = re.compile(r'^SPECS\["(Wildbound\w+_Test)"\]\s*=\s*\{', re.MULTILINE)
SKIP_ENTRY = re.compile(r'^SKIP\["(Wildbound\w+_Test)"\]\s*=\s*"([^"]+)"', re.MULTILINE)
SIGNATURE = re.compile(r"^return function\(([^)]*)\)", re.MULTILINE)


def suites():
    return sorted(path.stem for path in TESTS.glob("Wildbound*_Test.luau"))


def signature_arity(name):
    text = (TESTS / f"{name}.luau").read_text(encoding="utf-8", errors="replace")
    match = SIGNATURE.search(text)
    if not match:
        return None
    params = [part.strip() for part in match.group(1).split(",") if part.strip()]
    return len(params)


def balanced_body(text, open_index):
    """Return the text between the brace at open_index and its matching close brace."""
    depth, index, quote = 0, open_index, None
    while index < len(text):
        char = text[index]
        if quote:
            if char == "\\":
                index += 1
            elif char == quote:
                quote = None
        elif char == "-" and text.startswith("--", index):
            newline = text.find("\n", index)
            index = len(text) if newline < 0 else newline
            continue
        elif char in "\"'":
            quote = char
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return text[open_index + 1 : index]
        index += 1
    raise AssertionError(f"unbalanced braces at offset {open_index}")


def top_level_count(body):
    """Count the comma-separated entries of a Luau table body at depth 0 (a trailing comma is allowed)."""
    depth, quote, count, pending = 0, None, 0, False
    index = 0
    while index < len(body):
        char = body[index]
        if quote:
            if char == "\\":
                index += 1
            elif char == quote:
                quote = None
        elif char in "\"'":
            quote, pending = char, True
        elif char == "-" and body.startswith("--", index):
            newline = body.find("\n", index)
            index = len(body) if newline < 0 else newline
            continue
        elif char == "{":
            depth, pending = depth + 1, True
        elif char == "}":
            depth -= 1
        elif char == "," and depth == 0:
            count, pending = count + 1, False
        elif not char.isspace():
            pending = True
        index += 1
    return count + (1 if pending else 0)


def top_level_entries(body):
    """Split a Luau table body into its depth-0 entries (comments dropped)."""
    body = re.sub(r"--[^\n]*", "", body)
    entries, depth, quote, current = [], 0, None, ""
    for char in body:
        if quote:
            if char == quote:
                quote = None
        elif char in "\"'":
            quote = char
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
        elif char == "," and depth == 0:
            entries.append(current)
            current = ""
            continue
        current += char
    if current.strip():
        entries.append(current)
    return entries


def runner_entries():
    text = RUNNER.read_text(encoding="utf-8")
    specs = {}
    for match in SPEC_START.finditer(text):
        specs[match.group(1)] = balanced_body(text, match.end() - 1)
    skips = {match.group(1): match.group(2) for match in SKIP_ENTRY.finditer(text)}
    return specs, skips


def deployed_names():
    # Deployed names come from the manifest; a module whose manifest row is not written yet (another track's new
    # src/wildbound/<Name>.luau ModuleScript) still counts, under its file name.
    text = MANIFEST.read_text(encoding="utf-8")
    names = {target.rsplit(".", 1)[-1] for target in re.findall(r'"((?:ServerStorage|ServerScriptService|ReplicatedStorage|StarterPlayer)\.[\w.]+)"', text)}
    names.update(path.stem for path in (ROOT / "src" / "wildbound").glob("Wildbound*.luau") if "." not in path.stem)
    return names


class StudioFreshRunnerSpecs(unittest.TestCase):
    def test_every_suite_has_a_spec_or_a_skip(self):
        specs, skips = runner_entries()
        missing = [name for name in suites() if name not in specs and name not in skips]
        self.assertEqual(missing, [], f"{len(missing)} suites have no SPECS or SKIP entry: {', '.join(missing)}")

    def test_no_entry_names_a_missing_suite_or_is_both(self):
        specs, skips = runner_entries()
        known = set(suites())
        stale = sorted(name for name in set(specs) | set(skips) if name not in known)
        self.assertEqual(stale, [], "entries without a tests/ suite")
        self.assertEqual(sorted(set(specs) & set(skips)), [], "a suite is both specified and skipped")

    def test_spec_arity_matches_the_suite_signature(self):
        specs, _ = runner_entries()
        wrong = []
        for name, body in sorted(specs.items()):
            expected = signature_arity(name)
            got = top_level_count(body)
            if expected is None or got != expected:
                wrong.append(f"{name}: spec passes {got}, signature takes {expected}")
        self.assertEqual(wrong, [])

    def test_spec_tokens_name_deployed_scripts(self):
        specs, _ = runner_entries()
        names = deployed_names()
        unknown = []
        for name, body in sorted(specs.items()):
            for kind, value in TOKEN.findall(body):
                if kind in ("mod", "src") and value not in names:
                    unknown.append(f"{name}: {kind}:{value}")
                if kind == "inst" and not value.startswith("ServerStorage."):
                    unknown.append(f"{name}: inst:{value} (only read-only ServerStorage instances)")
        self.assertEqual(unknown, [])

    def test_every_spec_entry_is_a_known_token_or_table(self):
        specs, _ = runner_entries()
        bad = []
        for name, body in sorted(specs.items()):
            stripped = re.sub(r"--[^\n]*", "", body)
            for literal in re.findall(r'"[^"]*"', stripped):
                if not TOKEN.fullmatch(literal):
                    bad.append(f"{name}: {literal}")
        self.assertEqual(bad, [])

    def test_table_arguments_carry_every_key_the_suite_reads(self):
        # A header can be shorter than the body (WildboundText_Test reads sources.campView and more): every
        # `param.key` the suite reads directly must be a key of the table the spec passes for that parameter.
        specs, _ = runner_entries()
        missing = []
        for name, body in sorted(specs.items()):
            text = (TESTS / f"{name}.luau").read_text(encoding="utf-8", errors="replace")
            params = [part.strip() for part in SIGNATURE.search(text).group(1).split(",") if part.strip()]
            for param, argument in zip(params, top_level_entries(body)):
                if not argument.lstrip().startswith("{"):
                    continue
                keys = set(re.findall(r"(\w+)\s*=", argument))
                used = set(re.findall(rf"\b{re.escape(param)}\.(\w+)", text))
                for key in sorted(used - keys):
                    missing.append(f"{name}: {param}.{key}")
        self.assertEqual(missing, [])

    def test_skips_give_a_reason(self):
        _, skips = runner_entries()
        for name, reason in skips.items():
            self.assertGreater(len(reason.strip()), 20, name)

    def test_table_arguments_carry_every_key_read_by_computed_index(self):
        # `sources[key]` inside `for key in pairs(ENGLISH)` or `for _, name in ipairs({ "a", "b" })` reads the keys of
        # that literal list; each must be a key of the table the spec passes.
        specs, _ = runner_entries()
        missing = []
        for name, body in sorted(specs.items()):
            missing += computed_key_gaps(name, body)
        self.assertEqual(missing, [])

    def test_computed_index_check_catches_a_dropped_key(self):
        specs, _ = runner_entries()
        text_body = specs["WildboundText_Test"].replace('inventory = "src:WildboundClient",', "")
        save_body = specs["WildboundSave_Test"].replace('campView = "src:WildboundCampView",', "")
        self.assertIn("WildboundText_Test: sources[key] needs inventory", computed_key_gaps("WildboundText_Test", text_body))
        self.assertIn("WildboundSave_Test: sources[name] needs campView", computed_key_gaps("WildboundSave_Test", save_body))

    def test_spec_kinds_match_the_header(self):
        # A header `require(fresh...)` is a "mod:" token and a `.Source` is a "src:" token, for positional arguments
        # and for every key of a table argument.
        specs, _ = runner_entries()
        wrong = []
        for name, body in sorted(specs.items()):
            wrong += kind_mismatches(name, body)
        self.assertEqual(wrong, [])

    def test_kind_check_catches_a_swapped_kind(self):
        specs, _ = runner_entries()
        gear = specs["WildboundGear_Test"].replace('text = "mod:WildboundText"', 'text = "src:WildboundText"')
        balance = specs["WildboundBalance_Test"].replace('"src:WildboundBalance"', '"mod:WildboundBalance"')
        self.assertIn("WildboundGear_Test: arg 3.text is src, header says mod", kind_mismatches("WildboundGear_Test", gear))
        self.assertIn("WildboundBalance_Test: arg 2 is mod, header says src", kind_mismatches("WildboundBalance_Test", balance))

    def test_modules_with_sibling_requires_are_in_the_sibling_rule(self):
        # A ModuleScript that requires script.Parent:WaitForChild/FindFirstChild("<Sibling>") hangs or loses the
        # sibling unless the runner clones it next to the module first.
        text = RUNNER.read_text(encoding="utf-8")
        self.assertEqual(sibling_gaps(text), [])

    def test_sibling_check_catches_an_unlisted_module(self):
        text = RUNNER.read_text(encoding="utf-8")
        trimmed = re.sub(r"^\s*WildboundCaptureView\s*=.*$", "", text, flags=re.MULTILINE)
        self.assertIn("WildboundCaptureView needs WildboundText", sibling_gaps(trimmed))

    def test_suites_that_parent_outside_the_temp_folder_are_skipped(self):
        # The runner only owns its temporary folder: a suite that parents a fixture into a real service (Workspace,
        # ServerStorage, ...) must be a SKIP entry.
        specs, skips = runner_entries()
        leaking = [name for name in suites() if parents_into_a_service(name) and name not in skips]
        self.assertEqual(leaking, [])

    def test_parent_detector_flags_known_cases_and_ignores_strings(self):
        for name in ("WildboundForestDress_Test", "WildboundP0Map_Test", "WildboundSiluetaVisual_Test"):
            self.assertTrue(parents_into_a_service(name), name)
        for name in ("WildboundStaminaWiring_Test", "WildboundLumipolArt_Test", "WildboundEggCarry_Test"):
            self.assertFalse(parents_into_a_service(name), name)


SERVICES = "Workspace|ServerStorage|ReplicatedStorage|ServerScriptService|StarterPlayer|StarterGui|StarterPack|Lighting|SoundService"
LOOP = re.compile(r"for\s+(\w+)(?:\s*,\s*(\w+))?\s+in\s+(ipairs|pairs)\(\s*")


def suite_params(name):
    text = (TESTS / f"{name}.luau").read_text(encoding="utf-8", errors="replace")
    return text, [part.strip() for part in SIGNATURE.search(text).group(1).split(",") if part.strip()]


def literal_list(text, position, kind):
    """Keys (pairs) or string values (ipairs) of the literal table iterated at text[position]."""
    if text[position] == "{":
        body = balanced_body(text, position)
    else:
        ident = re.match(r"\w+", text[position:])
        if not ident:
            return None
        defs = [m for m in re.finditer(rf"\blocal\s+{ident.group(0)}\s*=\s*\{{", text) if m.start() < position]
        if not defs:
            return None
        body = balanced_body(text, defs[-1].end() - 1)
    found = set()
    for entry in top_level_entries(body):
        if kind == "pairs":
            match = re.match(r"\s*(?:(\w+)|\[\s*[\"'](\w+)[\"']\s*\])\s*=", entry)
        else:
            match = re.fullmatch(r"\s*[\"']([^\"']+)[\"']\s*", entry)
        if match:
            found.add(next(group for group in match.groups() if group))
    return found


def computed_key_gaps(name, body):
    text, params = suite_params(name)
    gaps = []
    for param, argument in zip(params, top_level_entries(body)):
        if not argument.lstrip().startswith("{"):
            continue
        keys = set(re.findall(r"(\w+)\s*=", argument))
        for read in re.finditer(rf"\b{re.escape(param)}\[(\w+)\]", text):
            var = read.group(1)
            loops = [m for m in LOOP.finditer(text, 0, read.start())
                     if (m.group(3) == "pairs" and m.group(1) == var) or (m.group(3) == "ipairs" and m.group(2) == var)]
            if not loops:
                continue  # an index that is not a loop over a literal list (e.g. a write in a helper)
            listed = literal_list(text, loops[-1].end(), loops[-1].group(3))
            if listed is None:
                gaps.append(f"{name}: {param}[{var}] iterates a list this check cannot read")
                continue
            for key in sorted(listed - keys):
                gaps.append(f"{name}: {param}[{var}] needs {key}")
    return sorted(set(gaps))


def header_arguments(name):
    """The argument list of the suite's `Invoke with require(freshTestClone)(...)` header, or None."""
    text = (TESTS / f"{name}.luau").read_text(encoding="utf-8", errors="replace")
    lines = []
    for line in text.splitlines():
        if not line.startswith("--"):
            break
        lines.append(line[2:].strip())
    header = " ".join(lines)
    start = header.find("Invoke with require(freshTestClone)(")
    if start < 0:
        return None
    index = start + len("Invoke with require(freshTestClone)")
    depth, end = 0, None
    for position in range(index, len(header)):
        if header[position] in "({[":
            depth += 1
        elif header[position] in ")}]":
            depth -= 1
            if depth == 0:
                end = position
                break
    if end is None:
        return None
    return split_top(header[index + 1 : end])


def split_top(body):
    parts, depth, current = [], 0, ""
    for char in body:
        if char in "({[":
            depth += 1
        elif char in ")}]":
            depth -= 1
        elif char == "," and depth == 0:
            parts.append(current.strip())
            current = ""
            continue
        current += char
    if current.strip():
        parts.append(current.strip())
    return parts


def header_kind(value):
    if "require(" in value:
        return "mod"
    if re.search(r"\.Source\b|\w*Source$", value.strip()):
        return "src"
    return None


def spec_kind(entry):
    match = re.fullmatch(r'\s*"(mod|src|inst|tuning):[^"]*"\s*', entry)
    return match.group(1) if match else None


def table_pairs(body_inner, splitter):
    out = {}
    for entry in splitter(body_inner):
        match = re.match(r"\s*(\w+)\s*=\s*(.+)$", entry, re.DOTALL)
        if match:
            out[match.group(1)] = match.group(2).strip()
    return out


def kind_mismatches(name, body):
    header = header_arguments(name)
    if header is None:
        return []
    wrong = []
    for index, (spec, head) in enumerate(zip(top_level_entries(body), header), start=1):
        spec = re.sub(r"--[^\n]*", "", spec).strip()
        if spec.startswith("{") and head.startswith("{"):
            spec_keys = table_pairs(spec[1:spec.rfind("}")], top_level_entries)
            head_keys = table_pairs(head[1:head.rfind("}")], split_top)
            for key in sorted(set(spec_keys) & set(head_keys)):
                got, want = spec_kind(spec_keys[key]), header_kind(head_keys[key])
                if got in ("mod", "src") and want and got != want:
                    wrong.append(f"{name}: arg {index}.{key} is {got}, header says {want}")
            continue
        got, want = spec_kind(spec), header_kind(head)
        if got in ("mod", "src") and want and got != want:
            wrong.append(f"{name}: arg {index} is {got}, header says {want}")
    return wrong


def sibling_gaps(runner_text):
    match = re.search(r"local SIBLINGS\s*=\s*\{", runner_text)
    listed = {}
    if match:
        for entry in top_level_entries(balanced_body(runner_text, match.end() - 1)):
            pair = re.match(r"\s*(\w+)\s*=\s*\{([^}]*)\}", entry)
            if pair:
                listed[pair.group(1)] = set(re.findall(r'"(\w+)"', pair.group(2)))
    gaps = []
    for path in sorted((ROOT / "src" / "wildbound").glob("Wildbound*.luau")):
        if "." in path.stem:
            continue  # .server / .client scripts are never required by the runner
        text = re.sub(r"--[^\n]*", "", path.read_text(encoding="utf-8", errors="replace"))
        for sibling in sorted(set(re.findall(r"script\.Parent[^\n]{0,40}?:\s*(?:WaitForChild|FindFirstChild)\(\s*[\"'](\w+)[\"']", text))):
            if sibling not in listed.get(path.stem, set()):
                gaps.append(f"{path.stem} needs {sibling}")
    return gaps


def parents_into_a_service(name):
    text = (TESTS / f"{name}.luau").read_text(encoding="utf-8", errors="replace")
    text = re.sub(rf"GetService\(\s*[\"']({SERVICES})[\"']\s*\)", r"GetService_\1", text)
    text = re.sub(r"--[^\n]*", "", text)
    text = re.sub(r'"(?:\\.|[^"\\\n])*"|\'(?:\\.|[^\'\\\n])*\'', '""', text)
    aliases = set(re.findall(rf"local\s+(\w+)\s*=\s*game:GetService_(?:{SERVICES})\b", text))
    targets = [r"\bworkspace\b", r"\bgame\.(?:" + SERVICES + r")\b", r"GetService_(?:" + SERVICES + r")\b"]
    targets += [rf"\b{re.escape(alias)}\b" for alias in aliases]
    target = "|".join(targets)
    for line in text.splitlines():
        assign = re.search(r"\.Parent\b[^=\n]*?(?<![=~<>])=(?!=)(.*)$", line)
        if assign and re.search(target, assign.group(1)):
            return True
    return False


if __name__ == "__main__":
    unittest.main()
