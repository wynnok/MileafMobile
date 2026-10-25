"""Offline synthetic CSV data for #16; standard library only, no external repository imports."""

import argparse
import csv
import hashlib
import json
import math
import os
import shutil
import subprocess
import sys
import tempfile
import time
from datetime import UTC, datetime, timedelta
from pathlib import Path
from random import Random
from uuid import uuid4

ROOT = Path(__file__).resolve().parents[2]
FROZEN = Path(__file__).with_name("frozen")
SERVER = "146cb3b9a16af3d632b04ed8d197d0f2243d9b71"
FROZEN_HASHES = {
    "schema.sql": "ecffecdcfbbd6bbf38083a761845d46fdee8b0e72b1e95a3ce980e7c2ea74425",
    "migration_versions.txt": "ea850d1b038c4af950db32e7a0939aa5ebe8f1dcefe5e56dcd592f3451038868",
}
COLUMNS = {
    "settings": "id,inserted_at,updated_at",
    "car_settings": "id",
    "cars": "id,eid,vid,vin,name,model,efficiency,settings_id,inserted_at,updated_at",
    "states": "id,car_id,state,start_date",
    "updates": "id,car_id,start_date,end_date,version",
    "drives": "id,car_id,start_date,end_date,distance,duration_min,start_rated_range_km,end_rated_range_km,speed_max,start_position_id,end_position_id",
    "positions": "id,car_id,drive_id,date,latitude,longitude,speed,battery_level,elevation,rated_battery_range_km,odometer",
    "charging_processes": "id,car_id,position_id,start_date,end_date,charge_energy_added,charge_energy_used,cost,duration_min,start_battery_level,end_battery_level",
    "charges": "id,charging_process_id,date,charge_energy_added,charger_power,charger_phases,battery_level,ideal_battery_range_km",
}
COUNTS = dict(
    settings=1,
    car_settings=1,
    cars=1,
    states=1,
    updates=1,
    drives=50_000,
    positions=500_000,
    charging_processes=5_000,
    charges=100_000,
)


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def stamp(value):
    return value.astimezone(UTC).replace(tzinfo=None).isoformat(timespec="microseconds")


def anchor_value(value):
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo != UTC or parsed.microsecond:
        raise ValueError("anchor must be UTC with whole seconds")
    return parsed


def write_json(path, value):
    path.write_text(
        json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n"
    )


def safe_output(path):
    if ".." in path.parts:
        raise ValueError("parent traversal forbidden")
    path = path if path.is_absolute() else ROOT / path
    relative = path.relative_to(ROOT / ".cache")
    if not relative.parts:
        raise ValueError("cache root cannot be a dataset")
    for candidate in (path, *path.parents):
        if candidate.is_symlink():
            raise ValueError("symbolic links forbidden")
    return path


def generate(output, seed, anchor):
    output.mkdir(parents=True, exist_ok=False)
    for name, expected in FROZEN_HASHES.items():
        if digest(FROZEN / name) != expected:
            raise ValueError("frozen source mismatch")
        (output / name).write_bytes((FROZEN / name).read_bytes())
    random = Random(seed)
    streams = {}
    writers = {}
    try:
        for table, columns in COLUMNS.items():
            streams[table] = (output / f"{table}.csv").open("w", newline="")
            writers[table] = csv.writer(streams[table], lineterminator="\n")
            writers[table].writerow(columns.split(","))
        end = anchor - timedelta(hours=1)
        start = end - timedelta(minutes=15 * 49_999)
        writers["settings"].writerow([1, stamp(start), stamp(start)])
        writers["car_settings"].writerow([3])
        writers["cars"].writerow(
            [
                3,
                1003,
                2003,
                "FIXTURE00000000003",
                "性能合成车",
                "3",
                "0.15",
                3,
                stamp(start),
                stamp(start),
            ]
        )
        writers["states"].writerow([1, 3, "asleep", stamp(end + timedelta(minutes=5))])
        writers["updates"].writerow([1, 3, stamp(start), stamp(start), "synthetic-1"])
        position_id = 1_000_000
        charge_id = 1_000_000
        for index in range(50_000):
            drive_id = 100_000 + index
            when = start + timedelta(minutes=15 * index)
            count = 20_000 if index == 49_999 else 10 if index < 30_009 else 9
            distance = random.randrange(500, 901) / 100
            writers["drives"].writerow(
                [
                    drive_id,
                    3,
                    stamp(when),
                    stamp(when + timedelta(minutes=5)),
                    f"{distance:.2f}",
                    5,
                    350,
                    325,
                    110,
                    position_id,
                    position_id + count - 1,
                ]
            )
            for point in range(count):
                progress = point / (count - 1)
                writers["positions"].writerow(
                    [
                        position_id + point,
                        3,
                        drive_id,
                        stamp(when + timedelta(seconds=300 * progress)),
                        f"{31.23 + 0.01 * progress:.6f}",
                        f"{121.47 + 0.01 * progress:.6f}",
                        random.randrange(0, 111),
                        80 - int(10 * progress),
                        random.randrange(0, 100),
                        f"{350 - 25 * progress:.2f}",
                        f"{10_000 + index * 10 + distance * progress:.3f}",
                    ]
                )
            if index % 10 == 0:
                session_id = 100_000 + index // 10
                charging_start = when + timedelta(minutes=6)
                writers["charging_processes"].writerow(
                    [
                        session_id,
                        3,
                        position_id + count - 1,
                        stamp(charging_start),
                        stamp(charging_start + timedelta(minutes=8)),
                        20,
                        22,
                        12,
                        8,
                        40,
                        70,
                    ]
                )
                for point in range(20):
                    progress = point / 19
                    writers["charges"].writerow(
                        [
                            charge_id,
                            session_id,
                            stamp(charging_start + timedelta(seconds=480 * progress)),
                            f"{20 * progress:.2f}",
                            120 if session_id % 2 else 11,
                            "" if session_id % 2 else 3,
                            40 + int(30 * progress),
                            300,
                        ]
                    )
                    charge_id += 1
            position_id += count
    finally:
        for stream in streams.values():
            stream.close()
    files = {path.name: digest(path) for path in sorted(output.iterdir())}
    write_json(
        output / "manifest.json",
        {
            "format": 1,
            "seed": seed,
            "anchor": anchor.isoformat().replace("+00:00", "Z"),
            "server_commit": SERVER,
            "schema": FROZEN_HASHES,
            "counts": COUNTS,
            "files": files,
            "resources": {
                "vehicle": {"id": 3},
                "dense_drive": {
                    "id": 149_999,
                    "source_points": 20_000,
                    "from": stamp(end),
                    "to": stamp(end + timedelta(minutes=5)),
                    "fields": "speed,battery,elevation",
                    "points": 200,
                },
                "charging": {"first_id": 100_000, "last_id": 104_999, "page_size": 20},
                "interval": {"from": stamp(start), "to": stamp(anchor), "tz": "UTC"},
            },
        },
    )


def verify(output):
    if not output.is_dir() or any(
        p.is_symlink() or not p.is_file() for p in output.iterdir()
    ):
        raise ValueError("nonregular artifact forbidden")
    manifest = json.loads((output / "manifest.json").read_text())
    if (
        manifest["format"] != 1
        or manifest["server_commit"] != SERVER
        or manifest["counts"] != COUNTS
        or manifest["schema"] != FROZEN_HASHES
    ):
        raise ValueError("manifest mismatch")
    expected = {f"{table}.csv" for table in COLUMNS} | set(FROZEN_HASHES)
    if set(manifest["files"]) != expected or {
        p.name for p in output.iterdir()
    } != expected | {"manifest.json"}:
        raise ValueError("unexpected artifacts")
    for name, expected_hash in manifest["files"].items():
        if digest(output / name) != expected_hash:
            raise ValueError("artifact hash mismatch")
    for name, expected_hash in FROZEN_HASHES.items():
        if digest(output / name) != expected_hash:
            raise ValueError("schema mismatch")
    validate_rows(output, manifest)
    return manifest


def rows(output, table):
    with (output / f"{table}.csv").open(newline="") as stream:
        reader = csv.DictReader(stream)
        if reader.fieldnames != COLUMNS[table].split(","):
            raise ValueError("CSV header mismatch")
        seen = set()
        for row in reader:
            if None in row or None in row.values():
                raise ValueError("CSV row shape mismatch")
            identifier = int(row["id"])
            if identifier <= 0 or identifier in seen:
                raise ValueError("duplicate or invalid row ID")
            seen.add(identifier)
            for key, value in row.items():
                if any(character in value for character in ("\\", "\n", "\r", "\x00")):
                    raise ValueError("unsafe CSV control data")
                if key in (
                    "date",
                    "start_date",
                    "end_date",
                    "inserted_at",
                    "updated_at",
                ):
                    parsed = datetime.fromisoformat(value)
                    if (
                        parsed.tzinfo is not None
                        or stamp(parsed.replace(tzinfo=UTC)) != value
                    ):
                        raise ValueError("timestamp format mismatch")
                elif key not in ("vin", "name", "model", "state", "version") and value:
                    if not math.isfinite(float(value)):
                        raise ValueError("nonfinite number")
            yield row
        if len(seen) != COUNTS[table]:
            raise ValueError("CSV count mismatch")


def validate_rows(output, manifest):
    anchor = anchor_value(manifest["anchor"])
    if not isinstance(manifest["seed"], int) or isinstance(manifest["seed"], bool):
        raise ValueError("seed mismatch")
    tables = {
        table: {int(row["id"]): row for row in rows(output, table)}
        for table in COLUMNS
        if table not in ("positions", "charges")
    }
    if (
        set(tables["cars"]) != {3}
        or set(tables["settings"]) != {1}
        or set(tables["car_settings"]) != {3}
    ):
        raise ValueError("vehicle identity mismatch")
    for car in tables["cars"].values():
        if int(car["settings_id"]) not in tables["car_settings"]:
            raise ValueError("car settings reference mismatch")
    drives = tables["drives"]
    for table in ("states", "updates", "drives", "charging_processes"):
        for row in tables[table].values():
            if int(row["car_id"]) not in tables["cars"]:
                raise ValueError("vehicle reference mismatch")
            if row.get("end_date", row["start_date"]) < row["start_date"]:
                raise ValueError("negative duration")
    if set(drives) != set(range(100_000, 150_000)):
        raise ValueError("drive identities mismatch")
    endpoints = {}
    position_references = {
        int(row["position_id"]) for row in tables["charging_processes"].values()
    }
    referenced_positions = {}
    for row in rows(output, "positions"):
        drive_id = int(row["drive_id"])
        if drive_id not in drives:
            raise ValueError("position drive reference mismatch")
        drive = drives[drive_id]
        if (
            row["car_id"] != drive["car_id"]
            or not drive["start_date"] <= row["date"] <= drive["end_date"]
        ):
            raise ValueError("position ownership or time mismatch")
        if (
            not -90 <= float(row["latitude"]) <= 90
            or not -180 <= float(row["longitude"]) <= 180
            or not 0 <= int(row["battery_level"]) <= 100
            or not 0 <= int(row["speed"]) <= 110
        ):
            raise ValueError("position metric mismatch")
        identifier = int(row["id"])
        if identifier in position_references:
            referenced_positions[identifier] = (row["car_id"], row["date"])
        aggregate = endpoints.get(drive_id)
        if aggregate is None:
            endpoints[drive_id] = [identifier, identifier, row["date"], row["date"], 1]
        else:
            if row["date"] <= aggregate[3] or identifier <= aggregate[1]:
                raise ValueError("position order mismatch")
            aggregate[1], aggregate[3] = identifier, row["date"]
            aggregate[4] += 1
    for identifier, drive in drives.items():
        aggregate = endpoints.get(identifier)
        if (
            aggregate is None
            or (int(drive["start_position_id"]), int(drive["end_position_id"]))
            != tuple(aggregate[:2])
            or (drive["start_date"], drive["end_date"]) != tuple(aggregate[2:4])
        ):
            raise ValueError("drive endpoints mismatch")
        if aggregate[4] != (
            20_000 if identifier == 149_999 else 10 if identifier < 130_009 else 9
        ):
            raise ValueError("drive sample count mismatch")
        if float(drive["distance"]) <= 0 or int(drive["duration_min"]) != 5:
            raise ValueError("drive metrics mismatch")
    sessions = tables["charging_processes"]
    for session in sessions.values():
        position = referenced_positions.get(int(session["position_id"]))
        if (
            position is None
            or position[0] != session["car_id"]
            or position[1] > session["start_date"]
        ):
            raise ValueError("charging position reference mismatch")
        if (
            float(session["charge_energy_added"]) < 0
            or float(session["charge_energy_used"])
            < float(session["charge_energy_added"])
            or not 0
            <= int(session["start_battery_level"])
            <= int(session["end_battery_level"])
            <= 100
        ):
            raise ValueError("charging metric mismatch")
    samples = {}
    for row in rows(output, "charges"):
        identifier = int(row["charging_process_id"])
        if identifier not in sessions:
            raise ValueError("charge session reference mismatch")
        session = sessions[identifier]
        if not session["start_date"] <= row["date"] <= session["end_date"]:
            raise ValueError("charge time mismatch")
        if (
            not 0
            <= float(row["charge_energy_added"])
            <= float(session["charge_energy_added"])
            or not 0 <= int(row["battery_level"]) <= 100
            or int(row["charger_power"]) < 0
            or row["charger_phases"]
            and int(row["charger_phases"]) <= 0
        ):
            raise ValueError("charge metric mismatch")
        previous = samples.get(identifier)
        if previous is None:
            samples[identifier] = [
                row["date"],
                row["date"],
                1,
                float(row["charge_energy_added"]),
            ]
        else:
            if (
                row["date"] <= previous[1]
                or float(row["charge_energy_added"]) < previous[3]
            ):
                raise ValueError("charge sample order mismatch")
            previous[1], previous[3] = row["date"], float(row["charge_energy_added"])
            previous[2] += 1
    for identifier, session in sessions.items():
        sample = samples.get(identifier)
        if (
            sample is None
            or sample[:3] != [session["start_date"], session["end_date"], 20]
            or sample[3] != float(session["charge_energy_added"])
        ):
            raise ValueError("charge sample endpoints mismatch")
    resource = manifest["resources"]
    dense = resource["dense_drive"]
    if (
        dense
        != {
            "id": 149_999,
            "source_points": 20_000,
            "from": drives[149_999]["start_date"],
            "to": drives[149_999]["end_date"],
            "fields": "speed,battery,elevation",
            "points": 200,
        }
        or resource["vehicle"] != {"id": 3}
        or resource["charging"]
        != {"first_id": 100_000, "last_id": 104_999, "page_size": 20}
    ):
        raise ValueError("resource manifest mismatch")
    if (
        resource["interval"]
        != {"from": drives[100_000]["start_date"], "to": stamp(anchor), "tz": "UTC"}
        or drives[149_999]["end_date"] != stamp(anchor - timedelta(minutes=55))
        or set(sessions) != set(range(100_000, 105_000))
    ):
        raise ValueError("resource interval mismatch")


def docker(socket_path, *arguments, stdin=None, timeout=60):
    # Never inherit a remote DOCKER_HOST/context, production .env, home config,
    # TLS certificate paths or credential helpers. The socket is always local.
    with tempfile.TemporaryDirectory(
        prefix="performance-docker-", dir=ROOT / ".cache"
    ) as config:
        environment = {"PATH": os.environ.get("PATH", os.defpath), "LANG": "C"}
        return subprocess.run(
            [
                "docker",
                "--host",
                "unix://" + str(socket_path),
                "--config",
                config,
                *arguments,
            ],
            stdin=stdin,
            env=environment,
            capture_output=True,
            timeout=timeout,
            check=False,
        )


def load(output, manifest, preflight=False, socket_path=Path("/var/run/docker.sock")):
    # Only this command creates a new disposable container. No DSN, existing
    # resource identifier, host mount, registry pull, daemon start or port publish.
    if not socket_path.is_socket():
        raise ValueError("local Unix socket unavailable")
    image = docker(
        socket_path, "image", "inspect", "--format", "{{.Id}}", "postgres:16-alpine"
    )
    if image.returncode:
        raise ValueError("cached image or local Docker unavailable")
    if preflight:
        return
    task_id = uuid4().hex
    name = "mileaf-performance-" + task_id
    created = False
    try:
        result = docker(
            socket_path,
            "run",
            "--detach",
            "--rm",
            "--pull=never",
            "--network",
            "none",
            "--name",
            name,
            "--label",
            "mileaf.performance-data=" + task_id,
            "--tmpfs",
            "/var/lib/postgresql/data:rw,size=1073741824",
            "--env",
            "POSTGRES_HOST_AUTH_METHOD=trust",
            "postgres:16-alpine",
        )
        # A failed/timed-out run can have created a resource: finally checks its
        # unique task label before cleanup, rather than assuming failure is atomic.
        if result.returncode:
            raise ValueError("container creation failed")
        created = True
        for attempt in range(100):
            ready = docker(
                socket_path, "exec", name, "pg_isready", "-U", "postgres", timeout=5
            )
            if ready.returncode == 0:
                break
            time.sleep(0.1)
        else:
            raise ValueError("database readiness failed")
        server_version = docker(
            socket_path,
            "exec",
            name,
            "psql",
            "--no-psqlrc",
            "-t",
            "-A",
            "-U",
            "postgres",
            "-d",
            "postgres",
            "-c",
            "SHOW server_version_num",
        )
        if (
            server_version.returncode
            or int(server_version.stdout.strip()) // 10000 != 16
        ):
            raise ValueError("PostgreSQL16 required")
        with tempfile.TemporaryFile(dir=ROOT / ".cache") as sql:
            sql.write(b"BEGIN;\n")
            sql.write((output / "schema.sql").read_bytes())
            sql.write(
                b"\nALTER TABLE drives ALTER CONSTRAINT drives_start_position_id_fkey DEFERRABLE INITIALLY DEFERRED;\n"
            )
            sql.write(
                b"ALTER TABLE drives ALTER CONSTRAINT drives_end_position_id_fkey DEFERRABLE INITIALLY DEFERRED;\n"
            )
            for version in (output / "migration_versions.txt").read_text().splitlines():
                sql.write(
                    f"INSERT INTO schema_migrations VALUES ({int(version)},'2026-01-01');\n".encode()
                )
            for table, columns in COLUMNS.items():
                sql.write(
                    f"COPY {table} ({columns}) FROM STDIN WITH (FORMAT csv, HEADER true);\n".encode()
                )
                with (output / f"{table}.csv").open("rb") as stream:
                    shutil.copyfileobj(stream, sql)
                sql.write(b"\\.\n")
            sql.write(b"COMMIT;\n")
            for table in COLUMNS:
                sql.write(f"ANALYZE {table};\n".encode())
            sql.write(
                b"CREATE ROLE mileaf_reader LOGIN; GRANT USAGE ON SCHEMA public TO mileaf_reader; GRANT SELECT ON ALL TABLES IN SCHEMA public TO mileaf_reader; ALTER ROLE mileaf_reader SET default_transaction_read_only=on; SET ROLE mileaf_reader; BEGIN READ ONLY;\n"
            )
            counts = ",".join(
                f"'{table}',(SELECT count(*) FROM {table})" for table in COLUMNS
            )
            sql.write(f"SELECT json_build_object({counts}); COMMIT;\n".encode())
            sql.seek(0)
            result = docker(
                socket_path,
                "exec",
                "-i",
                name,
                "psql",
                "--no-psqlrc",
                "-q",
                "-t",
                "-A",
                "-v",
                "ON_ERROR_STOP=1",
                "-U",
                "postgres",
                "-d",
                "postgres",
                stdin=sql,
                timeout=180,
            )
        if result.returncode or json.loads(result.stdout) != manifest["counts"]:
            raise ValueError("database load or read-only counts failed")
        report = {
            "server_commit": SERVER,
            "image_id": image.stdout.decode().strip(),
            "manifest_sha256": digest(output / "manifest.json"),
            "counts": manifest["counts"],
            "database_loaded": True,
            "postgres_version_num": int(server_version.stdout.strip()),
            "api_200_points_verified": False,
            "device_samples": 0,
        }
    finally:
        ownership = docker(
            socket_path,
            "inspect",
            "--format",
            '{{ index .Config.Labels "mileaf.performance-data" }}',
            name,
        )
        if ownership.returncode == 0 and ownership.stdout.decode().strip() == task_id:
            if docker(socket_path, "rm", "--force", name).returncode:
                raise ValueError("task container cleanup failed")
        elif created:
            raise ValueError("task container cleanup could not be confirmed")
    report["task_container_removed"] = True
    report_path = ROOT / ".cache" / ("performance-load-" + task_id + ".json")
    with report_path.open("x") as stream:
        json.dump(report, stream, sort_keys=True, indent=2)
        stream.write("\n")


def local_socket(value):
    path = Path(value)
    if not path.is_absolute() or ".." in path.parts or "://" in value:
        raise argparse.ArgumentTypeError("requires an absolute local Unix socket path")
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["generate", "verify", "load"])
    parser.add_argument("--output", type=Path, default=ROOT / ".cache/performance-data")
    parser.add_argument("--seed", type=int, default=27)
    parser.add_argument(
        "--docker-socket",
        type=local_socket,
        default=Path("/var/run/docker.sock"),
        help="load only: explicit absolute local Unix socket; never a Docker context or remote URL",
    )
    parser.add_argument(
        "--preflight",
        action="store_true",
        help="load only: inspect the cached image on the fixed local Unix socket without creating a database",
    )
    parser.add_argument("--anchor", default="2026-03-15T12:00:00Z")
    args = parser.parse_args()
    if args.preflight and args.command != "load":
        parser.error("--preflight requires load")
    try:
        args.output = safe_output(args.output)
        if args.command == "generate":
            generate(args.output, args.seed, anchor_value(args.anchor))
        manifest = verify(args.output)
        if args.command == "load":
            load(args.output, manifest, args.preflight, args.docker_socket)
    except (
        ValueError,
        OverflowError,
        OSError,
        KeyError,
        TypeError,
        StopIteration,
        csv.Error,
        subprocess.SubprocessError,
    ):
        print(
            "PERFORMANCE_DATA_FAILED: artifact/input validation or isolated load unavailable; no external database is accepted",
            file=sys.stderr,
        )
        return 1
    if args.preflight:
        print(
            "PERFORMANCE_PREFLIGHT_OK: cached image inspected on fixed local Unix socket; no database created"
        )
        return 0
    print(
        "PERFORMANCE_LOAD_OK: disposable database counts verified and container removed"
        if args.command == "load"
        else "PERFORMANCE_DATA_OK: verified synthetic CSV artifacts; no database was accessed"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
