---
name: "llama-cpp-steamos"
description: "Install and optimize llama.cpp on SteamOS/SteamFork with AMD APU Vulkan acceleration (battle-tested)"
version: "1.1.0"
author: "Andrew Wyatt (Fewtarius)"
tools: ["terminal_operations", "file_operations", "user_collaboration"]
---

# llama.cpp Installation for SteamOS/SteamFork (AMD APU)

## When to Use

- Installing llama.cpp on SteamOS, SteamFork, or similar immutable Linux distributions
- Setting up large language model inference on AMD APUs (especially 7840U with Radeon 780M)
- Optimizing llama.cpp with Vulkan and ROCm/HIP acceleration
- Configuring kernel parameters for optimal VRAM allocation on AMD integrated graphics
- Running local LLM API servers on handheld gaming devices

**Target Hardware:**
- AMD Ryzen 7840U (or similar Zen 4 APUs)
- AMD Radeon 780M integrated GPU (RDNA 3, gfx1103)
- 16GB+ RAM (tested on 16GB, works with 8GB-128GB)
- SteamOS 3.x, SteamFork, or similar Arch-based systems

**Battle-Tested:**
- Device: Ayaneo 2S
- CPU: AMD Ryzen 7 7840U
- GPU: AMD Radeon 780M (RDNA 3)
- RAM: 16GB
- OS: SteamFork
- Date: 2026-01-31

## Instructions

### Core Principles

**Investigation First:**
1. Always check current system state before making changes
2. Verify GPU detection and current VRAM allocation
3. Read existing configuration files before modifying
4. Test at each stage (don't skip validation steps)

**Safe System Modification:**
1. On SteamOS/SteamFork, disable read-only filesystem ONLY when needed
2. Re-enable read-only after package installation
3. Back up configuration files before editing (especially /etc/default/grub)
4. Test kernel parameter changes safely (can boot without them if issues occur)

**Checkpoint Discipline:**
1. After investigation, present findings and proposed changes to user
2. Before kernel modifications, confirm GRUB changes with user
3. After build completion, verify binary works before proceeding
4. Before final configuration, show user what will be changed

### Phase 1: System Preparation and ROCm Setup

#### 1.1 Verify System State and Detect RAM

**CRITICAL: Detect total RAM to determine safe VRAM allocation**

```bash
# Check total system RAM
total_ram_gb=$(free -g | grep Mem | awk '{print $2}')
echo "Total System RAM: ${total_ram_gb}GB"

# Check GPU detection
lspci | grep -i vga

# Check current VRAM and GTT allocation
echo "Current VRAM:"
cat /sys/class/drm/card*/device/mem_info_vram_total 2>/dev/null | awk '{printf "%.2f GB\n", $1/1024/1024/1024}'
echo "Current GTT (Graphics Translation Table):"
cat /sys/class/drm/card*/device/mem_info_gtt_total 2>/dev/null | awk '{printf "%.2f GB\n", $1/1024/1024/1024}'

# Check if amdgpu driver is loaded
lsmod | grep amdgpu

# Check ROCm device presence (optional - Vulkan doesn't need this)
ls -la /dev/kfd

# Check current user groups
groups

# Check available disk space (need ~10GB for build + models)
df -h /home
```

**CHECKPOINT: Analyze RAM and propose VRAM allocation**

Use user_collaboration to present findings and get approval:

```
System Analysis:
- GPU: [detected model and PCI ID]
- Total RAM: [X]GB
- Current VRAM: [Y]GB (fixed BIOS allocation)
- Current GTT: [Z]GB (dynamic pool)
- ROCm device: [present/not needed for Vulkan]
- Disk space: [available]

Recommended VRAM Allocation for [X]GB RAM:
- Conservative: [A]GB GTT (leaves [X-A]GB for system)
- Balanced: [B]GB GTT (leaves [X-B]GB for system) <- RECOMMENDED
- Aggressive: [C]GB GTT (leaves [X-C]GB for system, minimum 4GB)

The balanced option allows:
- Model size: [list compatible models]
- System stability: [description]

Proceed with [B]GB allocation?
```

**RAM-based allocation guidelines:**

| Total RAM | Conservative | Balanced (Recommended) | Aggressive |
|-----------|--------------|------------------------|------------|
| 8GB       | 2GB          | 3GB                    | 4GB        |
| 12GB      | 4GB          | 6GB                    | 8GB        |
| 16GB      | 6GB          | 8GB                    | 10GB       |
| 24GB      | 10GB         | 12GB                   | 16GB       |
| 32GB      | 12GB         | 16GB                   | 20GB       |
| 64GB+     | 24GB         | 32GB+                  | 48GB+      |

**Model compatibility estimates:**

- **2-4GB:** 7B Q4 models with partial GPU offload
- **6-8GB:** 7B Q4 fully on GPU, 13B Q4 partial
- **10-12GB:** 13B Q4 fully on GPU, 32B Q2/Q3 partial
- **16GB+:** 32B Q4, 70B Q2 models
- **32GB+:** 70B Q4, large multimodal models

#### 1.2 Disable Read-Only Filesystem (SteamOS Specific)

**CRITICAL: Only for SteamOS/SteamFork immutable systems**

```bash
# Check if system is read-only
mount | grep "/ "

# If read-only, disable it temporarily
sudo steamos-readonly disable

# Verify
mount | grep "/ "
# Should NOT show "ro" flag
```

**Note:** You'll re-enable this after package installation completes.

#### 1.3 Install ROCm and Development Tools

**Install required packages:**

```bash
# Update package database
sudo pacman -Sy

# Install ROCm stack (for HIP support)
sudo pacman -S --needed rocm-hip-sdk rocm-device-libs

# Install Vulkan stack (primary acceleration method)
sudo pacman -S --needed vulkan-headers vulkan-icd-loader vulkan-validation-layers vulkan-tools

# Install build tools
sudo pacman -S --needed base-devel git cmake

# Re-enable read-only if on SteamOS
sudo steamos-readonly enable
```

**Verify Vulkan installation:**

```bash
# Check Vulkan devices
vulkaninfo --summary | grep -A 5 deviceName

# Should show: AMD Radeon Graphics (RADV GFX1103)
```

#### 1.4 Set Environment Variables for AMD GPU

**Based on ALICE's detection script, Phoenix APUs need specific overrides:**

Create `~/.config/environment.d/rocm.conf` for persistent environment:

```bash
# Create directory
mkdir -p ~/.config/environment.d

# Create ROCm environment file
cat > ~/.config/environment.d/rocm.conf << 'EOF'
# ROCm configuration for AMD Phoenix APU (7840U / Radeon 780M)
# Architecture: gfx1103 (RDNA 3)

PYTORCH_ROCM_ARCH=gfx1103
HSA_OVERRIDE_GFX_VERSION=11.0.0
TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1

# Vulkan optimizations
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.x86_64.json
AMD_VULKAN_ASYNC_COMPUTE=1
RADV_PERFTEST=aco,ngg,sam,rt
EOF

# Source for current session
export PYTORCH_ROCM_ARCH=gfx1103
export HSA_OVERRIDE_GFX_VERSION=11.0.0
export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.x86_64.json
export AMD_VULKAN_ASYNC_COMPUTE=1
export RADV_PERFTEST=aco,ngg,sam,rt
```

**Key learnings from ALICE:**
- Phoenix (gfx1103) uses HSA 11.0.0 for best compatibility
- TheRock PyTorch builds include proper gfx1103 support
- Official PyTorch ROCm packages may NOT include gfx1103 kernels

### Phase 2: Build llama.cpp with Vulkan + HIP Support

#### 2.1 Clone and Prepare

```bash
# Clone llama.cpp repository
cd ~
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp/

# Check current commit (for reproducibility)
git log -1 --oneline
```

**CHECKPOINT: Before building, confirm build configuration:**

Use user_collaboration to show:
```
Build Configuration:
- Vulkan: ENABLED (primary acceleration)
- HIP/ROCm: ENABLED (additional acceleration)
- Target GPU: AMD Radeon 780M (gfx1103)

This build will take 5-10 minutes. Proceed?
```

#### 2.2 Build with Vulkan and ROCm Support

```bash
# Create build directory and configure
cmake -B build \
  -DGGML_VULKAN=1 \
  -DGGML_HIPBLAS=on \
  -DCMAKE_BUILD_TYPE=Release

# Build (use all CPU cores)
cmake --build build --config Release -j$(nproc)

# Verify binaries were created
ls -lh build/bin/llama-*

# Expected binaries:
# - llama-cli (command-line interface)
# - llama-server (API server)
# - llama-bench (benchmarking tool)
```

**If build fails:**
1. Check error messages for missing dependencies
2. Verify Vulkan headers are installed: `pacman -Qs vulkan-headers`
3. Verify ROCm is installed: `pacman -Qs rocm-hip-sdk`
4. Try build with only Vulkan: `cmake -B build -DGGML_VULKAN=1` (omit HIPBLAS)

#### 2.3 Verify Build Success

```bash
# Check Vulkan backend is available
./build/bin/llama-cli --help | grep -i vulkan

# Should show Vulkan-related options
```

### Phase 3: Kernel Configuration for GPU Memory Allocation

**CRITICAL: This modifies bootloader configuration. Back up first.**

#### 3.1 Understand AMD APU Memory Architecture

**Key concepts:**

- **VRAM (Video RAM)**: Fixed allocation set in BIOS/UEFI (typically 512MB-3GB on APUs)
- **GTT (Graphics Translation Table)**: Dynamic GPU-accessible memory pool from system RAM
- **TTM (Translation Table Manager)**: Kernel subsystem that manages GPU memory
- **Total GPU Memory**: VRAM + GTT (both accessible to GPU)

**Example on Ayaneo 2S (16GB RAM, 3GB BIOS VRAM, 8GB GTT configured):**
```
VRAM (fixed):     3.00 GB  (from /sys/class/drm/card*/device/mem_info_vram_total)
GTT (dynamic):    8.00 GB  (from /sys/class/drm/card*/device/mem_info_gtt_total)
Total GPU Memory: 11.00 GB (VRAM + GTT, what llama.cpp can use)
System RAM left:  ~8 GB    (for OS and applications)
```

#### 3.2 CRITICAL: Both TTM Parameters Required

**On AMD APUs, you MUST set BOTH parameters to the same value:**

```bash
ttm.pages_limit=XXXXXX ttm.page_pool_size=XXXXXX
```

**Why both?**
- `ttm.pages_limit`: Maximum pages TTM can allocate
- `ttm.page_pool_size`: Pool size for page allocation
- On APUs (Unified Memory Architecture), both must match for full allocation

**Common mistake:** Setting only `ttm.pages_limit` results in GTT not expanding.

#### 3.3 Calculate TTM Parameter Values

**Formula:**
```
ttm_value = (target_GTT_GB * 1024 * 1024) / 4
```

**Quick reference table:**

| Target GTT | ttm.pages_limit | ttm.page_pool_size | Use Case |
|------------|-----------------|--------------------| ---------|
| 2GB        | 524288          | 524288             | 8GB RAM, minimal |
| 3GB        | 786432          | 786432             | 8GB RAM, balanced |
| 4GB        | 1048576         | 1048576            | 8GB/12GB RAM |
| 6GB        | 1572864         | 1572864            | 12GB RAM, balanced |
| 8GB        | 2097152         | 2097152            | 16GB RAM, balanced |
| 10GB       | 2621440         | 2621440            | 16GB RAM, aggressive |
| 12GB       | 3145728         | 3145728            | 24GB RAM, balanced |
| 16GB       | 4194304         | 4194304            | 32GB RAM, balanced |
| 24GB       | 6291456         | 6291456            | 48GB+ RAM |

**CHECKPOINT: Before modifying GRUB, confirm with user:**

Use user_collaboration:
```
Kernel Parameter Changes Required:
- rocm.allowed_devices=3 (enables consumer GPU support for gfx1103)
- ttm.pages_limit=6881280 (allocates 26.25GB VRAM from system RAM)

Current VRAM: [show current]
After change: ~26.25GB

This requires:
1. Editing /etc/default/grub
2. Running update-grub
3. REBOOT to take effect

System RAM will be reduced by 26GB (32GB → ~6GB usable for OS).

Proceed with kernel parameter changes?
```

#### 3.3 Edit GRUB Configuration

**Back up first:**
```bash
sudo cp /etc/default/grub /etc/default/grub.backup
```

**Edit GRUB config:**
```bash
sudo nano /etc/default/grub
```

**Find the line:**
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
```

**Modify to:**
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash rocm.allowed_devices=3 ttm.pages_limit=6881280"
```

**Explanation:**
- `rocm.allowed_devices=3` - Enables ROCm on consumer GPUs (gfx1103)
- `ttm.pages_limit=6881280` - Allocates 26.25GB VRAM from system RAM

**Alternative for 16GB RAM systems (allocate 12GB):**
```
ttm.pages_limit = 12 * 1024 * 1024 * 1024 / 4096 = 3145728
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash rocm.allowed_devices=3 ttm.pages_limit=3145728"
```

#### 3.4 Apply Changes and System Restart

**IMPORTANT: Detect OS variant to use correct GRUB command**

```bash
# Detect OS variant
if grep -q "DISTRO_NAME=.*SteamFork" /etc/os-release; then
  OS_VARIANT="steamfork"
  GRUB_UPDATE_CMD="steamfork-grub-update"
  echo "Detected: SteamFork"
elif grep -q "VARIANT_ID=steamdeck" /etc/os-release; then
  OS_VARIANT="steamos"
  GRUB_UPDATE_CMD="update-grub"
  echo "Detected: SteamOS (Valve)"
else
  OS_VARIANT="generic"
  GRUB_UPDATE_CMD="grub-mkconfig -o /boot/grub/grub.cfg"
  echo "Detected: Generic SteamOS/Arch"
fi
```

**For SteamOS/SteamFork (read-only filesystem):**

```bash
# Disable read-only temporarily
sudo steamos-readonly disable

# Update GRUB with detected command
if [ "$OS_VARIANT" = "steamfork" ]; then
  sudo steamfork-grub-update
elif [ "$OS_VARIANT" = "steamos" ]; then
  sudo update-grub
else
  sudo grub-mkconfig -o /boot/grub/grub.cfg
fi

# Re-enable read-only filesystem
sudo steamos-readonly enable
```

**Verify changes were applied:**

```bash
# Check for both TTM parameters in grub.cfg
sudo grep "ttm.page" /boot/grub/grub.cfg | head -1

# Should show both:
# ttm.pages_limit=XXXXXX ttm.page_pool_size=XXXXXX
```

**System restart required for kernel parameters to take effect.**

**After system restart, verify BOTH parameters are active and GTT expanded:**

```bash
# 1. Check kernel command line shows BOTH parameters
cat /proc/cmdline | grep -o "ttm.[a-z_]*=[0-9]*"
# Expected:
# ttm.pages_limit=2097152
# ttm.page_pool_size=2097152

# 2. Verify VRAM (won't change, this is BIOS-set)
cat /sys/class/drm/card*/device/mem_info_vram_total | \
  awk '{printf "VRAM (fixed): %.2f GB\n", $1/1024/1024/1024}'

# 3. Verify GTT expanded (THIS should match your configured value)
cat /sys/class/drm/card*/device/mem_info_gtt_total | \
  awk '{printf "GTT (dynamic): %.2f GB\n", $1/1024/1024/1024}'

# 4. Calculate total GPU memory available to llama.cpp
paste <(cat /sys/class/drm/card*/device/mem_info_vram_total) \
      <(cat /sys/class/drm/card*/device/mem_info_gtt_total) | \
  awk '{printf "Total GPU Memory: %.2f GB (%.2f VRAM + %.2f GTT)\n", \
        ($1+$2)/1024/1024/1024, $1/1024/1024/1024, $2/1024/1024/1024}'
```

**Success indicators:**
-  Both `ttm.pages_limit` and `ttm.page_pool_size` in /proc/cmdline
-  `mem_info_gtt_total` shows configured value (e.g., 8.00 GB)
-  Total GPU memory = VRAM + GTT (this is what llama.cpp can use)

### Phase 4: Model Setup and Basic Testing

#### 4.1 Create Model Directory

```bash
cd ~/llama.cpp
mkdir -p models

# Check available disk space
df -h ~/llama.cpp/models
```

**Model size estimates:**
- 7B GGUF Q4: ~4GB
- 13B GGUF Q4: ~7GB
- 32B GGUF Q4: ~18GB
- 70B GGUF Q2: ~26GB

#### 4.2 Download a Test Model

**For initial testing, use a smaller model:**

```bash
cd ~/llama.cpp/models

# Example: Download Qwen2.5-Coder-7B-Instruct (Q4_K_M quantization)
# Replace with your preferred model from HuggingFace

# Using huggingface-cli (if installed)
huggingface-cli download \
  Qwen/Qwen2.5-Coder-7B-Instruct-GGUF \
  qwen2.5-coder-7b-instruct-q4_k_m.gguf \
  --local-dir .

# Or use wget/curl with direct link
```

**CHECKPOINT: Before running first test:**

Use user_collaboration:
```
Test Configuration:
- Model: [model name] (~[size]GB)
- GPU layers: 99 (offload all to GPU)
- Test prompt: "Hi, how are you?"

Expected behavior:
- Model loads to VRAM (~20-60s)
- Generation starts
- Speed: 3-15 tokens/second (depending on model size)

This is the moment of truth - testing GPU acceleration!
Proceed with test?
```

#### 4.3 Test with CLI

```bash
cd ~/llama.cpp

# Run basic test (replace model path with your downloaded model)
./build/bin/llama-cli \
  -m models/qwen2.5-coder-7b-instruct-q4_k_m.gguf \
  -p "Hi, how are you?" \
  -ngl 99

# -ngl 99 means "offload 99 layers to GPU" (effectively all layers)
```

**What to look for in output:**
```
llama_model_load: loaded meta data with X key-value pairs
llama_model_load: Dumping metadata keys/values
...
llm_load_tensors: offloading X repeating layers to GPU
llm_load_tensors: offloaded X/X layers to GPU
...
llama_perf_sampler_print:    sampling time =    X.XX ms
llama_perf_context_print:        eval time =    X.XX ms / X tokens
```

**Success indicators:**
- "offloaded X/X layers to GPU" - All layers on GPU
- Generation speed: 3-15 tok/s (varies by model size)
- No "failed to allocate" errors

**If it fails:**
1. Check VRAM allocation: `cat /sys/class/drm/card*/device/mem_info_vram_total`
2. Try fewer layers: `-ngl 32` instead of `-ngl 99`
3. Try smaller model first
4. Check vulkaninfo still shows GPU: `vulkaninfo --summary`

### Phase 5: API Server Setup

#### 5.1 Create Server Startup Script

```bash
cd ~/llama.cpp

# Create startup script
cat > start_server.sh << 'EOF'
#!/bin/bash
# llama.cpp API Server Startup Script

# Set environment variables (redundant if using systemd, but safe)
export PYTORCH_ROCM_ARCH=gfx1103
export HSA_OVERRIDE_GFX_VERSION=11.0.0
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.x86_64.json
export AMD_VULKAN_ASYNC_COMPUTE=1
export RADV_PERFTEST=aco,ngg,sam,rt

# Configuration
MODEL_PATH="models/qwen2.5-coder-32b-instruct-q4_k_m.gguf"
HOST="0.0.0.0"
PORT="8080"
THREADS="8"
BATCH_SIZE="2048"
GPU_LAYERS="99"

# Start server
./build/bin/llama-server \
  -m "$MODEL_PATH" \
  -ngl "$GPU_LAYERS" \
  --host "$HOST" \
  --port "$PORT" \
  --threads "$THREADS" \
  --batch-size "$BATCH_SIZE" \
  --ctx-size 4096 \
  --log-format text

EOF

chmod +x start_server.sh
```

**Customize the script:**
- Update `MODEL_PATH` to your actual model
- Adjust `PORT` if 8080 is in use
- Adjust `THREADS` based on your CPU (8 cores = 8 threads)
- `BATCH_SIZE` 2048 is good for 32GB RAM; reduce to 512 for 16GB

#### 5.2 Test Server Manually

```bash
# Start server in foreground (for testing)
./start_server.sh

# Server should start and show:
# "llama server listening at http://0.0.0.0:8080"
```

**In another terminal, test the API:**

```bash
# Basic completion test
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "Write a Python function to calculate factorial"}
    ],
    "temperature": 0.7,
    "max_tokens": 500
  }'
```

**Expected response:**
```json
{
  "id": "chatcmpl-...",
  "object": "chat.completion",
  "created": 1234567890,
  "model": "...",
  "choices": [{
    "index": 0,
    "message": {
      "role": "assistant",
      "content": "def factorial(n):\n    if n == 0:\n        return 1\n ..."
    },
    "finish_reason": "stop"
  }],
  "usage": {"prompt_tokens": X, "completion_tokens": Y, "total_tokens": Z}
}
```

#### 5.3 Create Systemd Service (Optional)

**For automatic startup:**

```bash
# Create user service directory
mkdir -p ~/.config/systemd/user

# Create service file
cat > ~/.config/systemd/user/llama-server.service << EOF
[Unit]
Description=llama.cpp API Server
After=network.target

[Service]
Type=simple
WorkingDirectory=${HOME}/llama.cpp
Environment="PYTORCH_ROCM_ARCH=gfx1103"
Environment="HSA_OVERRIDE_GFX_VERSION=11.0.0"
Environment="VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.x86_64.json"
Environment="AMD_VULKAN_ASYNC_COMPUTE=1"
Environment="RADV_PERFTEST=aco,ngg,sam,rt"
ExecStart=${HOME}/llama.cpp/start_server.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

# Reload systemd
systemctl --user daemon-reload

# Enable and start service
systemctl --user enable llama-server
systemctl --user start llama-server

# Check status
systemctl --user status llama-server

# View logs
journalctl --user -u llama-server -f
```

### Phase 6: Performance Optimization

#### 6.1 GPU Performance Tuning (Optional)

**Install PowerDeck (if available) or use ryzenadj for APU tuning:**

```bash
# Check if ryzenadj is available
which ryzenadj

# If available, create tuning script
cat > ~/gpu_tune.sh << 'EOF'
#!/bin/bash
# AMD APU Performance Tuning Script

# Set power limits for better sustained performance
sudo ryzenadj --stapm-limit=28000 --fast-limit=32000 --slow-limit=28000
sudo ryzenadj --tdc-limit=30000 --edc-limit=48000

# Force performance mode
echo "high" | sudo tee /sys/class/drm/card*/device/power_dpm_force_performance_level

echo "Performance tuning applied"
EOF

chmod +x ~/gpu_tune.sh
```

**WARNING: This increases power consumption and heat. Monitor temperatures.**

#### 6.2 Monitor Performance

**While server is running:**

```bash
# Monitor GPU usage (if radeontop is installed)
radeontop

# Monitor system resources
htop

# Check VRAM usage
cat /sys/class/drm/card*/device/mem_info_vram_used
cat /sys/class/drm/card*/device/mem_info_vram_total

# Calculate VRAM usage percentage
paste <(cat /sys/class/drm/card*/device/mem_info_vram_used) \
      <(cat /sys/class/drm/card*/device/mem_info_vram_total) | \
      awk '{printf "VRAM Usage: %.1f%%\n", ($1/$2)*100}'
```

#### 6.3 Benchmark Different Configurations

**Test different layer offload levels:**

```bash
# Full GPU offload
./build/bin/llama-cli -m models/your-model.gguf -p "Test" -ngl 99

# Partial GPU offload (if VRAM limited)
./build/bin/llama-cli -m models/your-model.gguf -p "Test" -ngl 32

# CPU only (for comparison)
./build/bin/llama-cli -m models/your-model.gguf -p "Test" -ngl 0
```

**Measure tokens/second for each configuration and report to user.**

### Phase 7: Troubleshooting

#### Common Issues and Solutions

**Issue: "Not enough memory for command submission"**
- **Cause:** Insufficient VRAM allocation
- **Solution:** Increase `ttm.pages_limit` in GRUB config, or use smaller model

**Issue: "amdgpu version file missing" or ROCm errors**
- **Cause:** ROCm not properly configured for consumer GPU
- **Solution:** Verify `rocm.allowed_devices=3` in kernel parameters
- **Workaround:** Use Vulkan-only build (omit `-DGGML_HIPBLAS=on`)

**Issue: Low performance (< 1 token/second)**
- **Cause:** Running on CPU instead of GPU
- **Check:** Look for "offloaded X/X layers to GPU" in startup logs
- **Solution:** Verify Vulkan environment variables are set

**Issue: Vulkan initialization failed**
- **Cause:** Missing Vulkan drivers or wrong ICD
- **Check:** `vulkaninfo --summary`
- **Solution:** Reinstall vulkan-icd-loader and vulkan-radeon

**Issue: System crashes or freezes during generation**
- **Cause:** VRAM allocation too high, system RAM exhausted
- **Solution:** Reduce `ttm.pages_limit` to leave more RAM for OS (minimum 4GB)

**Issue: Server won't start on port 8080**
- **Cause:** Port already in use
- **Check:** `ss -tulpn | grep 8080`
- **Solution:** Change PORT in start_server.sh

#### Reset to Defaults

**To remove kernel parameter changes:**

```bash
# Restore GRUB backup
sudo cp /etc/default/grub.backup /etc/default/grub

# Update GRUB
sudo update-grub

# Reboot
sudo reboot

# After reboot, check VRAM returned to default
cat /sys/class/drm/card*/device/mem_info_vram_total
```

### Performance Expectations

**AMD 7840U + Radeon 780M (RDNA 3, gfx1103) with 26GB VRAM:**

| Model Size | Quantization | Expected Speed | VRAM Usage |
|------------|--------------|----------------|------------|
| 7B         | Q4_K_M       | 10-15 tok/s    | ~4GB       |
| 13B        | Q4_K_M       | 6-10 tok/s     | ~8GB       |
| 32B        | Q4_K_M       | 3-5 tok/s      | ~18GB      |
| 70B        | Q2_K         | 1-3 tok/s      | ~24GB      |

**Note:** Speed varies based on:
- Context length (longer contexts = slower)
- Batch size settings
- CPU/RAM speed for CPU offloading
- Thermal throttling (keep system cool)

## Battle-Tested Learnings (Ayaneo 2S, January 2026)

### Critical Success Factors

1. **BOTH TTM Parameters Required (MOST IMPORTANT)**
   - Setting only `ttm.pages_limit` will NOT expand GTT on AMD APUs
   - MUST also set `ttm.page_pool_size` to the **exact same value**
   - This is specific to AMD APUs with Unified Memory Architecture
   - Missing `page_pool_size` is the #1 reason GTT allocation fails

2. **VRAM vs GTT Understanding**
   - `mem_info_vram_total` = Fixed BIOS allocation (typically 512MB-3GB, doesn't change)
   - `mem_info_gtt_total` = Dynamic pool controlled by TTM parameters (THIS is what you're configuring)
   - Total GPU memory = VRAM + GTT (llama.cpp can use both)
   - **Don't expect VRAM to change - watch GTT instead!**

3. **Vulkan-Only Works Excellently**
   - ROCm/HIP not required for good GPU acceleration
   - Vulkan with RADV driver provides excellent performance
   - Simpler, more reliable than trying to compile with HIP on Phoenix APUs
   - Official ROCm 6.4.1 doesn't include gfx1103 (Phoenix/780M) support

4. **Actual Test Results**
   ```
   Hardware: Ayaneo 2S
   - CPU: AMD Ryzen 7 7840U
   - GPU: Radeon 780M (RDNA 3, gfx1103)
   - RAM: 16GB total
   
   Configuration:
   - VRAM (fixed): 3GB
   - GTT (configured): 8GB  
   - Total GPU memory: 11GB
   - System RAM remaining: ~8GB
   
   Model: Qwen2.5-14B-Instruct Q4_K_M (8.5GB)
   - Layers offloaded: 20/48 (partial)
   - VRAM used: 4.3GB
   - Performance: 5.69 tokens/second
   - Status: Worked perfectly ✓
   ```

5. **SteamFork-Specific Commands**
   - Use `sudo steamfork-grub-update` instead of `update-grub`
   - Must `sudo steamos-readonly disable` before GRUB updates
   - Re-enable with `sudo steamos-readonly enable` after updates
   - These steps are critical on SteamOS/SteamFork immutable systems

### Common Pitfalls and Solutions

| Pitfall | Symptom | Solution |
|---------|---------|----------|
| Only set `ttm.pages_limit` | GTT stays at default, no expansion | Add matching `ttm.page_pool_size` |
| Expecting VRAM to change | Confusion when VRAM shows 3GB | Check GTT with `mem_info_gtt_total` |
| Using ROCm 6.4.1 on Phoenix | Build fails or no acceleration | Use Vulkan-only, skip HIP |
| Allocating too much GTT | System OOM, freezes | Leave minimum 4-6GB for OS |
| Forgot to reboot | Parameters in grub.cfg but not active | Reboot required for kernel params |
| Not verifying /proc/cmdline | Params in grub but typo/syntax error | Always verify both params active |
| Wrong GRUB update command | "Command not found" or install fails | Detect OS: SteamFork=`steamfork-grub-update`, SteamOS=`update-grub` |

### Recommended Configurations by RAM

| Total RAM | GTT Allocation | TTM Value | Use Case |
|-----------|----------------|-----------|----------|
| 8GB       | 3GB            | 786432    | 7B Q4 models |
| 12GB      | 6GB            | 1572864   | 13B Q4 models |
| 16GB      | 8GB            | 2097152   | 14B Q4, 32B Q2 (**tested**) |
| 24GB      | 12GB           | 3145728   | 32B Q4 models |
| 32GB      | 16GB           | 4194304   | 70B Q2/Q3 models |

**Tested configuration (16GB RAM, 8GB GTT):**
```bash
# In /etc/default/grub, add to GRUB_CMDLINE_LINUX_DEFAULT:
rocm.allowed_devices=3 ttm.pages_limit=2097152 ttm.page_pool_size=2097152
```

Results:
-  3GB VRAM + 8GB GTT = 11GB total GPU memory
-  Qwen2.5-14B-Instruct runs at 5.7 tok/s
-  Stable, no OOM issues
-  System remains responsive with 8GB RAM free

### Verification Checklist

After configuration and reboot, verify:

```bash
# 1. Both parameters active in kernel
cat /proc/cmdline | grep -o "ttm.[a-z_]*=[0-9]*"
# Should show BOTH:
# ttm.pages_limit=2097152
# ttm.page_pool_size=2097152

# 2. GTT expanded (not just VRAM)
cat /sys/class/drm/card*/device/mem_info_gtt_total | \
  awk '{printf "GTT: %.2f GB\n", $1/1024/1024/1024}'
# Should show your configured value (e.g., 8.00 GB)

# 3. Total GPU memory available
paste <(cat /sys/class/drm/card*/device/mem_info_vram_total) \
      <(cat /sys/class/drm/card*/device/mem_info_gtt_total) | \
  awk '{printf "Total GPU: %.2f GB\n", ($1+$2)/1024/1024/1024}'
# Should be VRAM + GTT (e.g., 11.00 GB)
```

All three checks must pass for successful configuration.

## Additional Resources

**llama.cpp Documentation:**
- Main repository: https://github.com/ggerganov/llama.cpp
- Build guide: https://github.com/ggerganov/llama.cpp/blob/master/docs/build.md
- Server API: https://github.com/ggerganov/llama.cpp/blob/master/examples/server/README.md

**AMD ROCm:**
- ROCm documentation: https://rocm.docs.amd.com/
- Supported GPUs: https://rocm.docs.amd.com/projects/install-on-linux/en/latest/reference/system-requirements.html

**Model Sources:**
- HuggingFace GGUF models: https://huggingface.co/models?library=gguf
- TheBloke's quantizations: https://huggingface.co/TheBloke

**SteamOS/SteamFork:**
- SteamFork GitHub: https://github.com/SteamFork
- SteamOS wiki: https://help.steampowered.com/

## Examples

### Example 1: Basic CLI Usage

```bash
# Simple question
./build/bin/llama-cli \
  -m models/qwen2.5-coder-7b-instruct-q4_k_m.gguf \
  -p "What is the capital of France?" \
  -ngl 99 \
  -c 2048

# Code generation
./build/bin/llama-cli \
  -m models/qwen2.5-coder-32b-instruct-q4_k_m.gguf \
  -p "Write a Python script to parse JSON and extract all email addresses" \
  -ngl 99 \
  -c 4096 \
  -n 1000
```

### Example 2: API Server with Streaming

```bash
# Start server
./start_server.sh

# Streaming chat completion
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "system", "content": "You are a helpful coding assistant."},
      {"role": "user", "content": "Explain quantum computing in simple terms"}
    ],
    "stream": true,
    "temperature": 0.7,
    "max_tokens": 500
  }'
```

### Example 3: Integration with Other Tools

**Use with SAM (if installed):**

```bash
# Configure SAM to use llama.cpp endpoint
# In SAM's config, set:
# llm_endpoint: "http://localhost:8080/v1/chat/completions"
```

**Use with Open WebUI:**

```bash
# Install Open WebUI
docker run -d -p 3000:8080 \
  -e OLLAMA_API_BASE_URL=http://localhost:8080 \
  ghcr.io/open-webui/open-webui:main

# Access at http://localhost:3000
```

## Notes

- **GTT allocation is persistent** - Kernel parameters apply on every boot
- **Both TTM parameters required** - `ttm.pages_limit` AND `ttm.page_pool_size` must match
- **VRAM won't change** - Check GTT (`mem_info_gtt_total`), not VRAM, to verify allocation
- **Vulkan-only is simpler** - HIP/ROCm not needed for excellent acceleration on Phoenix APUs
- **Model quantization matters** - Q4_K_M is best balance of quality/speed
- **Context length impacts memory** - Larger contexts require more GPU memory
- **Thermal management** - APUs throttle under sustained load; ensure adequate cooling
- **SteamOS updates may reset changes** - Re-apply kernel parameters after major OS updates
- **Leave RAM for OS** - Minimum 4GB system RAM, 6-8GB recommended for stability

## Skill Maintenance

**This skill was battle-tested on:**
- Device: Ayaneo 2S
- CPU: AMD Ryzen 7 7840U  
- GPU: AMD Radeon 780M (RDNA 3, gfx1103)
- RAM: 16GB (not 32GB - documentation corrected)
- OS: SteamFork (based on SteamOS 3.x)
- Date: January 31, 2026

**Test Results:**
- Model: Qwen2.5-14B-Instruct Q4_K_M (8.5GB)
- Configuration: 3GB VRAM + 8GB GTT = 11GB total GPU memory
- Performance: 5.69 tokens/second with partial GPU offload
- Status: Stable, no issues

**Key Discovery:**  
The original gist mentioned only `ttm.pages_limit`, but AMD APUs require **both** `ttm.pages_limit` and `ttm.page_pool_size` set to the same value. This is documented in ALICE's TTM Tuning Guide and was confirmed through live testing.

**If you encounter issues not covered here, please report them for skill improvement.**
