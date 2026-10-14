"""Inline queue for tests: runs the job immediately (with the same retry/dead-letter logic)."""

from typing import Any

from app.queue.core import JobDeps, execute


class EagerQueue:
    def __init__(self) -> None:
        self.deps: JobDeps | None = None  # set once the dependencies exist
        self.seen: set[str] = set()
        self.log: list[tuple[str, tuple[Any, ...], str]] = []  # (name, args, outcome)
        self.paused = False
        self.held: list[tuple[str, tuple[Any, ...], str | None]] = []

    async def enqueue(
        self, name: str, *args: Any, job_id: str | None = None, defer_by: float = 0
    ) -> bool:
        if job_id is not None:
            if job_id in self.seen:
                return False
            self.seen.add(job_id)
        if self.paused:  # lets a test observe the "still processing" state
            self.held.append((name, args, job_id))
            return True
        assert self.deps is not None, "EagerQueue.deps must be set"  # noqa: S101
        max_tries = self.deps.settings.queue_max_tries
        outcome = None
        for attempt in range(1, max_tries + 1):  # backoff delays are skipped in tests
            outcome = await execute(name, args, self.deps, try_number=attempt, max_tries=max_tries)
            if outcome.kind != "retry":
                break
        assert outcome is not None  # noqa: S101
        self.log.append((name, args, outcome.kind))
        return True

    async def drain(self) -> None:
        """Runs jobs held while ``paused`` (then stays unpaused)."""
        self.paused = False
        held, self.held = self.held, []
        for name, args, job_id in held:
            if job_id:
                self.seen.discard(job_id)
            await self.enqueue(name, *args, job_id=job_id)
