# Admin Config Tables History

## Earlier launch and branch milestones

- Earlier raw launches failed for expected reasons such as missing wrapper-managed secret injection or prompt-file placement.
- A later wrapper launch verified that Codex interactive sessions were starting correctly on the intended image.
- Historical implementation work on the branch was merged into `origin/roster` as `8fd5779`.
- Upstream `roster` later gained prompt commit `841131f` to require a stabilization pass before continuing slice `7.1`.

## Runtime-debug sequence that still matters

The runtime investigation moved through these concrete failure modes:

1. cache reachability and writable Nix paths
2. daemon socket creation and relocation
3. user handoff (`su` then `runuser`)
4. final host-side discovery that the container is forced to run as non-root

Recent weavers and their useful takeaways:

- `019cb764-f996-7789-bb4b-200f5711bb1d`
  - socket relocation moved the failure forward to the user handoff step
- `019cb76c-8f1c-7e27-9ae5-b130a1cff864`
  - host logs showed `exec: su: not found`
- `019cb785-9fd8-7432-9193-119b35a83bac`
  - host logs showed `runuser: may not be used by non-root users`
  - pod spec inspection confirmed `runAsNonRoot: true`, making the daemon-backed root handoff design incompatible with the current pod shape

## Current conclusion

Further image-only iteration on root-based daemon startup is not useful unless the Loom pod security context changes or the image is redesigned to work entirely as non-root.
