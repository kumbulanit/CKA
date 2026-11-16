# Workshop 3 explained: break-and-fix in pairs

This page goes with [Workshop 3](./lab-w3-break-and-fix.md). The workshop page has the commands, hints and answers; this page explains why five faults at once is harder than five faults one by one, and how to work through them as a pair. It gives no answers. There is nothing to paste here.

## In short

In Lab 8.1 the faults came one at a time, so every symptom had one cause. Here five come at once, and they interfere: one fault can hide another, and one symptom can have two causes. The method stays the same; what changes is the discipline: fix one thing, check again, and keep notes.

## The ideas behind this workshop

### Why several faults are harder

| Effect | What it looks like |
| --- | --- |
| **One fault hides another** | You fix what `kubectl get pods` shows, and only then does the next problem appear |
| **One symptom, several causes** | The Shop gives no answer: is it the Service, the network, or the backend? Possibly all three |
| **One fault blocks the fix of another** | A fix creates new pods, but something stops new pods from being created at all |

That last effect is the reason the order of fixes matters. When nothing new can start, every other fix that needs new pods waits.

### The method, unchanged

Pods → describe → logs → Services → events → network → nodes (Lab 8.1). After **every** fix, run `check-shop.sh` and `kubectl get pods` again: the picture has changed, and the next lead may be somewhere else now.

### Working as a pair

| Role | Does |
| --- | --- |
| The typist | Runs the commands, one at a time |
| The navigator | Reads the method, decides the next question, writes the notes |

Swapping after each fault means both practise both. The navigator's notes (what we saw, what was wrong, how we fixed it) are the material for Step 5, and the habit that turns a fix into a lesson.

## Step by step

### Step 1: make sure the Shop works

A passing check before breaking anything proves that every failure afterwards comes from the planned faults, not from an earlier leftover.

### Step 2: break it

`break.sh all` puts in the faults of Lab 8.1, numbers 1 to 5, at the same time. Fault 6 (the node) is left out: it would affect everyone on the node and takes the longest to recover.

### Step 3: find and fix

`check-shop.sh` tells you **what** fails, not **why**. Use it as a progress meter: after each fix, fewer lines should fail. The two hints narrow the search without solving it: the first says where to start, the second names the five areas. A good pair needs neither, but a stuck pair loses less time with them.

Think about the order before you fix. Ask: is there anything that stops new pods from being created? If so, that comes first, or the other fixes cannot take effect.

### Step 4: done

All eight checks pass. If one still fails right after the last fix, wait 30 seconds: the backend reconnects to the database.

### Step 5: explain

Each pair explains one fault: what they saw first, which command showed the cause, and the fix. Hearing how another pair found the same fault by another path is often the most useful part of the workshop.

## When something goes wrong

| What you see | What it means | What to do |
| --- | --- | --- |
| A fix seems to have no effect | Something else stops new pods, or the fix needs new pods that cannot start | Look at the namespace events |
| More checks fail after a fix | A hidden fault is now visible | Normal: carry on with the method |
| The pair disagrees on the next step | Two leads at once | Follow the method's order: the earlier step wins |
| Out of time | Five faults in 60 minutes is a lot | Open Hint 2; note what you would have done next |

## For the exam

- Exam troubleshooting tasks usually have one fault, but a broken cluster task may combine a few. The same rule applies: fix one thing, check, repeat.
- The namespace events (`kubectl get events --sort-by=.lastTimestamp`) are the fastest way to see everything that went wrong recently, in one list.
- Keep a short note of what you changed, so you can undo a wrong fix.

## Check your understanding

1. Why can one fault hide another?
2. Why does the order of fixes matter here, when it did not in Lab 8.1?
3. What does `check-shop.sh` tell you, and what does it not?
4. Why keep notes during troubleshooting?

<details><summary>Answers</summary>

1. The first visible problem stops the request early; the problems further along the path only show once it is fixed.
2. A fault that stops new pods from being created blocks every fix that relies on new pods.
3. It says which part fails; it does not say why.
4. To know what you changed (and undo a wrong change), and to explain the cause afterwards.

</details>

**Back to:** [Workshop 3](./lab-w3-break-and-fix.md) · **Next:** [Workshop 4 explained](./lab-w4-mock-exam-explained.md)
