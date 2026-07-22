#!/usr/bin/env python3

import json
import os
import subprocess
import sys
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit


class RouterHandler(BaseHTTPRequestHandler):
    models = {"keep/model:Q4", "old/model:Q4"}
    mutations = []

    def log_message(self, _format, *_args):
        pass

    def send_json(self, status, value):
        body = json.dumps(value).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def read_model(self):
        length = int(self.headers.get("Content-Length", "0"))
        payload = json.loads(self.rfile.read(length) or b"{}")
        return payload["model"]

    def do_GET(self):
        parsed = urlsplit(self.path)
        if parsed.path != "/models":
            self.send_json(404, {"error": "not found"})
            return
        self.send_json(
            200,
            {"data": [{"id": model} for model in sorted(self.models)]},
        )

    def do_POST(self):
        model = self.read_model()
        if self.path == "/models/unload":
            self.mutations.append(("POST", self.path, model))
            self.send_json(200, {"success": True})
            return
        if self.path == "/models":
            self.mutations.append(("POST", self.path, model))
            self.models.add(model)
            self.send_json(200, {"success": True})
            return
        self.send_json(404, {"error": "not found"})

    def do_DELETE(self):
        parsed = urlsplit(self.path)
        if parsed.path != "/models":
            self.send_json(404, {"error": "not found"})
            return
        model = parse_qs(parsed.query)["model"][0]
        self.mutations.append(("DELETE", parsed.path, model))
        self.models.discard(model)
        self.send_json(200, {"success": True})


def run_sync(binary, base_url, models_file):
    env = os.environ.copy()
    env.update(
        {
            "LLAMA_CPP_BASE_URL": base_url,
            "LLAMA_CPP_MODELS_FILE": models_file,
            "LLAMA_CPP_MAX_ATTEMPTS": "2",
            "LLAMA_CPP_RETRY_DELAY": "0",
        }
    )
    return subprocess.run(
        [binary],
        env=env,
        check=False,
        capture_output=True,
        text=True,
    )


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def main():
    sync_binary = sys.argv[1]
    server = ThreadingHTTPServer(("127.0.0.1", 0), RouterHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    base_url = f"http://127.0.0.1:{server.server_port}"

    with tempfile.TemporaryDirectory() as temp_dir:
        models_file = os.path.join(temp_dir, "models.json")
        with open(models_file, "w", encoding="utf-8") as handle:
            json.dump(["keep/model:Q4", "new/model:Q4"], handle)

        first = run_sync(sync_binary, base_url, models_file)
        require(first.returncode == 0, first.stderr)
        require(
            RouterHandler.mutations
            == [
                ("POST", "/models/unload", "old/model:Q4"),
                ("DELETE", "/models", "old/model:Q4"),
                ("POST", "/models", "new/model:Q4"),
            ],
            f"unexpected mutations: {RouterHandler.mutations}",
        )
        require(
            RouterHandler.models == {"keep/model:Q4", "new/model:Q4"},
            f"unexpected model set: {RouterHandler.models}",
        )

        RouterHandler.mutations.clear()
        second = run_sync(sync_binary, base_url, models_file)
        require(second.returncode == 0, second.stderr)
        require(
            RouterHandler.mutations == [],
            f"second run was not idempotent: {RouterHandler.mutations}",
        )

        server.shutdown()
        server.server_close()
        thread.join()
        unreachable = run_sync(sync_binary, base_url, models_file)
        require(unreachable.returncode != 0, "unreachable server unexpectedly passed")
        require(
            "not ready after 2 attempts" in unreachable.stderr,
            f"missing timeout diagnostic: {unreachable.stderr}",
        )

    print("llama-cpp model sync tests passed")


if __name__ == "__main__":
    main()
