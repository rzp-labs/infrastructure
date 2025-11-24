# DDD Workflow - Subagent Mapping

**Complete guide to optimal subagent delegation for Document-Driven Development phases**

---

## Overview

The Document-Driven Development (DDD) workflow consists of 5 main phases plus utilities. Each phase has distinct requirements and an optimal subagent for execution. This guide eliminates confusion about delegation patterns and ensures maximum efficiency.

**Key Principle**: Delegate to specialized agents. Your role as orchestrator is coordination, not implementation.

---

## Quick Reference Table

| Phase | Command | Optimal Agent | Delegation Pattern |
|-------|---------|---------------|-------------------|
| **Phase 0** | `/ddd:0-help` | *(no agent - info only)* | Display help directly |
| **Phase 1** | `/ddd:1-plan` | **zen-architect** | Planning & design |
| **Phase 2** | `/ddd:2-docs` | **doc-retcon-specialist** | Documentation retcon |
| **Phase 3** | `/ddd:3-code-plan` | **zen-architect** | Code planning |
| **Phase 4** | `/ddd:4-code` | **modular-builder** | Implementation |
| **Phase 5** | `/ddd:5-finish` | **post-task-cleanup** | Finalization |
| **Utility** | `/ddd:prime` | *(no agent - context loading)* | Load DDD context |
| **Utility** | `/ddd:status` | *(no agent - status check)* | Show current state |

---

## Phase Breakdown

### Phase 0: Help & Context

**Command**: `/ddd:0-help`

**Purpose**: Load comprehensive DDD help and guidance

**Optimal Subagent**: *None - orchestrator displays help directly*

**What it does**:
- Loads DDD methodology documentation
- Shows complete workflow guide
- Provides quick reference
- Explains each phase

**Delegation Pattern**: *No delegation needed*

**Example**:
```
User: "/ddd:0-help"
Orchestrator: [Displays comprehensive help with loaded context]
```

---

### Phase 1: Planning & Design

**Command**: `/ddd:1-plan [feature description]`

**Purpose**: Design and plan the feature before touching ANY files

**Optimal Subagent**: **zen-architect**

**Why zen-architect?**
- Expert in analysis-first development
- Breaks down problems systematically
- Proposes multiple solution approaches
- Evaluates trade-offs
- Checks philosophy alignment (ruthless simplicity, modular design)
- Creates comprehensive specifications

**What it produces**: `ai_working/ddd/plan.md` with:
- Problem statement and solution
- Architecture & design
- Module boundaries and interfaces
- Files to change (docs and code)
- Philosophy alignment check
- Test strategy
- Implementation approach

**Delegation Pattern**:
```
Task zen-architect: "Design and plan [feature description]. Create comprehensive
plan in ai_working/ddd/plan.md following DDD Phase 1 methodology. Analyze problem,
propose solutions, check philosophy alignment, identify all files to change."
```

**Example**:
```
User: "/ddd:1-plan Add JWT authentication with refresh tokens"
Orchestrator: "I'll use zen-architect to design the authentication system"
[Delegates to zen-architect for complete planning]
```

**Key Capabilities Required**:
- Problem framing and decomposition
- Codebase reconnaissance (Grep, Glob, Read)
- Multiple solution proposal
- Trade-off analysis
- Architecture design
- Module specification
- Philosophy compliance checking

---

### Phase 2: Documentation Retcon

**Command**: `/ddd:2-docs [optional override instructions]`

**Purpose**: Update ALL non-code files (docs, configs, READMEs) to reflect target state AS IF IT ALREADY EXISTS

**Optimal Subagent**: **doc-retcon-specialist** *(newly created)*

**Why doc-retcon-specialist?**
- Specialized in retcon writing (present tense, as-if-exists)
- Expert in file crawling technique (systematic processing)
- Enforces maximum DRY (zero duplication)
- Prevents context poisoning (inconsistent docs)
- Applies progressive organization
- Understands DDD Phase 2 methodology deeply

**What it produces**:
- All documentation updated with retcon writing
- `ai_working/ddd/docs_status.md` (status report)
- `ai_working/ddd/docs_checklist.txt` (progress tracking)
- Staged git changes (NOT committed - awaits user approval)

**Delegation Pattern**:
```
Task doc-retcon-specialist: "Execute DDD Phase 2 - update all non-code files
to reflect target state using retcon writing. Read plan from ai_working/ddd/plan.md.
Process all docs systematically with file crawling. Enforce maximum DRY.
Generate docs_status.md when complete. Stage but do NOT commit changes."
```

**Example**:
```
User: "/ddd:2-docs"
Orchestrator: "I'll use doc-retcon-specialist to update all documentation"
[Delegates to doc-retcon-specialist for systematic doc updates]
```

**Key Capabilities Required**:
- Retcon writing (present tense, no future/past references)
- File crawling (systematic one-by-one processing)
- Maximum DRY enforcement (eliminate ALL duplication)
- Context poisoning detection and resolution
- Progressive organization
- Conflict detection (PAUSE and ask human)
- Git operations (stage, diff, status - NO commit)

**Common Mistake to Avoid**:
- ❌ **DO NOT delegate to modular-builder** - that's a code agent
- ✅ **DO delegate to doc-retcon-specialist** - specialized for docs

**Iteration Support**:
This phase iterates until user approves. Agent stays active, incorporates feedback, regenerates status, shows new diff, repeats until user commits.

---

### Phase 3: Code Planning

**Command**: `/ddd:3-code-plan [optional override instructions]`

**Purpose**: Assess current code vs new docs, plan all implementation changes

**Optimal Subagent**: **zen-architect**

**Why zen-architect?**
- Expert code analyst and planner
- Understands current vs target state
- Breaks implementation into logical chunks
- Plans dependencies between chunks
- Defines test strategy
- Creates detailed implementation specs

**What it produces**: `ai_working/ddd/code_plan.md` with:
- Gap analysis (current vs target)
- File-by-file change specifications
- Implementation chunks (with dependencies)
- New files to create
- Files to delete
- Agent orchestration strategy
- Testing strategy
- Commit strategy
- Risk assessment

**Delegation Pattern**:
```
Task zen-architect: "Execute DDD Phase 3 - plan code implementation. Read plan
from ai_working/ddd/plan.md and ALL updated documentation (the specifications).
Analyze current code, identify gaps, create detailed code_plan.md with chunks,
dependencies, test strategy, and commit plan."
```

**Example**:
```
User: "/ddd:3-code-plan"
Orchestrator: "I'll use zen-architect to plan the code implementation"
[Delegates to zen-architect for comprehensive code planning]
```

**Key Capabilities Required**:
- Reading updated documentation (specs)
- Code reconnaissance (understanding current state)
- Gap analysis (current vs target)
- Implementation chunking
- Dependency identification
- Test strategy design
- Agent orchestration planning

---

### Phase 4: Code Implementation & Verification

**Command**: `/ddd:4-code [optional feedback or instructions]`

**Purpose**: Write code matching docs exactly, test as real user would, iterate until working

**Optimal Subagent**: **modular-builder** (primary), **bug-hunter** (when issues arise), **test-coverage** (for tests)

**Why modular-builder?**
- Primary implementation agent
- Builds code from specifications
- Follows "bricks and studs" philosophy
- Creates self-contained, regeneratable modules
- Implements exactly what specifications describe

**What it produces**:
- Code implementation (all chunks)
- Tests (unit and integration)
- `ai_working/ddd/impl_status.md` (tracking)
- `ai_working/ddd/test_report.md` (verification)
- Git commits (with user authorization)

**Delegation Pattern**:

**For implementation chunks**:
```
Task modular-builder: "Implement [chunk N] according to code_plan.md and
documentation specifications. Code must match docs exactly. Create tests.
Request commit authorization when complete."
```

**When issues arise**:
```
Task bug-hunter: "Debug [specific issue] found during testing. Analyze,
identify root cause, propose fix."
```

**For test suggestions**:
```
Task test-coverage: "Suggest comprehensive test cases for [feature].
Cover happy path, edge cases, error handling, integration scenarios."
```

**Example**:
```
User: "/ddd:4-code"
Orchestrator: "I'll use modular-builder to implement each chunk"
[Delegates chunk 1 to modular-builder]
[When complete, requests commit authorization]
[After commit, delegates chunk 2]
[If issue found, delegates to bug-hunter]
[Continues until all chunks implemented and tested]
```

**Key Capabilities Required**:
- Reading code specifications (code_plan.md + docs)
- Module implementation
- Test creation
- User-level testing (actually run the commands)
- Issue debugging
- Iteration based on feedback
- Git operations (commit with authorization)

**Iteration Support**:
This phase iterates until user confirms "all working". Agent stays active, fixes issues, re-tests, requests commits, repeats until complete.

---

### Phase 5: Wrap-Up & Cleanup

**Command**: `/ddd:5-finish [optional instructions]`

**Purpose**: Remove temporary files, verify clean state, push/PR with explicit authorization

**Optimal Subagent**: **post-task-cleanup**

**Why post-task-cleanup?**
- Specialized in thorough workspace cleanup
- Reviews for temporary files and artifacts
- Verifies clean working state
- Checks for debug code
- Ensures quality verification passes

**What it does**:
- Removes `ai_working/ddd/` artifacts
- Cleans test artifacts
- Removes debug code
- Runs final `make check`
- Verifies git status
- Lists all commits
- (With authorization) Commits remaining changes
- (With authorization) Pushes to remote
- (With authorization) Creates PR
- Generates final summary

**Delegation Pattern**:
```
Task post-task-cleanup: "Execute DDD Phase 5 cleanup. Remove ai_working/ddd/
directory and temporary files. Run make check. Verify git status. With user
authorization: commit remaining changes, push to remote, create PR. Generate
comprehensive completion summary."
```

**Example**:
```
User: "/ddd:5-finish"
Orchestrator: "I'll use post-task-cleanup to finalize and clean up"
[Delegates to post-task-cleanup for systematic cleanup]
[Agent requests authorization at each git operation checkpoint]
```

**Key Capabilities Required**:
- File cleanup (systematic removal)
- Quality verification (make check, tests)
- Git operations (status, commit, push - ALL with authorization)
- PR creation (with authorization)
- Summary generation

**Authorization Checkpoints**:
- Delete DDD working files?
- Delete temporary files?
- Remove debug code?
- Commit remaining changes?
- Push to remote?
- Create PR?

**User controls all git operations** - agent asks at every checkpoint.

---

## Utility Commands

### `/ddd:prime` - Load Complete DDD Context

**Purpose**: Load all DDD methodology documentation at session start

**Optimal Subagent**: *None - orchestrator loads context directly*

**What it loads**:
- `docs/document_driven_development/overview.md`
- `docs/document_driven_development/core_concepts/`
- `docs/document_driven_development/phases/`
- `docs/document_driven_development/reference/`
- Philosophy documents

**When to use**: At start of DDD session for full context

**Example**:
```
User: "/ddd:prime"
Orchestrator: [Loads all DDD methodology documentation]
"DDD context loaded. Ready to start with /ddd:1-plan"
```

---

### `/ddd:status` - Check Current Progress

**Purpose**: Show which phase you're in and what artifacts exist

**Optimal Subagent**: *None - orchestrator checks directly*

**What it shows**:
- Current phase
- Artifacts created
- Files in ai_working/ddd/
- Recent git commits
- Next recommended command

**When to use**: Any time to check progress or after resuming session

**Example**:
```
User: "/ddd:status"
Orchestrator: [Checks ai_working/ddd/ and git status]
"Phase 2 complete (docs committed). Ready for /ddd:3-code-plan"
```

---

## Common Delegation Patterns

### Pattern 1: Sequential Phase Execution

```
# Start new feature
/ddd:1-plan Add caching layer
  → zen-architect creates plan

# Update all docs
/ddd:2-docs
  → doc-retcon-specialist updates docs
  → User reviews and commits

# Plan code
/ddd:3-code-plan
  → zen-architect creates code plan
  → User approves

# Implement
/ddd:4-code
  → modular-builder implements chunks
  → bug-hunter fixes issues as needed
  → test-coverage suggests tests
  → User authorizes commits

# Finalize
/ddd:5-finish
  → post-task-cleanup cleans and finalizes
  → User authorizes git operations
```

### Pattern 2: Iteration in Phase 2

```
/ddd:2-docs
  → doc-retcon-specialist updates docs
  → Shows status and diff

User: "Add more detail to API section"
  → doc-retcon-specialist updates API docs
  → Shows new status and diff

User: "Perfect, approved"
  → User commits docs themselves

/ddd:3-code-plan
```

### Pattern 3: Iteration in Phase 4

```
/ddd:4-code
  → modular-builder implements chunk 1
  → Tests pass
  → User authorizes commit

  → modular-builder implements chunk 2
  → Tests fail with error

  → bug-hunter debugs error
  → modular-builder applies fix
  → Tests pass
  → User authorizes commit

User: "All working"
/ddd:5-finish
```

---

## When NOT to Use DDD

DDD is powerful but has overhead. Skip DDD for:

### ✅ Use DDD For:
- New features requiring multiple files
- System redesigns or refactoring
- API changes affecting documentation
- Any change touching 10+ files
- Cross-cutting concerns

### ❌ Don't Use DDD For:
- Simple typo fixes
- Single-file bug fixes
- Emergency hotfixes
- Trivial updates
- Documentation-only changes

**Rule of thumb**: If you're uncertain, lean toward using DDD. It prevents expensive mistakes.

---

## Troubleshooting Common Issues

### Issue: Wrong agent delegated in Phase 2

**Symptom**: modular-builder was delegated for documentation work

**Problem**: modular-builder is a code agent, not a documentation agent

**Fix**: Use doc-retcon-specialist for Phase 2:
```
Task doc-retcon-specialist: "Execute DDD Phase 2..."
```

---

### Issue: Agent doesn't have required context

**Symptom**: Agent asks basic questions about DDD methodology

**Problem**: Agent needs DDD context loaded

**Fix**: Include context loading in delegation:
```
Task doc-retcon-specialist: "Load @docs/document_driven_development/phases/01_documentation_retcon.md
and execute Phase 2..."
```

Or run `/ddd:prime` before starting workflow.

---

### Issue: User wants to resume after break

**Symptom**: Lost track of where we are in workflow

**Solution**:
```
/ddd:status
  → Shows current phase and artifacts
  → Recommends next command
```

---

### Issue: Phase 2 confusion about what to update

**Problem**: Unclear which files are "non-code"

**Clarification**:
- **Non-code files** (Phase 2): `*.md`, `*.yaml`, `*.toml`, `*.json`, READMEs, configs
- **Code files** (Phase 4): `*.py`, `*.js`, `*.ts`, `*.go`, etc.

---

## Agent Capability Matrix

| Capability | zen-architect | doc-retcon-specialist | modular-builder | bug-hunter | test-coverage | post-task-cleanup |
|-----------|---------------|----------------------|-----------------|-----------|---------------|------------------|
| **Problem analysis** | ✅ Expert | ❌ | ❌ | ✅ Good | ❌ | ❌ |
| **Architecture design** | ✅ Expert | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Code reconnaissance** | ✅ Good | ❌ | ✅ Good | ✅ Expert | ❌ | ❌ |
| **Documentation writing** | ✅ Good | ✅ Expert | ❌ | ❌ | ❌ | ❌ |
| **Retcon writing** | ❌ | ✅ Expert | ❌ | ❌ | ❌ | ❌ |
| **File crawling** | ❌ | ✅ Expert | ❌ | ❌ | ❌ | ✅ Good |
| **DRY enforcement** | ❌ | ✅ Expert | ❌ | ❌ | ❌ | ❌ |
| **Context poisoning prevention** | ❌ | ✅ Expert | ❌ | ❌ | ❌ | ❌ |
| **Code implementation** | ❌ | ❌ | ✅ Expert | ✅ Good | ❌ | ❌ |
| **Bug diagnosis** | ❌ | ❌ | ❌ | ✅ Expert | ❌ | ❌ |
| **Test creation** | ❌ | ❌ | ✅ Good | ❌ | ✅ Expert | ❌ |
| **Cleanup operations** | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ Expert |
| **Git operations** | ❌ | ✅ Good | ✅ Good | ❌ | ❌ | ✅ Expert |

---

## Key Decisions and Rationale

### Decision 1: Create doc-retcon-specialist

**Problem**: Phase 2 was incorrectly delegated to modular-builder (code agent)

**Analysis**: Phase 2 requires specialized capabilities:
- Retcon writing expertise
- File crawling technique
- Maximum DRY enforcement
- Context poisoning prevention
- Progressive organization
- Conflict detection and resolution

**None of the existing agents possessed this combination.**

**Solution**: Created dedicated **doc-retcon-specialist** agent with:
- Deep DDD Phase 2 methodology knowledge
- Retcon writing rules enforcement
- File crawling systematic processing
- Maximum DRY vigilance
- Context poisoning awareness
- Git staging (but no commits)

**Result**: Phase 2 now has optimal agent with exact required capabilities.

---

### Decision 2: zen-architect for both Phase 1 and Phase 3

**Rationale**: Both phases require:
- Analysis and planning expertise
- Architecture design skills
- Codebase understanding
- Specification creation
- Philosophy compliance checking

zen-architect operates in different modes:
- **Phase 1**: ANALYZE mode (problem decomposition, solution design)
- **Phase 3**: ARCHITECT mode (code planning, implementation specs)

**Single agent, different contexts** - efficient and consistent.

---

### Decision 3: Multiple agents for Phase 4

**Rationale**: Implementation is complex and multi-faceted:
- **Primary implementation**: modular-builder
- **Bug fixing**: bug-hunter (when issues arise)
- **Test design**: test-coverage (for comprehensive tests)

**Orchestrator coordinates** based on what's needed at each moment.

---

### Decision 4: No agent for utilities (prime, status, help)

**Rationale**: These are simple information operations:
- **prime**: Load documentation (orchestrator reads files)
- **status**: Check artifacts (orchestrator checks filesystem)
- **help**: Display guidance (orchestrator shows loaded docs)

**No specialized agent needed** - orchestrator handles directly.

---

## Integration with Orchestrator Boundary

**Remember**: As orchestrator, you **CANNOT** use Edit/Write tools directly (enforcement active).

**Your role**: Delegate to specialized agents who CAN use those tools.

**Phase 2 is special**: Documentation updates require Write/Edit tools, which is why doc-retcon-specialist exists.

**Orchestrator responsibilities**:
- Recognize which phase user is in
- Delegate to optimal agent
- Pass context and specifications
- Request user authorization at checkpoints
- Coordinate between phases
- Track progress

**You orchestrate, agents implement.**

---

## Success Metrics

### You're using DDD well when:

- ✅ Correct agent delegated for each phase
- ✅ Documentation and code never diverge
- ✅ Zero context poisoning incidents
- ✅ Changes require minimal rework
- ✅ Philosophy principles naturally followed
- ✅ Git history is clean
- ✅ Examples in docs all work

### Warning signs:

- ❌ Delegating modular-builder for Phase 2 (doc work)
- ❌ Trying to use Edit/Write directly (boundary violation)
- ❌ Skipping phase approvals
- ❌ Committing without authorization
- ❌ Context poisoning detected

---

## Quick Decision Tree

```
User runs DDD command
    ↓
Is it Phase 0, prime, or status?
    YES → Handle directly, no agent
    NO → Continue
        ↓
    Is it Phase 1 (plan)?
        YES → Delegate to zen-architect
        NO → Continue
            ↓
        Is it Phase 2 (docs)?
            YES → Delegate to doc-retcon-specialist
            NO → Continue
                ↓
            Is it Phase 3 (code-plan)?
                YES → Delegate to zen-architect
                NO → Continue
                    ↓
                Is it Phase 4 (code)?
                    YES → Delegate to modular-builder (primary)
                          Use bug-hunter if issues
                          Use test-coverage for tests
                    NO → Continue
                        ↓
                    Is it Phase 5 (finish)?
                        YES → Delegate to post-task-cleanup
                        NO → Unknown command
```

---

## Related Documentation

**Philosophy**:
- [IMPLEMENTATION_PHILOSOPHY.md](../../ai_context/IMPLEMENTATION_PHILOSOPHY.md) - Ruthless simplicity
- [MODULAR_DESIGN_PHILOSOPHY.md](../../ai_context/MODULAR_DESIGN_PHILOSOPHY.md) - Bricks and studs

**DDD Methodology**:
- [DDD Overview](../../docs/document_driven_development/overview.md)
- [Phase 1: Documentation Retcon](../../docs/document_driven_development/phases/01_documentation_retcon.md)
- [Core Concepts](../../docs/document_driven_development/core_concepts/)

**Orchestrator Boundary**:
- [Decision 003: Orchestrator Boundary Phase 3](../../ai_working/decisions/003-orchestrator-boundary-phase-3-enforcement.md)

---

## Version

**Document Version**: 1.0
**Created**: 2025-11-03
**Based On**: Analysis of DDD slash commands and agent capabilities

**Changes from previous approach**:
- ✅ Created doc-retcon-specialist for Phase 2
- ✅ Clarified zen-architect dual role (Phase 1 and 3)
- ✅ Defined clear delegation patterns
- ✅ Added troubleshooting guide
- ✅ Provided capability matrix

---

**This mapping eliminates confusion and ensures optimal DDD workflow execution.**
