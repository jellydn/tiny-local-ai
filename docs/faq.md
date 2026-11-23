# FAQ and troubleshooting

Short answers to common beginner questions, then fixes for common problems. Terms link to the [glossary](glossary.md).

[Back to the learning base](README.md)

## FAQ

### Do I need a GPU?

No, but it helps a lot. A model can run on the CPU only, but decode is slow. An Apple silicon Mac uses its built-in GPU through Metal, Apple's GPU system. A PC with an NVIDIA or AMD card is fast when the model fits in the card's own memory ([VRAM](glossary.md#unified-memory)).

### How much memory do I need?

Plan for the model file plus room for the KV cache, compute buffers and your other apps. A first rule: a model file no larger than about 60% of a Mac's RAM, or 80% of a GPU's VRAM, with a short context. See [Step 2: Plan](2-plan.md#2-use-the-memory-rule-of-thumb).

### Can I start without the terminal?

Yes. Install the free Unsloth Desktop app, pick a model from its list and chat. See [Step 3a: No-terminal start](3a-unsloth-desktop.md). Use the terminal path in [Step 3b](3-run.md) when you need full control over memory settings.

### Which model should I start with?

One that fits easily and is supported by a common engine. On a 32 GB Mac, the [worked example](worked-example-m1-max-32gb.md) shows three models that fit at 128K context. On a smaller machine, pick a smaller model and a 4-bit quant. The [memory size table](2-plan.md#which-model-for-your-memory-size) gives a starting point for each memory size.

### What does "26.4B / 3.4B active" mean?

The model has 26.4 billion parameters in total, and uses 3.4 billion for each token. You need memory for the total; speed depends on the active number. See [active parameters](glossary.md#active-parameters).

### Which quant should I download?

A **quant** is a smaller, [quantized](glossary.md#quantization) copy of a model. Start with a 4-bit quant such as [`Q4_K_M`](glossary.md#q4_k_m) or Unsloth's [`UD-Q4_K_XL`](glossary.md#ud-q4_k_xl). Use a larger one if it fits with room for context. See [Step 2](2-plan.md#4-choose-a-quant).

### GGUF or MLX?

GGUF runs in llama.cpp on almost any hardware. MLX runs only on Apple silicon. On a Mac, try both if the model has both: in the worked example, MLX was faster for some models and prompt lengths, and llama.cpp reached longer context. Use the engine and [build](glossary.md#build-mainline-and-fork) that the model card or the maker of the file (for example Unsloth) names. The [Mac notes](worked-example-m1-max-32gb.md#mac-notes) show where "use MLX on a Mac" did not hold.

### Why is the first answer slow when I paste a long document?

The model must read the whole prompt first. This is [prefill](glossary.md#prefill-vs-decode). A 25,000-token prompt at 150 tok/s prefill takes about 170 seconds before the first word appears.

### Is 20 tok/s good?

For one person chatting, yes. About 10 tok/s is near reading speed. But tok/s does not measure answer quality or how long the answer is. A [thinking model](glossary.md#thinking-model) that reasons for 15,000 tokens is slow to finish even at a good tok/s.

### Does a bigger context window cost anything if I do not use it?

Yes. The engine reserves KV cache memory for the full window at launch. Set `-c` to what you need.

### Is speculative decoding always faster?

No. It made Inkling 2 Mini slower and Qwen3.8-27B faster on the same Mac. See [why DSpark was slower](worked-example-m1-max-32gb.md#why-dspark-was-slower).

### Does local AI work offline?

Yes, after you download the engine and the model. The server runs on your computer. Downloads and any cloud services still need the network.

### Can other computers use my server?

Yes, on a trusted network. Start the server with `--host 0.0.0.0` and use your computer's private IP address. The example server has no password, so never expose its port to the internet. Unsloth Desktop has a built-in [LAN access](glossary.md#lan-access) option with a password; see [Step 3a](3a-unsloth-desktop.md#4-optional-share-it-on-your-home-network).

### Is it safe to raise the Mac GPU memory limit?

You can with `sudo sysctl iogpu.wired_limit_mb=…`, but it leaves less memory for macOS. None of the worked examples needed it. Try smaller settings first.

## Troubleshooting

| Symptom | Likely cause | What to do |
| --- | --- | --- |
| Server stops at load or at "warmup" (its first test pass) with `failed to allocate`, `Insufficient Memory` or similar | [OOM](glossary.md#oom): weights + KV cache + compute buffers exceed the budget | Read the `buffer size` lines. Use `-ctk q8_0 -ctv q8_0`, `-ub 256`, a smaller `-c` or a smaller quant. Close other apps. See [Step 5](5-optimise.md#1-make-it-fit). |
| `unknown model architecture` or another load error | The engine is too old or the wrong build for this model | Use the [build](glossary.md#build-mainline-and-fork) that the model card or the maker of the file (for example Unsloth) names. |
| The model loads but writes gibberish | Engine and file do not match, or a [kernel](glossary.md#kernel) bug | Check the build and the file layout. Inkling 2 Mini needed Unsloth's build. See [why that build](worked-example-m1-max-32gb.md#why-that-build). |
| Out of memory only on long prompts | The KV cache or prefill buffers grow with the prompt | Use q8_0 KV and a smaller `-ub` (llama.cpp) or `--prefill-step-size 256` (MLX). Lower `-c`. |
| Answers stop in the middle | The token limit is too low | Raise `max_tokens` in the request. For `mlx_lm.server`, set `--max-tokens`; the default is 512. |
| Answers are repetitive or strange | Wrong sampling or [chat template](glossary.md#chat-template-and-tool-calls) | Use the model card's sampling. For llama.cpp, add `--jinja`. |
| Decode slows down over a long session | Other apps, swap growth or heat | Close apps, stay on AC power, watch swap in Activity Monitor. Compare with control runs. |
| Very slow decode on a GPU computer | Some layers run on the CPU | Check that all layers are on the GPU (`-ngl 99`) and that the model fits in VRAM. |
| `Thread group size (…) is greater than the maximum allowed` | A custom [kernel](glossary.md#kernel) needs a newer Apple GPU | Update the engine; a newer version may have a fix for older chips. Otherwise use another engine or quant. See [LookAtMyQuant](worked-example-m1-max-32gb.md#lookatmyquant). |
| API request uses the wrong model | The `model` field does not match the server | Call `/v1/models` and copy the exact ID. |
| `curl: (7) Failed to connect` | The server is not ready, or the port is wrong | Check the server log in tmux. Wait for the listening message. Check the port. |
| Another computer cannot connect | Server bound to `127.0.0.1`, or a firewall | Use `--host 0.0.0.0` on a trusted network and allow the port in the firewall. |
| The download finished but the file will not load | Partial or wrong file | Compare the file's [sha256 checksum](glossary.md#revision-and-checksum-sha256) with the value on [Hugging Face](glossary.md#hugging-face). Download again. |

Still stuck? Read the full reports in [Discussions #3](https://github.com/jellydn/tiny-local-ai/discussions/3), [#4](https://github.com/jellydn/tiny-local-ai/discussions/4) and [#5](https://github.com/jellydn/tiny-local-ai/discussions/5), or ask a question there.
