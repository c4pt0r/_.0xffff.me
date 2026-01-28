Ed Huang | CTO/Co-founder, PingCAP TiDB | h@pingcap.com

---

## What We Talk About When We Talk About Agent Infra

Agent infrastructure is, without question, one of the hottest areas for VC investment right now. I'm personally placing bets here as well—but unlike most VCs, I approach this space as an infrastructure user and builder. From that perspective, I want to examine a simple but often overlooked question: When we talk about *Agent Infra*, what are we actually talking about?

---

## What This Is *Not* About

First, let's draw a clear boundary. This article is not about generalized AI infrastructure—whether that's pre-training, post-training RL, or inference infrastructure. None of that is in scope here, and frankly, it doesn't interest me much.

Most of those systems primarily serve training workflows, regardless of whether it's pre-training or RL. Model training is largely a one-off or per-generation activity, which means many of the surrounding scaffolding systems are inherently disposable.

Inference infrastructure, on the other hand, has become highly commoditized; there simply isn't much room left to innovate at the product level.

What *does* interest me is what happens above inference infrastructure. As Agents begin to take over more and more work, I believe a brand-new layer of infrastructure will emerge at the Agent level—*above* inference—as a runtime layer designed specifically to support Agent execution and collaboration.

---

## The Default Agent Architecture Today

Let's first align on the commonly accepted Agent architecture most people implicitly assume today. A typical Agent system consists of the following components:

* **LLM / Reasoning Core**  
  Responsible for understanding context, generating plans, and deciding the next action.

* **Planner / Executor**  
  Breaks down complex goals into steps and executes them incrementally.

* **Tools / Skills**  
  Encapsulated external capabilities, such as calling APIs, executing code, accessing databases, or browsing the web.

* **Memory / Context Store**  
  Stores intermediate state, historical actions, long-term preferences, etc.

* **Environment (often implicit)**  
  The real or virtual world in which actions are executed.

These components operate inside a continuous loop—the *Agentic Loop*—which is effectively the architecture used by almost all Agents today.

---

## Problems With the Current Architecture

### 1. Sequential Execution Is a Natural Bottleneck

I've written about this before. Even if planning is perfect, most Agents still execute tasks like this:

> One step → wait for the result → next step

This is a deeply sequential execution model. Even when sub-agents are used, task distribution happens at very small scales.

The downsides are obvious:

* Strong dependencies between actions make parallelism nearly impossible
* A single failure blocks the entire execution path
* Extremely inefficient for exploratory tasks

I have a strong intuition that exploration—at scale—is essential for truly complex tasks. For example, in my work optimizing Coding Agent workflows, my goal is to let Agents operate autonomously for as long as possible *without* human intervention. But autonomy without direction is meaningless, so the key is enabling Agents to continuously explore alternatives, summarize outcomes, and iteratively improve.

If exploration itself is inefficient, overall throughput and quality collapse.

---

### 2. The Limits of Agent-to-Agent Collaboration

We've seen many attempts at Agent collaboration: communication protocols, coordination frameworks, multi-agent systems. MCP and A2A are notable examples—but none have truly succeeded.

Today's Agent collaboration feels more like "Agents that can barely talk to each other," which is still far from what I would call real collaboration.

Yes, people are actively pushing A2A-style approaches, and the *ideas* are sound. Agents should be able to delegate tasks, report progress, and collaborate dynamically.

The problem is that protocols alone are insufficient.

A2A tells you *what should happen*, but not *how to build a usable system that actually makes it happen*. There is still a critical missing layer—and, as of now, no truly usable platform.

---

### 3. Environmental Degradation in Long-Running Tasks

There is another issue that I consider critically important—and deeply underestimated.

If your system cannot provide atomic, side-effect-free actions, then during complex task execution, the environment will inevitably degrade over time.

This isn't obvious in demos. But in any long-chain, multi-step, exploratory workflow, it is almost guaranteed.

Most real-world actions have strong side effects. The moment the first action runs, the environment is already "polluted." As actions accumulate, states stack, errors compound, and failed paths intertwine with successful ones. Eventually, the Agent no longer knows what state the environment is actually in.

At that point, no matter how smart the planner or how strong the reasoning, the Agent is making decisions inside a decaying environment.

This problem is painfully obvious with Coding Agents. Put them into a large, real-world codebase, and the same pattern emerges quickly: the workspace becomes a mess. Random Markdown files appear, logging styles diverge, temporary code is left behind, and multiple sub-agents overwrite each other's changes in the same working directory.

This is a textbook case of environment degradation.

---

### Git Worktree: A Partial, Local Solution

Engineers have already found a crude but effective workaround: Git worktrees.

Each sub-agent gets its own isolated worktree, completes its task in a minimal environment, and only returns results via diffs or pull requests.

At its core, this is a low-cost way to provide isolated, disposable execution environments. It's close to the right answer—but it doesn't scale, and it doesn't generalize.

---

### 4. The "Last Mile" to the Physical World

On the surface, Agents look powerful today. But the moment you ask them to do something without a clean API—something that actually affects the real world—the experience becomes fragile.

Try asking an Agent to place an order, make a payment, or book a hotel.

Skills are a great abstraction—I like them a lot. In purely software contexts, they work well. But once the task crosses into the physical world, the abstraction breaks down.

The real world is full of implicit state: login sessions, permissions, risk controls, UI changes, transient validations, retries. Humans intuitively understand these, but they are rarely encapsulated into clean execution models.

As a result, every step an Agent takes leaves residue in the environment—and that residue feeds back into future planning.

I suspect that Skills will soon expand beyond software into things like "grocery shopping Skill" or "coffee buying Skill." Only then can products like Claude Cowork reach their full potential.

---

## A Possible Direction: Skill + Environment = Box

Many of these problems feel strangely familiar.

Over the past decade, DevOps and cloud computing faced remarkably similar challenges while transitioning from single-node systems to large-scale distributed architectures.

Early systems were unstable, hard to debug, and impossible to reproduce. On a single machine, issues were manageable. At 1,000 machines, state explosion became fatal.

At first, we blamed people: poor process, careless operations, incomplete documentation. Eventually, we realized the real issue wasn't human error—it was the lack of a stable execution foundation.

Containers, immutable infrastructure, Infrastructure as Code, and declarative configuration didn't make software smarter—but they made environments controllable. Failures became reproducible. Deployments became repeatable and idempotent.

When I look at Agent Infra today, it feels like we're at the same inflection point.

Agents don't lack intelligence. They're forced to operate in unstable, unpredictable environments.

---

### Introducing "Box"

My first recommendation is simple: **Bind Skills to their execution environments.**

Introduce a new abstraction—let's call it a *Box*.

A Box:

* Exposes no execution details
* Has no external dependencies
* Has no side effects
* Encapsulates *Skill-guided Actions + a reproducible, disposable environment*

Boxes solve execution quality within a single environment. Because they are Skill-defined, they can be composed and inherited.

For example, "Buy me a coffee" can be decomposed into atomic Skills:

1. Launch browser → Box1
2. Log into my account → Box2
3. Place coffee order → Box3

These compose into a "Buy Coffee" Box. The first two Boxes can even be cached.

Claude only needs to write:

```python
box3 = box1 + box2
box3.spawn().buy_coffee('latte')
```

Once the coffee is purchased, the Box is destroyed—no pollution of the local environment.

Unlike Docker, a Box environment is pure, lightweight, and fully semantic. No technical details leak upward.

---

## From Coding to the Physical World

This approach addresses the "last mile" problem for Coding Agents—and more. It bridges the gap between code and real-world impact.

For actions like "buy a coffee" or "find and book the cheapest hotel," waiting for APIs is unrealistic.

Box is an attempt to *code the physical world*.

Once we have enough Box functions, programming the physical world becomes exactly what Agents are best at.

Some frontier startups are already exploring similar ideas, such as:

* [https://github.com/boxlite-ai/boxlite](https://github.com/boxlite-ai/boxlite)
* [https://github.com/vm0-ai/vm0](https://github.com/vm0-ai/vm0)

---

## Agents' "Kubernetes"?

If every action runs inside a reproducible, disposable Box, the next question is inevitable:

Who creates them? Who schedules them? Who monitors them? Who decides whether to retry, abandon, or fork execution paths?

Once again, the answer comes from cloud infrastructure. Kubernetes became the standard for container orchestration. So what does *Kubernetes for Agents* look like?

I believe it is a model-independent infrastructure layer, consisting of:

**1. Context Manager**

Built on distributed databases and distributed file systems. Databases manage structured shared context (e.g., conversation history) for prompt construction. File systems provide a co-working space alongside local Agent workspaces.

**2. Branching as a First-Class Capability**

This is not Git branching or worktrees. It is a system-level mechanism for representing alternative execution paths. Multiple Agents—or the same Agent—can explore different branches simultaneously, sharing goals but not side effects.

Metadata is managed by databases; branching file systems provide the foundation.

**3. In-Network Messaging / Communication Hub**

Embedded into every Box runtime:

```python
box1.send_message(box2, 'hello')
box1.publish_event('buy_coffee_success')
box2.on_event('buy_coffee_success', on_success)
```

**4. Scheduler + Lifecycle Manager**

Handles placement, concurrency, retries, timeouts, cancellation, and failure policies.

In container land, Kubernetes does this daily. In Agent systems, most teams still hardcode this logic into frameworks—reinventing wheels with wildly inconsistent reliability.

**5. Box Runtime**

As described above.

---

## Closing Thoughts

At this point, I don't think it's necessary to keep emphasizing how much smarter models will become.

What determines whether Agents can handle complex tasks is not intelligence alone—but whether execution is controllable, failure is cheap, environments are replaceable, and collaboration is infrastructure-backed.

The challenges of Agent Infra are not new. We've encountered them before—in other domains—and partially solved them.

What's left is to reorganize those lessons and apply them to this new runtime layer: the Agent runtime.
