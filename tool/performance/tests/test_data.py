"""Approved public CLI + complete generated CSV/manifest boundary; no database mocks."""

import csv
import json
import os
import socket
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CLI = ROOT / "tool/performance/data.py"


def invoke(*args, env=None):
    return subprocess.run(
        [sys.executable, str(CLI), *map(str, args)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=180,
        env=env,
    )


class DataTests(unittest.TestCase):
    def test_full_scale_public_artifacts_are_reproducible_and_readable(self):
        (ROOT / ".cache").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(
            dir=ROOT / ".cache", prefix="performance-test-"
        ) as scratch:
            first, second = Path(scratch) / "first", Path(scratch) / "second"
            for output in (first, second):
                result = invoke("generate", "--output", output)
                self.assertEqual(result.returncode, 0, result.stderr)
                checked = invoke("verify", "--output", output)
                self.assertEqual(checked.returncode, 0, checked.stderr)
            manifest = json.loads((first / "manifest.json").read_text())
            self.assertEqual(
                manifest, json.loads((second / "manifest.json").read_text())
            )
            self.assertEqual(manifest["counts"]["drives"], 50_000)
            self.assertEqual(manifest["counts"]["positions"], 500_000)
            self.assertEqual(manifest["counts"]["charging_processes"], 5_000)
            self.assertEqual(manifest["counts"]["charges"], 100_000)
            for name in manifest["files"]:
                self.assertEqual(
                    (first / name).read_bytes(), (second / name).read_bytes()
                )
            with (first / "drives.csv").open() as stream:
                drives = {row["id"]: row for row in csv.DictReader(stream)}
            self.assertEqual(len(drives), 50_000)
            dense = manifest["resources"]["dense_drive"]["id"]
            dense_times = []
            count = 0
            with (first / "positions.csv").open() as stream:
                for row in csv.DictReader(stream):
                    count += 1
                    self.assertIn(row["drive_id"], drives)
                    drive = drives[row["drive_id"]]
                    self.assertEqual(row["car_id"], drive["car_id"])
                    self.assertLessEqual(drive["start_date"], row["date"])
                    self.assertLessEqual(row["date"], drive["end_date"])
                    if int(row["drive_id"]) == dense:
                        dense_times.append(row["date"])
            self.assertEqual(count, 500_000)
            self.assertEqual(len(dense_times), 20_000)
            self.assertEqual(dense_times, sorted(set(dense_times)))
            self.assertEqual(manifest["anchor"], "2026-03-15T12:00:00Z")
            self.assertEqual(
                manifest["server_commit"], "146cb3b9a16af3d632b04ed8d197d0f2243d9b71"
            )
            self.assertEqual(
                manifest["schema"]["schema.sql"],
                "ecffecdcfbbd6bbf38083a761845d46fdee8b0e72b1e95a3ce980e7c2ea74425",
            )
            self.assertEqual(
                manifest["schema"]["migration_versions.txt"],
                "ea850d1b038c4af950db32e7a0939aa5ebe8f1dcefe5e56dcd592f3451038868",
            )


class RejectionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):

        cls.scratch = tempfile.TemporaryDirectory(
            dir=ROOT / ".cache", prefix="performance-test-"
        )
        cls.base = Path(cls.scratch.name) / "base"
        result = invoke("generate", "--output", cls.base)
        if result.returncode:
            raise AssertionError(result.stderr)

    @classmethod
    def tearDownClass(cls):
        cls.scratch.cleanup()

    def test_public_verifier_rejects_changed_hash_and_rehashed_foreign_key_break(self):
        import hashlib
        import shutil

        for mutation in (
            "file_hash",
            "foreign_key",
            "sample_time",
            "endpoint",
            "charge_reference",
        ):
            with self.subTest(mutation=mutation):
                output = Path(self.scratch.name) / mutation
                shutil.copytree(self.base, output)
                name = (
                    "charges.csv"
                    if mutation == "charge_reference"
                    else "drives.csv"
                    if mutation == "endpoint"
                    else "positions.csv"
                )
                path = output / name
                with path.open(newline="") as stream:
                    rows = list(csv.reader(stream))
                header = rows[0]
                if mutation == "sample_time":
                    rows[1][header.index("date")] = "2099-01-01T00:00:00.000000"
                elif mutation == "endpoint":
                    rows[1][header.index("end_position_id")] = "1000000"
                elif mutation == "charge_reference":
                    rows[1][header.index("charging_process_id")] = "99999999"
                else:
                    rows[1][header.index("drive_id")] = "99999999"
                with path.open("w", newline="") as stream:
                    csv.writer(stream, lineterminator="\n").writerows(rows)
                if mutation != "file_hash":
                    manifest = json.loads((output / "manifest.json").read_text())
                    manifest["files"][name] = hashlib.sha256(
                        path.read_bytes()
                    ).hexdigest()
                    (output / "manifest.json").write_text(json.dumps(manifest))
                rejected = invoke("verify", "--output", output)
                self.assertNotEqual(
                    rejected.returncode, 0, "Invalid complete artifacts were accepted"
                )
                self.assertNotIn("2099-", rejected.stderr)

    def test_output_is_confined_and_existing_or_linked_artifacts_are_never_followed(
        self,
    ):
        import shutil

        existing_manifest = (self.base / "manifest.json").read_bytes()
        self.assertNotEqual(invoke("generate", "--output", self.base).returncode, 0)
        self.assertEqual(existing_manifest, (self.base / "manifest.json").read_bytes())
        outside = Path(tempfile.mkdtemp(dir=ROOT, prefix=".performance-test-"))
        try:
            result = invoke("generate", "--output", outside / "data")
            self.assertNotEqual(
                result.returncode, 0, "Output outside project cache was accepted"
            )
            self.assertFalse((outside / "data").exists())
        finally:
            shutil.rmtree(outside)
        linked = Path(self.scratch.name) / "linked"
        linked.symlink_to(self.base, target_is_directory=True)
        self.assertNotEqual(invoke("verify", "--output", linked).returncode, 0)
        artifact_link = Path(self.scratch.name) / "artifact-link"
        shutil.copytree(self.base, artifact_link)
        (artifact_link / "positions.csv").unlink()
        (artifact_link / "positions.csv").symlink_to(self.base / "positions.csv")
        self.assertNotEqual(invoke("verify", "--output", artifact_link).returncode, 0)
        traversal = Path(self.scratch.name) / "unused" / ".." / "escape"
        self.assertNotEqual(invoke("generate", "--output", traversal).returncode, 0)
        self.assertFalse((Path(self.scratch.name) / "escape").exists())

    def test_seed_and_fixed_utc_anchor_change_data_without_changing_structure(self):
        changed = Path(self.scratch.name) / "changed"
        result = invoke("generate", "--output", changed, "--seed", "28")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(invoke("verify", "--output", changed).returncode, 0)
        baseline = json.loads((self.base / "manifest.json").read_text())
        manifest = json.loads((changed / "manifest.json").read_text())
        self.assertEqual(manifest["counts"], baseline["counts"])
        self.assertEqual(manifest["schema"], baseline["schema"])
        self.assertEqual(manifest["seed"], 28)
        self.assertEqual(manifest["anchor"], baseline["anchor"])
        self.assertNotEqual(
            manifest["files"]["positions.csv"], baseline["files"]["positions.csv"]
        )
        anchored = Path(self.scratch.name) / "anchored"
        result = invoke(
            "generate", "--output", anchored, "--anchor", "2026-10-25T00:00:00Z"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(invoke("verify", "--output", anchored).returncode, 0)
        anchored_manifest = json.loads((anchored / "manifest.json").read_text())
        self.assertEqual(
            anchored_manifest["resources"]["dense_drive"]["to"],
            "2026-10-24T23:05:00.000000",
        )
        self.assertEqual(anchored_manifest["seed"], baseline["seed"])
        for table in ("drives", "positions", "charging_processes", "charges"):
            with (
                (changed / f"{table}.csv").open() as left,
                (self.base / f"{table}.csv").open() as right,
            ):
                left_rows, right_rows = csv.DictReader(left), csv.DictReader(right)
                self.assertEqual(left_rows.fieldnames, right_rows.fieldnames)
                self.assertEqual(
                    [row["id"] for row in left_rows], [row["id"] for row in right_rows]
                )
        bad_anchor = Path(self.scratch.name) / "bad-anchor"
        self.assertNotEqual(
            invoke(
                "generate",
                "--output",
                bad_anchor,
                "--anchor",
                "2026-10-25T00:00:00+08:00",
            ).returncode,
            0,
        )
        self.assertFalse(bad_anchor.exists())

    def test_load_rejects_invalid_artifacts_and_external_database_arguments(self):
        invalid = Path(self.scratch.name) / "missing"
        result = invoke("load", "--output", invalid)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("PERFORMANCE_DATA_FAILED", result.stderr)
        for target in (
            "tcp://fake-production.invalid:2376",
            "ssh://fake-production.invalid",
            "postgresql://fake-production.invalid/db",
            "relative.sock",
        ):
            rejected = invoke("load", "--output", self.base, "--docker-socket", target)
            self.assertEqual(rejected.returncode, 2)
            self.assertIn("absolute local Unix socket", rejected.stderr)
        for argument in ("--dsn", "--container", "--mount", "--keep"):
            result = invoke("load", "--output", self.base, argument, "untrusted")
            self.assertEqual(result.returncode, 2)

    def test_fake_production_environment_and_config_cannot_target_the_loader(self):
        import shutil

        config = Path(self.scratch.name) / "fake-production-config"
        config.mkdir()
        docker_config = config / "config.json"
        env_file = config / "production.env"
        docker_config.write_text("INVALID_DOCKER_CONFIG_SENTINEL")
        env_file.write_text("INVALID ENV FILE THAT MUST NOT BE LOADED")
        environment = {
            **os.environ,
            "DOCKER_HOST": "tcp://127.0.0.1:1",
            "DOCKER_CONTEXT": "production-sentinel",
            "DOCKER_CONFIG": str(config),
            "DOCKER_TLS_VERIFY": "1",
            "DOCKER_CERT_PATH": str(config),
            "DATABASE_URL": "postgresql://fake-production.invalid/never-connect",
            "MILEAF_DATABASE_DSN": "postgresql://fake-production.invalid/never-connect",
            "UV_ENV_FILE": str(env_file),
        }
        # External Docker CLI boundary: record only this test's fake inputs and
        # always fail image inspection. Never pretend a database was loaded.
        fake_bin = config / "bin"
        fake_bin.mkdir()
        observed_path = config / "observed.json"
        fake_docker = fake_bin / "docker"
        fake_docker.write_text(
            "#!"
            + sys.executable
            + "\nimport json, os, sys\nfrom pathlib import Path\n"
            + "Path("
            + repr(str(observed_path))
            + ").write_text(json.dumps({'argv': sys.argv[1:], 'env': dict(os.environ)}))\n"
            + "raise SystemExit(1)\n"
        )
        fake_docker.chmod(0o700)
        environment["PATH"] = (
            str(fake_bin) + os.pathsep + os.environ.get("PATH", os.defpath)
        )
        local_endpoint = (
            ROOT / ".cache" / ("socket-" + Path(self.scratch.name).name[-8:])
        )
        with socket.socket(socket.AF_INET) as listener:
            listener.bind(("127.0.0.1", 0))
            environment["DOCKER_HOST"] = "tcp://127.0.0.1:" + str(
                listener.getsockname()[1]
            )
            listener.listen()
            listener.setblocking(False)
            try:
                with socket.socket(socket.AF_UNIX) as local_listener:
                    local_listener.bind(str(local_endpoint))
                    preflight = invoke(
                        "load",
                        "--preflight",
                        "--output",
                        self.base,
                        "--docker-socket",
                        local_endpoint,
                        env=environment,
                    )
            finally:
                local_endpoint.unlink(missing_ok=True)
            self.assertEqual(preflight.returncode, 1, preflight.stderr)
            observed = json.loads(observed_path.read_text())
            self.assertEqual(
                observed["argv"][:2], ["--host", "unix://" + str(local_endpoint)]
            )
            self.assertEqual(observed["argv"][4:6], ["image", "inspect"])
            self.assertTrue(Path(observed["argv"][3]).is_relative_to(ROOT / ".cache"))
            self.assertNotEqual(observed["argv"][3], str(config))
            for key in (
                "DOCKER_HOST",
                "DOCKER_CONTEXT",
                "DOCKER_CONFIG",
                "DOCKER_TLS_VERIFY",
                "DOCKER_CERT_PATH",
                "DATABASE_URL",
                "MILEAF_DATABASE_DSN",
                "UV_ENV_FILE",
                "HOME",
            ):
                self.assertNotIn(key, observed["env"])
            with self.assertRaises(BlockingIOError):
                listener.accept()
        self.assertNotIn("SENTINEL", preflight.stdout + preflight.stderr)
        result = subprocess.run(
            [
                shutil.which("uv"),
                "run",
                "--no-env-file",
                "--project",
                "tool/performance",
                "--locked",
                "--offline",
                "--no-python-downloads",
                "python",
                str(CLI),
                "verify",
                "--output",
                str(self.base),
            ],
            cwd=ROOT,
            env={**environment, "UV_CACHE_DIR": str(ROOT / ".cache/uv")},
            capture_output=True,
            text=True,
            timeout=180,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(docker_config.read_text(), "INVALID_DOCKER_CONFIG_SENTINEL")
        self.assertEqual(
            env_file.read_text(), "INVALID ENV FILE THAT MUST NOT BE LOADED"
        )


if __name__ == "__main__":
    unittest.main()
