"""TDD contract for the Phase 3 GitHub evidence verifier."""

import importlib.util
import contextlib
import io
import tempfile
import unittest
from pathlib import Path


HERE = Path(__file__).resolve().parent
MODULE_PATH = HERE.parent / "audit" / "github_verifier.py"


def load_verifier():
    spec = importlib.util.spec_from_file_location("github_verifier", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise AssertionError("GitHub verifier module is missing")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class FakeGitHub:
    def __init__(self, commit, check_pages=None, review_pages=None, comment_pages=None, repository=None, project=None, pull_request=None):
        self.commit = commit
        self.check_pages = check_pages or [[]]
        self.review_pages = review_pages or [[]]
        self.comment_pages = comment_pages or [[]]
        self.repository = repository or {"id": 1, "name": "repository", "owner_id": 2}
        self.project = project
        self.pull_request = pull_request or {"number": 222, "head": {"sha": commit["sha"]}, "merged": False}
        self.calls = []

    def get_commit(self, repository, sha):
        self.calls.append(("commit", repository, sha))
        return self.commit

    def get_check_runs(self, repository, sha, page):
        self.calls.append(("checks", repository, sha, page))
        return self.check_pages[page - 1] if page <= len(self.check_pages) else []

    def get_reviews(self, repository, pull_request, page):
        self.calls.append(("reviews", repository, pull_request, page))
        return self.review_pages[page - 1] if page <= len(self.review_pages) else []

    def get_pull_request(self, repository, pull_request):
        self.calls.append(("pull_request", repository, pull_request))
        return self.pull_request

    def get_comments(self, repository, pull_request, page):
        self.calls.append(("comments", repository, pull_request, page))
        return self.comment_pages[page - 1] if page <= len(self.comment_pages) else []

    def get_repository(self, repository):
        self.calls.append(("repository", repository))
        return self.repository

    def get_project(self, owner, number):
        self.calls.append(("project", owner, number))
        return self.project


class GitHubVerifierTests(unittest.TestCase):
    def test_verified_head_collects_paginated_checks_and_signed_off_state(self):
        verifier = load_verifier()
        sha = "a" * 40
        github = FakeGitHub(
            {"sha": sha, "commit": {"message": "change\n\nSigned-off-by: Aydin.A <ayd.abd@gmail.com>"}, "verification": {"verified": True, "reason": "valid"}},
            check_pages=[[{"id": 10, "name": "quality", "status": "completed", "conclusion": "success", "head_sha": sha}], [{"id": 11, "name": "security", "status": "completed", "conclusion": "success", "head_sha": sha}]],
            review_pages=[[{"id": 20, "state": "APPROVED", "commit_id": sha}]],
            comment_pages=[[{"id": 30, "commit_id": None}]],
        )
        result = verifier.verify(github, "aydabd/repository", {"pull_request": 222, "head_sha": sha})
        self.assertEqual(result["result"], "PASS")
        self.assertEqual(result["verification"], {"commit_signature_verified": True, "signed_off": True, "required_checks": "PASS"})
        self.assertEqual(result["evidence"]["checks"], [
            {"kind": "CHECK_RUN", "id": 10, "sha": sha, "attempt": None, "assurance": "GITHUB_VERIFIED"},
            {"kind": "CHECK_RUN", "id": 11, "sha": sha, "attempt": None, "assurance": "GITHUB_VERIFIED"},
        ])
        self.assertEqual([call[-1] for call in github.calls if call[0] == "checks"], [1, 2, 3])
        self.assertEqual(result["evidence"]["reviews"], [{"kind": "PULL_REQUEST", "id": 20, "sha": None, "attempt": None, "assurance": "GITHUB_VERIFIED"}])
        self.assertEqual(result["evidence"]["comments"], [{"kind": "PULL_REQUEST", "id": 30, "sha": None, "attempt": None, "assurance": "GITHUB_VERIFIED"}])
        self.assertEqual(result["evidence"]["merge_state"], {"merged": False, "merge_commit_sha": None})

    def test_project_reference_is_independently_bound(self):
        verifier = load_verifier()
        sha = "a" * 40
        github = FakeGitHub(
            {"sha": sha, "commit": {"message": "change\n\nSigned-off-by: Aydin.A <ayd.abd@gmail.com>"}, "verification": {"verified": True, "reason": "valid"}},
            check_pages=[[{"id": 10, "name": "quality", "status": "completed", "conclusion": "success", "head_sha": sha}]],
            project={"id": 99, "owner": "aydabd", "number": 4},
        )
        result = verifier.verify(github, "aydabd/repository", {"pull_request": 222, "head_sha": sha, "project": {"owner": "aydabd", "number": 4}})
        self.assertEqual(result["result"], "PASS")
        self.assertEqual(result["evidence"]["project"], {"kind": "PROJECT", "id": 99, "sha": None, "attempt": None, "assurance": "GITHUB_VERIFIED"})

    def test_stale_commit_evidence_fails_without_echoing_api_data(self):
        verifier = load_verifier()
        requested = "a" * 40
        observed = "b" * 40
        github = FakeGitHub({"sha": observed, "commit": {"message": "PRIVATE"}, "verification": {"verified": True, "reason": "valid"}})
        result = verifier.verify(github, "aydabd/repository", {"pull_request": 222, "head_sha": requested})
        self.assertEqual(result, {"result": "FAIL", "error_code": "STALE_HEAD_EVIDENCE"})
        self.assertNotIn("PRIVATE", str(result))

    def test_missing_signed_off_trailer_fails_closed(self):
        verifier = load_verifier()
        sha = "a" * 40
        github = FakeGitHub(
            {"sha": sha, "commit": {"message": "change"}, "verification": {"verified": True, "reason": "valid"}},
            check_pages=[[{"id": 10, "name": "quality", "status": "completed", "conclusion": "success", "head_sha": sha}]],
        )
        result = verifier.verify(github, "aydabd/repository", {"pull_request": 222, "head_sha": sha})
        self.assertEqual(result, {"result": "FAIL", "error_code": "SIGNED_OFF_MISSING"})

    def test_cli_emits_fixed_failure_without_input_contents(self):
        verifier = load_verifier()
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json") as source:
            source.write('{"repository":"aydabd/repository","subject":"SECRET"}')
            source.flush()
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                status = verifier.main(["--input", source.name])
        self.assertEqual(status, 1)
        self.assertEqual(output.getvalue(), '{"result":"FAIL","error_code":"INVALID_EVIDENCE"}\n')
        self.assertNotIn("SECRET", output.getvalue())

    def test_invalid_workflow_attempt_fails_closed(self):
        verifier = load_verifier()
        sha = "a" * 40
        github = FakeGitHub(
            {"sha": sha, "commit": {"message": "change\n\nSigned-off-by: Aydin.A <ayd.abd@gmail.com>"}, "verification": {"verified": True, "reason": "valid"}},
            check_pages=[[{"id": 10, "name": "quality", "status": "completed", "conclusion": "success", "head_sha": sha, "run_attempt": 0}]],
        )
        result = verifier.verify(github, "aydabd/repository", {"pull_request": 222, "head_sha": sha})
        self.assertEqual(result, {"result": "FAIL", "error_code": "INVALID_EVIDENCE"})

    def test_changes_requested_review_fails_closed(self):
        verifier = load_verifier()
        sha = "a" * 40
        github = FakeGitHub(
            {"sha": sha, "commit": {"message": "change\n\nSigned-off-by: Aydin.A <ayd.abd@gmail.com>"}, "verification": {"verified": True, "reason": "valid"}},
            check_pages=[[{"id": 10, "name": "quality", "status": "completed", "conclusion": "success", "head_sha": sha}]],
            review_pages=[[{"id": 20, "state": "CHANGES_REQUESTED", "commit_id": sha}]],
        )
        result = verifier.verify(github, "aydabd/repository", {"pull_request": 222, "head_sha": sha})
        self.assertEqual(result, {"result": "FAIL", "error_code": "REVIEW_RESOLUTION_FAILED"})


if __name__ == "__main__":
    unittest.main()
