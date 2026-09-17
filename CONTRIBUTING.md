# Contributing to Jotwisp

Thanks for helping keep Jotwisp fast, small, and dependable.

## Development

Use macOS 14 or later and Xcode with Swift 5.10 or later. The application has
no third-party runtime dependencies. Build with `bash scripts/build.sh` and
test with `bash scripts/test.sh`. See [release instructions](docs/RELEASING.md)
for the sandboxed Xcode target.

Keep personal drafts out of test fixtures. Use `TEXTDUMP_DATA_DIR` pointing to
an isolated directory for source-build manual testing; never commit that folder.
Do not run two builds against the same library at once.

## Pull requests

1. Describe the problem before proposing a large feature.
2. Keep the change focused. Include regression tests for persistence or search changes.
3. Run tests and check keyboard navigation, light/dark appearance, and small windows.
4. Explain how you verified the change and any remaining limitations.
5. Include only code and assets you have the right to contribute.

Contributions are licensed under the repository's MIT license. Do not add
telemetry, networking, paid dependencies, or new system permissions without
discussing the need first. Do not include signing certificates or account keys.

Be constructive and respectful. Discuss code and behavior, not personal traits.
Report private security issues by email rather than in a public issue.
