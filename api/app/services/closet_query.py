"""Closet listing: filters, search, sorting and keyset (cursor) pagination. Always scoped to one user."""

import base64
import json
import uuid
from dataclasses import dataclass
from datetime import datetime
from typing import Any

from sqlalchemy import ColumnElement, String, and_, false, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.sql import Select

from app.core.errors import ApiError
from app.domain.taxonomy_data import TAXONOMY
from app.models import AnalysisStatus, Availability, Garment

SORTS = ("created_desc", "created_asc", "updated_desc", "formality_asc", "formality_desc")


@dataclass(frozen=True)
class Filters:
    category: str | None = None
    subcategory: str | None = None
    color: str | None = None  # matches the primary OR the secondary colour
    season: str | None = None
    formality_min: int | None = None
    formality_max: int | None = None
    q: str | None = None
    favorite: bool | None = None
    availability: Availability | None = None
    archived: str = "exclude"  # exclude | only | include
    analysis_status: AnalysisStatus | None = None
    reviewed: bool | None = None


def _like(token: str) -> str:
    esc = token.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    return f"%{esc}%"


def _ids_matching(token: str, items: list[dict[str, Any]]) -> list[str]:
    t = token.lower().replace("-", "_")
    return [
        i["id"]
        for i in items
        if t in i["id"].lower()
        or t in i["label"].lower().replace("-", "_").replace(" ", "_")
        or t in i["label"].lower()
    ]


# Everyday words people type that are not (part of) a label in the taxonomy.
SYNONYMS: dict[str, list[str]] = {
    "tee": ["t_shirt", "long_sleeve_tee"],
    "tshirt": ["t_shirt"],
    "pants": ["trousers", "chinos", "jeans", "joggers"],
    "trainers": ["sneakers"],
    "jumper": ["sweater"],
    "sweatshirt": ["hoodie", "sweater"],
    "gown": ["cocktail_dress", "maxi_dress"],
    "heel": ["heels"],
    "shoe": ["sneakers", "boots", "loafers", "sandals", "dress_shoes", "heels", "flats"],
    "shoes": ["sneakers", "boots", "loafers", "sandals", "dress_shoes", "heels", "flats"],
}


def search_clause(q: str) -> ColumnElement[bool] | None:
    """Every word must match somewhere: a category, subcategory, colour, pattern, fit, material (by id or
    label, so "tee" finds T-shirts and "denim" finds denim) or the free-text brand / notes."""
    clauses: list[ColumnElement[bool]] = []
    subs = [s for c in TAXONOMY["categories"] for s in c["subcategories"]]
    for raw in q.split():
        tok = raw.strip().lower()
        if not tok:
            continue
        if not any(c.isalnum() for c in tok):
            return false()  # punctuation alone matches nothing (and never acts as a wildcard)
        parts: list[ColumnElement[bool]] = [
            Garment.brand.ilike(_like(tok), escape="\\"),
            Garment.notes.ilike(_like(tok), escape="\\"),
        ]
        for column, items in (
            (Garment.category, TAXONOMY["categories"]),
            (Garment.subcategory, subs),
            (Garment.pattern, TAXONOMY["patterns"]),
            (Garment.fit, TAXONOMY["fits"]),
            (Garment.material, TAXONOMY["materials"]),
        ):
            ids = _ids_matching(tok, items)
            if ids:
                parts.append(column.in_(ids))
        if tok in SYNONYMS:
            parts.append(Garment.subcategory.in_(SYNONYMS[tok]))
        color_ids = _ids_matching(tok, TAXONOMY["palette"])
        if color_ids:
            parts.append(
                or_(Garment.primary_color.in_(color_ids), Garment.secondary_color.in_(color_ids))
            )
        season_ids = _ids_matching(tok, TAXONOMY["seasons"])
        if season_ids:
            parts.extend(func.cast(Garment.seasons, String).like(f'%"{s}"%') for s in season_ids)
        clauses.append(or_(*parts))
    return and_(*clauses) if clauses else None


def apply_filters(stmt: Select[Any], user_id: uuid.UUID, f: Filters) -> Select[Any]:
    stmt = stmt.where(Garment.user_id == user_id)
    if f.archived == "exclude":
        stmt = stmt.where(Garment.archived_at.is_(None))
    elif f.archived == "only":
        stmt = stmt.where(Garment.archived_at.is_not(None))
    if f.category:
        stmt = stmt.where(Garment.category == f.category)
    if f.subcategory:
        stmt = stmt.where(Garment.subcategory == f.subcategory)
    if f.color:
        stmt = stmt.where(or_(Garment.primary_color == f.color, Garment.secondary_color == f.color))
    if f.season:
        stmt = stmt.where(func.cast(Garment.seasons, String).like(f'%"{f.season}"%'))
    if f.formality_min is not None:
        stmt = stmt.where(Garment.formality >= f.formality_min)
    if f.formality_max is not None:
        stmt = stmt.where(Garment.formality <= f.formality_max)
    if f.favorite is not None:
        stmt = stmt.where(Garment.favorite.is_(f.favorite))
    if f.availability is not None:
        stmt = stmt.where(Garment.availability == f.availability)
    if f.analysis_status is not None:
        stmt = stmt.where(Garment.analysis_status == f.analysis_status)
    if f.reviewed is not None:
        stmt = stmt.where(
            Garment.reviewed_at.is_not(None) if f.reviewed else Garment.reviewed_at.is_(None)
        )
    if f.q and (clause := search_clause(f.q)) is not None:
        stmt = stmt.where(clause)
    return stmt


def _key(sort: str) -> tuple[Any, bool]:
    """(sort expression, descending?)"""
    return {
        "created_desc": (Garment.created_at, True),
        "created_asc": (Garment.created_at, False),
        "updated_desc": (Garment.updated_at, True),
        "formality_asc": (func.coalesce(Garment.formality, 0), False),
        "formality_desc": (func.coalesce(Garment.formality, 0), True),
    }[sort]


def encode_cursor(sort: str, value: Any, gid: uuid.UUID) -> str:
    v = value.isoformat() if isinstance(value, datetime) else value
    return base64.urlsafe_b64encode(
        json.dumps({"s": sort, "v": v, "i": str(gid)}).encode()
    ).decode()


def decode_cursor(cursor: str, sort: str) -> tuple[Any, uuid.UUID]:
    try:
        data = json.loads(base64.urlsafe_b64decode(cursor.encode()))
        if data["s"] != sort:
            raise ValueError("sort changed")
        value = data["v"]
        if sort.startswith(("created", "updated")):
            value = datetime.fromisoformat(value)
        return value, uuid.UUID(data["i"])
    except (ValueError, KeyError, TypeError) as exc:
        raise ApiError(422, "invalid_cursor", "Invalid pagination cursor") from exc


async def list_garments(
    session: AsyncSession,
    user_id: uuid.UUID,
    f: Filters,
    *,
    sort: str,
    limit: int,
    cursor: str | None,
) -> tuple[list[Garment], str | None, int]:
    total = (
        await session.execute(apply_filters(select(func.count()).select_from(Garment), user_id, f))
    ).scalar_one()

    expr, desc = _key(sort)
    stmt = apply_filters(select(Garment), user_id, f)
    if cursor:
        value, last_id = decode_cursor(cursor, sort)
        after = (expr < value) if desc else (expr > value)
        same = and_(expr == value, Garment.id < last_id if desc else Garment.id > last_id)
        stmt = stmt.where(or_(after, same))
    order = [expr.desc(), Garment.id.desc()] if desc else [expr.asc(), Garment.id.asc()]
    rows = list((await session.execute(stmt.order_by(*order).limit(limit + 1))).scalars())
    next_cursor = None
    if len(rows) > limit:
        rows = rows[:limit]
        last = rows[-1]
        key_value = {
            "created": last.created_at,
            "updated": last.updated_at,
            "formality": last.formality or 0,
        }[sort.split("_")[0]]
        next_cursor = encode_cursor(sort, key_value, last.id)
    return rows, next_cursor, total
