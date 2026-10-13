"""Stub place data behind the PlacesService seam (US cities only, no geocoding)."""

US_CITIES = [
    "New York, NY", "Los Angeles, CA", "Chicago, IL", "Houston, TX", "Phoenix, AZ",
    "Philadelphia, PA", "San Antonio, TX", "San Diego, CA", "Dallas, TX", "San Jose, CA",
    "Austin, TX", "Jacksonville, FL", "San Francisco, CA", "Columbus, OH", "Seattle, WA",
    "Denver, CO", "Boston, MA", "Nashville, TN", "Portland, OR", "Atlanta, GA",
    "Miami, FL", "Minneapolis, MN", "New Orleans, LA", "Salt Lake City, UT", "Washington, DC",
]  # fmt: skip


def autocomplete(query: str, limit: int = 5) -> list[str]:
    q = query.strip().lower()
    if len(q) < 2:
        return []
    starts = [c for c in US_CITIES if c.lower().startswith(q)]
    contains = [c for c in US_CITIES if q in c.lower() and c not in starts]
    return (starts + contains)[:limit]
