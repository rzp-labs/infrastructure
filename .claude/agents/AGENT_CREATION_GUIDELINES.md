# Agent Creation Guidelines for Amplifier Ecosystem

**For AI agents interacting with Amplifier CLI tools and the broader ecosystem**

---

## Core Philosophy Integration

### "Code for Structure, AI for Intelligence"

This is THE foundational principle of the Amplifier ecosystem:

**Code handles:**
- Pipeline orchestration and flow control
- State management and checkpointing
- File I/O and error handling
- User interaction and feedback parsing
- Iteration loops and progress tracking

**AI handles:**
- Understanding and extraction
- Creative generation
- Nuanced quality judgments
- Incorporating feedback effectively
- Synthesis and insight discovery

**This separation** means tools are both reliable (code manages the flow) and creative (AI handles the content).

### Ruthless Simplicity

From `@ai_context/IMPLEMENTATION_PHILOSOPHY.md`:

- **KISS principle taken to heart**: Keep everything as simple as possible, but no simpler
- **Minimize abstractions**: Every layer of abstraction must justify its existence
- **Start minimal, grow as needed**: Begin with the simplest implementation that meets current needs
- **Avoid future-proofing**: Don't build for hypothetical future requirements
- **Question everything**: Regularly challenge complexity in the codebase

### Modular "Bricks & Studs" Design

From `@ai_context/MODULAR_DESIGN_PHILOSOPHY.md`:

1. **Think "bricks & studs"**
   - A _brick_ = a self-contained directory (or file set) that delivers one clear responsibility
   - A _stud_ = the public contract (function signatures, CLI, API schema, or data model) other bricks latch onto

2. **Always start with the contract**
   - Create or update a short `README` or top-level docstring inside the brick
   - States: _purpose, inputs, outputs, side-effects, dependencies_
   - Keep it small enough to hold in one prompt

3. **Build the brick in isolation**
   - Put code, tests, and fixtures inside the brick's folder
   - Expose only the contract via `__all__` or an interface file

4. **Regenerate, don't patch**
   - When a change is needed _inside_ a brick, rewrite the whole brick from its spec
   - If the contract itself must change, locate every brick that consumes that contract and regenerate them too

---

## THE Exemplar: blog_writer

`@scenarios/blog_writer/` is **THE canonical example** that all new scenario tools MUST follow.

### Why blog_writer Is THE Standard

**ALL tools MUST match blog_writer's quality in:**

1. **README.md Structure and Content**
   - Clear problem statement (The Problem)
   - Clear solution overview (The Solution)
   - Quick start that actually works
   - Usage examples with real scenarios
   - "How It Works" section showing the pipeline
   - Configuration and troubleshooting

2. **HOW_TO_CREATE_YOUR_OWN.md Documentation**
   - Step-by-step creation narrative
   - Philosophy and design decisions
   - Code walkthrough with explanations
   - Extension points and patterns
   - Learning objectives clearly stated

3. **Code Organization**
   - Clear separation of concerns
   - Defensive patterns throughout
   - Progress visibility
   - State management with resume capability
   - User feedback integration

4. **User Experience**
   - Minimal input required
   - Maximum leverage delivered
   - Clear progress indicators
   - Graceful error handling
   - Resumable on interruption

**This is not optional** - blog_writer defines the standard. Model everything after it.

**Reference it constantly:**
```
"Study @scenarios/blog_writer/ README.md for structure and content"
"Model documentation after @scenarios/blog_writer/HOW_TO_CREATE_YOUR_OWN.md"
"Match @scenarios/blog_writer/ quality and completeness"
```

---

## Template-First Approach

### CRITICAL: Always Start with tool_template.py

**NEVER start from scratch when creating Amplifier CLI tools.**

```bash
cp amplifier/ccsdk_toolkit/templates/tool_template.py [destination]/
```

The template contains **ALL defensive patterns** discovered through real failures:

- Retry logic for file I/O (cloud sync issues)
- LLM response parsing (handles markdown-wrapped JSON)
- Progress visibility patterns
- State management for resume
- Recursive file discovery
- Minimum input validation
- Graceful partial failure handling

**The template is your starting point** - modify it, don't replace it.

### Template Contains Proven Patterns

From real-world failures documented in `@DISCOVERIES.md`:

1. **Recursive glob patterns** (`**/*.md` not `*.md`)
2. **Minimum input validation** before processing
3. **Progress visibility** (show what's being processed)
4. **Fail fast and loud** (clear errors, no silent failures)
5. **Defensive LLM parsing** (`parse_llm_json()`)
6. **File I/O retry logic** (handles cloud sync delays)
7. **Incremental state saves** (resume from any point)

**Starting from scratch means rediscovering these patterns** - don't do it.

---

## Progressive Maturity Model

### Tool Organization Lifecycle

Tools progress through maturity stages with clear graduation criteria:

#### Stage 1: ai_working/[tool_name]/

**Use when:**
- Experimental or prototype stage
- Internal development tool
- Not ready for user consumption
- Missing documentation
- Rapid iteration needed

**Characteristics:**
- Quick iteration, rough edges acceptable
- Internal use only
- No documentation requirements
- Can break or change frequently

#### Stage 2: scenarios/[tool_name]/

**Use when (ALL must be true):**
- ✓ Solves a real user problem
- ✓ Has clear metacognitive recipe
- ✓ Includes full documentation (README + HOW_TO_CREATE_YOUR_OWN modeled after blog_writer)
- ✓ Ready for others to use
- ✓ Serves as learning exemplar
- ✓ Has been used successfully 2-3 times by real users

**Characteristics:**
- User-facing with excellent documentation
- Serves as learning exemplar for others
- Embodies "minimal input, maximum leverage" philosophy
- README and HOW_TO_CREATE_YOUR_OWN match blog_writer quality
- Philosophy from `@scenarios/README.md`

#### Stage 3: amplifier/

**Use when:**
- Core library component (not standalone tool)
- Shared utility across tools
- Infrastructure code
- Truly production-ready and stable

**Characteristics:**
- Foundational infrastructure
- Versioned and stable
- Comprehensive tests
- Not a standalone CLI tool

### Graduation Criteria: ai_working/ → scenarios/

A tool is ready to graduate when:

1. **Usage validation**: Used successfully by 2-3 real users
2. **Documentation complete**: README + HOW_TO_CREATE_YOUR_OWN modeled after blog_writer
3. **Quality standard met**: Matches blog_writer's completeness and polish
4. **Learning value**: Others can learn from it (per `@scenarios/README.md`)
5. **Tests exist**: Working examples in tests/ directory
6. **Make target**: Integrated into Makefile

**Don't rush graduation** - scenarios/ tools are exemplars, not experiments.

---

## Decision Frameworks

### Command vs Amplifier CLI Tool vs Skill

This three-way decision is critical:

```
START: Need to automate a workflow
  ├─ Does it process 10+ items with AI? → Amplifier Tool
  ├─ Does it need SessionManager/resume? → Amplifier Tool
  ├─ Multi-stage AI pipeline? → Amplifier Tool
  ├─ Reusable across projects? → Amplifier Tool OR Skill
  ├─ Simple orchestration? → Command
  ├─ Project-specific workflow? → Command
  ├─ Needs composition interface? → Skill (wrapping Amplifier Tool)
  └─ Conversational wrapper? → Hybrid (Command orchestrating Tool)
```

### Detailed Decision Matrix

| Characteristic | Amplifier Tool | Command | Skill |
|---------------|----------------|---------|-------|
| **Batch processing** | ✅ Implements | ❌ Orchestrates | ❌ Orchestrates |
| **Session persistence** | ✅ Has SessionManager | ❌ Delegates | ❌ Delegates |
| **Composable** | ⚠️ Via skills | ❌ Project-specific | ✅ Yes |
| **Reusable** | ✅ Cross-project | ❌ Single project | ✅ Cross-project |
| **AI pipelines** | ✅ Implements | ❌ Delegates | ❌ Delegates |
| **User-facing** | ✅ Standalone | ✅ Interactive | ❌ Programmatic |
| **Project context** | ❌ No assumptions | ✅ Project-aware | ❌ No assumptions |

### When to Delegate

**To amplifier-cli-architect:**
- Batch processing (10+ items with AI)
- Session persistence needed
- Multi-stage AI pipelines
- Complex state management
- Heavy AI processing

**To command-architect:**
- Simple workflow orchestration
- Project-specific automation
- Git/version control workflows
- Conversational wrappers

**To skill-architect:**
- Composable interfaces needed
- Wrapping amplifier tools for reuse
- No project assumptions
- Programmatic invocation

**When uncertain:** Consult the appropriate architect agent first.

---

## Integration Patterns

### Pattern 1: Pure Amplifier Tool

**When:** Complex processing that stands alone

```python
# scenarios/my_tool/tool.py
from amplifier.ccsdk_toolkit import ClaudeSession, SessionManager

# Full implementation with state management
# Handles all processing internally
# Can be invoked standalone
```

**Example:** blog_writer (THE exemplar)

### Pattern 2: Command Orchestrating Amplifier Tool

**When:** Project-specific wrapper for conversational interaction

```markdown
---
description: Conversational wrapper for my_tool
---

# What This Command Does

1. Validates project-specific context
2. Runs amplifier tool: `uv run python -m scenarios.my_tool`
3. Presents results interactively
4. Offers follow-up actions

$ARGUMENTS
```

**Example:** Commands that invoke amplifier tools with project context

### Pattern 3: Skill Wrapping Amplifier Tool

**When:** Composable interface for tool reuse

```python
# .claude/skills/my-skill.py
def my_skill(args):
    """Provide composable interface to amplifier tool."""
    # Invoke amplifier tool
    result = subprocess.run([...])
    # Return structured results
    return parsed_result
```

**Example:** Skills providing composition layer over heavy processing

### Pattern 4: Template-First Tool Development

**When:** Creating any new amplifier CLI tool

```bash
# ALWAYS start here
cp amplifier/ccsdk_toolkit/templates/tool_template.py scenarios/my_tool/

# Modify the template (don't start from scratch)
# Keep all defensive patterns
# Add your specific logic
# Model documentation after blog_writer
```

**Why:** Template contains ALL discovered defensive patterns

---

## Essential Amplifier References

### Must-Read Documentation

**Core Philosophy:**
- `@ai_context/IMPLEMENTATION_PHILOSOPHY.md` - Ruthless simplicity, core principles
- `@ai_context/MODULAR_DESIGN_PHILOSOPHY.md` - Bricks & studs, modular design
- `@DISCOVERIES.md` - Real-world failures and solutions

**THE Exemplar:**
- `@scenarios/blog_writer/README.md` - **MODEL ALL READMES AFTER THIS**
- `@scenarios/blog_writer/HOW_TO_CREATE_YOUR_OWN.md` - **MODEL ALL HOW-TOs AFTER THIS**
- `@scenarios/blog_writer/` - **MODEL ALL CODE ORGANIZATION AFTER THIS**

**Technical Foundation:**
- `@amplifier/ccsdk_toolkit/DEVELOPER_GUIDE.md` - Complete technical guide
- `@amplifier/ccsdk_toolkit/templates/tool_template.py` - **START HERE for new tools**
- `@scenarios/README.md` - Philosophy for user-facing tools

**Pattern Examples:**
- `@amplifier/ccsdk_toolkit/examples/code_complexity_analyzer.py` - Batch processing
- `@amplifier/ccsdk_toolkit/examples/idea_synthesis/` - Multi-stage pipeline

### Component References

**Core Components:**
- `@amplifier/ccsdk_toolkit/core/` - ClaudeSession, SessionOptions, DEFAULT_TIMEOUT
- `@amplifier/ccsdk_toolkit/sessions/` - SessionManager pattern
- `@amplifier/ccsdk_toolkit/defensive/` - parse_llm_json, retry utilities
- `@amplifier/ccsdk_toolkit/defensive/file_io.py` - File I/O with retry

**SDK Documentation:**
- `@ai_context/claude_code/sdk/` - Claude Code SDK references

---

## Quality Checklist for Amplifier-Aware Agents

### Pre-Finalization Checklist

Before finalizing any amplifier tool or documentation:

#### Documentation Quality

- [ ] README matches blog_writer's structure and completeness
- [ ] HOW_TO_CREATE_YOUR_OWN follows blog_writer's approach
- [ ] Clear problem statement and solution overview
- [ ] Quick start that actually works
- [ ] Usage examples with real scenarios
- [ ] "How It Works" section explaining pipeline
- [ ] Configuration and troubleshooting sections

#### Code Quality

- [ ] Started from tool_template.py (not from scratch)
- [ ] Uses ccsdk_toolkit components (ClaudeSession, SessionManager)
- [ ] Implements all defensive patterns from template
- [ ] Recursive file discovery (`**/*.ext` not `*.ext`)
- [ ] Minimum input validation before processing
- [ ] Clear progress visibility to user
- [ ] Graceful error handling (fail fast and loud)
- [ ] Incremental state saves with resume capability

#### Architecture Quality

- [ ] "Code for structure, AI for intelligence" separation clear
- [ ] Follows modular "bricks & studs" design
- [ ] Contract (inputs, outputs, failures) clearly defined
- [ ] Located in correct maturity stage directory
- [ ] Integration pattern chosen appropriately
- [ ] Philosophy alignment verified

#### User Experience Quality

- [ ] Minimal input required
- [ ] Maximum leverage delivered
- [ ] Progress indicators clear
- [ ] Error messages helpful
- [ ] Resumable on interruption
- [ ] Matches blog_writer's UX standard

#### Learning Value (for scenarios/ tools)

- [ ] Serves as exemplar for others
- [ ] Documentation teaches the pattern
- [ ] Clear metacognitive recipe
- [ ] Philosophy explained
- [ ] Extension points documented

---

## Common Anti-Patterns to Avoid

### 1. Starting From Scratch

❌ **Don't:**
```python
# Creating new tool without template
def my_new_tool():
    # Writing everything from scratch
    # Missing all defensive patterns
```

✅ **Do:**
```bash
# Always start with template
cp amplifier/ccsdk_toolkit/templates/tool_template.py scenarios/my_tool/
# Modify, don't replace
```

### 2. Non-Recursive File Discovery

❌ **Don't:**
```python
files = list(dir.glob("*.md"))  # Only top-level files
```

✅ **Do:**
```python
files = list(dir.glob("**/*.md"))  # Recursive discovery
```

### 3. Ignoring Minimum Validation

❌ **Don't:**
```python
# Process with no validation
for file in files:
    process(file)
```

✅ **Do:**
```python
if len(files) < min_required:
    logger.error(f"Need at least {min_required} files, found {len(files)}")
    sys.exit(1)
```

### 4. Silent Failures

❌ **Don't:**
```python
try:
    result = process(item)
except Exception:
    pass  # Silent failure
```

✅ **Do:**
```python
try:
    result = process(item)
except Exception as e:
    logger.error(f"Failed to process {item}: {e}")
    # Continue or exit depending on severity
```

### 5. Poor Documentation

❌ **Don't:**
```markdown
# My Tool

This tool does stuff.

Usage: `python tool.py`
```

✅ **Do:**
```markdown
# Tool Name: Transform Ideas Into Results

**The Problem**
[Clear problem statement]

**The Solution**
[Clear solution overview]

**Quick Start**
[Actually working example]

[Follow blog_writer structure completely]
```

### 6. Graduating Too Early

❌ **Don't:**
- Move tools to scenarios/ without real user validation
- Skip documentation because "it works"
- Graduate before matching blog_writer quality

✅ **Do:**
- Keep in ai_working/ during iteration
- Wait for 2-3 successful real user experiences
- Complete ALL documentation before graduating
- Verify quality matches blog_writer standard

---

## Language and Emphasis

### Mandatory vs Optional

When writing agent prompts or guidelines:

**Mandatory (use strong language):**
- "MUST follow blog_writer's structure"
- "ALWAYS start with tool_template.py"
- "NEVER start from scratch"
- "ALL tools MUST match blog_writer's quality"
- "THE exemplar" (not "an exemplar")

**Guidance (use softer language):**
- "Consider using..."
- "Typically you would..."
- "Often beneficial to..."
- "Good practice includes..."

### Emphasis Patterns

**For blog_writer:**
- "THE canonical example" (not just "a good example")
- "MODEL ALL documentation after blog_writer" (not "reference blog_writer")
- "Match blog_writer's quality" (not "follow similar patterns")

**For tool_template.py:**
- "START HERE for new tools" (not "consider using template")
- "Contains ALL defensive patterns" (not "has useful patterns")
- "NEVER start from scratch" (not "preferably use template")

**For Progressive Maturity:**
- "Graduation criteria" (not "suggestions for moving")
- "ALL must be true" (not "should generally meet")
- "2-3 successful uses by real users" (specific, not vague)

---

## Integration with Other Agents

### When Creating Agents That Work With Amplifier

**Agent should:**

1. **Reference THE exemplar early and often**
   - Mention blog_writer in first 50 lines
   - Position as THE standard, not an example
   - Use strong language: "ALL tools MUST match blog_writer's quality"

2. **Emphasize template-first approach**
   - "ALWAYS start with tool_template.py"
   - "NEVER start from scratch"
   - Position template as containing ALL defensive patterns

3. **Include philosophy section early**
   - After "Core Mission" (~line 25)
   - "Code for structure, AI for intelligence"
   - Ruthless simplicity
   - Modular design

4. **Provide clear decision frameworks**
   - Command vs Tool vs Skill matrices
   - Visual decision trees when helpful
   - Specific criteria, not vague guidance

5. **Reference real implementations**
   - Use existing tools as examples (not hypothetical)
   - Point to blog_writer for structure
   - Reference template for starting point

6. **Emphasize delegation**
   - When to consult amplifier-cli-architect
   - When to consult command-architect
   - When to consult skill-architect
   - Make delegation boundaries clear

---

## Resource Templates for Agents

### Template: Essential References Section

```markdown
## Essential Resources

**THE Exemplar (MODEL ALL WORK AFTER THIS):**
- `@scenarios/blog_writer/` - THE canonical example for scenario tools
  - Study README.md for structure and content
  - Model HOW_TO_CREATE_YOUR_OWN.md documentation approach
  - Match code organization and quality

**Starting Point (ALWAYS BEGIN HERE):**
- `@amplifier/ccsdk_toolkit/templates/tool_template.py` - START HERE for new tools
  - Contains ALL defensive patterns
  - NEVER start from scratch
  - Modify the template, don't replace it

**Philosophy and Principles:**
- `@ai_context/IMPLEMENTATION_PHILOSOPHY.md` - Ruthless simplicity
- `@ai_context/MODULAR_DESIGN_PHILOSOPHY.md` - Bricks & studs
- `@scenarios/README.md` - Philosophy for user-facing tools
- `@DISCOVERIES.md` - Real-world failures and solutions

**Technical Foundation:**
- `@amplifier/ccsdk_toolkit/DEVELOPER_GUIDE.md` - Complete technical guide
- `@amplifier/ccsdk_toolkit/core/` - Core components
- `@amplifier/ccsdk_toolkit/sessions/` - State management
- `@amplifier/ccsdk_toolkit/defensive/` - Defensive utilities

**Pattern Examples:**
- `@amplifier/ccsdk_toolkit/examples/code_complexity_analyzer.py` - Batch processing
- `@amplifier/ccsdk_toolkit/examples/idea_synthesis/` - Multi-stage pipeline
```

### Template: Decision Framework Section

```markdown
## Decision Framework: [Type A vs Type B]

**Use Type A when:**
- ✓ [Specific criterion 1]
- ✓ [Specific criterion 2]
- ✓ [Specific criterion 3]

**Use Type B when:**
- ✓ [Specific criterion 1]
- ✓ [Specific criterion 2]
- ✓ [Specific criterion 3]

**Decision Matrix:**

| Characteristic | Type A | Type B |
|---------------|--------|--------|
| [Aspect 1] | [Type A approach] | [Type B approach] |
| [Aspect 2] | [Type A approach] | [Type B approach] |

**When uncertain:** Consult [specific-agent] for guidance.
```

### Template: Progressive Maturity Guidance

```markdown
## Tool Location (Progressive Maturity Model)

**Stage 1: ai_working/[tool_name]/ (Experimental)**
- Prototypes and rapid iteration
- Internal use only
- No documentation requirements

**Stage 2: scenarios/[tool_name]/ (Production-Ready)**

**Use when ALL criteria met:**
- ✓ Solves real user problem
- ✓ Used successfully by 2-3 real users
- ✓ Full documentation modeled after @scenarios/blog_writer/
- ✓ README + HOW_TO_CREATE_YOUR_OWN complete
- ✓ Tests and make target exist
- ✓ Serves as learning exemplar

**Stage 3: amplifier/ (Core Library)**
- Core infrastructure components
- Shared utilities (not standalone tools)
- Production-ready and stable

**Graduation Criteria:** [Specific requirements for moving between stages]
```

---

## Measuring Success

### Agent Quality Indicators

**A well-designed amplifier-aware agent:**

1. **Positions blog_writer as THE standard**
   - Not just mentioned, but emphasized as mandatory reference
   - Uses strong language: "ALL tools MUST match"
   - Appears in first 50 lines of agent description

2. **Emphasizes template-first approach**
   - "ALWAYS start with tool_template.py"
   - "NEVER start from scratch"
   - Explains why (contains ALL defensive patterns)

3. **Includes philosophy early**
   - Core philosophy section after mission (~line 25)
   - "Code for structure, AI for intelligence"
   - Ruthless simplicity principles

4. **Provides clear decision frameworks**
   - Matrices and decision trees
   - Specific criteria, not vague guidance
   - Clear delegation boundaries

5. **References real implementations**
   - Points to existing tools as examples
   - Uses blog_writer for structure
   - References template for patterns

6. **Emphasizes quality standards**
   - Documentation must match blog_writer
   - Graduation criteria are specific
   - Quality is non-negotiable

---

## Continuous Improvement

This document should evolve as:

- New patterns emerge from tool development
- Additional anti-patterns are discovered
- blog_writer or other exemplars are enhanced
- New defensive patterns are added to template
- Progressive maturity criteria are refined

**Remember:** The goal is to create agents that help others build amplifier tools that match blog_writer's quality from day one, using the template as foundation, and following the philosophy religiously.

---

**Built to ensure every agent understands and propagates amplifier excellence.**
