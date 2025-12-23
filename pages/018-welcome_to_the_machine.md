Ed Huang | CTO/Co-founder, PingCAP TiDB | h@pingcap.com

---

Just in time for Christmas—here in the U.S., the holiday atmosphere is already everywhere around me. I happen to have a bit of time these days, so I decided to write down a question I’ve been repeatedly thinking about lately.

The main reason is that I’ve been seeing one trend with increasing clarity:
the primary users of infrastructure software are rapidly shifting from developers (humans) to AI agents.

Take databases as an example. On TiDB Cloud, we have already observed an extremely clear signal: over 90% of newly created TiDB clusters every day are created directly by AI agents. This is not in theory—it is a reality already happening in production environments.

By continuously observing how these agents use databases—how they create resources, how they read and write data, how they experiment and fail—I’ve learned a great deal. The way AI uses systems is very different from how human developers do, and it keeps challenging many of our long-held assumptions about how databases should be used.

Because of this, I’ve started to rethink the problem from a more ontological perspective:
when the core users of foundational software are no longer humans but AI, what essential characteristics should such software have?

What follows are still only partial thoughts and interim conclusions. They may not be fully mature yet, but I believe they are worth recording.

## Mental Models

The first thing to note is this: when the user shifts from humans to AI, what software truly exposes to the user is no longer the UI or the API, but the mental model behind it.

During training, LLMs have already internalized a vast number of implicit assumptions and factual conventions. After being a software engineer for so many years, I increasingly feel that the most fundamental things in the computing world rarely change in essence once they are invented. Especially the closer you get to the lower layers: file systems, operating systems, programming languages, I/O abstractions. Over decades, their forms have evolved, but their core ideas, interface boundaries, and underlying assumptions have remained remarkably stable.

When AI encounters massive amounts of code and engineering practices during training, what it sees is not a colorful, diverse world, but a huge number of repeated patterns: repeated abstractions, repeated wheels, repeated choices, repeated ways of fixing bugs. Once these repetitions reach a sufficient scale, they crystallize into very strong priors (after all, humans themselves are essentially pattern repeaters).

This leads me to the following conclusion:
if you want to design “software for AI agents,” you must align as closely as possible with these old—but repeatedly validated—mental models.

These models are not new. Many have existed for decades: file systems, the Bash script, Python codes, SQL queries. What they have in common is extremely stable underlying mental models combined with very flexible “glue” at the top.

On top of these mental models, humans have built enormous amounts of glue code (I’ve always believed that the real IT world is made of glue). Many systems that look complex, when taken apart, are essentially just compositions and orchestrations around these stable abstractions.

From this perspective, designing software for agents is not about inventing a “brand-new correct interface.” (This is also why I’m pessimistic about new agent frameworks like LangChain—it's so new that even programmers are reluctant to learn it, let alone AI.) Instead, it’s about deliberately conforming to the cognitive structures that have already been trained into the model.

In other words, agents are not waiting for a smarter or more powerful system. They prefer a system they already understand—and then extend it with glue code at an efficiency 1,000× higher than humans.

### A good mental model must be extensible.

File systems are a good example and something I’ve been thinking about a lot recently. Whether it’s Plan 9’s 9P or Linux’s VFS, they both accomplish something extremely important: they allow you to introduce entirely new implementations without breaking the original mental model.

A concrete example is an experimental file system I’ve been hacking on recently: agfs (https://github.com/c4pt0r/agfs). In short, it’s a pluggable file system. You can implement all kinds of strange capabilities as long as you satisfy the file system interface contract.

One example is vectorfs. In vectorfs, files are still files, directories are still directories. echo, cat, ls, cp -r all behave exactly the same. But under this completely unchanged mental model, the implementation quietly does a lot of extra work:

Documents copied into a vectorfs directory are automatically chunked, embedded, and written into vector index.

grep is no longer just string matching; it becomes semantic similarity search.

```
$ cp ./docs/* /vectorfs/docs     # auto index / upload to S3 / chunk
$ grep -r "Does TiDB Support JSON?" /vectorfs/docs  # search over vector index in TiDB
```

Linux VFS follows the same logic. You can implement a user-space file system with entirely different semantics and a completely different backend. As long as it follows POSIX conventions, it can be mounted into the existing system and immediately become part of it. From the upper layers, nothing has changed; from the system’s perspective, it has gained the ability to evolve continuously.

This is especially important in the AI era. AI agents write code thousands of times faster than humans, which means systems evolve thousands of times faster. Without stable constraints, things quickly spiral out of control. But if abstractions are closed, you can’t take advantage of that speed either.

From here, a natural question follows: does software ecosystem still matter?
Syntax, protocols—things that look like old-school dogma in the agent era—are they still worth arguing over?

My answer is: yes, and no.

Let’s start with the “no.”
If your software is built on the right mental model, then in many cases the difference between it and mainstream alternatives is really just syntax. MySQL vs PostgreSQL. MongoDB vs other NoSQL databases. Humans can argue endlessly about these choices, but from an agent’s perspective, they barely matter.

Agents don’t have “preferences.” They don’t care whether syntax is elegant. They don’t care about community culture or ideological purity. As long as the interface is stable, semantics are clear, the ecosystem is complete, and documentation is available online, they can adapt quickly. Preference differences are completely flattened on the agent side.

But that doesn’t mean ecosystem doesn’t matter at all.

It matters not because of syntax, but because popular software usually corresponds to very classic, very stable mental models that are deeply embedded in LLM training data. MySQL and PostgreSQL are both relational databases. Behind both is SQL. And SQL itself is a repeatedly validated, extremely stable abstraction. Knowledge transfers easily between them.

So as long as the overarching mental model is correct, whether you choose MySQL or PostgreSQL, you can do CRUD, guarantee consistency, and be understood by agents. Syntax and ecosystem differences are dialects, not worldviews.

What really matters is not surface-level ecosystem differences, but whether the underlying model is correct and stable enough. If it is, agents will automatically bridge the rest of those stylistic debates. But this also implies something slightly depressing: paradigm-level innovation is becoming harder. This is another reason I’m skeptical of frameworks like LangChain.

## Interface Design

If the earlier discussion was about “what systems agents can understand,” interface design is about “how agents should talk to your system.”

In the era where agents are users, a good software interface must satisfy at least three conditions:

- It can be described in natural language
- It can be solidified into symbolic logic
- It can deliver deterministic results

If the second is done well, the third follows naturally.

On the first point: “interfaces describable in natural language” does not mean “support natural language input.” It means: can the intent of your interface be clearly expressed in natural language?

For example, Cloud Code deliberately abandoned traditional GUIs. Why? Because GUIs are often extremely difficult to describe precisely in language. “Click here, drag there, select this state”—once you lose visual context, the interface is almost invisible to agents. Meanwhile, most coding happens in the world of symbols and language.

There’s also a more practical reason: today’s models are still fundamentally language models. Understanding text is far easier and more reliable than understanding images or implicit interaction states. Agent-friendly interfaces are those whose capabilities can be clearly described in language.

A common objection is that natural language is ambiguous and unsuitable for serious systems. From an agent’s perspective, this needs reconsideration.

Modern LLMs are already very good at inferring intent—not because language became precise, but because the model has seen countless similar expressions, contexts, and task patterns. Accuracy may not be 100%, but it’s good enough for most engineering scenarios.

Humans themselves solve complex problems primarily through ambiguous, context-dependent natural language—talking with colleagues or reasoning internally. Natural language is not an imprecise compromise; it’s the native representation of human problem-solving. LLMs simply scale and digitize that process.

So rather than over-fearing ambiguity, it’s better to accept reality: if the system’s mental model is correct, interface semantics are stable, and results are verifiable, small ambiguities at the caller (agent) level won’t become systemic issues. Agents can resolve them through context, feedback, and iteration.

In databases, Text-to-SQL is a great example. It’s not perfect, but it proves that if your abstraction is right, it’s naturally describable in language.

For well-designed systems, there is often only one correct way to accomplish an intent—which makes them naturally language-friendly. Go is a good example. Many people dislike this philosophy, but I find it very wise: it dramatically reduces ambiguity.

However, precisely because natural language is ambiguous, systems must converge early to an unambiguous intermediate representation. This brings us to the second point: symbolic logic that can be solidified.

Natural language is great for expressing intent, but terrible for execution semantics. Once tasks need reuse, composition, or automated verification, they must be compressed into a clear, stable, reason-able form.

That’s why almost all successful systems place an intermediate layer between human-readable input and machine-executable behavior: SQL, scripts, code, configuration files. Once generated, they no longer depend on contextual interpretation.

With agents as users, this intermediate representation becomes even more important. Agents can tolerate ambiguity at the input stage, but the system must clearly define the moment when ambiguity is eliminated. Once defined, the system gains a new capability: it can freeze a fuzzy intent into a deterministic structure—storable, auditable, reusable, and reloadable by another agent later.

Natural language explores the space; symbols collapse it.

What makes a good symbolic representation? My personal criterion is: can it express the maximum number of possibilities with the fewest tokens?

As of late 2025, the best representation is still code, even for non-programming agents.

This isn’t about saving cost; it’s about cognitive density. For example, I recently wanted to build a vocabulary app. I had a list of 10,000 English words and wanted an LLM to add Chinese definitions. The naive way is to send the entire list and ask the model to annotate it—hugely inefficient in tokens.

A better way is to solidify the logic as code:

```
def enrich_vocab(src, dst, llm_translate):
    with open(src) as f, open(dst, "w") as out:
        for word in map(str.strip, f):
            if not word:
                continue
            zh = llm_translate(word)
            out.write(f"{word}\t{zh}\n")
```

Once the logic is expressed as code, you no longer need to stuff all data into context. The model understands the rule once and applies it to arbitrary-scale data. A small number of symbols describe an infinitely repeatable process. This is why I believe programming is the best meta-tool—and why I dislike the trend of piling on MCP tools.

Required Properties of Infra for Agent Infras

“Infra for Infra for AI Agents” is a bit awkward as a title, but you know what I mean.

Once AI agents become the primary users of infrastructure, many assumptions we took for granted no longer hold. The user is no longer a carefully planned, long-term human developer, but an agent that creates resources quickly, experiments, discards, and retries—at speeds thousands of times faster than humans.

Agent workloads are fundamentally disposable. Instant usability, easy creation, and zero-cost failure matter more than long-term stability. Even success is often temporary.

This means infrastructure can no longer assume that “a cluster is precious.” Instances must be cheap, short-lived, and massively scalable.

When observing agents using TiDB (our own platform), one thing is very clear: they love spinning up multiple branches in parallel. Once one works, the rest are discarded. Their SQL and code often look like glue—not elegant, but good enough as long as it runs and validates an idea.

This leads to a further implication: the barrier to writing code has dropped so low that “writing code” itself is no longer a scarce skill. Many things that used to require significant engineering effort are now just a generation cost for agents.

As a result, many demands previously deemed “not worth doing” suddenly become feasible: small features, one-off tools, niche scenarios. Code production is massively unleashed, serving long-tail real needs rather than only “worthwhile” users.

This likely means explosive growth in tenant count and reliability requirements—even though individual workloads are ephemeral. This is why I think pausing instances to save costs (as some platforms do) is fundamentally flawed: even the smallest online service is still an online service.

I’ll save deeper discussion for the business model section.

### Extreme Cost Efficiency

“Extreme low cost” doesn’t just mean cheap—it means the system can survive massive long-tail demand.

Many agent workloads are accessed extremely infrequently—once a day, or even once every few days. But they still online services.

Traditional models—one task per real infra environment, or one Postgres process per agent—simply don’t scale. Managing millions of processes, heartbeats, and states would be unbearable even before considering hardware cost.

This leads to an unavoidable conclusion:

You cannot provide a real physical instance for every agent and every demand.

You must introduce virtualization: virtual database instances, virtual branches, virtual environments. Resources are heavily shared, but semantics must be isolated.

The hard part is here:
maximizing resource reuse while making the agent feel, interaction-wise, that “this is my own environment.”

A concrete example is Manus 1.5, whose agents use TiDB Cloud as their database. Agents can create tables, drop tables, run experiments, write garbage SQL—without affecting others or worrying about side effects. TiDB X was designed for exactly this scenario (though admittedly, we didn’t foresee today’s agent explosion when we designed it).

If you can’t do this, agents are forced back into “careful resource usage” mode—and once agents have to conserve, the advantage of parallel exploration and fast iteration disappears entirely.

From this perspective, “seemingly exclusive but actually virtualized” design is not an optimization—it’s a prerequisite for scalable, ultra-low-cost agent infrastructure.

### Compute Leverage per job 

One topic rarely discussed in agent infrastructure: how much compute can you leverage per job?

Most current interaction patterns—ChatGPT or local coding agents—are serial: one request, one GPU, one response. Powerful, but fundamentally sequential.

But many real-world problems require team-scale parallelism.

Imagine skimming hundreds of NeurIPS papers. Traditional agents would read them sequentially. A distributed-agent approach would split the task across hundreds or thousands of jobs in parallel, then aggregate, cross-validate, and structure results.

In that model, compute per unit time scales from one GPU to hundreds or thousands.

This raises a concrete infra question:
can your system cheaply spin up 1,000 workstations? Can it distribute tasks, aggregate results, deduplicate, retry, replay? Is cost visible in real time?

This may be a Kubernetes- or Hadoop-scale opportunity.

## Business Model Shifts

The biggest change in business models is this:
many previously uneconomical models suddenly make sense.

In traditional software, customization was a red flag. Engineers are expensive. Small customers aren’t worth it.

Take a small grocery store owner who wants inventory management. Historically, impossible—too expensive for both sides.

The demand always existed, but economics blocked it.

Agents change this. They democratize computation. Coding, prototyping, experimentation become cheap. Demand didn’t disappear before—cost just finally dropped low enough.

This is why I increasingly believe a successful agent company should not be “selling tokens.”

Token-based models have structural problems: usage scales with cost. Even if token prices drop, selling more tokens still increases costs. That’s fragile.

The sustainable model looks more like a cloud service company whose user base is amplified 100× or 1,000× by agents. The key is converting repeated inference into reusable, deterministic system capabilities—boring online services with near-zero marginal cost.

Interestingly, the end product may look very traditional: cloud services are still cloud services; databases are still databases. What changed is the scale of users.

## Conclusion

The agent era is here, and many assumptions we took for granted as programmers need rethinking. Code is no longer scarce. Software no longer needs to be carefully preserved. Systems will be created, tested, and discarded naturally.

This doesn’t make engineering less important—quite the opposite. The focus shifts: from perfecting individual systems to designing foundational capabilities that AI can use at scale, iterate on, and run cheaply.

Let go of the obsession with “writing code” or “controlling systems,” and the path forward becomes clearer. Many truly important questions are old ones, revisited.

The world has already switched usage modes. There’s no need to resist.

Welcome to the machine.
