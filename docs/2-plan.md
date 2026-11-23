# Step 2: Plan

This page helps you choose a model and a quant that fit your computer before you download anything. Large files take a long time to download, so plan first.

[Back to the learning base](README.md) · Previous: [Step 1: Understand](1-understand.md) · Next: [Step 3a: No-terminal start](3a-unsloth-desktop.md)

## 1. Find your memory budget

| Computer | Your budget |
| --- | --- |
| Apple silicon Mac (units: [GB, GiB and MiB](glossary.md#gb-gib-and-mib)) | The [Metal memory budget](glossary.md#metal-memory-budget), not the full RAM. On the tested 32 GB M1 Max it was 25.0 GiB (measured). You see your exact number in Step 3b, when llama.cpp starts: it prints `recommendedMaxWorkingSetSize`. |
| PC with an NVIDIA or AMD GPU | The GPU card's own memory ([VRAM](glossary.md#unified-memory)), for full speed. Layers that do not fit run on the CPU and are much slower. |
| CPU only | System RAM minus the operating system and apps. Expect slow decode. |

Also count the apps you keep open. In the worked example, other desktop apps used about 14 GiB of the 32 GB the whole time.

## 2. Use the memory rule of thumb

Add the three GPU parts from [Step 1](1-understand.md#where-the-memory-goes):

> total ≈ weights + KV cache + compute buffers, and this total must fit inside your budget

Then estimate each part:

| Part | Estimate (all estimated, then check the server log) |
| --- | --- |
| Weights | Model file size. Or: parameters in billions × bits per weight ÷ 8 = GB. |
| KV cache | Depends on the model. Use the [formula](glossary.md#kv-cache), or start with a short context and read the log. Models with few [attention](glossary.md#attention) layers have small caches. |
| Compute buffers | Usually 0.5–1 GB. Some models need much more: Inkling 2 Mini needed 4.7 GB at `-ub 256`. |
| Safety margin | Keep at least 1–2 GB free inside the budget. |

**Quick rule for a first try (estimated):** pick a model file no larger than about **60% of your RAM** on a Mac, or about **80% of VRAM** on a GPU, and start with a short context, such as 4K–8K tokens. Increase the context only after it runs.

*Worked check for a 32 GB Mac:* a 17.6 GB file is 55% of 32 GB. The budget is 25.0 GiB, about 26.8 GB (see [GB, GiB and MiB](glossary.md#gb-gib-and-mib)). That leaves about 9 GB for the KV cache and compute buffers. Inkling 2 Mini at 128K needed about 7.3 GB for those with q8_0 KV, so it fit with a small margin. With the default 16-bit ([f16](glossary.md#f16-and-q8_0-kv)) KV cache it did not fit.

## 3. Choose a model

Answer these questions in order.

```mermaid
flowchart TB
    A["How much memory budget do you have?"] --> B{"Does a 4-bit file of the model<br/>fit with room for context?"}
    B -->|"no"| C["Pick a smaller model,<br/>or an MoE with fewer total parameters"]
    B -->|"yes"| D{"Does your engine support<br/>this architecture and format?"}
    D -->|"no"| E["Wait for support,<br/>or use the build the model card names"]
    D -->|"yes"| F{"What matters most?"}
    F -->|"fast answers"| G["Prefer few active parameters (MoE)"]
    F -->|"long documents"| H["Prefer small KV cache and fast prefill"]
    F -->|"best quality per GB"| I["Compare quality on your own tasks"]
```

### Which model for your memory size

Use this table to find a starting point. It applies the quick rule above: a file no larger than about 80% of a GPU card's VRAM, or about 60% of a Mac's RAM.

*All sizes in the first three columns are estimated. Inkling 2 Mini file sizes are source-reported by [Unsloth](https://unsloth.ai/docs/models/inkling-2-mini), checked 23 November 2026.*

| Memory | Largest file to try first: GPU / Mac | Model size at about 4 bits: GPU / Mac | Inkling 2 Mini quant that fits | Context to start with |
| --- | --- | --- | --- | --- |
| 8 GB | 6.4 GB / 4.8 GB | about 10B / 8B | None. The smallest file, `UD-IQ1_S`, is 7.76 GB. | 4K–8K |
| 12 GB | 9.6 GB / 7.2 GB | about 15B / 12B | GPU: `UD-IQ2_XXS` (8.49 GB), with clear quality loss. Mac: none. | 8K |
| 16 GB | 12.8 GB / 9.6 GB | about 20B / 15B | GPU: `UD-IQ3_XXS` (11.66 GB). Mac: `UD-IQ2_XXS` (8.49 GB). | 8K–16K |
| 24 GB | 19.2 GB / 14.4 GB | about 30B / 23B | GPU: `UD-Q4_K_XL` (17.63 GB). Mac: `UD-Q3_K_XL` (13.63 GB). | 16K–32K |
| 32 GB | 25.6 GB / 19.2 GB | about 40B / 30B | `UD-Q4_K_XL` (17.63 GB). **Tested** on a 32 GB Mac up to 128K, with `-ub 256` and q8_0 KV. | 32K, then up to 128K |
| 64 GB or more | 51 GB / 38 GB | larger models | `UD-Q8_K_XL` (22.87 GB), Unsloth's reference quant. | 128K |

How to read it:

- **Model size at about 4 bits** uses: parameters in billions ≈ file size in GB × 1.6. This assumes about 5 bits per weight, like the Unsloth `UD-Q4_K_XL` files (see [bits per weight](glossary.md#bits-per-weight-bpw)). It is the **total** parameters, also for MoE models.
- **Smaller quants lose quality.** For Inkling 2 Mini, Unsloth reports that the most likely next token matches its reference 98.0% of the time for `UD-Q4_K_XL`, 96.3% for `UD-Q3_K_XL` and 90.6% for `UD-IQ2_XXS` (source-reported). Below 4 bits, test the answers on your own tasks in [Step 4](4-measure.md).
- **MoE models on a GPU PC can use system RAM too.** The engine can keep some expert weights in normal RAM and the rest in VRAM. It is slower than all in VRAM, but can still be usable, because each token uses only a few experts. The [GPU Partner guide](https://www.gpupartner.com/blog/beginners-guide-local-ai-inkling-qwen-unsloth) lists Inkling 2 Mini at 4 bits on a 16 GB card this way. This was not tested for this site.
- **Inkling 2 Small does not fit any row.** It has 594B parameters, and its smallest file is 171.7 GB ([source-reported](https://unsloth.ai/docs/models/inkling-2-small)). It needs a computer with about 256 GB of unified memory, not a graphics card.

The other two models in the [worked example](worked-example-m1-max-32gb.md) also fit the 32 GB row: Qwen3.8-27B `UD-Q4_K_XL` (17.7 GB) and LFM2.5-24B-A2B MLX 6-bit (19.5 GB), both at 128K.

The table idea comes from the GPU Partner guide, which lists more models for each VRAM size. Check the model card and the file sizes before you download any model from that list.

Points to remember:

- **Total parameters decide memory. Active parameters decide decode speed.** See [active parameters](glossary.md#active-parameters).
- **Read the model card.** It states the architecture, the context limit, the recommended sampling and the supported engines.
- **Check the engine first.** A new architecture may need a special build. Do not mix files and builds from different guides.

## 4. Choose a quant

A **quant** is a quantized copy of a model: the same model stored with fewer bits per weight. See [quantization](glossary.md#quantization). The name tells you the bits: Q8 is about 8 bits, Q4 about 4 bits.

### A picture of quantization

Think of a photo. Each pixel stores a shade. With 8 bits, a pixel can have 256 shades, and the photo looks smooth. With 4 bits it has only 16 shades, and with 2 bits only 4. The picture is still there, but detail is lost.

![The same small sunset picture three times. At 8 bits the sky is a smooth gradient. At 4 bits the sky shows visible bands. At 2 bits only four flat colours are left.](images/quantization-photo.svg)

A model's weights are numbers, not shades, but the idea is the same. Fewer bits per weight means fewer possible values for each weight, so each weight is stored a little less exactly. The file gets smaller, and the answers can get a little worse.

Two differences from the photo:

- **Quants are smarter than this picture.** They store a scale for each small block of weights, so the few values fit that block well. Dynamic quants such as [UD-Q4_K_XL](glossary.md#ud-q4_k_xl) also give the most sensitive layers more bits.
- **You cannot see the loss.** You find it with numbers such as [KL divergence](glossary.md#kl-divergence-kld), and by testing answers on your own tasks.

*Picture: drawn for this site.* The photo comparison is a common one; the [GPU Partner guide](https://www.gpupartner.com/blog/beginners-guide-local-ai-inkling-qwen-unsloth) uses it too.

### Quant levels

| Quant level | Typical use (estimated guidance) |
| --- | --- |
| 8-bit (Q8_0, MLX 8-bit) | Close to the original. Use it when it fits with room for context. |
| 5–6-bit (Q5_K_M, Q6_K, MLX 6-bit) | Very close to 8-bit, smaller. |
| **4-bit ([Q4_K_M](glossary.md#q4_k_m), [UD-Q4_K_XL](glossary.md#ud-q4_k_xl), [MLX](glossary.md#mlx-format) 4-bit)** | **The usual starting point.** Good quality, half the size of 8-bit. |
| 3-bit and below | Use only when nothing larger fits. Quality loss becomes easier to notice. |

Prefer a quant with published quality data, such as [KL divergence](glossary.md#kl-divergence-kld) or top-token match. Then test it on your own prompts in [Step 4](4-measure.md).

*Measured example:* on a 32 GB Mac, `UD-Q4_K_XL` (17.63 GB) of Inkling 2 Mini left room for a 128K cache. The 8-bit `UD-Q8_K_XL` (22.9 GB) left no room inside the 25 GiB budget.

## 5. Check that the model is not far too large

Some models have small names but are very large. "Flash" or "Mini" does not mean small. Check the total parameters and the file sizes before you plan.

*Source-reported examples, checked 22 November 2026:*

| Model | Total parameters | Smallest GGUF file on [Hugging Face](glossary.md#hugging-face) | Fits a 32 GB Mac? |
| --- | --- | --- | --- |
| [GLM-5.3-Flash](https://huggingface.co/zai-org/GLM-5.3-Flash) | 320B, 18B active | about 93 GB ([`UD-IQ1_S`](https://huggingface.co/unsloth/GLM-5.3-Flash-GGUF)) | No |
| [DeepSeek V4.1 Flash](https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash) | 552B in the main model; uses 8B per token for prefill and 16B for decode | about 233 GB ([`UD-IQ1_S`](https://huggingface.co/unsloth/DeepSeek-V4.1-Flash-1017-GGUF)) | No |
| Inkling 2 Mini | 26.4B, 3.4B active | `UD-Q4_K_XL` is 17.63 GB | Yes, tested |

`IQ1_S` is an extreme quant of about 1 bit per weight, the smallest that exists for these models. The file sizes are the sum of the files in each Hugging Face folder. GLM-5.3-Flash and DeepSeek V4.1 Flash were not run on the M1 Max. See the [worked example](worked-example-m1-max-32gb.md#models-that-do-not-fit-or-do-not-work-well-on-m1) for why.

## Planning checklist

- [ ] I know my memory budget, and how much my other apps use.
- [ ] The model file is no larger than about 60% of my RAM (Mac) or 80% of the GPU card's memory (VRAM).
- [ ] The model card names an engine and format I can use.
- [ ] I picked a quant with published quality data, or I will test it.
- [ ] I will start with a short context and one request slot.

Next: [Step 3a: No-terminal start](3a-unsloth-desktop.md), or go straight to [Step 3b: Run a model in the terminal](3-run.md)
