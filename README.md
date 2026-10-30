# operation-safecracker

`operation-safecracker` provides a timed code-breaking game.

It is a Streampack extension: the server does not include it. A server has the game only when
this jar is in its `ext/` directory.

## Build

You need JDK 25 and [just](https://github.com/casey/just).

```sh
just test
```

This builds `target/operation-safecracker-<version>.jar` and runs the tests. The jar holds only
the game's own classes; the server provides `lib-extension-api`.

`streampack.version` in `pom.xml` is the server version the jar is built against, 1.16.12 or
later. Use the version of the server you run.

## Install

1. Copy the jar into the server's `ext/` directory (`/opt/streampack/ext` in the image, or
   `STREAMPACK_EXT_DIR`).
2. Recreate the server's container: `docker compose up -d --force-recreate server-streampack`.
3. In the server's startup log, find the line `Extensions from /opt/streampack/ext: jars …`. It
   names this jar.

To remove the game, delete the jar and recreate the container. Games in progress are lost.

For more about `ext/`, see Streampack's
[The `ext/` Directory](https://github.com/streampack-dev/streampack/blob/main/docs/reference/ext-directory.md).

## Operations

| Operation | Command | Purpose |
|-----------|---------|---------|
| `SafecrackerOperation` | `safecracker`, `safecracker <d0> <d1> <d2> <d3>`, `safecracker concede` | Starts, advances, and ends a 4-digit combination guessing game. |

## Behavior

Game state is stored per provenance URI through `ProvenanceStateService`. `SafecrackerTimerService` tracks active timers and cleans up timed-out games.

The operation is addressed and uses operation group `safecracker`.

## Example Flows

- Start a game:
  `safecracker`
- Make a guess:
  `safecracker 3 0 3 0`
- Give up and reveal the code:
  `safecracker concede`
