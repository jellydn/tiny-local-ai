# Tiny Local AI

A beginner handbook for running AI on your own computer, with **Inkling 2 Mini** as the main example. Learn to run a model, select hardware, test results, fine-tune for a task, and train a small model for education.

This repository is a documentation handbook. It contains setup examples and links to external tools. It does not contain model weights, bundled inference tools, a Mini training pipeline, or a recipe to reproduce its pretraining.

**Sources checked: 22 November 2026.** Model support changes quickly. Check the linked runtime guide before downloading large files.

## Choose your starting point

New to local AI? Start with the **[learning base](docs/README.md)**: a step-by-step path from zero, a [glossary](docs/glossary.md) in plain words, a [worked example on an M1 Max 32 GB](docs/worked-example-m1-max-32gb.md) and an [FAQ](docs/faq.md).

| Your goal | Start here | Result |
| --- | --- | --- |
| Learn the basics from zero | [Learning base](docs/README.md) | Terms, a memory plan, a running server and fair benchmarks |
| Chat with a local model | [Run Inkling 2 Mini](#run-inkling-2-mini) | A local web page and API |
| Check whether your computer can run it | [Hardware](#hardware-and-memory) | A memory plan |
| Add your documents | [Prompting and retrieval](#before-you-train) | Answers with relevant source text |
| Change response style or task behaviour | [Fine-tuning](#fine-tuning-inkling-2-mini) | An evaluated adapter |
| Understand how training works | [From scratch](#train-a-small-model-from-scratch) | A small educational language model |
| Learn from measured runs | [Hands-on notes](#hands-on-learning-notes) | Benchmarks and practical lessons |
| Understand the repository | [Repository scope](#repository-scope) | Files, examples and limits |

## Key terms

These are the words this page uses most. The [glossary](docs/glossary.md) explains more terms, each with an example.

- **[Inference](docs/glossary.md#inference):** Run an existing model to get an answer. The model does not change.
- **[Token](docs/glossary.md#token):** A small piece of text, such as a word or part of a word. Models read and write tokens.
- **[Weights](docs/glossary.md#model-and-weights):** The numbers a model learned during training. A **parameter** is one weight; "26.4B" means 26.4 billion parameters.
- **[Active parameters](docs/glossary.md#active-parameters):** The parameters a model uses for each token. In an [MoE (Mixture-of-Experts) model](docs/glossary.md#dense-vs-moe), this is much smaller than the total. Active parameters set the speed; total parameters set the memory.
- **[Context](docs/glossary.md#context-window):** All tokens the model can see in one request: your prompt, the chat history and the answer.
- **[Quantization](docs/glossary.md#quantization):** Store each weight with fewer bits, so the file is smaller. Quality can drop a little. A quantized file is called a **quant**.
- **[GGUF](docs/glossary.md#gguf):** A model file format for llama.cpp and the apps built on it.
- **[Engine](docs/glossary.md#engine-runtime) (runtime):** The program that loads the model file and runs it, such as llama.cpp.
- **[KV cache](docs/glossary.md#kv-cache):** Memory where the model keeps data for every token it has read, so it does not compute it again. It grows with the context.
- **Fine-tuning:** Train an existing model further on your own examples, so it changes its behaviour.
- **LoRA:** A cheap kind of fine-tuning. It trains a small extra set of weights (an **adapter**) and keeps the original weights unchanged.
- **Pretraining from scratch:** Start with random weights and teach a model to predict the next token.
- **RAG (retrieval-augmented generation):** Find documents that match the question and paste them into the prompt. It does not change the weights.

## Meet Inkling 2 Mini

Thinking Machines Lab released Mini on 20 November 2026 under the Apache 2.0 licence, which allows free use, including commercial use. It reads text and images and writes text.

It is an [MoE model](docs/glossary.md#dense-vs-moe) with 26.4B parameters in total. For each token it uses only 3.4B of them (its [active parameters](docs/glossary.md#active-parameters)). You still need memory for all 26.4B, because any token can need any part of the model.

A model is a stack of [layers](docs/glossary.md#layer). Mini stores 24 layers, but it runs its 12 middle layers three times for each token, reusing the same weights. These are called [looped layers](docs/glossary.md#looped-layers). Because of the repeats, each token does about as much work as a model with 5.4B active parameters. An engine must support this design on purpose; older engines cannot run it.

The official model card lists a context of up to 1M (one million) tokens. The official file (checkpoint) is about 20 GB and stores most weights in [NVFP4](docs/glossary.md#nvfp4), a 4-bit format, and some in MXFP8, an 8-bit format. A normal computer has memory for much less context than 1M tokens. See the [official model card and weights](https://huggingface.co/thinkingmachines/Inkling-2-Mini) for architecture, limitations, training information and licence details.

### Mini and Small are different models

| Model | Total / active parameters | Role in this handbook |
| --- | --- | --- |
| Inkling 2 Mini | 26.4B / 3.4B, with repeated computation as described above | Main local inference example |
| Inkling 2 Small | 594B / 17B | Separate, much larger model |

[drost-ai/finetune-inkling-2-small](https://github.com/drost-ai/finetune-inkling-2-small) is a community project that fine-tunes **Small** with LoRA on Tinker, Thinking Machines' hosted training service (see [Tinker](#official-hosted-path-tinker) below). It is linked to a fine-tuned model named Tess-4.5-594B-A17B. Its costs, hardware needs, checks and results apply to Small, not to Mini. Read it for workflow ideas. Do not rename the model and assume its scripts support Mini.

## Hardware and memory

The [official Mini card](https://huggingface.co/thinkingmachines/Inkling-2-Mini) supports NVIDIA DGX Spark (a small desktop AI computer) and Apple silicon Macs with at least 32 GB memory. For other GPUs it recommends at least 32 GB of [VRAM](docs/glossary.md#unified-memory), the GPU card's own memory.

Use this practical planning guide:

| Machine | Suggested first step |
| --- | --- |
| Apple silicon, 32 GB or more | Try the text-only setup below with a short context |
| NVIDIA or AMD GPU | Download the engine file for your GPU system (CUDA for NVIDIA; ROCm or Vulkan for AMD) from the linked runtime guide. Check that it supports this model. |
| 8–16 GB laptop | Start with a smaller model. Mini's smaller quants fit in less memory but lose more quality. |
| CPU-only computer | Start with a tiny model. Measure the speed before you download large files. |
| Computer for training | Training needs much more memory than running a model. A model that runs on your computer may not train on it. |

Plan memory for **weights + KV cache + [compute buffers](docs/glossary.md#compute-buffer) (scratch memory) + the operating system and other apps**. Image input adds memory. A longer context and more requests at the same time also add memory.

On an Apple silicon Mac, the CPU and GPU share one pool of memory ([unified memory](docs/glossary.md#unified-memory)), and macOS lets the GPU use only part of it (the [Metal memory budget](docs/glossary.md#metal-memory-budget)): 25.0 GiB on a 32 GB Mac. On a PC, the model must fit in the GPU card's VRAM for full speed. [Step 2 of the learning base](docs/2-plan.md) shows how to estimate each part.

Leave disk space for downloads. Start with one request and a short context. Change one setting at a time. A file that fits on your disk can still be too large for your memory.

### A measured M1 Max example

[jellydn's sybil-solutions/local-ai-registry PR #466](https://github.com/sybil-solutions/local-ai-registry/pull/466) reports a text-only run on a MacBook Pro with an M1 Max chip (32-core GPU, 32 GB memory). The [Local AI registry](docs/glossary.md#registry-recipe-and-lab-gates) is a public list of tested setups.

- **Engine:** Unsloth's version of llama.cpp, [build](docs/glossary.md#build-mainline-and-fork) `b12588-mix-c0c3de8`, using the Mac GPU.
- **Model file:** the [`UD-Q4_K_XL`](docs/glossary.md#ud-q4_k_xl) quant (17.63 GB).
- **Settings:** 131,072 tokens (128K) of context, one request at a time, a [micro-batch](docs/glossary.md#batch-and-ubatch--b--ub) of 256 tokens, an 8-bit ([q8_0](docs/glossary.md#f16-and-q8_0-kv)) KV cache and flash attention.
- **Result:** it passed all six registry tests ([lab gates](docs/glossary.md#registry-recipe-and-lab-gates)), and wrote 20.1 tokens per second.
- **Long input:** it found a hidden code in a 91,890-token prompt ([needle recall](docs/glossary.md#needle-recall)). One such test does not prove quality across the whole 128K window.
- **What failed:** the default launch, with a 16-bit KV cache, ran [out of memory](docs/glossary.md#oom). The DSpark helper model ([speculative decoding](docs/glossary.md#speculative-decoding)) made it slower, not faster.

The PR was **open when checked**. These numbers come from the author's own Mac. They are not a speed guarantee, and this handbook did not rerun them. To repeat the test, use the exact launch command and file versions in the PR. 128K is what fits on this Mac, not the model's limit. The [worked example](docs/worked-example-m1-max-32gb.md) explains every result.

## Hands-on learning notes

Read the full experiments in [Inkling 2 Mini on M1 Max](https://github.com/jellydn/tiny-local-ai/discussions/3) and [Qwen3.8-27B on the same Mac](https://github.com/jellydn/tiny-local-ai/discussions/4). Their supporting submissions are [sybil-solutions/local-ai-registry PR #466](https://github.com/sybil-solutions/local-ai-registry/pull/466) and [sybil-solutions/local-ai-registry PR #470](https://github.com/sybil-solutions/local-ai-registry/pull/470).

These are **author-reported results**, checked against the linked reports on 21 November 2026. They were not rerun for this handbook. Both models ran on the same M1 Max (32-core GPU, 32 GB), with the same engine build, the same `UD-Q4_K_XL` quant type, one request at a time and 128K tokens of context. Each model used its own best [sampling](docs/glossary.md#sampling-settings) and speculation settings, so this compares two tuned setups, not a test where only one thing changed.

Qwen3.8-27B is a [dense model](docs/glossary.md#dense-vs-moe): it uses all 27 billion parameters for every token. Inkling 2 Mini is an MoE model that uses 3.4 billion of its 26.4 billion. Both files are about 17.6 GB.

### What the measurements show

- **[Prefill](docs/glossary.md#prefill-vs-decode)** (prompt processing): the model reads your whole prompt before it answers.
- **[Decode](docs/glossary.md#prefill-vs-decode):** the model writes the answer, one token at a time.
- **[Speculative decoding](docs/glossary.md#speculative-decoding):** a small, fast helper guesses the next few tokens, and the main model checks them in one step. It helps only if checking is cheap.
- **[MTP](docs/glossary.md#mtp-multi-token-prediction)** (multi-token prediction): a helper built into the model itself. Qwen has one. **[DSpark](docs/glossary.md#dspark)** is a separate helper model for Inkling.
- **tok/s:** tokens per second. **MiB:** a memory unit; 1,024 MiB is 1 GiB (see [units](docs/glossary.md#gb-gib-and-mib)).

| Reported metric | Inkling 2 Mini | Qwen3.8-27B |
| --- | --- | --- |
| Decode speed, middle value (median) of six runs | About 20.5 tok/s without DSpark | About 14.8–15.0 tok/s with MTP guessing three tokens; about 11.9 without MTP |
| Decode speed in the registry's separate speed test | 20.1 tok/s | 17.6 tok/s |
| Prefill speed, short / longer prompt | 202.6 tok/s at 3.3K tokens / 146.5 at 25.5K | 124.1 tok/s at 2.8K tokens / 116.6 at 21.6K |
| Total GPU memory used at 128K (from the server log) | 23,326 MiB | 20,954 MiB |
| Longest prompt where it found the hidden code | 91,890 tokens | 106,294 tokens |
| Effect of speculative decoding | DSpark made decode slower | MTP with three guesses made decode faster than the runs without it |

The prompt lengths differ between the two models. Finding one hidden code is one task, not proof of quality across the whole window. The registry speed test and the six-run benchmark use different prompts and methods, so do not compare a number from one with a number from the other. tok/s also does not measure answer quality, or how long the model takes to finish a whole answer.

### Lessons to apply to your own experiments

1. **Check the GPU memory budget.** When the server starts, its log lists the memory for the weights, the KV cache and the compute buffers. Add them up. On this Mac, Mini's default 128K launch needed more than the 25.0 GiB budget and ran out of memory. A micro-batch of 256 tokens and an 8-bit KV cache made it fit. The 8-bit cache can lower quality a little, so test it on your own tasks.
2. **A smaller total does not mean every part is smaller.** Qwen's 8-bit KV cache (4,352 MiB) is almost twice Mini's (2,282 MiB). But Qwen's total is lower, because its compute buffer is much smaller.
3. **Measure speculative decoding on your own engine and GPU.** It is not enough that the helper guesses well: checking the guesses must also cost less than it saves. Here it helped dense Qwen and slowed MoE Mini. This is not a rule for every model, GPU or engine version.
4. **Measure prefill and decode separately.** Mini read prompts faster in these tests. Qwen's prefill speed changed less as the prompt grew. Test your own prompt lengths before you choose a model for long documents.
5. **Run the unchanged setup before and after each change.** A busy laptop slows down during a long session. Run unchanged → changed → unchanged ([control runs](docs/glossary.md#control-run)), repeat each several times and use the median. Keep prompts and sampling the same.
6. **Record the complete setup.** Save the model [revision and file checksum](docs/glossary.md#revision-and-checksum-sha256), the engine build, the launch command and the test prompts. The same model name can mean different files that need different engines.

For a first try, use the short-context Mini setup below. Move to the 128K setup only after the short one works. These notes are about running the model; they say nothing about what fine-tuning needs.

## Run Inkling 2 Mini

These steps are short. [Step 3 of the learning base](docs/3-run.md) has the same setup with every command and flag explained.

### 1. Select a matching runtime and GGUF

Unsloth is a company that makes quantized copies of models and shares them on [Hugging Face](docs/glossary.md#hugging-face), a website for model files. Use the [Unsloth Mini guide](https://unsloth.ai/docs/models/inkling-2-mini) and its [GGUF files](https://huggingface.co/unsloth/Inkling-2-Mini-GGUF).

**The engine and the file must match.** The GGUF files at the top of that repository need Unsloth's own llama.cpp, build `b12588-mix-c0c3de8`. The official llama.cpp ([mainline](docs/glossary.md#build-mainline-and-fork)) needs the different files in the [Mainline_Support folder](https://huggingface.co/unsloth/Inkling-2-Mini-GGUF/blob/main/Mainline_Support/README.md). Do not use a file from one path with the engine from the other.

If you prefer an app to the terminal, follow the guide's Unsloth Desktop steps. The terminal example below uses the Unsloth build, text only, with no speculative-decoding helper. It follows the documentation; it was not tested for this handbook.

### 2. Prepare the folder

You need Git, Python 3.10 or newer, and tmux, a terminal program that keeps the server running after you close the window (on a Mac: `brew install tmux`).

```bash
git clone https://github.com/jellydn/tiny-local-ai.git
cd tiny-local-ai
python3 -m venv .venv
source .venv/bin/activate
python -m pip install huggingface_hub
mkdir -p models/inkling-2-mini runtime
```

The `venv` lines make a private Python folder and turn it on. Run `source .venv/bin/activate` again in each new terminal before you use `hf`, the download command that `huggingface_hub` installs.

Download the archive for your system and GPU from the [Unsloth release page](https://github.com/unslothai/llama.cpp/releases/tag/b12588-mix-c0c3de8). On an Apple silicon Mac, it is the `macos-arm64` file. Unpack it into `runtime/`, then run `find runtime -name llama-server`. The commands below use `runtime/llama-b12588-mix-c0c3de8/llama-server`; if `find` prints another path, use that path. Do not move `llama-server` out of its folder, because it needs the library files next to it.

### 3. Download the text model

The recommended `UD-Q4_K_XL` file is about 17.63 GB. Running it needs more memory than that, because the KV cache and compute buffers come on top.

```bash
hf download unsloth/Inkling-2-Mini-GGUF \
  Inkling-2-Mini-UD-Q4_K_XL.gguf \
  --local-dir models/inkling-2-mini
```

To repeat a test later, record the repository revision (an exact version) and the file's [sha256 checksum](docs/glossary.md#revision-and-checksum-sha256). To get exactly the file from the M1 Max test, use the revision and checksum listed in [sybil-solutions/local-ai-registry PR #466](https://github.com/sybil-solutions/local-ai-registry/pull/466).

### 4. Start a text-only server

Run these from the `tiny-local-ai` folder. The first start uses a 4K-token context, so it needs little memory.

Open a tmux session:

```bash
tmux new -s tiny-local-ai
```

Inside tmux, paste this command and press Enter:

```bash
./runtime/llama-b12588-mix-c0c3de8/llama-server \
  --model models/inkling-2-mini/Inkling-2-Mini-UD-Q4_K_XL.gguf \
  --alias inkling-2-mini --jinja --ctx-size 4096 --n-gpu-layers 99 --parallel 1 \
  --temp 1.0 --top-p 1.0 --top-k 0 --min-p 0.0 --host 127.0.0.1 --port 8080
```

Loading can take a minute or more. The server is ready when the log shows `listening on http://127.0.0.1:8080`. Then open the chat page at `http://127.0.0.1:8080` in your browser.

To leave tmux and keep the server running, press Ctrl-b, then d. To go back, run `tmux attach -t tiny-local-ai`. To stop the server, go back and press Ctrl-C.

For image input, you also need the model's [projector](docs/glossary.md#projector-mmproj) file; follow the guide's instructions for it. Try a speculative-decoding helper only after you have measured the basic setup.

### 5. Test the API

The server has an API: a web address that programs can send requests to. In a second terminal (not in tmux), run:

```bash
curl http://127.0.0.1:8080/health
curl http://127.0.0.1:8080/v1/models
curl http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"inkling-2-mini","messages":[{"role":"user","content":"Explain local AI in three short sentences."}],"max_tokens":256,"temperature":1.0}'
```

Check that `/v1/models` lists `inkling-2-mini` and that the answer is readable text. Random characters usually mean the engine and the file do not match. A successful load is only the first check: also test arithmetic, your own language, long input and any [tool calls](docs/glossary.md#chat-template-and-tool-calls) you need.

Inkling 2 Mini is a [thinking model](docs/glossary.md#thinking-model): it writes its reasoning before the answer, and the reasoning counts toward `max_tokens`. If answers stop too early, raise `max_tokens`. In every request, set the `model` field to an ID from `/v1/models`. Any app that supports the OpenAI API can use `http://127.0.0.1:8080/v1` ([OpenAI-compatible server](docs/glossary.md#openai-compatible-server)).

### Optional: access from another computer

With `--host 127.0.0.1`, only the server computer can connect. To use it from other computers on your own trusted home or office network (LAN), start the server with `--host 0.0.0.0`. Then use the server computer's private IP address on the other computer, such as `http://192.168.1.100:8080/v1`.

The example server has no password. Never open this port to the internet. If you add a password (an API key), send it with each request. After you download the files, the model runs offline. Downloads and cloud training still need the network.

## Before you train

Choose the smallest change that solves your problem:

| Problem | First approach |
| --- | --- |
| The answer needs clearer instructions | Improve the prompt and provide examples |
| The answer needs current or private documents | Use RAG: find the matching passages and paste them into the prompt |
| The output needs a fixed format or special behaviour every time | Try supervised fine-tuning: train on example questions with correct answers |
| You want to learn how models work | Train a tiny model from scratch |

Before any training, measure how the unchanged model does (your **baseline**). Keep 20–50 test prompts from your real work, each with a way to check the answer. Include prompts where the model fails today. Never put test prompts in the training data, or the test will look better than it is. Record quality, response time, memory and answer length.

## Fine-tuning Inkling 2 Mini

### Official hosted path: Tinker

Tinker is Thinking Machines' hosted training service. The [official Tinker Cookbook](https://github.com/thinking-machines-lab/tinker-cookbook) supports `thinkingmachines/Inkling-2-Mini`. It includes the Mini-specific code that turns chat messages into the model's text format (the **renderer**) and splits text into tokens (the **tokenizer**). It has examples of supervised fine-tuning and other training after pretraining.

Tinker trains on Thinking Machines' computers, through an API. Your laptop does not do the training. Check access, model limits and prices before a run. Use the cookbook's Mini model name and code; do not copy a recipe written for Small.

A beginner workflow:

1. Define one measurable task, such as producing a fixed support-ticket format.
2. Prepare a small, clean dataset. Remove secrets and duplicates. Confirm that you can use the data.
3. Split the data into three sets: **training** (the model learns from it), **validation** (you check progress during training) and **test** (you check the final result once). Split by source or topic, so similar examples do not appear in two sets. When test examples leak into training, the score is too high.
4. Turn the examples into Mini's text format and count tokens with Mini's own tokenizer. Check the service's limits on input and output length.
5. Run a small LoRA training with a spending limit.
6. Compare the original model and the model with your adapter on the same test prompts and sampling settings.
7. Keep the adapter only if your task gets better and other tasks do not get much worse.
8. Before you plan to run the adapter on your own computer, check that you can download it, combine it with the model and run it in your engine.

Training data is often a JSONL file: one JSON record per line. This record shows the idea; check that your trainer reads this format:

```json
{"messages":[{"role":"user","content":"Classify: The package arrived damaged."},{"role":"assistant","content":"delivery_damage"}]}
```

Start with short, correct examples. Do not add private data to a hosted service without the required permission.

### Local fine-tuning

This repository has **no tested recipe for fine-tuning Mini on your own computer**. A GGUF file is made for running a model, not for training it. Mini's looped layers, experts and mixed 4-bit/8-bit formats need a training program that supports them on purpose.

Before you train locally, confirm that your training program supports Mini's design and file format, which layers get the adapter, how much memory training needs, and how to save the result. First prove that a tiny run can save, load again and improve a test task. Training needs much more memory than the 17.63 GB file suggests.

To learn how adapters work, see [Hugging Face PEFT](https://github.com/huggingface/peft) and [TRL](https://github.com/huggingface/trl), two Python libraries for fine-tuning. They are learning resources; this handbook does not claim they support Mini. If your training program does not fully support Mini, learn the whole process on a smaller model that it does support.

Full fine-tuning changes all weights and needs much more memory than LoRA. Reinforcement learning (training with scores instead of correct answers) is harder to set up and to check. Learn supervised fine-tuning first.

## Train a small model from scratch

**Educational goal:** learn how training works: how text becomes tokens, how a model learns to predict the next token, how the **loss** (a number for how wrong the predictions are) goes down, how **gradients** tell each weight which way to change, and how to check progress on data the model did not train on. Making a model like Inkling 2 Mini needs far more data, computers and engineering than this exercise. Its published weights do not include a full recipe to recreate it.

Suggested learning order:

1. [Neural Networks: Zero to Hero](https://github.com/karpathy/nn-zero-to-hero) — work through neural-network fundamentals.
2. [nanoGPT](https://github.com/karpathy/nanoGPT) — inspect and train a small GPT. Use it as a compact educational example.
3. [llm.c](https://github.com/karpathy/llm.c) — study lower-level training implementation after the Python workflow.

### First experiment: character-level Shakespeare

This follows nanoGPT's example for computers without a GPU. Do it in a separate folder, outside `tiny-local-ai`, with its own Python environment. The model learns to write text one letter at a time from Shakespeare's plays.

```bash
git clone https://github.com/karpathy/nanoGPT.git
cd nanoGPT
python3 -m venv .venv
source .venv/bin/activate
python -m pip install torch numpy transformers datasets tiktoken wandb tqdm
python data/shakespeare_char/prepare.py
tmux new -s nanogpt
```

Inside tmux, run `source .venv/bin/activate` again, then start training:

```bash
python train.py config/train_shakespeare_char.py --device=cpu --compile=False --eval_iters=20 --log_interval=1 --block_size=64 --batch_size=12 --n_layer=4 --n_head=4 --n_embd=128 --max_iters=2000 --lr_decay_iters=2000 --dropout=0.0
```

The flags make a very small model so it trains on a CPU. Wait for training to finish. In the same tmux window, generate a sample:

```bash
python sample.py --out_dir=out-shakespeare-char --device=cpu
```

Runtime depends on your computer. This produces a small text predictor, not an instruction-following assistant.

Then change one thing at a time: model size, context length, training steps or dataset. Compare the loss on the training data with the loss on the validation data. If training loss keeps falling while validation loss rises, the model is memorising its training text instead of learning (**overfitting**). Save the settings, the dataset source, the random seed and the saved model file (checkpoint) so you can repeat the experiment.

## Repository scope

| File | Purpose |
| --- | --- |
| [README.md](README.md) | Beginner handbook, setup examples and learning resources |
| [docs/](docs/README.md) | Learning base: learning path, glossary, worked example and FAQ; also published as a [website](https://jellydn.github.io/tiny-local-ai/) |
| [package.json](package.json) | VitePress tools that build the website from `docs/` (`bun install`, then `bun run docs:dev` or `bun run docs:build`) |
| [.github/workflows/deploy-docs.yml](.github/workflows/deploy-docs.yml) | Builds the website on pull requests and deploys it to GitHub Pages from `main` |
| [.agents/setup](.agents/setup) | Prepares Amp orbs with the link checker and website tools |
| [AGENTS.md](AGENTS.md) | Guidance for maintaining this handbook |
| [.gitignore](.gitignore) | Excludes local downloads, environments and experiment output |
| [LICENSE](LICENSE) | Repository licence; model weights and datasets have their own terms |

Run inference with the external runtime described above. Run the educational training exercise in its separate nanoGPT checkout.

The earlier launchers, routing tools, hardware data and Qwen/GLM benchmark notes were removed to keep the repository consistent with this handbook. They remain in [Git history before the cleanup](https://github.com/jellydn/tiny-local-ai/tree/84e52cbbd8359dbef8a2251c989e10a6177fcafe). Treat those files as historical material.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Unknown architecture, load error or random characters | The engine build and the GGUF file must match. A finished download does not prove that the file works with your engine. |
| Out of memory | Close other apps. Use a shorter context and one request at a time. Then try a smaller quant. Check the KV cache and compute buffers in the log, not only the file size. |
| Slow first answer | Find which part is slow: loading the model, reading the prompt (prefill) or writing the answer (decode). A long prompt can take minutes to read. |
| API request reaches the wrong model | Check the URL and the `model` field in the request. Compare it with `/v1/models`. |
| Another computer cannot connect | Check that the server uses `--host 0.0.0.0`, the private IP address and the firewall. First check that it works on the server computer. |
| Fine-tuned model is worse than the original | Check data quality, test data in training data (leakage), the text format, the learning rate and how you measure. |
| Adapter does not run on your computer | Check that it matches the exact model version and tokenizer, and that your engine supports its format. |

The [FAQ and troubleshooting page](docs/faq.md) has more fixes.

## Record your results

For each experiment, save the model ID and revision, the quant file name and checksum, the engine version, the operating system, the hardware, the context size, the sampling settings, the prompt, the answer, the memory use and the times. Label each result: **measured** (you ran it), **source-reported** (a model card or document says it) or **estimated** (a calculation).

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
