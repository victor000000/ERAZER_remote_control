"""Regression checks for documentation drift detection; temporary source only."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location('check_docs', Path(__file__).resolve().parents[1] / 'build/check_docs.py')
DOCS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(DOCS)


class DocumentationChecks(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / 'target.md').write_text('# Configuration\n\n## Repeated\n## Repeated\n', encoding='utf-8')

    def check(self, text):
        (self.root / 'README.md').write_text(text, encoding='utf-8')
        return DOCS.check_document(self.root, 'README.md')

    def test_valid_file_and_fragment(self):
        self.assertEqual([], self.check('[Config](target.md#configuration) [Duplicate](target.md#repeated-1)'))

    def test_inline_code_link_labels_still_validate_targets(self):
        self.assertIn('missing target', self.check('[`code label`](absent.md)')[0])

    def test_missing_file(self):
        self.assertIn('missing target', self.check('[Missing](absent.md)')[0])

    def test_stale_fragment(self):
        self.assertIn('missing Markdown anchor', self.check('[Stale](target.md#deleted)')[0])

    def test_repository_escape(self):
        self.assertIn('leaves repository', self.check('[Outside](../private.md)')[0])

    def test_code_examples_and_external_links_are_not_fetched(self):
        self.assertEqual([], self.check('```md\n[Example](missing.md)\n```\n[External](https://invalid.example/#anything)'))

    def test_unsafe_scheme(self):
        self.assertIn('unsafe link scheme', self.check('[Local](file:///private.md)')[0])

    def test_code_fence_headings_do_not_create_anchors(self):
        self.assertNotIn('example', DOCS.anchors('```\n# Example\n```'))

    def test_tilde_fence_and_unicode_heading(self):
        self.assertEqual({'actual-heading'}, DOCS.anchors('~~~\n# Hidden\n~~~\n# Actual heading'))


if __name__ == '__main__':
    unittest.main()
