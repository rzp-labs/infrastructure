---
description: Investigate issues in parallel, find patterns, propose solutions
argument-hint: [project-path] or [filtering options]
allowed-tools: Bash, Read, Glob, Grep, Task, TodoWrite
---

# Investigate Beads Issues

Automatically investigates open beads issues in parallel, identifies patterns across investigations, and proposes meta-issues when one solution solves multiple problems.

## Quick Start

```bash
# In project with beads tracker
/investigate-beads

# Specify project path
/investigate-beads /path/to/project

# Natural language filtering
/investigate-beads priority 1 issues
/investigate-beads max 5 issues
/investigate-beads REPL issues
```

## Arguments

```
$ARGUMENTS: Optional project path and/or filtering criteria in natural language
```

**Project Path**:
- Starts with `/` or `./` → Treated as project root path
- Otherwise → Uses current working directory
- Must contain: `AGENTS.md` file and `.beads/` directory

**Filtering Examples**:
- `priority 1` or `P1` → Only priority 1 issues
- `max 5` or `limit 5` → Limit to 5 issues
- `labels repl,agent` → Filter by labels
- `REPL` or `agent` → Keywords to match in titles

**Combined**:
```
/investigate-beads /path/to/project priority 1 max 5
/investigate-beads REPL and agent issues
```

## What Happens

This command follows a systematic process:

### 1. Discovery
- Finds project root (AGENTS.md file)
- Locates `.beads/` directory and database
- Reads project philosophy from AGENTS.md
- Lists open uninvestigated issues (no 🔍 marker)

### 2. Parallel Investigation
**Launches beads-investigator agents in parallel** (one per issue, all in single message):
- Each agent investigates independently
- Each identifies root causes and proposes solutions
- Each checks philosophy alignment
- Each identifies related issues

### 3. Meta-Analysis
**Synthesizes findings across all investigations**:
- Detects shared root causes
- Identifies when one solution solves multiple issues
- Maps file/module clusters
- Discovers dependency chains

### 4. Meta-Issue Creation
**Automatically creates meta-issues when**:
- ≥3 issues share the same solution → Create unified implementation task
- ≥2 issues stem from same root cause → Fix cause, not symptoms
- Solution X enables solutions Y, Z → Create enabling task
- Multiple issues fixed by same refactor → Philosophy-driven improvement

### 5. Beads Updates
**Updates issue tracker**:
- Adds investigation markers to all issues
- Creates meta-issues with comprehensive designs
- Links dependencies (blocks, enables, relates)
- Exports to JSONL for git tracking

### 6. Comprehensive Report
**Delivers synthesis**:
- Individual investigation summaries
- Meta-patterns detected
- Meta-issues created
- Relationship graph
- Implementation priorities
- Next steps

## Example Output

```markdown
# 🔍 BEADS INVESTIGATION REPORT

Issues Investigated: 8
Meta-Issues Created: 1

## Meta-Pattern: Unified REPL Solution
Issues: bd-7, bd-8, bd-9, bd-10
Shared Solution: Adopt prompt_toolkit
Benefit: 4 issues → 1 implementation (~4 hours vs ~12 hours)

## Meta-Issue Created
bd-19: Modernize REPL with prompt_toolkit
  Solves: bd-7, bd-8, bd-9, bd-10
  Priority: P1
  Links: All 4 issues marked "See bd-19 for implementation"

## Recommendations
Immediate: Implement bd-19 (highest ROI - solves 4 issues)
```

## For Claude: Implementation Details

### Discovery Phase

**Find project root**:
```bash
# Parse arguments
args="$ARGUMENTS"

# Extract project path (starts with / or ./)
if [[ "$args" =~ ^[./] ]]; then
  project_root=$(echo "$args" | grep -oE '^[^ ]+')
else
  project_root="$PWD"
fi

# Verify structure
if [[ ! -f "$project_root/AGENTS.md" ]]; then
  echo "Error: No AGENTS.md found in $project_root"
  exit 1
fi

if [[ ! -d "$project_root/.beads" ]]; then
  echo "Error: No .beads/ directory found in $project_root"
  exit 1
fi

# Find database
db_file=$(ls "$project_root/.beads"/*.db 2>/dev/null | head -1)
```

**Read project context**:
```bash
# Always read AGENTS.md first for project philosophy
Read @$project_root/AGENTS.md
```

**Parse filtering from arguments**:
```bash
# Extract max issues (default: 10)
max_issues=10
if [[ "$args" =~ max[[:space:]]+([0-9]+) ]]; then
  max_issues="${BASH_REMATCH[1]}"
elif [[ "$args" =~ limit[[:space:]]+([0-9]+) ]]; then
  max_issues="${BASH_REMATCH[1]}"
fi

# Extract priority (P0, P1, P2, P3)
priority=""
if [[ "$args" =~ [Pp]([0-3]) ]]; then
  priority="${BASH_REMATCH[1]}"
elif [[ "$args" =~ priority[[:space:]]+([0-3]) ]]; then
  priority="${BASH_REMATCH[1]}"
fi

# Extract labels or keywords
labels=""
if [[ "$args" =~ labels[[:space:]]+([a-zA-Z,]+) ]]; then
  labels="${BASH_REMATCH[1]}"
else
  # Keywords in title search
  keywords=$(echo "$args" | grep -oE '\b[A-Z][A-Z]+\b|\brepl\b|\bagent\b' | tr '\n' ' ')
fi
```

**Query uninvestigated issues**:
```bash
# List open issues
bd --db "$db_file" list --status open > /tmp/beads_open.txt

# Filter out investigated (have 🔍 marker)
grep -v "🔍 INVESTIGATION COMPLETE" /tmp/beads_open.txt > /tmp/beads_uninvestigated.txt

# Apply filters
if [[ -n "$priority" ]]; then
  grep "\[P$priority\]" /tmp/beads_uninvestigated.txt > /tmp/beads_filtered.txt
else
  cp /tmp/beads_uninvestigated.txt /tmp/beads_filtered.txt
fi

# Apply keyword filter
if [[ -n "$keywords" ]]; then
  grep -i "$keywords" /tmp/beads_filtered.txt > /tmp/beads_final.txt
else
  cp /tmp/beads_filtered.txt /tmp/beads_final.txt
fi

# Limit to max_issues
head -n "$max_issues" /tmp/beads_final.txt > /tmp/beads_to_investigate.txt
```

### Task Planning

Use **TodoWrite** to track investigation:

```markdown
Tasks to track:
[ ] Discover project structure
[ ] Query uninvestigated issues
[ ] Launch parallel beads-investigator agents
[ ] Collect investigation reports
[ ] Synthesize findings (meta-analysis)
[ ] Detect meta-patterns
[ ] Create meta-issues
[ ] Update beads database
[ ] Link dependencies
[ ] Generate comprehensive report
```

### Parallel Investigation

**CRITICAL: Launch ALL agents in SINGLE message**

For each issue in results, create ONE Task call:

```
Task beads-investigator: "Investigate [issue-id]: [title]

Project: $project_root
Read: @$project_root/AGENTS.md

Issue Details:
[from: bd --db $db_file show [issue-id]]

Related Context:
[List any known related issues from same query]

Your Mission:
- Identify root cause with evidence
- Propose 2-4 solution options
- Verify philosophy alignment
- Identify related issues
- Estimate implementation effort
"
```

**Example for 3 issues**:

```
# ONE message with THREE Task calls:

Task beads-investigator: "Investigate bd-7: REPL editing
Project: /path/to/project
Read: @/path/to/project/AGENTS.md
Issue: [details]
Related: bd-8, bd-9 also involve REPL"

Task beads-investigator: "Investigate bd-8: Ctrl-C exits
Project: /path/to/project
Read: @/path/to/project/AGENTS.md
Issue: [details]
Related: bd-7, bd-9 also involve REPL"

Task beads-investigator: "Investigate bd-9: Paste breaks
Project: /path/to/project
Read: @/path/to/project/AGENTS.md
Issue: [details]
Related: bd-7, bd-8 also involve REPL"
```

### Meta-Analysis

After all agents return, analyze patterns:

**Shared Root Causes**:
```
Pattern: Multiple issues stem from same problem
Example: bd-7, bd-8, bd-9 all identify "Rich console.input() limitations"
→ Root cause clustering detected
```

**Shared Solutions**:
```
Pattern: Multiple issues propose same solution
Example: bd-7, bd-8, bd-9, bd-10 all propose "Adopt prompt_toolkit"
→ Unified solution opportunity detected
```

**File Clustering**:
```
Pattern: Multiple issues affect same files
Example: bd-7, bd-8, bd-9 all affect "main.py:1413"
→ Module hotspot detected
```

**Philosophy Alignment**:
```
Pattern: Multiple issues violate same principle
Example: bd-7, bd-8 violate "Library vs Custom" principle
→ Systematic improvement opportunity
```

### Meta-Issue Creation

**When to create meta-issue**:

1. **Unified Solution** (≥3 issues, same solution):
   ```
   Title: [Solution description] (solves bd-X, bd-Y, bd-Z)
   Type: task
   Priority: [Highest among solved issues]
   Design: [Synthesized from individual investigations]
   ```

2. **Shared Root Cause** (≥2 issues, same cause):
   ```
   Title: Fix [root cause] (addresses bd-X, bd-Y)
   Type: task
   Design: [Fix cause, not symptoms]
   ```

3. **Enabling Solution** (X enables Y, Z):
   ```
   Title: [Enabling solution] (enables bd-Y, bd-Z)
   Type: feature
   Design: [Capability that unblocks others]
   ```

**Create and link**:
```bash
# Create meta-issue
meta_id=$(bd --db "$db_file" create "[Meta-issue title]" \
  --type task \
  --priority [P0-P3] \
  --design "[Comprehensive design]" | grep -oE 'bd-[0-9]+')

# Link all solved issues
for issue in bd-X bd-Y bd-Z; do
  bd --db "$db_file" dep add "$meta_id" "$issue" --type blocks
done
```

### Update Beads

**Mark all investigated issues**:

```bash
for issue in [all investigated]; do
  bd --db "$db_file" update "$issue" --notes "🔍 INVESTIGATION COMPLETE - See $meta_id for implementation

[Full investigation report from agent]"
done
```

**Export to JSONL**:
```bash
bd --db "$db_file" export -o "$project_root/.beads/[project].jsonl"
```

### Report Generation

Deliver comprehensive synthesis:

```markdown
# 🔍 BEADS INVESTIGATION REPORT

**Date**: [timestamp]
**Project**: [from AGENTS.md]
**Issues Investigated**: [count]
**Meta-Issues Created**: [count]

## Summary
[High-level findings]

## Individual Investigations
[One per issue with root cause, solution, status]

## Meta-Patterns Detected
[Shared causes, solutions, files, principles]

## Meta-Issues Created
[Title, solves, approach, benefits, effort]

## Relationship Graph
[Visual text representation]

## Updated Issues
[What was marked/linked]

## Recommendations
### Immediate Actions
[Prioritized list]

### Implementation Priority
[High/Medium/Low with justification]

## Next Steps
1. Review findings
2. Approve meta-issues
3. Choose implementation priority
4. Delegate to implementation agents
```

## Error Handling

**No beads found**:
```
Error: No .beads/ directory found in [path]

This command requires a beads issue tracker.
Initialize with: bd init
```

**No AGENTS.md**:
```
Warning: No AGENTS.md found, proceeding with generic investigation

Recommendation: Create AGENTS.md to document project philosophy
```

**No uninvestigated issues**:
```
All [N] open issues already investigated (have 🔍 marker)

Options:
- Re-investigate: [list issue IDs]
- Check closed issues: bd list --status closed
```

**Agent failures**:
- Continue with other investigations
- Report failed issues separately
- Don't block on single failure

## Philosophy Alignment

This command embodies:

**Ruthless Simplicity**:
- Natural language arguments (not complex flags)
- Automatic discovery (not manual configuration)
- Clear what happens (not hidden magic)

**Specialization**:
- One agent per issue (focused investigation)
- Command orchestrates (doesn't duplicate agent work)

**Context Efficiency**:
- Agents fork context (work independently)
- Agents return essentials (not full analysis in main thread)
- Main thread synthesizes (pattern detection across reports)

**Pattern Recognition**:
- Meta-analysis finds emergent solutions
- One implementation → Multiple issues solved

**Modular Design**:
- Each investigation is self-contained
- Meta-issues are clear specifications
- Human decides, AI implements

## Additional Context

$ARGUMENTS
