import unittest
from issue_card import suggest, card, is_markdown_noise

ISSUES = [
    {"number": 279, "title": "Re-target converter", "state": "open", "labels": [{"name": "enhancement"}],
     "body": "## Problem\n\nPart of #258.\nSecond line.\nThird.", "html_url": "https://x/279"},
    {"number": 27, "title": "Old one", "state": "closed", "labels": [], "body": None,
     "html_url": "https://x/27", "pull_request": {}},
    {"number": 280, "title": "Other", "state": "open", "labels": [], "body": "", "html_url": "https://x/280"},
]

class Suggest(unittest.TestCase):
    def test_prefix_lists_one_row_per_match(self):
        self.assertEqual(suggest("28", ISSUES), ["#280 [OPEN] Other"])

    def test_exact_match_shows_full_card_first(self):
        rows = suggest("279", ISSUES)
        self.assertEqual(rows[0], "#279 [OPEN] Re-target converter")
        self.assertEqual(rows[-1], "    https://x/279")

    def test_exact_match_on_shorter_number_still_lists_longer_prefixes(self):
        rows = suggest("27", ISSUES)
        self.assertEqual(rows[0], "#27 [CLOSED PR] Old one")
        self.assertIn("#279 [OPEN] Re-target converter", rows)

    def test_no_match_is_empty(self):
        self.assertEqual(suggest("999", ISSUES), [])

    def test_caps_at_15_rows(self):
        many = [dict(ISSUES[2], number=1000 + i) for i in range(40)]
        self.assertEqual(len(suggest("1", many)), 15)

class Card(unittest.TestCase):
    def test_fields_and_body_skips_headers_and_blanks(self):
        self.assertEqual(card(ISSUES[0]), [
            "#279 [OPEN] Re-target converter",
            "    labels: enhancement",
            "    Part of #258.",
            "    Second line.",
            "    https://x/279",
        ])

    def test_long_body_line_truncated(self):
        row = card(dict(ISSUES[2], body="x" * 300))[1]
        self.assertEqual(len(row), 4 + 100)
        self.assertTrue(row.endswith("…"))

    def test_no_labels_no_body(self):
        self.assertEqual(card(ISSUES[2]), ["#280 [OPEN] Other", "    https://x/280"])

    def test_noise(self):
        for s in ["## Problem", "", "---", "<!-- x -->"]:
            self.assertTrue(is_markdown_noise(s), s)

if __name__ == "__main__":
    unittest.main()
