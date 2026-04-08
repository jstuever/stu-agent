# implement-spec

Implement a technical specification from a local file.

## Usage

```
/implement-spec <file>
```

## Arguments

- `<file>`: A path to a spec file (e.g., .claude/spec.md)

## Description

This command automates the implementation of a technical specification by:
1. Reading the specification from a local file.
2. Analyzing the requirements, acceptance criteria, and implementation steps
3. Implementing the feature following the outlined steps
4. Running tests to validate the implementation

## Implementation Instructions

When this command is invoked:

### 1. Read the Specification

- Use the Read tool to read the specification file
- Parse the specification structure

### 2. Analyze the Specification

Extract and understand:
- **User Story / Context**: What problem is being solved?
- **Acceptance Criteria**: What are the success conditions?
- **Technical Requirements**: What are the constraints and requirements?
- **Implementation Steps**: What is the recommended implementation approach?
- **Reference Code / Patterns**: What existing code should be used as a template?
- **Error Handling & Edge Cases**: What error conditions must be handled?
- **Testing Strategy**: What tests need to be written?

### 3. Plan the Implementation

- Review the implementation steps provided in the spec
- Identify all files that need to be created or modified
- Read reference files mentioned in the specification to understand patterns
- Create a brief implementation plan outlining the order of operations

### 4. Execute the Implementation

Follow the implementation steps in order:

1. **Read reference code first**: Before creating new files, read the reference code/patterns mentioned to understand the coding style and structure
2. **Create files in logical order**: Implement shared utilities first, then build commands that use them
3. **Follow the specification exactly**: Implement each step as outlined in the spec
4. **Match existing patterns**: Use the same coding style, error handling patterns, and structure as reference code
5. **Implement error handling**: Add all error cases mentioned in the spec
6. **Add appropriate logging**: Include user-friendly messages for success and error cases
7. **Stage the changes**: Stage, but do not commit the changes

### 5. Implement Tests

Based on the testing strategy in the spec:
- Create or update test files following existing test patterns
- Write unit tests for new functions
- Add test cases for error conditions and edge cases
- Ensure tests cover all acceptance criteria

### 6. Validate the Implementation

- Run relevant tests using `go test` or the appropriate test command
- Fix any compilation errors or test failures
- Verify that all acceptance criteria are met

## Error Handling

- If the local file doesn't exist, suggest checking the path or looking in common directories like `.specs/`
- If the specification is missing required sections, ask the user for clarification
- If tests fail, analyze the failures and attempt to fix them before reporting

## Example

```bash
/implement-spec .claude/spec.md
```

## Notes

- This command assumes the specification follows a structured format with clear implementation steps
- The command will read and follow reference code patterns to ensure consistency
- All changes should be validated with tests before completion
- The command may ask clarifying questions if the specification is ambiguous
