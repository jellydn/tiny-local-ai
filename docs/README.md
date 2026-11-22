# Learn to run local AI models

This is a learning base for people who start from zero. It teaches you how to run an AI model on your own computer, step by step. Every page explains its terms in plain words.

Read it on the [website](https://jellydn.github.io/tiny-local-ai/) or here on GitHub.

**Sources checked: 22 November 2026.** Models and tools change quickly. Check the linked sources before you download large files.

## Who this is for

You can use a terminal and copy commands. You do not need to know how AI models work. If a word is new, look it up in the [glossary](glossary.md).

## The learning path

Follow the five steps in order. Each step answers one question.

```mermaid
flowchart LR
    A["1. Understand<br/>What happens when<br/>a model runs?"] --> B["2. Plan<br/>Which model and file<br/>fit my computer?"]
    B --> C["3. Do<br/>Install, download,<br/>launch, test"]
    C --> D["4. Measure<br/>How fast? How good?<br/>How much memory?"]
    D --> E["5. Optimise<br/>Change one setting,<br/>measure again"]
    E -.->|"next idea"| D
```

| Step | Page | You will learn |
| --- | --- | --- |
| 1 | [Understand](1-understand.md) | Weights, tokens, memory, and the two phases of generation |
| 2 | [Plan](2-plan.md) | How to pick a model and a quant that fit your memory |
| 3 | [Do](3-do.md) | How to install an engine, download a model, start a server and test it |
| 4 | [Measure](4-measure.md) | How to measure speed, memory and answer quality fairly |
| 5 | [Optimise](5-optimise.md) | Which settings help, which do not, and why |

## Reference pages

- [Glossary](glossary.md): every term, with a simple explanation and an example.
- [Worked example: three models on an M1 Max 32 GB](worked-example-m1-max-32gb.md): real results and the lessons from them.
- [FAQ and troubleshooting](faq.md): common questions and fixes for common errors.

## How to read the numbers

This learning base uses three labels:

- **Measured:** someone ran it and recorded the result. The source is linked.
- **Source-reported:** a model card or tool documentation states it.
- **Estimated:** a calculation or rule of thumb. Use it to plan, then measure.

The M1 Max results come from the author's [Discussions #3](https://github.com/jellydn/tiny-local-ai/discussions/3), [#4](https://github.com/jellydn/tiny-local-ai/discussions/4) and [#5](https://github.com/jellydn/tiny-local-ai/discussions/5), and from [sybil-solutions/local-ai-registry PR #466](https://github.com/sybil-solutions/local-ai-registry/pull/466), [PR #470](https://github.com/sybil-solutions/local-ai-registry/pull/470) and [PR #475](https://github.com/sybil-solutions/local-ai-registry/pull/475). They were not rerun for this learning base. Your computer will give different numbers.

## Scope

These pages cover **local inference**: running an existing model on your computer. Fine-tuning and training from scratch are different tasks. The [main handbook](https://github.com/jellydn/tiny-local-ai#readme) introduces them.
