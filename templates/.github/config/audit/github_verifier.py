"""Verify allowlisted GitHub evidence for the Phase 3 audit boundary."""

import json
import re
import subprocess
import sys


SHA = re.compile(r"^[0-9a-f]{40}$")
REPOSITORY = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,38}/[A-Za-z0-9][A-Za-z0-9_.-]{0,99}$")
SIGNED_OFF = re.compile(r"(?m)^Signed-off-by:\s+[^\n<>]+\s+<[^\n<>@]+@[^\n<>]+>\s*$")


def _failure(code):
    return {"result": "FAIL", "error_code": code}


def _pages(fetch, *args):
    page = 1
    while True:
        values = fetch(*args, page)
        if not isinstance(values, list):
            return None
        if not values:
            return page - 1
        yield from values
        page += 1


def _valid_sha(value):
    return isinstance(value, str) and SHA.fullmatch(value) is not None


def _check_evidence(github, repository, head_sha):
    checks = []
    for item in _pages(github.get_check_runs, repository, head_sha):
        attempt = item.get("run_attempt") if isinstance(item, dict) else None
        if not isinstance(item, dict) or isinstance(item.get("id"), bool) or not isinstance(item.get("id"), int) or (attempt is not None and (isinstance(attempt, bool) or not isinstance(attempt, int) or attempt < 1)):
            return False
        if item.get("head_sha") != head_sha or item.get("status") != "completed" or item.get("conclusion") != "success":
            return None
        checks.append({"kind": "CHECK_RUN", "id": item["id"], "sha": head_sha, "attempt": item.get("run_attempt"), "assurance": "GITHUB_VERIFIED"})
    return checks or None


def _review_evidence(github, repository, pull_request, head_sha):
    reviews = []
    for item in _pages(github.get_reviews, repository, pull_request):
        if not isinstance(item, dict) or isinstance(item.get("id"), bool) or not isinstance(item.get("id"), int) or item.get("commit_id") not in (None, head_sha):
            return None
        if item.get("state") == "CHANGES_REQUESTED":
            return None
        reviews.append({"kind": "PULL_REQUEST", "id": item["id"], "sha": None, "attempt": None, "assurance": "GITHUB_VERIFIED"})
    comments = []
    for item in _pages(github.get_comments, repository, pull_request):
        if not isinstance(item, dict) or isinstance(item.get("id"), bool) or not isinstance(item.get("id"), int) or item.get("commit_id") not in (None, head_sha):
            return None
        comments.append({"kind": "PULL_REQUEST", "id": item["id"], "sha": None, "attempt": None, "assurance": "GITHUB_VERIFIED"})
    return reviews, comments


def _project_evidence(github, project):
    if project is None:
        return None
    if not isinstance(project, dict) or not isinstance(project.get("owner"), str) or not isinstance(project.get("number"), int):
        return False
    observed = github.get_project(project["owner"], project["number"])
    if not isinstance(observed, dict) or observed.get("owner") != project["owner"] or observed.get("number") != project["number"]:
        return False
    if not isinstance(observed.get("id"), int) or observed["id"] < 1:
        return False
    return {"kind": "PROJECT", "id": observed["id"], "sha": None, "attempt": None, "assurance": "GITHUB_VERIFIED"}


def _merge_state(pull_request):
    merged = pull_request.get("merged")
    merge_sha = pull_request.get("merge_commit_sha")
    if not isinstance(merged, bool) or (merge_sha is not None and not _valid_sha(merge_sha)):
        return False
    return {"merged": merged, "merge_commit_sha": merge_sha}


def verify(github, repository, subject):
    """Return sanitized verification evidence for one exact audit subject."""
    if not isinstance(repository, str) or REPOSITORY.fullmatch(repository) is None or not isinstance(subject, dict):
        return _failure("INVALID_EVIDENCE")
    head_sha = subject.get("head_sha")
    if not _valid_sha(head_sha):
        return _failure("INVALID_EVIDENCE")
    try:
        commit = github.get_commit(repository, head_sha)
        if not isinstance(commit, dict) or commit.get("sha") != head_sha:
            return _failure("STALE_HEAD_EVIDENCE")
        verification = commit.get("verification", {})
        message = commit.get("commit", {}).get("message", "")
        if verification.get("verified") is not True or verification.get("reason") != "valid":
            return _failure("COMMIT_SIGNATURE_UNVERIFIED")
        if not SIGNED_OFF.search(message):
            return _failure("SIGNED_OFF_MISSING")
        checks = _check_evidence(github, repository, head_sha)
        if checks is False:
            return _failure("INVALID_EVIDENCE")
        if checks is None:
            return _failure("REQUIRED_CHECKS_FAILED")
        pull_request = subject.get("pull_request")
        if not isinstance(pull_request, int) or pull_request < 1:
            return _failure("INVALID_EVIDENCE")
        pull_request_data = github.get_pull_request(repository, pull_request)
        if not isinstance(pull_request_data, dict) or pull_request_data.get("number") != pull_request or pull_request_data.get("head", {}).get("sha") != head_sha:
            return _failure("STALE_HEAD_EVIDENCE")
        merge_state = _merge_state(pull_request_data)
        if merge_state is False:
            return _failure("INVALID_EVIDENCE")
        review_evidence = _review_evidence(github, repository, pull_request, head_sha)
        if review_evidence is None:
            return _failure("REVIEW_RESOLUTION_FAILED")
        project = _project_evidence(github, subject.get("project"))
        if project is False:
            return _failure("PROJECT_EVIDENCE_INVALID")
        evidence = {"checks": checks, "reviews": review_evidence[0], "comments": review_evidence[1], "merge_state": merge_state}
        if project is not None:
            evidence["project"] = project
        return {
            "result": "PASS",
            "verification": {"commit_signature_verified": True, "signed_off": bool(SIGNED_OFF.search(message)), "required_checks": "PASS"},
            "evidence": evidence,
        }
    except (AttributeError, KeyError, TypeError, ValueError):
        return _failure("INVALID_EVIDENCE")


class GhApi:
    """Bounded GitHub CLI adapter; raw API responses never enter output."""

    def _get(self, endpoint):
        try:
            completed = subprocess.run(["gh", "api", endpoint], check=True, capture_output=True, text=True)
            return json.loads(completed.stdout)
        except (OSError, subprocess.SubprocessError, ValueError):
            return None

    def get_commit(self, repository, sha):
        return self._get(f"/repos/{repository}/commits/{sha}")

    def get_check_runs(self, repository, sha, page):
        response = self._get(f"/repos/{repository}/commits/{sha}/check-runs?per_page=100&page={page}")
        return response.get("check_runs") if isinstance(response, dict) else None

    def get_pull_request(self, repository, pull_request):
        return self._get(f"/repos/{repository}/pulls/{pull_request}")

    def get_reviews(self, repository, pull_request, page):
        response = self._get(f"/repos/{repository}/pulls/{pull_request}/reviews?per_page=100&page={page}")
        return response if isinstance(response, list) else None

    def get_comments(self, repository, pull_request, page):
        response = self._get(f"/repos/{repository}/issues/{pull_request}/comments?per_page=100&page={page}")
        return response if isinstance(response, list) else None

    def get_project(self, owner, number):
        return self._get(f"/users/{owner}/projects/{number}")


def main(argv=None):
    args = list(sys.argv[1:] if argv is None else argv)
    if len(args) != 2 or args[0] != "--input":
        print('{"schema_version":1,"result":"FAIL","error_code":"AUDIT_USAGE"}')
        return 1
    try:
        with open(args[1], encoding="utf-8") as source:
            data = json.load(source)
        result = verify(GhApi(), data.get("repository"), data.get("subject"))
    except (AttributeError, OSError, TypeError, ValueError):
        result = _failure("INVALID_EVIDENCE")
    print(json.dumps(result, separators=(",", ":"), ensure_ascii=True))
    return 0 if result.get("result") == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
