# Claude Code Agents Catalog

This catalog organizes all specialized Claude Code subagents available in this workspace. Agents are categorized by their primary domain of expertise.

## How to Use This Catalog

- **Find the right agent**: Browse categories to identify agents matching your task
- **Delegate proactively**: Use the Task tool to delegate to specialized agents
- **Create new agents**: If no existing agent fits, use subagent-architect to create one

## Development Agents

Core development and implementation agents:

- **zen-architect**: Code planning, architecture design, and review (ANALYZE/ARCHITECT/REVIEW modes)
- **modular-builder**: Primary implementation agent building code from specifications
- **bug-hunter**: Bug diagnosis and fix implementation
- **test-coverage**: Test creation and coverage improvement
- **integration-specialist**: External service integration
- **performance-optimizer**: Performance analysis and optimization
- **security-guardian**: Security analysis and vulnerability assessment
- **database-architect**: Database design and schema optimization
- **api-contract-designer**: API contract design and specification
- **contract-spec-author**: Contract and specification authoring
- **module-intent-architect**: Module purpose and intent definition
- **post-task-cleanup**: Codebase hygiene and cleanup after tasks

## Documentation Agents

Documentation maintenance and creation:

- **documentation-specialist**: Markdown documentation maintenance with project conventions
- **doc-retcon-specialist**: Documentation updates and retroactive documentation

## Design System Agents

Design and component system agents:

- **design-system-architect**: Design system architecture and planning
- **component-designer**: Component design and implementation
- **animation-choreographer**: Animation and motion design
- **art-director**: Visual design direction and aesthetics
- **layout-architect**: Layout and spatial design
- **voice-strategist**: Content voice and tone strategy
- **responsive-strategist**: Responsive design strategy

## Knowledge Synthesis Agents

Knowledge processing and synthesis:

- **content-researcher**: Content research and information gathering
- **analysis-engine**: Analysis and evaluation
- **concept-extractor**: Concept extraction from documents
- **insight-synthesizer**: Insight synthesis across documents
- **knowledge-archaeologist**: Knowledge recovery and historical context
- **visualization-architect**: Data and knowledge visualization
- **graph-builder**: Knowledge graph construction
- **pattern-emergence**: Pattern identification and emergence detection

## Investigation and Analysis Agents

Problem investigation and analysis:

- **beads-investigator**: Parallel issue investigation with the /investigate-beads command
- **ambiguity-guardian**: Ambiguity detection and clarification

## Meta Agents

Agents for creating and managing other agents:

- **subagent-architect**: Creates new Claude Code subagents
- **amplifier-cli-architect**: Amplifier CLI tool architecture and guidance
- **command-architect**: Slash command creation and architecture
- **skill-architect**: Skill creation and architecture

---

## Agent Categories Summary

- **Development**: 13 agents - Implementation, architecture, testing, security
- **Documentation**: 2 agents - Markdown docs, retroactive documentation
- **Design System**: 7 agents - Design, components, animation, layout
- **Knowledge Synthesis**: 8 agents - Research, analysis, synthesis, visualization
- **Investigation**: 2 agents - Issue investigation, ambiguity detection
- **Meta**: 4 agents - Agent/tool/command creation

**Total**: 36 specialized agents

---

## Creating New Agents

When no existing agent fits your need:

1. Use **subagent-architect** to design and create new agents
2. Follow patterns from @.claude/agents/AGENT_CREATION_GUIDELINES.md
3. Update this catalog after creating new agents
4. Test delegation via Task tool before widespread use

## Agent Delegation Pattern

```
# Good delegation
Task → zen-architect: "Design the caching architecture"
Task → modular-builder: "Implement the cache module from spec"
Task → documentation-specialist: "Update the architecture README"

# Bad: Doing it yourself when an agent exists
Edit: [modifying documentation directly]
```

Remember: **Always delegate to specialized agents when available.** They have focused expertise and follow established patterns.
