#!/usr/bin/env python3
import time, json, subprocess, threading, http.server, socketserver, argparse

def get_gpu_metrics():
    metrics = {
        "timestamp": time.time(),
        "device": "Intel Xe (Battlemage)",
        "utilisation": 0,
        "memory_used": 0,
        "memory_total": 0,
        "temperature": 0,
        "power_watts": 0
    }
    try:
        output = subprocess.check_output(["intel_gpu_top", "-J", "-s", "100"], stderr=subprocess.DEVNULL)
        data = json.loads(output.decode())
        metrics["utilisation"] = data.get("engines", {}).get("Render/3D", {}).get("busy", 0)
        metrics["temperature"] = data.get("temp", 0)
        metrics["power_watts"] = data.get("power", 0)
    except Exception:
        pass
    return metrics

class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/metrics":
            m = get_gpu_metrics()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(m, indent=2).encode())
        else:
            self.send_response(404)
            self.end_headers()

def run_server(port):
    with socketserver.TCPServer(("", port), Handler) as httpd:
        httpd.serve_forever()

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=9200)
    parser.add_argument("--daemon", action="store_true")
    args = parser.parse_args()

    if args.daemon:
        t = threading.Thread(target=run_server, args=(args.port,), daemon=True)
        t.start()
        while True:
            time.sleep(10)
    else:
        print(json.dumps(get_gpu_metrics(), indent=2))