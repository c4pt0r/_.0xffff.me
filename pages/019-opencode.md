Ed Huang | CTO/Co-founder, PingCAP TiDB | h@pingcap.com

---

Over the past couple of days, I’ve been using **opencode + oh-my-opencode** intensively on a real, non-trivial engineering task. As a result, my understanding of agent systems has undergone a very noticeable shift.

The task itself was concrete and unapologetically hard:

> Re-implement a PostgreSQL-protocol-compatible SQL layer on top of TiKV, capable of running basic tests such as dvdrental compatibility tests and TPC-C.

In practice, this is equivalent to rewriting TiDB’s SQL layer.

I know very well how difficult this is. Even getting a minimal TPC-C workload running took us roughly two months—and that was a team effort.

The final result honestly gave me chills.

The project is here: [https://github.com/c4pt0r/tipg](https://github.com/c4pt0r/tipg)
I won’t expand on the details in this post.

What shocked me was not whether it *could* be done, but **how fast** it happened.

In less than a single afternoon, the system burned through a little over millions of tokens. Because I’m using various “Pro Max” agent subscriptions, this didn’t even translate into additional out-of-pocket cost.

That was the moment it truly clicked for me:

**The marginal cost of writing code is now close to zero.**
Even for systems as complex as databases, operating systems, or compilers—which, frankly, are not that complex *from an AI’s perspective*.

This post is about that journey and what it changed in my thinking.

---

## Context Engineering Is Not About Stacking Prompts

Before switching to opencode, I had already been a heavy user of tools like Claude Code, Gemini Pro, and Codex.

Structurally, they are all similar:
*agentic loops + tool use, wrapped in a CLI.*

And to be honest, the underlying model capabilities have largely converged. Everyone is using top-tier models now.

Yet the difference in real-world results is stark.

The reason is not the model.
It is **context engineering**.

There’s a common illusion that “wrappers” are low-tech, that they don’t contain real innovation. My experience is the opposite: this is where the real depth is.

Effective context engineering means continuously, structurally, and stably injecting the following into the system:

* A clear but not over-specified goal (human)
* An explicit plan (agent)
* Engineering boundaries and constraints (human)
* Historical decisions and implicit assumptions (agent)
* Stable intermediate structures that prevent the model from drifting in long contexts (agent)

After switching to opencode + oh-my-opencode, the *model was the same*, but the behavior was entirely different.

Same agentic loop.
Same tool usage.
Yet the delivery quality for complex engineering tasks was on a completely different level.

One design choice in oh-my-opencode that I found particularly elegant is this:

It is not obsessed with “using the strongest single model.”
Instead, it orchestrates **multiple first-tier models within the same workflow**.

This isn’t a novel idea—three cobblers can outdo Zhuge Liang, and here we have three Zhuge Liangs.

The results exceeded my expectations.

The future ceiling is unlikely to come from ever-larger models alone. More likely, it will come from:

**multi-model collaboration (at the top tier) + context engineering + stable loops as a system-level design.**

---

## Non-Interruption Matters More Than “Being Smarter”

Another critical—and often overlooked—factor is the **non-interruptive flow**.

Many agent systems constantly interrupt the process:

*think → execute → error → wait for human confirmation*

Yes, the context technically exists, but the workflow is fractured.

I currently address this using **ralph-loop**, allowing agents to run inside a stable, continuous loop indefinitely (burning tokens), while humans intervene only when truly necessary—usually at final review.

Humans are no longer forced to act as the “next-step commander.”

Once interruptions are reduced, the difference is dramatic:

* The engineering rhythm starts to resemble real, continuous development
* Human cognitive load drops significantly

At this point, AI is already smart enough.
The tools are already good enough.

**The bottleneck is the human.**

---

## The Human Interface Matters Just as Much

Even within a TUI, opencode feels noticeably better than Claude Code. The core reason, in my opinion, is simple:

**Humans need a sense of control.**

A good system ensures the human always understands:

* What the system is doing right now and what's next (thinking state, TODOs)
* Why it is doing it
* When and how intervention is possible

The moment a human is reduced to issuing commands and waiting for results, the experience degrades immediately.

A truly good agent system keeps complexity inside the code and the loop, while returning **decision authority, pacing, and trust** to the human through a carefully designed interface.

---

## The Worst Experience Today: Infrastructure

If I had to name the weakest part of today’s agent experience, it would still be **infrastructure**:

* Sandbox and runtime configuration
* Starting databases and dependent services
* Test environments, fixtures, data preparation
* Consistency between local setups and CI

These tasks are repetitive, context-fragmented, and deeply unfriendly to agents.

Even if the model can “write code” extremely well, once you hit infra friction, momentum grinds to a halt.

The next phase that truly determines the upper bound of the experience will not be opencode itself, but:

**opencode + infrastructure abstraction.**

When sandboxes, databases, tests, and CI/CD become first-class contextual objects—rather than brittle scripts humans have to glue together—agents can finally evolve from “code-writing assistants” into systems that continuously drive engineering forward.

---

## “Opencode for XXX” Is Coming Soon

Programmers are likely among the first groups to viscerally feel the arrival of AGI.

Whether we like it or not, professional code-writing as a job will disappear. But this is not something to panic about. Humans no longer need to hunt for survival, yet we still go to the gym—for enjoyment, challenge, and mental exercise.

“Classical programming” will survive as a craft, a hobby, a thinking game.

That said, based on the recent trajectory of programming agents, I believe:

* Context engineering is transferable
* Model capability is becoming standardized
* More tokens equals more intelligence

In other words, with the same ingredients (LLMs) but different chefs (Claude Code, opencode), you get radically different outcomes—even when your personal “init prompt” (goal) hasn’t changed.

We will soon see systems like **opencode for XXX**, **opencode for YYY**.

The underlying models may be identical, but through different context organization, they will behave like entirely different professional systems.

At that point, the question of whether “general-purpose models are strong enough” will no longer matter.

The real differentiator will be:

**Who understands how to construct a long-running, stable, sustainable context.**

---
