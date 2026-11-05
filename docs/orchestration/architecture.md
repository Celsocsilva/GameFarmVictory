# Orchestration architecture

Product Owner/Human Supervisor -> Governance -> Orchestrator -> Specialized Agents -> Execution & Evidence -> Quality Gates/Human Approval -> GitHub main/Mobile Build.

Governance is policy and approval. Agents are contracts and scopes. Runtime persists tasks, state, handoffs and evidence. GitHub remains the versioned source of truth.

The first mode is assisted: CLI creates a package, a human forwards it to ChatGPT/Claude, and the response is recorded. LLM calls are interfaces only and disabled by default.
