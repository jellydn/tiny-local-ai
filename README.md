# Tiny Local AI

A beginner handbook for running AI on your own computer, with **Inkling 2 Mini** as the main example. Learn to run a model, select hardware, test results, fine-tune for a task, and train a small model for education.

This repository is a documentation handbook. It contains setup examples and links to external tools. It does not contain model weights, bundled inference tools, a Mini training pipeline, or a recipe to reproduce its pretraining.

**Sources checked: 21 November 2026.** Model support changes quickly. Check the linked runtime guide before downloading large files.

## Choose your starting point

| Your goal | Start here | Result |
| --- | --- | --- |
| Chat with a local model | [Run Inkling 2 Mini](#run-inkling-2-mini) | A local web page and API |
| Check whether your computer can run it | [Hardware](#hardware-and-memory) | A memory plan |
| Add your documents | [Prompting and retrieval](#before-you-train) | Answers with relevant source text |
| Change response style or task behaviour | [Fine-tuning](#fine-tuning-inkling-2-mini) | An evaluated adapter |
| Understand how training works | [From scratch](#train-a-small-model-from-scratch) | A small educational language model |
| Learn from measured runs | [Hands-on notes](#hands-on-learning-notes) | Benchmarks and practical lessons |
| Understand the repository | [Repository scope](#repository-scope) | Files, examples and limits |

## Key terms

- **Inference:** Run existing model weights to generate an answer.
- **Token:** A unit of text processed by the model. It can be part of a word.
- **Weights:** The numbers learned during training.
- **Context:** The input and generated tokens available to a request.
- **Quantization:** Store weights with fewer bits to reduce memory use. Quality can change.
- **GGUF:** A model file format used by llama.cpp and compatible runtimes.
- **KV cache:** Runtime memory used to retain attention information.
- **Fine-tuning:** Update an existing model with task examples.
- **LoRA:** Train small adapter weights while keeping most base weights fixed.
- **Pretraining from scratch:** Start with random weights and learn to predict tokens.
- **RAG:** Retrieve relevant documents and include them in the prompt. It does not change weights.

## Meet Inkling 2 Mini

Thinking Machines Lab released Mini on 20 November 2026 under Apache 2.0. It accepts text and images and produces text. It has 26.4B total parameters and 3.4B active parameters. Repeated layer passes give about 5.4B effective active parameters per token.

Its 24 layers include 12 middle layers that run three times with shared weights. This looped MoE architecture needs explicit runtime support. Active parameter count is not the amount of memory needed to store the model.

The official card specifies up to 1M context tokens and an approximately 20 GB mixed NVFP4/MXFP8 checkpoint. A local machine may support much less context. See the [official model card and weights](https://huggingface.co/thinkingmachines/Inkling-2-Mini) for architecture, limitations, training information and licence details.

### Mini and Small are different models

| Model | Total / active parameters | Role in this handbook |
| --- | --- | --- |
| Inkling 2 Mini | 26.4B / 3.4B, with repeated computation as described above | Main local inference example |
| Inkling 2 Small | 594B / 17B | Separate, much larger model |

[drost-ai/finetune-inkling-2-small](https://github.com/drost-ai/finetune-inkling-2-small) is a community LoRA workflow for **Small on Tinker**, associated with Tess-4.5-594B-A17B. Its costs, hardware needs, tokenizer checks, merge steps and benchmark results are not Mini results. Read it for workflow ideas. Do not rename the model and assume its scripts support Mini.

## Hardware and memory

The [official Mini card](https://huggingface.co/thinkingmachines/Inkling-2-Mini) supports DGX Spark and Apple silicon with at least 32 GB memory. It recommends at least 32 GB VRAM for other GPUs.

Use this practical planning guide:

| Machine | Suggested first step |
| --- | --- |
| Apple silicon, 32 GB or more | Try the text-only setup below with a short context |
| NVIDIA or AMD GPU | Select the matching build in the linked runtime guide; check model and backend support |
| 8–16 GB laptop | Start with a smaller model, or investigate smaller Mini quants and their quality trade-offs |
| CPU-only computer | Use a tiny educational model first; measure speed before committing to larger downloads |
| Computer for training | Check the training framework separately; inference fit does not prove training fit |

Budget memory for **weights + KV cache + runtime buffers + the operating system and other apps**. Image processing adds memory. More context and concurrent requests can increase memory use. Unified memory and discrete GPU VRAM have different constraints.

Leave disk space for downloads, temporary files and checkpoints. Start with one request and a short context. Increase one setting at a time. A file that fits on disk may still fail to load.

### A measured M1 Max example

[jellydn's sybil-solutions/local-ai-registry PR #466](https://github.com/sybil-solutions/local-ai-registry/pull/466) reports a text-only run on an M1 Max with a 32-core GPU and 32 GB memory:

- Unsloth `b12588-mix-c0c3de8`, Metal, `UD-Q4_K_XL`.
- 131,072 configured context tokens, one slot, micro-batch 256, Q8 KV cache and flash attention.
- Six lab gates passed; reported decode was 20.1 tokens/second.
- A 91,890-token recall prompt passed. This is not a test of every token in the configured window.
- The default F16 KV setup ran out of memory. DSpark was slower in the reported comparison.

The PR was **open when checked**. These are author-reported measurements from that setup, not a speed guarantee or a benchmark run performed by this handbook. Use its pinned launch and evidence for reproduction. Its 128K configuration is not Mini's maximum model context.

## Hands-on learning notes

Read the full experiments in [Inkling 2 Mini on M1 Max](https://github.com/jellydn/tiny-local-ai/discussions/3) and [Qwen3.8-27B on the same Mac](https://github.com/jellydn/tiny-local-ai/discussions/4). Their supporting submissions are [sybil-solutions/local-ai-registry PR #466](https://github.com/sybil-solutions/local-ai-registry/pull/466) and [sybil-solutions/local-ai-registry PR #470](https://github.com/sybil-solutions/local-ai-registry/pull/470).

These are **author-reported results**, checked against the linked reports on 21 November 2026. The benchmarks were not rerun for this handbook. Both setups used an M1 Max with a 32-core GPU, 32 GB memory, Metal, Unsloth `b12588-mix-c0c3de8`, `UD-Q4_K_XL`, one request slot and 131,072 configured context tokens. Sampling and speculation settings differ by model, so this is a comparison of tuned setups, not a test with only one variable changed.

### What the measurements show

**Prefill** processes the prompt before generation. **Decode** generates output tokens. **Speculative decoding** drafts tokens, then checks them with the main model. **MTP** means multi-token prediction; Qwen's tested setup uses its built-in prediction head.

| Reported metric | Inkling 2 Mini | Qwen3.8-27B |
| --- | --- | --- |
| Decode benchmark, median of six samples | About 20.5 tokens/s without DSpark | About 14.8–15.0 tokens/s with three MTP drafts; about 11.9 without MTP |
| Separate lab speed gate | 20.1 tokens/s | 17.6 tokens/s |
| Prompt processing, short / longer prompt | 202.6 at 3.3K / 146.5 at 25.5K tokens/s | 124.1 at 2.8K / 116.6 at 21.6K tokens/s |
| Total Metal buffers at the tested 128K settings | 23,326 MiB | 20,954 MiB |
| Successful recall prompt length | 91,890 tokens | 106,294 tokens |
| Speculation result on this setup | DSpark reduced decode speed | Three MTP drafts improved decode against nearby controls |

The prompt lengths differ. Recall success is one task, not proof of quality across the full context window. The lab speed gate and the repeated benchmark use different prompts and measurement methods; keep their figures separate. Tokens/s also does not measure answer quality or total time to finish a task.

### Lessons to apply to your own experiments

1. **Check the GPU memory budget.** Add the model, KV cache and compute buffers from the server log. On this Mac, Mini's default 128K launch ran out of memory. Micro-batch 256 and Q8 KV cache made the reported launch fit. Cache quantization can affect quality, so test it on your tasks.
2. **Separate cache size from total memory.** The reports list Qwen's Q8 KV cache as 4,352 MiB and Mini's as 2,282 MiB. Qwen still has lower total Metal buffers because other buffers are smaller. Do not assume that a smaller total means every component is smaller.
3. **Measure speculation on the exact backend.** Draft acceptance alone is not enough: verification must save more work than drafting adds. These tests found a gain with Qwen MTP and a loss with Mini DSpark. This does not establish a rule for every dense model, MoE model, GPU or future runtime.
4. **Measure prompt processing and generation separately.** Mini was faster in the listed prompt-processing tests. Qwen's rate changed less between its two tested lengths. Test your own prompt lengths before choosing a model for long documents.
5. **Use a baseline before and after each change.** A busy laptop can slow down during a long session. Run baseline → candidate → baseline, repeat samples and report the median. Keep prompts and sampling fixed within each comparison.
6. **Keep the complete recipe.** Record weight revision, file checksum, runtime build, launch flags and test prompts. The same model name can refer to files with different formats or runtime requirements.

For a first experiment, use the short-context Mini setup below. Move to the linked 128K recipe only after the basic setup works. These notes concern inference; they do not establish local fine-tuning requirements.

## Run Inkling 2 Mini

### 1. Select a matching runtime and GGUF

Use the [Unsloth Mini guide](https://unsloth.ai/docs/models/inkling-2-mini) and [GGUF repository](https://huggingface.co/unsloth/Inkling-2-Mini-GGUF).

**Compatibility matters:** root GGUFs use Unsloth's layout and its `b12588-mix-c0c3de8` build. For upstream llama.cpp, use [Mainline_Support and its README](https://huggingface.co/unsloth/Inkling-2-Mini-GGUF/blob/main/Mainline_Support/README.md). Do not mix the two paths.

For a graphical start, use the guide's Unsloth Desktop steps. The terminal example below uses the pinned Unsloth build, text only, without a drafter. It is a documented starting configuration, not a local hardware test.

### 2. Prepare the folder

Prerequisites: Git, Python 3.10+, tmux, and the compatible runtime.

```bash
git clone https://github.com/jellydn/tiny-local-ai.git
cd tiny-local-ai
python3 -m venv .venv
source .venv/bin/activate
python -m pip install huggingface_hub
mkdir -p models/inkling-2-mini runtime
```

Download the archive for your OS and GPU from the [pinned runtime release](https://github.com/unslothai/llama.cpp/releases/tag/b12588-mix-c0c3de8). Extract it into `runtime/`. Locate `llama-server` and keep its libraries with it. The commands below assume `runtime/llama-server`; adjust that path if the archive has another folder level.

### 3. Download the text model

The recommended `UD-Q4_K_XL` file is about 17.63 GB. This is the weight download, not total memory use.

```bash
hf download unsloth/Inkling-2-Mini-GGUF \
  Inkling-2-Mini-UD-Q4_K_XL.gguf \
  --local-dir models/inkling-2-mini
```

Record the Hugging Face revision and file checksum for repeatable tests. For a historical reproduction, use the revision and checksums in sybil-solutions/local-ai-registry PR #466.

### 4. Start a text-only server

Run from the repository root. This starts with 4K context to limit the first test's memory use.

```bash
SESSION="$(basename "$PWD")"
tmux new-session -d -s "$SESSION"
tmux send-keys -t "$SESSION" './runtime/llama-server --model models/inkling-2-mini/Inkling-2-Mini-UD-Q4_K_XL.gguf --alias inkling-2-mini --jinja --ctx-size 4096 --n-gpu-layers 99 --parallel 1 --temp 1.0 --top-p 1.0 --top-k 0 --min-p 0.0 --host 127.0.0.1 --port 8000' Enter
tmux capture-pane -p -t "$SESSION" -S -30
```

If the session already exists, use a new pane in it before sending the command. Wait for the server's ready message. Open [the local chat page](http://127.0.0.1:8000). To stop this server, attach with `tmux attach -t "$SESSION"` and press Ctrl-C.

For image input, follow the guide's matching projector instructions. Enable optional drafting only after you have measured the basic setup.

### 5. Test the API

In a second terminal:

```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/v1/models
curl http://127.0.0.1:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"inkling-2-mini","messages":[{"role":"user","content":"Explain local AI in three short sentences."}],"max_tokens":256,"temperature":1.0}'
```

Check that the model ID appears and the answer is readable. Loading successfully is only the first check. Also test arithmetic, your language, long input, and any tool use you need.

Use the direct API example above for requests. Set the model field to an ID returned by `/v1/models`.

### Optional: access from another computer

Keep `127.0.0.1` for use on the server computer. For a trusted LAN, change the server bind address to `0.0.0.0`, then use the server's private IP in the client URL, such as `http://192.168.1.100:8000/v1`.

The example has no authentication. Do not forward this port to the internet. If you add server authentication, send the required credentials with each API request. Local inference can run offline after required files are downloaded, but downloads, remote URLs and cloud training still use the network.

## Before you train

Choose the smallest change that solves your problem:

| Problem | First approach |
| --- | --- |
| The answer needs clearer instructions | Improve the prompt and provide examples |
| The answer needs current or private documents | Use retrieval and include relevant passages |
| The output needs a repeated format or specialised behaviour | Evaluate supervised fine-tuning |
| You want to learn how models work | Train a tiny model from scratch |

Create a baseline before any training. Keep 20–50 representative test prompts and expected checks. Include failure cases. Keep test examples out of training data. Record quality, latency, memory and output length.

## Fine-tuning Inkling 2 Mini

### Official hosted path: Tinker

The [official Tinker Cookbook](https://github.com/thinking-machines-lab/tinker-cookbook) supports `thinkingmachines/Inkling-2-Mini` through its model-specific renderer and tokenizer. It provides supervised learning and other post-training examples.

Tinker runs training remotely through an API. It is not training on your laptop. Check current access, model limits and pricing before a run. Use the cookbook's Mini model name and rendering path, rather than copying a Small recipe.

A beginner workflow:

1. Define one measurable task, such as producing a fixed support-ticket format.
2. Prepare a small, clean dataset. Remove secrets and duplicates. Confirm that you can use the data.
3. Separate training, validation and final test sets by source or topic to reduce leakage.
4. Render and count tokens with the tokenizer for the exact model. Check the service's input and output limits.
5. Run a small supervised LoRA experiment with a capped budget.
6. Compare the base model and adapter on the same held-out prompts and sampling settings.
7. Keep the adapter only if task quality improves without unacceptable regressions.
8. Verify export, merge and runtime compatibility before planning local deployment.

Conceptual JSONL record; the trainer's loader must support this schema:

```json
{"messages":[{"role":"user","content":"Classify: The package arrived damaged."},{"role":"assistant","content":"delivery_damage"}]}
```

Start with short, correct examples. Do not add private data to a hosted service without the required permission.

### Local fine-tuning

This repository has **no verified local Mini fine-tuning recipe**. A GGUF inference file is not a ready training checkpoint. Mini's looped layers, MoE modules and mixed precision require explicit trainer support.

Before training locally, confirm the exact architecture, checkpoint format, adapter targets, backward-pass support, memory needs and export path. Prove that a tiny run can save, reload and improve a held-out task. Do not infer training requirements from the 17.63 GB inference file.

For general adapter concepts, see [Hugging Face PEFT](https://github.com/huggingface/peft) and [TRL](https://github.com/huggingface/trl). These are learning resources, not a claim of Mini compatibility. Learn the full workflow on a smaller model that your selected trainer explicitly supports if Mini support is incomplete.

Full fine-tuning updates all weights and usually needs much more memory than adapter training. Reinforcement learning adds reward design and evaluation complexity. Learn supervised fine-tuning first.

## Train a small model from scratch

**Educational goal:** Learn tokenization, next-token prediction, loss, gradients, validation and sampling. Reproducing Inkling 2 Mini needs far more data, compute and engineering than this exercise. Open weights do not provide a complete reproduction recipe.

Suggested learning order:

1. [Neural Networks: Zero to Hero](https://github.com/karpathy/nn-zero-to-hero) — work through neural-network fundamentals.
2. [nanoGPT](https://github.com/karpathy/nanoGPT) — inspect and train a small GPT. Use it as a compact educational example.
3. [llm.c](https://github.com/karpathy/llm.c) — study lower-level training implementation after the Python workflow.

### First experiment: character-level Shakespeare

This follows nanoGPT's CPU example. Use a separate directory and environment. Run training and sampling in tmux.

```bash
git clone https://github.com/karpathy/nanoGPT.git
cd nanoGPT
python3 -m venv .venv
source .venv/bin/activate
python -m pip install torch numpy transformers datasets tiktoken wandb tqdm
python data/shakespeare_char/prepare.py

SESSION="$(basename "$PWD")"
tmux new-session -d -s "$SESSION"
tmux send-keys -t "$SESSION" 'python train.py config/train_shakespeare_char.py --device=cpu --compile=False --eval_iters=20 --log_interval=1 --block_size=64 --batch_size=12 --n_layer=4 --n_head=4 --n_embd=128 --max_iters=2000 --lr_decay_iters=2000 --dropout=0.0' Enter
tmux attach -t "$SESSION"
```

Wait for training to finish. In that tmux shell, generate a sample:

```bash
python sample.py --out_dir=out-shakespeare-char --device=cpu
```

Runtime depends on your computer. This produces a small text predictor, not an instruction-following assistant.

Then change one variable at a time: model width, context, training steps or dataset. Compare training and validation loss. If training loss falls while validation loss rises, investigate overfitting. Save the configuration, dataset source, seed and checkpoint so you can repeat the experiment.

## Repository scope

| File | Purpose |
| --- | --- |
| [README.md](README.md) | Beginner handbook, setup examples and learning resources |
| [AGENTS.md](AGENTS.md) | Guidance for maintaining this handbook |
| [.gitignore](.gitignore) | Excludes local downloads, environments and experiment output |
| [LICENSE](LICENSE) | Repository licence; model weights and datasets have their own terms |

Run inference with the external runtime described above. Run the educational training exercise in its separate nanoGPT checkout.

The earlier launchers, routing tools, hardware data and Qwen/GLM benchmark notes were removed to keep the repository consistent with this handbook. They remain in [Git history before the cleanup](https://github.com/jellydn/tiny-local-ai/tree/84e52cbbd8359dbef8a2251c989e10a6177fcafe). Treat those files as historical material.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Unknown architecture, load error or nonsense output | Runtime version and GGUF layout must match. A successful file download does not prove compatibility. |
| Out of memory | Close other apps, reduce context and concurrency, then try a smaller quant. Check runtime buffers as well as weights. |
| Slow first response | Separate model load, prompt processing and token generation time. Long prompts can dominate latency. |
| API request reaches the wrong model | Check the endpoint URL and the JSON `model` field; inspect `/v1/models`. |
| LAN client cannot connect | Check server bind address, private IP and firewall. Confirm local access first. |
| Fine-tune is worse than the base model | Check data quality, leakage, formatting, learning rate and evaluation settings. |
| Adapter cannot be served locally | Check exact base revision, tokenizer, adapter format and runtime support before merging or conversion. |

## Record your results

For each experiment, save the model ID and revision, quant filename and checksum, runtime version, OS, hardware, context, sampling, prompt, output, memory use and timing. Label results as measured, source-reported or estimated.

This README was checked against the repository files and linked sources. The inference commands and training exercise were not executed as part of this documentation update. This documentation repository has no build or application test suite. Check file links, section links and example consistency when changing the handbook. Hardware and model support must be tested separately.

## Resources

- [Official Inkling 2 Mini model card and weights](https://huggingface.co/thinkingmachines/Inkling-2-Mini)
- [Official Tinker Cookbook](https://github.com/thinking-machines-lab/tinker-cookbook)
- [Tinker documentation](https://tinker-docs.thinkingmachines.ai/)
- [Unsloth Mini local inference guide](https://unsloth.ai/docs/models/inkling-2-mini)
- [Unsloth Mini GGUF files](https://huggingface.co/unsloth/Inkling-2-Mini-GGUF)
- [Upstream llama.cpp](https://github.com/ggml-org/llama.cpp)
- [M1 Max evidence: sybil-solutions/local-ai-registry PR #466](https://github.com/sybil-solutions/local-ai-registry/pull/466)
- [Separate Small fine-tuning workflow](https://github.com/drost-ai/finetune-inkling-2-small)
