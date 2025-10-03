#!/usr/bin/env python3
"""
Conxian GUI Deployer (Dev Env)

A Tkinter-based GUI to:
- Sync Clarinet.toml with all contracts
- Verify contracts (listings/traits/compile)
- Install deps and run tests
- Deploy to devnet/testnet (SDK or from Clarinet list)
- Execute post-deploy handover (dry-run or execute)
- Run the full PowerShell pipeline orchestrator

Notes
- Do NOT hardcode secrets. Provide DEPLOYER_PRIVKEY at runtime via input or OS env.
- Designed for Windows (PowerShell + Clarinet + Node/NPM on PATH).
"""
import os
import sys
import json
import threading
import subprocess
import queue
from pathlib import Path
import tkinter as tk
from tkinter import ttk
from tkinter.scrolledtext import ScrolledText

ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = ROOT / "scripts"

class GuiDeployer(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Conxian GUI Deployer")
        self.geometry("1000x700")
        self.log_queue = queue.Queue()
        self.current_proc = None

        # State vars
        self.network = tk.StringVar(value="testnet")
        initial_api = os.environ.get("CORE_API_URL") or os.environ.get("STACKS_API_BASE", "")
        initial_priv = os.environ.get("DEPLOYER_PRIVKEY") or os.environ.get("STACKS_DEPLOYER_PRIVKEY", "")
        self.core_api_url = tk.StringVar(value=initial_api)
        self.deployer_privkey = tk.StringVar(value=initial_priv)
        self.contract_filter = tk.StringVar(value="")
        self.devnet_dry_run = tk.BooleanVar(value=True)
        self.handover_execute = tk.BooleanVar(value=False)
        self.deploy_mode = tk.StringVar(value="sdk")  # sdk | toml

        self.status_labels = {}
        self._build_ui()
        self.after(100, self._drain_log)
        # Initial status
        self.refresh_status()

    def on_generate_wallets(self):
        net = self.network.get().strip().lower()
        cmd = f"node {SCRIPTS / 'generate_wallets.js'} {net}"
        # After generation, auto-load wallets file
        def after_gen():
            self.on_load_wallets()
        # Run and then schedule a delayed refresh
        self._run(cmd)
        self.after(1500, after_gen)

    def _build_ui(self):
        top = ttk.Frame(self)
        top.pack(fill=tk.X, padx=10, pady=10)

        # Network + settings
        ttk.Label(top, text="Network:").grid(row=0, column=0, sticky=tk.W)
        net_cb = ttk.Combobox(top, textvariable=self.network, values=["devnet", "testnet", "mainnet"], width=10)
        net_cb.grid(row=0, column=1, sticky=tk.W, padx=5)
        net_cb.bind('<<ComboboxSelected>>', lambda e: self.on_network_change())
        ttk.Label(top, text="CORE_API_URL:").grid(row=0, column=2, sticky=tk.W, padx=(15,5))
        ttk.Entry(top, textvariable=self.core_api_url, width=40).grid(row=0, column=3, sticky=tk.W)
        ttk.Label(top, text="DEPLOYER_PRIVKEY:").grid(row=1, column=0, sticky=tk.W, pady=(5,0))
        ttk.Entry(top, textvariable=self.deployer_privkey, show="*", width=60).grid(row=1, column=1, columnspan=3, sticky=tk.W, pady=(5,0))

        ttk.Label(top, text="Contract Filter (comma list):").grid(row=2, column=0, sticky=tk.W, pady=(5,0))
        ttk.Entry(top, textvariable=self.contract_filter, width=60).grid(row=2, column=1, columnspan=3, sticky=tk.W, pady=(5,0))

        ttk.Label(top, text="Deploy Mode:").grid(row=3, column=0, sticky=tk.W, pady=(5,0))
        ttk.Radiobutton(top, text="SDK deploy", variable=self.deploy_mode, value="sdk").grid(row=3, column=1, sticky=tk.W)
        ttk.Radiobutton(top, text="From Clarinet.toml", variable=self.deploy_mode, value="toml").grid(row=3, column=2, sticky=tk.W)

        ttk.Checkbutton(top, text="Devnet DRY_RUN", variable=self.devnet_dry_run).grid(row=4, column=0, sticky=tk.W, pady=(5,0))
        ttk.Checkbutton(top, text="EXECUTE_HANDOVER (post-deploy)", variable=self.handover_execute).grid(row=4, column=1, columnspan=2, sticky=tk.W, pady=(5,0))

        # Actions
        actions = ttk.Frame(self)
        actions.pack(fill=tk.X, padx=10)

        ttk.Button(actions, text="Sync Clarinet.toml", command=self.on_sync).grid(row=0, column=0, padx=5, pady=5)
        ttk.Button(actions, text="Verify Contracts", command=self.on_verify).grid(row=0, column=1, padx=5, pady=5)
        ttk.Button(actions, text="Clarinet Check", command=self.on_check).grid(row=0, column=2, padx=5, pady=5)
        ttk.Button(actions, text="Install Deps (npm ci)", command=self.on_install_deps).grid(row=0, column=3, padx=5, pady=5)
        ttk.Button(actions, text="Run Tests", command=self.on_tests).grid(row=0, column=4, padx=5, pady=5)

        ttk.Button(actions, text="Deploy (Devnet)", command=self.on_deploy_devnet).grid(row=1, column=0, padx=5, pady=5)
        ttk.Button(actions, text="Deploy (Testnet)", command=self.on_deploy_testnet).grid(row=1, column=1, padx=5, pady=5)
        ttk.Button(actions, text="Handover", command=self.on_handover).grid(row=1, column=2, padx=5, pady=5)
        ttk.Button(actions, text="Run Orchestrator", command=self.on_pipeline).grid(row=1, column=3, padx=5, pady=5)
        ttk.Button(actions, text="Generate Wallets", command=self.on_generate_wallets).grid(row=1, column=4, padx=5, pady=5)

        # Secrets / Env panel
        secrets = ttk.LabelFrame(self, text="Environment & Secrets Status")
        secrets.pack(fill=tk.X, padx=10, pady=(0,10))

        row = 0
        for key in [
            "HIRO_API_KEY", "DEPLOYER_PRIVKEY", "STACKS_DEPLOYER_PRIVKEY",
            "TESTNET_WALLET1_MNEMONIC", "TESTNET_WALLET2_MNEMONIC",
            "DAO_BOARD_ADDRESS", "OPS_MULTISIG_ADDRESS", "GUARDIAN_ADDRESS",
            "TREASURY_ADDRESS", "TIMELOCK_CONTRACT"
        ]:
            ttk.Label(secrets, text=f"{key}:").grid(row=row, column=0, sticky=tk.W, padx=(5,5))
            lbl = ttk.Label(secrets, text="")
            lbl.grid(row=row, column=1, sticky=tk.W)
            self.status_labels[key] = lbl
            row += 1

        buttons = ttk.Frame(secrets)
        buttons.grid(row=0, column=2, rowspan=row, padx=10, sticky=tk.N)
        ttk.Button(buttons, text="Refresh", command=self.refresh_status).grid(row=0, column=0, pady=2, sticky=tk.EW)
        ttk.Button(buttons, text="Load .env", command=self.on_load_env).grid(row=1, column=0, pady=2, sticky=tk.EW)
        ttk.Button(buttons, text="Save .env", command=self.on_save_env).grid(row=2, column=0, pady=2, sticky=tk.EW)
        ttk.Button(buttons, text="Load wallets.*.json", command=self.on_load_wallets).grid(row=3, column=0, pady=2, sticky=tk.EW)

        # Log area
        self.log = ScrolledText(self, wrap=tk.WORD, height=25)
        self.log.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)

    # Helpers
    def _env(self, overrides=None):
        env = os.environ.copy()
        if self.core_api_url.get().strip():
            env["CORE_API_URL"] = self.core_api_url.get().strip()
        if self.deployer_privkey.get().strip():
            env["DEPLOYER_PRIVKEY"] = self.deployer_privkey.get().strip()
        # Aliases for compatibility
        if not env.get("DEPLOYER_PRIVKEY") and env.get("STACKS_DEPLOYER_PRIVKEY"):
            env["DEPLOYER_PRIVKEY"] = env["STACKS_DEPLOYER_PRIVKEY"]
        if not env.get("CORE_API_URL") and env.get("STACKS_API_BASE"):
            env["CORE_API_URL"] = env["STACKS_API_BASE"]
        env["NETWORK"] = self.network.get().strip()
        if overrides:
            env.update(overrides)
        return env

    def _default_core_api_url(self, network: str) -> str:
        n = network.lower()
        if n == 'devnet':
            return 'http://localhost:20443'
        if n == 'mainnet':
            return 'https://api.hiro.so'
        return 'https://api.testnet.hiro.so'

    def _run(self, cmd, cwd=None, env=None):
        def worker():
            try:
                self._log(f"\n$ {cmd}\n")
                self.current_proc = subprocess.Popen(cmd, cwd=str(cwd or ROOT), env=env or self._env(), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, shell=True)
                for line in self.current_proc.stdout:
                    self.log_queue.put(line)
                rc = self.current_proc.wait()
                self._log(f"\n[exit {rc}]\n")
            except Exception as e:
                self._log(f"[error] {e}\n")
            finally:
                self.current_proc = None
        threading.Thread(target=worker, daemon=True).start()

    def _log(self, s):
        self.log_queue.put(s)

    def _drain_log(self):
        try:
            while True:
                line = self.log_queue.get_nowait()
                self.log.insert(tk.END, line)
                self.log.see(tk.END)
        except queue.Empty:
            pass
        self.after(100, self._drain_log)

    # Actions
    def on_network_change(self):
        # Auto-populate API URL if empty or mismatched
        default_url = self._default_core_api_url(self.network.get())
        if not self.core_api_url.get().strip() or self.core_api_url.get().strip() in ["", "http://localhost:20443", "https://api.hiro.so", "https://api.testnet.hiro.so"]:
            self.core_api_url.set(default_url)
        self.refresh_status()

    def on_sync(self):
        cmd = f"python {SCRIPTS / 'sync_clarinet_contracts.py'} --write"
        self._run(cmd)

    def on_verify(self):
        cmd = f"python {SCRIPTS / 'verify_contracts.py'}"
        self._run(cmd)

    def on_check(self):
        cmd = "clarinet check"
        self._run(cmd)

    def on_install_deps(self):
        cmd = "npm ci"
        self._run(cmd)

    def on_tests(self):
        cmd = "npm test"
        self._run(cmd)

    def on_deploy_devnet(self):
        env = self._env()
        env["NETWORK"] = "devnet"
        if not env.get("CORE_API_URL"):
            env["CORE_API_URL"] = self._default_core_api_url('devnet')
        if self.devnet_dry_run.get():
            env["DRY_RUN"] = "1"
        else:
            env.pop("DRY_RUN", None)
        if self.contract_filter.get().strip():
            env["CONTRACT_FILTER"] = self.contract_filter.get().strip()
        if self.deploy_mode.get() == "sdk":
            cmd = f"node {SCRIPTS / 'sdk_deploy_contracts.js'}"
        else:
            cmd = f"node {SCRIPTS / 'deploy_from_clarinet_list.js'}"
        self._run(cmd, env=env)

    def on_deploy_testnet(self):
        env = self._env()
        env["NETWORK"] = "testnet"
        env.pop("DRY_RUN", None)
        if not env.get("CORE_API_URL"):
            env["CORE_API_URL"] = self._default_core_api_url('testnet')
        if not env.get("DEPLOYER_PRIVKEY"):
            self._log("[abort] DEPLOYER_PRIVKEY is required for testnet deploy\n")
            return
        if self.contract_filter.get().strip():
            env["CONTRACT_FILTER"] = self.contract_filter.get().strip()
        if self.deploy_mode.get() == "sdk":
            cmd = f"node {SCRIPTS / 'sdk_deploy_contracts.js'}"
        else:
            cmd = f"node {SCRIPTS / 'deploy_from_clarinet_list.js'}"
        self._run(cmd, env=env)

    def on_handover(self):
        env = self._env()
        if self.handover_execute.get():
            env["EXECUTE_HANDOVER"] = "1"
        else:
            env.pop("EXECUTE_HANDOVER", None)
        cmd = f"npx ts-node {SCRIPTS / 'post_deploy_handover.ts'}"
        self._run(cmd, env=env)

    def on_pipeline(self):
        # Run the full orchestrator; respects wallet configs per network
        cmd = f"powershell -ExecutionPolicy Bypass -File {SCRIPTS / 'pipeline_orchestrator.ps1'}"
        self._run(cmd)

    # Env/secrets panel actions
    def refresh_status(self):
        def set_status(key, present):
            lbl = self.status_labels.get(key)
            if not lbl:
                return
            lbl.configure(text=("Found" if present else "Missing"), foreground=("green" if present else "red"))

        env = os.environ
        keys = list(self.status_labels.keys())
        for k in keys:
            set_status(k, bool(env.get(k)))

    def on_load_env(self):
        env_path = ROOT / '.env'
        if not env_path.exists():
            self._log('[info] .env not found\n')
            return
        try:
            for line in env_path.read_text(encoding='utf-8').splitlines():
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                if '=' in line:
                    k, v = line.split('=', 1)
                    v = v.strip().strip('"')
                    os.environ[k.strip()] = v
                    if k.strip() in ('CORE_API_URL','STACKS_API_BASE') and not self.core_api_url.get().strip():
                        self.core_api_url.set(v)
                    if k.strip() in ('DEPLOYER_PRIVKEY','STACKS_DEPLOYER_PRIVKEY') and not self.deployer_privkey.get().strip():
                        self.deployer_privkey.set(v)
            self._log('[env] Loaded .env\n')
        except Exception as e:
            self._log(f"[env] load error: {e}\n")
        self.refresh_status()

    def on_save_env(self):
        # Save minimal snapshot of current UI and key env values
        env_path = ROOT / '.env'
        lines = []
        if self.core_api_url.get().strip():
            lines.append(f"CORE_API_URL={self.core_api_url.get().strip()}")
        if self.deployer_privkey.get().strip():
            lines.append(f"DEPLOYER_PRIVKEY={self.deployer_privkey.get().strip()}")
        for k in ["HIRO_API_KEY", "STACKS_DEPLOYER_PRIVKEY", "TESTNET_WALLET1_MNEMONIC", "TESTNET_WALLET2_MNEMONIC"]:
            if os.environ.get(k):
                lines.append(f"{k}={os.environ[k]}")
        try:
            env_path.write_text("\n".join(lines) + "\n", encoding='utf-8')
            self._log('[env] Saved .env snapshot (ensure this file is gitignored)\n')
        except Exception as e:
            self._log(f"[env] save error: {e}\n")

    def on_load_wallets(self):
        net = self.network.get().strip().lower()
        cfg = ROOT / 'config' / f'wallets.{net}.json'
        if not cfg.exists():
            self._log(f"[wallets] config not found: {cfg}\n")
            return
        try:
            data = json.loads(cfg.read_text(encoding='utf-8'))
            # export as env for downstream scripts (handover placeholders)
            mapping = {
                'DAO_BOARD_ADDRESS': data.get('dao_board_address',''),
                'OPS_MULTISIG_ADDRESS': data.get('ops_multisig_address',''),
                'GUARDIAN_ADDRESS': data.get('guardian_address',''),
                'TREASURY_ADDRESS': data.get('treasury_address',''),
                'TIMELOCK_CONTRACT': data.get('timelock_contract',''),
                'DEPLOYER_ADDRESS': data.get('deployer_address',''),
            }
            for k, v in mapping.items():
                if v:
                    os.environ[k] = v
            self._log(f"[wallets] Loaded {cfg}\n")
        except Exception as e:
            self._log(f"[wallets] load error: {e}\n")
        self.refresh_status()


if __name__ == "__main__":
    app = GuiDeployer()
    app.mainloop()
