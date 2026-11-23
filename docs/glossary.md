# Glossary

Each term has a short explanation and an example. The examples use the [M1 Max 32 GB results](worked-example-m1-max-32gb.md) where possible.

[Back to the learning base](README.md)

**Jump to:** [Model basics](#model-basics) · [Model files and quantization](#model-files-and-quantization) · [Memory](#memory) · [Speed](#speed) · [Speculative decoding](#speculative-decoding) · [Engines and servers](#engines-and-servers) · [Quality](#quality) · [Testing and sharing results](#testing-and-sharing-results)

## Model basics

### Model and weights

A **model** is a large list of numbers plus the code that uses them. The numbers are called **weights**. Training sets the weights. When you run a model, the weights do not change.

*Example:* the Inkling 2 Mini file `Inkling-2-Mini-UD-Q4_K_XL.gguf` holds its weights. It is 17.63 GB.

### Token

A **token** is a small piece of text. It can be a whole word, part of a word or a punctuation mark. Models read and write tokens, not letters. In English, 100 tokens is roughly 75 words.

*Example:* "unbelievable" can be three tokens: `un`, `believ`, `able`.

### Inference

**Inference** means running a model to get an answer. Everything in this learning base is inference. Training and fine-tuning change the weights; inference does not.

### Parameters

A **parameter** is one weight. Model sizes count parameters in billions, written **B**. More parameters usually means more knowledge, a bigger file and slower speed.

*Example:* Qwen3.8-27B has 27 billion parameters.

### Dense vs MoE

A **dense** model uses all of its parameters for every token.

A **Mixture-of-Experts (MoE)** model splits many of its layers into small blocks called **experts**. For each token, a small **router** picks a few experts. The other experts do no work for that token.

```mermaid
flowchart LR
    subgraph Dense["Dense: every weight works on every token"]
        T1[token] --> L1["all 27B parameters"]
    end
    subgraph MoE["MoE: the router picks a few experts"]
        T2[token] --> R{router}
        R --> E1["expert 12"]
        R --> E2["expert 87"]
        R -.->|"not used"| E3["126 other experts"]
    end
```

*Example:* Qwen3.8-27B is dense. Inkling 2 Mini is MoE: each layer sends each token to 8 of 128 experts.

### Active parameters

**Active parameters** are the parameters that do work for one token. In a dense model, active = total. In an MoE model, active is much smaller than total.

Active parameters mostly decide **speed**. Total parameters decide **memory**, because every expert must be in memory: the next token may need any of them.

*Example:* LFM2.5-24B-A2B has 24B total and about 2.4B active ("A2B" in the name means about 2B active). It needs memory for 24B, but it runs about as fast as a small model: 68.9 tokens per second on the M1 Max. Dense Qwen3.8-27B, with a file of almost the same size, ran at 11.9 tokens per second, or about 15 with speculative decoding. [Step 1](1-understand.md#example-two-models-with-the-same-file-size-but-different-speeds) compares the two side by side.

### Thinking model

A **thinking model** (or reasoning model) first writes its reasoning as tokens, then writes the answer. The reasoning also uses tokens, so a short answer can need hundreds or thousands of tokens. Give it a large enough `max_tokens` limit.

*Example:* on a "write a 600-word story" test, Qwen3.8-27B wrote 15,182 tokens, mostly reasoning.

### Chat template and tool calls

A **chat template** is the exact text format a model expects for user and assistant messages. It is stored in the model file. A **tool call** is when the model asks your program to run a function, such as "get the weather for Paris", and then uses the result.

### Layer

A model is a stack of **layers**. Each layer changes the numbers that represent your text a little, then passes them to the next layer. The last layer predicts the next token. More layers usually means more work per token.

### Looped layers

Most models run each layer once per token. A **looped** model runs some layers several times, reusing the same weights. This gives more work per token without a bigger file.

*Example:* Inkling 2 Mini stores 24 layers, but runs its middle 12 layers three times, so each token goes through 48 layer passes.

### Attention

**Attention** is the part of a layer that looks back at earlier tokens to decide what matters for the next one. Normal attention keeps a [KV cache](#kv-cache) entry for every earlier token.

### Linear attention

Normal attention keeps a [KV cache](#kv-cache) entry for every earlier token, so its memory grows with the context. **Linear attention** keeps one fixed-size summary instead. It uses less memory on long prompts, and its cost per token does not grow with the context.

*Example:* in Qwen3.8-27B, 48 of 64 layers use linear attention (a type called Gated DeltaNet). Only 16 layers keep a KV cache, so its cache is small. LFM2.5-24B-A2B uses short convolution layers, which look only at a few nearby tokens and keep no KV cache, for a similar reason.

## Model files and quantization

### Quantization

**Quantization** stores each weight with fewer bits. This makes the file smaller and faster to read. It also makes each weight less exact, so quality can drop a little. A common target is about 4 bits per weight instead of the original 16.

A quantized model file is often called a **quant**. Its name tells you roughly how many bits each weight uses: Q8 is about 8 bits, Q4 about 4 bits, and IQ1 about 1 bit.

*Analogy:* a photo stored with fewer bits per pixel. It looks almost the same, but some detail is gone. [Step 2](2-plan.md#a-picture-of-quantization) shows a picture of this.

### Bits per weight (bpw)

**Bits per weight** is the average storage for one weight, including extra numbers such as scales. Use it to estimate file size:

> file size in GB ≈ parameters in billions × bits per weight ÷ 8

*Example:* 26.4B × 5.3 bpw ÷ 8 ≈ 17.5 GB. The Inkling 2 Mini `UD-Q4_K_XL` file is 17.63 GB, so it averages about 5.3 bpw. "Q4" does not mean exactly 4 bits.

### GGUF

**GGUF** is a single-file model format used by llama.cpp and the apps built on it. One `.gguf` file holds the weights, the tokenizer and settings. The quant type is in the file name.

### Q4_K_M

**Q4_K_M** is a common llama.cpp quant type. "Q4" means mostly 4-bit weights. "K" is the k-quant method, which stores weights in small blocks with their own scales. "M" means medium: some sensitive weight groups (tensors) keep more bits. It averages a little under 5 bpw (estimated). It is a good default when you do not know which quant to choose.

### UD-Q4_K_XL

**UD-Q4_K_XL** is an Unsloth "Dynamic" quant. Unsloth measures which layers are sensitive and gives them more bits; other layers get fewer. "XL" means more layers keep higher precision than in "M". The worked examples use this quant for Inkling 2 Mini and Qwen3.8-27B.

### MLX format

**MLX** is Apple's machine learning framework for Apple silicon. MLX models are folders of `.safetensors` files, not GGUF. An MLX "4-bit" model with group size 64 averages 4.5 bpw, because each group of 64 weights also stores a scale and an offset. A "6-bit" model with group size 64 averages 6.5 bpw.

*Example:* `LiquidAI/LFM2.5-24B-A2B-MLX-6bit` is 19.5 GB at 6.5 bpw.

### NVFP4

**NVFP4** is a 4-bit floating-point format from NVIDIA. Each block of 16 weights shares one 8-bit scale, so it averages 4.5 bpw. Some models are trained directly in this format. Inkling 2 Mini was trained natively in NVFP4, with its last 4 layers in MXFP8, an 8-bit format.

NVFP4 needs runtime support. Mainline llama.cpp gave wrong output on the Inkling quants when checked; the Unsloth build was required. See the [worked example](worked-example-m1-max-32gb.md#why-that-build).

### Projector (mmproj)

A **projector** is an extra file that lets a text model read images. It turns an image into numbers the model understands. In GGUF repositories it is usually named `mmproj-….gguf`. You need it only for image input, and it uses extra memory.

## Memory

### GB, GiB and MiB

These units measure memory and file size, and tools mix them:

- **GB** (gigabyte) = 1,000,000,000 bytes. File sizes on Hugging Face use GB.
- **GiB** (gibibyte) = 1,073,741,824 bytes, about 7% more than 1 GB. macOS and memory tools often use GiB.
- **MiB** (mebibyte) = 1/1,024 GiB. llama.cpp logs use MiB.

*Example:* the GPU budget on the tested Mac was 25,558 MiB. That is 25.0 GiB, or about 26.8 GB. A 17.63 GB file is about 16.4 GiB.

### Context window

The **context window** is the maximum number of tokens the model can see at once: your prompt, the chat history and the answer together. A model card states the maximum. You choose the size you use at launch, and a bigger window needs more memory.

*Example:* Inkling 2 Mini supports up to 1M tokens. On a 32 GB Mac, the tested launch used `-c 131072`, which is 128K tokens.

### KV cache

When the model reads tokens, it saves some numbers for each token so it does not compute them again. These are the **keys** and **values** of attention, so this memory is called the **KV cache**. It grows with the context window.

> KV cache bytes ≈ 2 × layers with KV × KV heads × head size × bytes per value × context tokens

The first 2 counts keys and values. **KV heads** and **head size** describe how wide each attention layer's saved data is; the model card or the server log lists them. You do not need to compute this by hand: start the server and read the KV size in its log.

*Example:* LFM2.5-24B-A2B has 10 attention layers with 8 KV heads of size 64. At 128K tokens and 2 bytes per value (f16): 2 × 10 × 8 × 64 × 2 × 131,072 ≈ 2.7 GB, which is 2.5 GiB. Its other 30 layers keep no KV cache, so the cache is small.

### f16 and q8_0 KV

**f16** means a number stored in 16 bits. By default, llama.cpp stores the KV cache in f16. **q8_0** stores it in 8 bits with a scale per block, so the cache becomes about half the size. Set it with `-ctk q8_0 -ctv q8_0`. This is a small quality trade; test it on your tasks.

*Example:* for Inkling 2 Mini at 128K, the KV cache went from 4,296 MiB (f16) to 2,282 MiB (q8_0). This change made the launch fit.

### Unified memory

On Apple silicon, the CPU and GPU share one pool of memory. This is **unified memory**. A 32 GB Mac does not have separate graphics memory; the model and macOS share the same 32 GB.

On a PC with an NVIDIA or AMD card, the GPU has its own **VRAM**. A model is fastest when it fits fully in VRAM.

### Metal memory budget

**Metal** is Apple's GPU interface. macOS limits how much unified memory the GPU may use. This limit is the **Metal memory budget**, also called the recommended working set. llama.cpp prints it as `recommendedMaxWorkingSetSize` when it starts.

*Example:* on the 32 GB M1 Max, the budget was 25.0 GiB (25,558 MiB). The model weights, KV cache and compute buffers must all fit inside it. The full 32 GB is not available to the GPU.

### Compute buffer

The **compute buffer** is scratch memory for the math of one step. Its size depends on the model and on the ubatch size. llama.cpp prints it at startup.

### Batch and ubatch (`-b`, `-ub`)

During prefill, llama.cpp processes the prompt in chunks. The **batch** (`-b`, default 2048) is the largest chunk it accepts at once. The **ubatch** or micro-batch (`-ub`, default 512) is the chunk the GPU really computes in one pass. A bigger ubatch usually gives faster prefill but needs a bigger compute buffer.

*Example:* for Inkling 2 Mini at 128K, `-ub 512` needed a 6,118 MiB compute buffer and `-ub 256` needed 4,712 MiB. MLX has a similar setting called `--prefill-step-size` (default 2048).

### Slots and parallel requests (`-np`)

A **slot** serves one request at a time. `-np 1` means one slot. More slots let several users share the server, but each slot needs its own share of context memory.

### OOM

**OOM** means **out of memory**. The program asked for more memory than it may use, so it stopped. On a Mac, this often happens at "warmup", when the server runs its first test pass. Look for messages such as `failed to allocate` or `Insufficient Memory` in the log.

*Example:* the default Inkling 2 Mini launch at 128K needed 26,786 MiB, above the 25,558 MiB budget, so it hit OOM at warmup.

### Swap

When memory is full, macOS moves some data to disk. This is **swap**. A small, flat swap is fine. Swap that keeps growing while the model runs makes everything slow.

## Speed

### Prefill vs decode

Generation has two phases:

1. **Prefill** (prompt processing): the model reads your whole prompt and fills the KV cache. It can process many tokens in parallel, so it is fast per token. Its speed is limited mostly by GPU **compute**.
2. **Decode** (generation): the model writes the answer one token at a time. For each token it must read the active weights from memory. Its speed is limited mostly by **memory bandwidth**.

```mermaid
sequenceDiagram
    participant You
    participant Model
    You->>Model: prompt, 3,300 tokens
    Note over Model: Prefill: read all prompt tokens<br/>in parallel, fill the KV cache
    Model-->>You: first answer token
    Note over You,Model: time to first token
    loop Decode, one token per step
        Model-->>You: next token
    end
```

### Tokens per second (tok/s)

**Tokens per second** measures speed. Always say which phase you measured.

- **Decode tok/s** is how fast the answer appears. About 10 tok/s is near reading speed; 20 tok/s feels smooth.
- **Prefill tok/s** is how fast the model reads input. It matters when you paste long documents.

*Example:* Inkling 2 Mini on the M1 Max: 20.5 tok/s decode, 202.6 tok/s prefill on a 3.3K-token prompt.

### Time to first token (TTFT)

**TTFT** is the wait between sending a request and seeing the first answer token. For a long prompt, prefill makes up most of it.

> TTFT ≈ prompt tokens ÷ prefill tok/s

*Example:* a 25,500-token prompt at 146.5 tok/s prefill waits about 174 seconds before the first token.

### Bandwidth ceiling

The **bandwidth ceiling** is the best possible decode speed: memory bandwidth ÷ bytes read per token. Real speed is always lower. Use it to see whether a setting can still help.

*Example:* the M1 Max measured 353 GB/s. Dense Qwen3.8-27B reads about 16.5 GB per token, so its ceiling is about 21 tok/s. It reached 11.9 tok/s without speculation, 57% of the ceiling.

### Compute (TFLOPS)

**Compute** is how much math the GPU can do. It is measured in **TFLOPS**: trillions of math operations per second. Prefill speed depends mostly on compute, and more GPU cores give more compute.

*Example:* the 32-core M1 Max measured 9.5 TFLOPS. A 24-core M1 Max has less compute, so its prefill was slower (412 against 524 tok/s on a long prompt), but its decode was almost the same.

### Kernel

A **kernel** is a small program that runs on the GPU and does one kind of math, such as multiplying the weights by the input. An engine has many kernels. Some are well tuned for a model or a chip; others are slow. Kernels written for a new chip can fail on an older one.

*Example:* Inkling 2 Mini decoded at only 25% of its bandwidth ceiling, because the Metal kernels for its looped MoE layers were not efficient. No launch setting could fix that; only better kernels can.

## Speculative decoding

### How speculative decoding works

Decode is slow because the big model makes one token per step. **Speculative decoding** lets a small, fast helper guess the next few tokens. The big model then checks all the guesses in one step and keeps the correct ones. The final text is the same as without speculation; only the speed changes.

```mermaid
flowchart LR
    A["Small drafter guesses<br/>3 tokens"] --> B["Big model checks all 3<br/>in one verify step"]
    B --> C{"Which guesses<br/>are correct?"}
    C -->|"first 2 correct"| D["Keep 2 tokens, plus<br/>1 token from the big model"]
    C -->|"none correct"| E["Keep 1 token from<br/>the big model"]
    D --> A
    E --> A
```

It helps only when checking several drafted tokens in one verify step costs much less than making them one by one. See [why DSpark was slower](worked-example-m1-max-32gb.md#why-dspark-was-slower).

### Draft model

A **draft model** (drafter) is the small model that makes the guesses. It must use the same tokenizer as the main model.

*Example:* no drafter exists for LFM2.5-24B-A2B: the small LFM2.5 models know 65,536 different tokens (their **vocabulary**), and this model knows 128,000. A drafter must use exactly the same tokens.

### MTP (multi-token prediction)

**MTP** is a drafter built into the model itself: an extra layer trained to predict tokens further ahead. No separate file is needed.

*Example:* Qwen3.8-27B has one MTP layer. With `--spec-type draft-mtp --spec-draft-n-max 3`, decode rose from 11.9 to about 15 tok/s.

### DSpark

**DSpark** is a speculative decoding method that drafts several tokens at once and verifies them by confidence. Inkling 2 Mini ships a DSpark drafter, and the DeepSeek V4.1 Flash card also lists it.

*Example:* on the M1 Max, DSpark made Inkling 2 Mini slower: 15–17 tok/s against 20.5 without it.

### DFlash2

**DFlash2** is a drafter from z-lab that guesses a whole block of tokens in one pass (a method called block diffusion). When checked, the only DFlash2 model file was for Qwen3.8-27B, and it ran in an MLX-VLM fork.

*Example:* with block size 3, DFlash2 reached 24.3 tok/s on short prompts. With 4 or more tokens per block it fell to 2.7–6.5 tok/s on the M1.

### Acceptance rate

The **acceptance rate** is the share of drafted tokens that the big model keeps. Higher is better, but it is not enough on its own: the verify step must also be cheap.

*Example:* Qwen MTP accepted 63% of drafts with 1 draft and about 40% with 3. Three drafts were still fastest, because they gave about 2.2 tokens per step.

## Engines and servers

### Engine (runtime)

An **engine** is the program that loads the model file and runs it. The engine must support both the model's architecture and its file format.

### Hugging Face

[Hugging Face](https://huggingface.co) is a website that stores model files. A name such as `unsloth/Inkling-2-Mini-GGUF` is one repository there: `unsloth` is the owner and `Inkling-2-Mini-GGUF` is the folder. Each file page shows the file's size and its [sha256 checksum](#revision-and-checksum-sha256). The `hf` command downloads files from it.

### Build, mainline and fork

These words come from software projects on GitHub:

- A **build** is one ready-to-run version of a program, usually named by a number, such as llama.cpp `b12588`.
- **Mainline** (or upstream) is the official version of a project, for example llama.cpp from ggml-org.
- A **fork** is a copy of a project that another team changes. Unsloth's llama.cpp and the Neywa-Labs mlx-vlm are forks.
- A **pull request** (PR) is a proposed change to a project. Until it is **merged** (accepted), the official version does not have the change.

*Example:* the fix for Inkling 2 Mini was in a llama.cpp pull request that was not merged yet, so mainline llama.cpp gave wrong output. Unsloth's fork already had the fix.

### llama.cpp

**llama.cpp** is an open-source engine for GGUF files. It runs on Apple Metal, NVIDIA CUDA, AMD, Vulkan and plain CPU. Its `llama-server` program serves a web chat page and an API. Many desktop apps use it inside. Builds are named by number, such as `b12588`.

### mlx-lm

**mlx-lm** is Apple's engine for text models in MLX format. `mlx_lm.server` serves an API. It runs only on Apple silicon.

### MTPLX

**MTPLX** is an engine for Apple silicon, built on MLX. It uses a model's built-in [MTP](#mtp-multi-token-prediction) head for speculative decoding, and serves an OpenAI-compatible API with `mtplx serve`.

*Example:* on the M1 Max, MTPLX v2.13.1 with MTP decoded Qwen3.8-27B at about 30 tok/s up to 8K tokens, but it failed at 50K. See the [worked example](worked-example-m1-max-32gb.md#newer-result-mtplx-with-mtp).

### Unsloth Desktop

**Unsloth Desktop** is a free, open-source app from Unsloth for macOS, Windows and Linux. It downloads models, runs them with a built-in engine and shows a chat window, so you do not need the terminal. It can also share the model on your home network with [LAN access](#lan-access).

*Example:* [Step 3a](3a-unsloth-desktop.md) runs Inkling 2 Mini `UD-Q4_K_XL` in the app.

### LAN access

A **LAN** (local area network) is the network in your home or office: the devices on the same Wi-Fi or wired router. **LAN access** lets those devices use a server on your computer. Nothing goes to the internet, but anyone on the same network can reach the server, so protect it with a password.

*Example:* in Unsloth Desktop, Settings → Remote & LAN → **Start** shows an address such as `http://192.168.1.42:8888`. Other devices open it and sign in as `unsloth`. See [Step 3a](3a-unsloth-desktop.md#4-optional-share-it-on-your-home-network).

### mlx-vlm

**mlx-vlm** runs vision-language models (text plus images) in MLX format. The worked examples used a community fork, [Neywa-Labs/mlx-vlm](https://github.com/Neywa-Labs/mlx-vlm), for Inkling 2 Mini, Qwen3.8-27B and DFlash2.

### OpenAI-compatible server

An **OpenAI-compatible server** accepts the same HTTP requests as the OpenAI API. Any tool that can talk to OpenAI can talk to it: change the base URL to your local server. The usual endpoints are `/v1/models` (list models) and `/v1/chat/completions` (send a chat). Both `llama-server` and `mlx_lm.server` provide them.

```mermaid
flowchart LR
    A["Your app, script<br/>or chat client"] -->|"POST /v1/chat/completions"| B["Local server<br/>127.0.0.1:8080"]
    B --> C["Engine<br/>llama.cpp or MLX"]
    C --> D["Model file<br/>GGUF or MLX"]
```

## Quality

### KL divergence (KLD)

**KL divergence** measures how different two sets of predictions are. For quants, it compares the quant's next-token probabilities with those of a high-precision reference. 0 means identical. Smaller is better. Quant makers often report it with the **top-token match**: how often both pick the same most likely token.

*Example:* Unsloth reports a mean KLD of 0.0107 and a 98.0% top-token match for Inkling 2 Mini `UD-Q4_K_XL` against its 8-bit reference (source-reported).

### Needle recall

A **needle test** hides a fact, such as a 5-digit code, in a long document and asks the model to find it. It checks that the model can use a long context. Passing one needle test does not prove quality across the whole window.

*Example:* Inkling 2 Mini recalled the code `58213` from a 91,890-token prompt.

### Sampling settings

**Sampling** decides how the model picks each token from its predictions. **Temperature** controls randomness: 0 always picks the most likely token; 1.0 follows the model's probabilities. **top-p**, **top-k** and **min-p** remove unlikely tokens. **Repetition penalty** makes the model less likely to repeat the same words. Use the values from the model card, and keep them fixed when you compare.

## Testing and sharing results

### Control run

A **control run** is a benchmark of your current, unchanged setup. You run it before and after you test a change (the **candidate**). If the candidate is not better than both controls, the change did not help. Controls also show whether the computer itself got slower during the test.

*Example:* in the Qwen tests, the control runs got about 9% slower over 70 minutes, with no change to the setup. Without controls, that drift could look like a bad setting. See [Step 4](4-measure.md#compare-two-setups-fairly).

### Plateau

A setup is at a **plateau** when no change you try makes it measurably better. This is a good place to stop tuning.

### Revision and checksum (sha256)

A **revision** is one exact version of a model repository, named by a commit hash such as `ae9327c5…`. The same file name can change between revisions. A **checksum** is a short fingerprint of a file. **sha256** is a common checksum. If your file's sha256 matches the one on Hugging Face, you have exactly the same file, complete and unchanged.

*Example:* `shasum -a 256 model.gguf` prints the checksum on a Mac.

### Registry, recipe and lab gates

The [Local AI registry](https://github.com/sybil-solutions/local-ai-registry) is a public list of tested setups. A **recipe** is one setup in it: a model, a file, an engine build, a launch command and a computer. Before a recipe is accepted, a test program checks it with six pass-or-fail tests called **lab gates**: it loads, it chats, it reasons, it calls a tool, it recalls a fact from a long prompt, and it reaches a minimum speed. The speed test is the **speed gate**.

*Example:* the Inkling 2 Mini recipe in [sybil-solutions/local-ai-registry PR #466](https://github.com/sybil-solutions/local-ai-registry/pull/466) passed all six gates at 20.1 tok/s.
