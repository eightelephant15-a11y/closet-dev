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
