"""Pagination convention: ?limit=&cursor= -> {items, next_cursor}."""

from typing import Annotated

from fastapi import Query
from pydantic import BaseModel


class Page[T](BaseModel):
    items: list[T]
    next_cursor: str | None = None


class PageParams(BaseModel):
    limit: int = 25
    cursor: str | None = None


def page_params(
    limit: Annotated[int, Query(ge=1, le=100)] = 25, cursor: str | None = None
) -> PageParams:
    return PageParams(limit=limit, cursor=cursor)


def decode_cursor(cursor: str | None) -> int:
    """Opaque offset cursor. Invalid cursors are a client error."""
    if cursor is None:
        return 0
    import base64

    from app.core.errors import ApiError

    try:
        value = int(base64.urlsafe_b64decode(cursor.encode()).decode())
    except ValueError as exc:
        raise ApiError(422, "invalid_cursor", "Invalid pagination cursor") from exc
    if value < 0:
        raise ApiError(422, "invalid_cursor", "Invalid pagination cursor")
    return value


def encode_cursor(offset: int) -> str:
    import base64

    return base64.urlsafe_b64encode(str(offset).encode()).decode()
