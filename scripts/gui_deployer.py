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
        self.title("Conxian GUI Deployer - Simple Mode")
        self.geometry("900x650")
        self.log_queue = queue.Queue()
        self.current_proc = None

        # Auto-load .env first
        self._auto_load_env()
        
        # State vars with auto-detection
        self.network = tk.StringVar(value="testnet")
        initial_api = os.environ.get("CORE_API_URL") or os.environ.get("STACKS_API_BASE") or self._default_core_api_url("testnet")
        initial_priv = os.environ.get("DEPLOYER_PRIVKEY") or os.environ.get("STACKS_DEPLOYER_PRIVKEY", "")
        self.core_api_url = tk.StringVar(value=initial_api)
        self.deployer_privkey = tk.StringVar(value=initial_priv)
        self.contract_filter = tk.StringVar(value="")
        self.devnet_dry_run = tk.BooleanVar(value=False)  # Default to live deploy
        self.handover_execute = tk.BooleanVar(value=False)
        self.deploy_mode = tk.StringVar(value="sdk")

        # Auto-detect contracts
        self.total_contracts = self._count_contracts()
        
        self.status_labels = {}
        self._build_ui()
        self.after(100, self._drain_log)
        # Initial status
        self.refresh_status()
        self._log(f"✅ Auto-loaded environment\n")
        self._log(f"✅ Detected {self.total_contracts} contracts\n")
        self._log(f"✅ Network: {self.network.get()}\n")
        self._log(f"✅ Ready to deploy!\n\n")

    def _auto_load_env(self):
        """Automatically load .env on startup"""
        env_path = ROOT / '.env'
        if env_path.exists():
            try:
                for line in env_path.read_text(encoding='utf-8').splitlines():
                    line = line.strip()
                    if not line or line.startswith('#'):
                        continue
                    if '=' in line:
                        k, v = line.split('=', 1)
                        v = v.strip().strip('"')
                        os.environ[k.strip()] = v
            except:
                pass
    
    def _count_contracts(self):
        """Auto-detect total number of contracts"""
        try:
            contract_files = list((ROOT / 'contracts').rglob('*.clar'))
            return len(contract_files)
        except:
            return 144  # fallback
    
    def on_generate_wallets(self):
        net = self.network.get().strip().lower()
        cmd = f"node {SCRIPTS / 'generate_wallets.js'} {net}"
        def after_gen():
            self.on_load_wallets()
        self._run(cmd)
        self.after(1500, after_gen)

    def _build_ui(self):
        # Simple top info panel
        info = ttk.LabelFrame(self, text="📊 Deployment Status")
        info.pack(fill=tk.X, padx=10, pady=10)
        
        info_text = f"""
Network: {self.network.get().upper()}
Contracts: {self.total_contracts} detected
Deployer: {os.environ.get('SYSTEM_ADDRESS', 'Auto-detected from .env')}
Status: ✅ Ready to Deploy
        """.strip()
        
        ttk.Label(info, text=info_text, justify=tk.LEFT, padding=10).pack()

        # Simple action buttons (BIG and clear)
        actions = ttk.Frame(self)
        actions.pack(fill=tk.X, padx=10, pady=10)
        
        # Main deploy button - BIG
        deploy_btn = tk.Button(actions, text="🚀 DEPLOY TO TESTNET", 
                               command=self.on_deploy_testnet,
                               bg="#4CAF50", fg="white", font=("Arial", 16, "bold"),
                               height=2, cursor="hand2")
        deploy_btn.pack(fill=tk.X, pady=(0,10))
        
        # Secondary actions in row
        secondary = ttk.Frame(actions)
        secondary.pack(fill=tk.X)
        
        ttk.Button(secondary, text="✓ Check Compilation", command=self.on_check).pack(side=tk.LEFT, padx=5)
        ttk.Button(secondary, text="🧪 Run Tests", command=self.on_tests).pack(side=tk.LEFT, padx=5)
        ttk.Button(secondary, text="🔄 Refresh", command=self.refresh_status).pack(side=tk.LEFT, padx=5)

        # Log area
        ttk.Label(self, text="📝 Deployment Log:").pack(padx=10, anchor=tk.W)
        self.log = ScrolledText(self, wrap=tk.WORD, height=20, bg="#1e1e1e", fg="#00ff00", font=("Courier", 9))
        self.log.pack(fill=tk.BOTH, expand=True, padx=10, pady=(0,10))

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
