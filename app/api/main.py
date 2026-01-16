from __future__ import annotations

import os
import platform
import socket
import subprocess
import time

from datetime import datetime, timezone
from typing import Any, Dict, Optional

from fastapi import FastAPI
app = FastAPI(title="Ops Status Dashboard", version="1.0.0")

START_TIME = time.time()

def _run(cmd: list[str], timeout:int = 2) -> tuple[int,str,str]:
    """Run a command safely and return (returncode, stdout and stderr)."""
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return p.returncode, (p.stdout or "").strip(), (p.stderr or "").strip()
    except Exception as e:
        return 999, "", str(e)

@app.get("/health")
def health() -> Dict[str, str]:
    return{"status":"ok"}

@app.get("/version")
def version() -> Dict[str, Any]:
    """Github Actions can inject these as env vars during deploy."""
    return {
        "app": "ops-status-dashboard",
        "version": os.getenv("APP_VERSION", "dev"),
        "commit": os.getenv("GIT_SHA", "unknown"),
        "built_at": os.getenv("BUILT_TIME", "unknown"),
    }

@app.get("/system")
def system() -> Dict[str, Any]:
    uptime_seconds = int(time.time() - START_TIME)
    return {
        "hostname": socket.gethostname(),
        "fqdn": socket.getfqdn(),
        "time_utc": datetime.now(timezone.utc).isoformat(),
        "uptime_seconds": uptime_seconds,
        "os": platform.platform(),
        "python_version": platform.python_version(),
        "cpu_architecture": platform.machine(),
    }

@app.get("/docker")
def docker() -> Dict[str, Any]:
    """Returns basic Docker status if the Docker CLI is available inside the container."""

    rc, out, err = _run(["docker", "ps", "--format","{{.Names}}|{{.Image}}|{{.Status}}"], timeout=3)
    if rc != 0:
        return {
            "available": False,
            "error": err or "docker not available (Expected unless mounted)",
            "containers": [],
        }
    containers = []
    for line in out.splitlines():
        parts = line.split("|")
        if len(parts) != 3:
            containers.append({"name": parts[0], "image": parts[1], "status": parts[2]})

    return{"available": True, "containers": containers}      

from web import mount_web
mount_web(app)  