# Semantic Mappings: Cross-Language Pattern Reference

Used by scheduler and agents during porting. Target language defaults to TypeScript; notes for Python/Go where they diverge.

## Error Handling

| Rust | TypeScript | Python | Go |
|------|-----------|--------|-----|
| `Result<T, E>` | `T` (throw on error) or `{ ok: T } \| { err: E }` | `T` (raise on error) | `(T, error)` |
| `Option<T>` | `T \| undefined` | `T \| None` (`Optional[T]`) | `*T` (nil pointer) |
| `?` operator | let-it-throw (no catch) | let-it-raise | `if err != nil { return }` |
| `unwrap()` / `expect()` | `!` non-null assertion (unsafe) | direct access (crash) | unchecked dereference |
| `map_err()` / `with_context()` | wrap in new Error with `cause` | `raise X from e` | `fmt.Errorf("...: %w", err)` |
| `match` on `Result` | try/catch or if-check on union | try/except with typed exceptions | `if err != nil` + type switch |
| Custom error enum | class hierarchy or discriminated union | exception class hierarchy | sentinel errors or custom type |

**Port rule:** Prefer thrown exceptions in TS/Python unless the source explicitly models errors-as-values for control flow. In that case, use a discriminated union.

## Type Systems

| Rust | TypeScript | Python | Go |
|------|-----------|--------|-----|
| `struct` | `interface` or `type` | `@dataclass` | `struct` |
| `enum` (ADT) | discriminated union (`type \| kind` field) | `@dataclass` per variant + `Union` | interface + concrete types |
| `trait` | `interface` (no default impls) | `Protocol` (structural) or ABC | `interface` (structural) |
| `impl Trait for Struct` | class implements interface | class with protocol methods | methods on struct |
| `trait` default method | extract to helper function, call from impls | mixin or base class method | embed a helper struct |
| `impl` block (inherent) | class methods | class methods | methods with receiver |
| generics `<T: Bound>` | generics `<T extends Bound>` | generics `T: Bound` (3.12+) | generics `[T Constraint]` |
| `Box<dyn Trait>` | interface type (already dynamic) | just use the Protocol type | interface value |
| `Vec<T>` | `T[]` | `list[T]` | `[]T` |
| `HashMap<K, V>` | `Map<K, V>` or `Record<K, V>` | `dict[K, V]` | `map[K]V` |
| newtype `struct Foo(Bar)` | branded type or class wrapper | `NewType` or class wrapper | named type `type Foo Bar` |

## Concurrency

| Rust | TypeScript | Python | Go |
|------|-----------|--------|-----|
| `async fn` / `.await` | `async function` / `await` | `async def` / `await` | goroutine (no async/await) |
| `tokio::spawn` | `Promise.all([...])` | `asyncio.gather(...)` | `go func()` |
| `tokio::spawn` + `JoinHandle` | store Promise, await later | `asyncio.create_task` | `sync.WaitGroup` |
| `Mutex<T>` | usually unnecessary (cooperative async), but required with Worker Threads + SharedArrayBuffer | `asyncio.Lock` or `threading.Lock` | `sync.Mutex` |
| `Arc<T>` | not needed (GC) unless sharing across Worker Threads | GIL does not replace synchronization for shared mutable state — use `threading.Lock` | not needed (GC), but guard shared state |
| `mpsc::channel` | EventEmitter or async iterator (cooperative); `MessagePort` for Worker Threads | `asyncio.Queue` or `queue.Queue` for threads | `chan T` |
| `Send + Sync` bounds | N/A -- remove entirely | N/A | N/A |
| `tokio::select!` | `Promise.race([...])` | `asyncio.wait(FIRST_COMPLETED)` | `select {}` |

**Port rule:** Drop all Send/Sync/lifetime bounds. Default async in TS/Python is cooperative (no data races). However, Worker Threads (TS) and `threading` (Python) introduce real concurrency — synchronize shared mutable state with locks/atomics in those cases. Replace channels with events or async queues.

## Module Systems

| Rust | TypeScript | Python | Go |
|------|-----------|--------|-----|
| `mod foo;` (file = module) | `import from "./foo"` | `from . import foo` | `package foo` (dir = package) |
| `pub` | `export` | `__all__` or no underscore prefix | uppercase first letter |
| `pub(crate)` | no export (module-private) | `_` prefix convention | lowercase first letter |
| `use crate::foo::Bar` | `import { Bar } from "./foo"` | `from .foo import Bar` | `import "pkg/foo"` |
| `mod tests {}` | separate `*.test.ts` file | separate `test_*.py` file | `*_test.go` in same package |
| feature flags (`#[cfg]`) | env vars or build-time constants | env vars or settings | build tags |

## Testing

| Rust | TypeScript (Jest/Vitest) | Python (pytest) | Go |
|------|--------------------------|-----------------|-----|
| `#[test] fn name()` | `test("name", () => {})` | `def test_name():` | `func TestName(t *testing.T)` |
| `assert_eq!(a, b)` | `expect(a).toBe(b)` / `.toEqual(b)` | `assert a == b` | `if a != b { t.Fatal() }` |
| `assert!(cond)` | `expect(cond).toBeTruthy()` | `assert cond` | `if !cond { t.Fatal() }` |
| `#[should_panic]` | `expect(() => ...).toThrow()` | `pytest.raises(Exc)` | `defer recover()` pattern |
| `#[ignore]` | `test.skip(...)` | `@pytest.mark.skip` | `t.Skip()` |
| `#[cfg(test)] mod tests` | colocate `foo.test.ts` | colocate `test_foo.py` | same file `_test.go` |
| test fixtures (`setup`) | `beforeEach` / `beforeAll` | `@pytest.fixture` | `TestMain` or helper func |
| `cargo test -- --nocapture` | default (stdout visible) | `pytest -s` | `go test -v` |

## Common Gotchas

**Ownership/borrowing** vanishes in GC languages. Use `readonly` in TS for immutable intent but understand it is shallow and advisory. No direct equivalent of borrow-checker guarantees -- document invariants in specs instead.

**Lifetimes** disappear entirely. Where Rust uses lifetimes to tie data validity to scope, the GC handles it. If a lifetime encodes a meaningful relationship (e.g., "this ref must not outlive that"), document it as a contract in the spec and add a comment in the port.

**Rust macros** cannot be ported mechanically. Expand the macro mentally (or with `cargo expand`), then port the *generated* behavior. Derive macros (Serialize, Clone, Debug) map to library features (class-transformer, spread operator, toString).

**Go nil interface vs nil pointer**: a Go interface can be non-nil but contain a nil pointer, causing subtle bugs. In TS, both map to `null`/`undefined` -- the distinction evaporates. No action needed, but watch for nil-checks that test `interface == nil` vs `value == nil`.

**Python duck typing to TS strict types**: every implicit protocol in Python needs an explicit `interface` in TS. Audit all function signatures for parameters that accept "anything with method X" and define the interface.

**Rust `Clone` vs reference**: in GC languages, assignment is already by-reference for objects. Explicit `.clone()` calls often become no-ops -- but if the source clones to get an *independent copy* that is mutated separately, use structured clone or spread (`{ ...obj }`).

**String handling**: Rust strings are UTF-8 bytes; TS strings are UTF-16 code units. Emoji/multibyte indexing will differ. Use library helpers for grapheme-aware operations if the source code does byte-level string manipulation.
