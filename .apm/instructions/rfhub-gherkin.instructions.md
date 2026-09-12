---
description: Gherkin Robot cases stay human-readable like a book; keywords implement how, not the actor story
applyTo: "**/*.robot"
---

- Prefer Gherkin (`Given` / `When` / `Then` / `And` / `But`). Robot strips those prefixes when matching keywords.
- The case must stay human-readable like a book. A reader should be able to perform the test **manually** from the top-level steps alone — even with a different how.
- Case steps name **business artifacts and outcomes**; tool names (`pnpm`, `hadolint`, script paths) stay in keywords (HOW), not in the Gherkin.
- One execution path per case. People do not think in loops or `IF` / `ELSE` — they think straight. No branching (`IF` / `ELSE` / `Run Keyword If` / `FOR`) in the test body. Different actor goals are different cases. Decision logic belongs **deeper in the keyword spine**, not in the Gherkin. Top-level: `person turns to home from crossroads`. They turn toward home automatically; left vs right is not in the case. Simple `IF` / `FOR` may live in Robot keywords; shell out with Robot **Process**; **complex** decisioning, CSS/DOM/JavaScript, and seams Process cannot cover (API client, structured parse, math) go to Python, which logs what it did so the Robot log stays tidy.
- Do not hide test steps in keywords. The Gherkin case describes **what** the actor is doing; keywords tell **how**. Top-level names stay human — the customer memorizes a value (as if writing it on paper) and later uses the memorized value, so a reader sees where it came from. Deeper keywords get more technical; prefer stock Robot libraries before Python.
- Keywords used in a test case take **one** inlined `'${businessArguments}'` (single quotes) and **must not end** on the variable — finish with a meaningful word.
  - Right: `My nice keyword takes '${businessArguments}' inlined`
  - Wrong: `My nasty keyword takes inlined ${businessArguments}`
  Do not pass those values as a separate `[Arguments]` column on the Gherkin line. Do not use `"${name}"`.
- Several business values needed later: do **not** put multiple `'${a}'` `'${b}'` on one first-level keyword. Each choose/set step stores one value with `VAR    ${name}    ${value}    scope=TEST`. Later steps in the **same case** read those test variables. Use `scope=SUITE` to carry a value from one test case to another in the **same leaf** (`customer memorizes the order number` → `customer uses the memorized order number`). `VAR` without `scope=` is local to the keyword and later steps will not see it. Suite variables do not cross hub leaves (each leaf is a separate Robot process).
- Quotes and the trailing word exist so formatters cannot split the name. Robot treats **two or more spaces** as a new cell. Unquoted `${var}` gets padded (`My nice keyword takes ${businessArguments}` → `My nice keyword takes    ${businessArguments}`) and becomes a **different** keyword plus an argument. After indent, a Gherkin step must stay one cell: only single spaces between words.
- Keywords only called from other keywords may take arguments any way (`[Arguments]`, positional, named).
- Do not hide user interactions deep in keywords unless the step is totally technical (selectors, waits, payload encoding). Clicking, typing, navigating, and reading on-screen results belong in the case narrative.
- Hub synthetic/demo suites that only burn time or inject failures are not product Gherkin — do not rewrite them into Given/When/Then.
