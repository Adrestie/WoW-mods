# -*- coding: utf-8 -*-
# This file is part of mod-spheregrid.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.

"""Cutting a Lua file into code, strings and comments.

WHY IT IS NOT A REGULAR EXPRESSION. A first attempt matched string literals
with a pattern, and French comments broke it: the apostrophe in `l'un` opened a
quote that ran to the next one, swallowing the code in between. Two thirds of
every file was mistaken for text. Nothing renamed there, and no check could see
it -- the check used the same broken cut.

So the file is walked character by character, in the order the language reads
it: a comment cannot start inside a string, and a quote inside a comment is
just a quote.
"""

CODE = "code"
STRING = "string"
COMMENT = "comment"


def _long_bracket(text, index):
    """The level of a long bracket at `index`, or None.

    Lua writes them `[[`, `[=[`, `[==[` and so on; the closing one must carry
    the same number of equals signs.
    """
    if index >= len(text) or text[index] != "[":
        return None
    level = 0
    at = index + 1
    while at < len(text) and text[at] == "=":
        level += 1
        at += 1
    return level if at < len(text) and text[at] == "[" else None


def pieces(text):
    """The file as a list of (kind, text), in order and lossless.

    Joining every piece back together gives the file exactly as it was.
    """
    out = []
    start = 0
    at = 0
    size = len(text)

    def flush(to):
        if to > start:
            out.append((CODE, text[start:to]))

    while at < size:
        char = text[at]

        # a comment: `--`, then either a long bracket or the rest of the line
        if char == "-" and text.startswith("--", at):
            flush(at)
            level = _long_bracket(text, at + 2)
            if level is not None:
                closing = "]" + "=" * level + "]"
                end = text.find(closing, at + 2)
                end = size if end < 0 else end + len(closing)
            else:
                end = text.find("\n", at)
                end = size if end < 0 else end
            out.append((COMMENT, text[at:end]))
            at = start = end
            continue

        # a long string
        level = _long_bracket(text, at)
        if level is not None:
            flush(at)
            closing = "]" + "=" * level + "]"
            end = text.find(closing, at)
            end = size if end < 0 else end + len(closing)
            out.append((STRING, text[at:end]))
            at = start = end
            continue

        # a quoted string, escapes respected
        if char in "\"'":
            flush(at)
            end = at + 1
            while end < size:
                if text[end] == "\\":
                    end += 2
                    continue
                if text[end] == char or text[end] == "\n":
                    end += 1
                    break
                end += 1
            out.append((STRING, text[at:end]))
            at = start = end
            continue

        at += 1

    flush(size)
    return out


def join(pieces_):
    return "".join(body for _, body in pieces_)


def only(pieces_, kind):
    return [body for what, body in pieces_ if what == kind]
