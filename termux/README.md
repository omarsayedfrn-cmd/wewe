# ⚡ EDU SOLVER CLI — Unified Platform Suite

A modern, fast, and unified Command-Line Interface (CLI) built for **Termux (Android)** and **Linux** environments to automatically solve, complete, and master courses across multiple educational platforms.

---

## 🎯 Supported Engines

| ID | Platform | Course / Subject | Language | Scope & Target | Mode |
|:--:|:---------|:-----------------|:--------:|:---------------|:-----|
| **1** | **QUREO** | JavaScript | Arabic 🇸🇦 | 54 Chapters • 270 Diamonds ★ | Precomputed Database |
| **2** | **QUREO** | JavaScript | English 🇬🇧 | 54 Chapters • 270 Diamonds ★ | Real-Time Self-Discovery |
| **3** | **QUREO2** | Python | Arabic 🇸🇦 | 25 Chapters • 125 Diamonds ★ | Precomputed Database |
| **4** | **QUREO2** | Python | English 🇬🇧 | 10 Chapters • 50 Diamonds ★ | Real-Time Self-Discovery |
| **5** | **SPRIX** | Financial Literacy | Arabic 🇸🇦 | Units 1–6 (Curriculum 19–24) | Precomputed Database |
| **6** | **SPRIX** | Financial Literacy | English 🇬🇧 | Units 1–6 | Real-Time Self-Discovery |

> **Note on Modes:**
> - **Precomputed Database (1, 3, 5):** Uses verified answer mappings located in `answers/`.
> - **Real-Time Self-Discovery (2, 4, 6):** Dynamically extracts and verifies correct answers directly from the platform in real time without needing local answer files.

---

## 🚀 Quick Installation

Run the automated setup script to install all dependencies (`curl`, `jq`, `coreutils`, `bash`):

```bash
bash setup.sh
```

Or install them manually inside Termux:
```bash
pkg update -y
pkg install -y curl jq coreutils bash
chmod +x solve.sh
```

---

## ▶️ Usage & CLI Commands

### 1. Interactive Wizard Mode
Simply run the script with no arguments to launch the colored menu wizard:
```bash
./solve.sh
```
The wizard will guide you through:
1. Engine selection (1–6)
2. Student / Login ID
3. Password (securely masked)
4. Starting chapter or unit

---

### 2. Direct Headless Execution
You can pass all parameters directly to bypass prompts:

```bash
# Syntax:
./solve.sh <engine_id> <login_id> <password> [start_chapter_or_unit]

# Examples:
./solve.sh 5 471352766 SecretPass123        # SPRIX Arabic, from Unit 1
./solve.sh 1 482438443 SecretPass123 20     # QUREO Arabic, resume from Chapter 20
./solve.sh 2 482438443 SecretPass123        # QUREO English, from Chapter 1
```

---

### 3. Named Flags & Options
For advanced usage and automation scripts:

```bash
./solve.sh -e 1 -u 482438443 -p SecretPass123 -s 10 --speed 0.1
```

#### CLI Options Reference:
| Option | Description |
|:-------|:------------|
| `-e, --engine <1-6>` | Target engine ID (1 through 6) |
| `-u, --user <id>` | Account Login / Student ID |
| `-p, --pass <password>` | Account Password |
| `-s, --start <num>` | Starting chapter (1-54/25/10) or unit (1-6) |
| `--speed <scale>` | Pacing delay multiplier (default: `0.05`, higher = slower) |
| `-h, --help` | Display formatted help manual |
| `-v, --version` | Display version information |

---

## ⚡ Performance & Pacing

- **Default speed:** `SLEEP_SCALE=0.05` delivers rapid execution (~2–3 minutes for complete courses).
- To run with safer, slower pacing on high-latency mobile networks:
  ```bash
  ./solve.sh --speed 0.2
  # or via environment variable:
  SLEEP_SCALE=0.3 ./solve.sh 1 482438443 pass 1
  ```

---

## 📂 Project Structure

```
├── solve.sh               # Main unified CLI script (color-coded, robust error handling)
├── setup.sh               # Environment & dependency installer
├── answers/               # Answer repositories for precomputed engines
│   ├── qureo.json         # QUREO JavaScript Arabic answers
│   ├── qureo2.json        # QUREO2 Python Arabic answers
│   └── sprix.json         # SPRIX Arabic answers
└── README.md              # Project documentation
```

---

## 💡 Key Highlights

- **Native Android / Termux Integration:** Automatically engages `termux-wake-lock` when available to prevent the OS from sleeping during execution.
- **Graceful Signal Handling:** Cleans up session cookie files and safely unlocks system resources on exit or interrupt (`Ctrl+C`).
- **Resumable Operations:** Pass any chapter or unit number to resume from where you left off.
