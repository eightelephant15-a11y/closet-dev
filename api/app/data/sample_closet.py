"""Read-only sample closet for guests and the first-outfit stub."""

from typing import Any

# category: top | bottom | shoes | dress | outerwear
# dept: menswear | womenswear | unisex ; tags map to quiz "never wear" choices
SAMPLE_ITEMS: list[dict[str, Any]] = [
    {"id": "s1", "name": "White oxford shirt", "category": "top", "color": "white", "formality": 0.6, "dept": "unisex", "tags": []},
    {"id": "s2", "name": "Navy knit sweater", "category": "top", "color": "navy", "formality": 0.5, "dept": "unisex", "tags": []},
    {"id": "s3", "name": "Grey crew tee", "category": "top", "color": "grey", "formality": 0.1, "dept": "unisex", "tags": []},
    {"id": "s4", "name": "Black sleeveless blouse", "category": "top", "color": "black", "formality": 0.7, "dept": "womenswear", "tags": ["sleeveless"]},
    {"id": "s5", "name": "Olive overshirt", "category": "top", "color": "olive", "formality": 0.3, "dept": "unisex", "tags": []},
    {"id": "s6", "name": "Red cropped top", "category": "top", "color": "red", "formality": 0.2, "dept": "womenswear", "tags": ["crop_tops", "bright_colors"]},
    {"id": "s7", "name": "Dark indigo jeans", "category": "bottom", "color": "navy", "formality": 0.3, "dept": "unisex", "tags": []},
    {"id": "s8", "name": "Beige chinos", "category": "bottom", "color": "beige", "formality": 0.5, "dept": "unisex", "tags": []},
    {"id": "s9", "name": "Black tailored trousers", "category": "bottom", "color": "black", "formality": 0.8, "dept": "unisex", "tags": []},
    {"id": "s10", "name": "Khaki shorts", "category": "bottom", "color": "beige", "formality": 0.1, "dept": "unisex", "tags": ["shorts"]},
    {"id": "s11", "name": "Midi pleated skirt", "category": "bottom", "color": "brown", "formality": 0.6, "dept": "womenswear", "tags": ["skirts"]},
    {"id": "s12", "name": "White leather sneakers", "category": "shoes", "color": "white", "formality": 0.2, "dept": "unisex", "tags": []},
    {"id": "s13", "name": "Brown leather loafers", "category": "shoes", "color": "brown", "formality": 0.7, "dept": "unisex", "tags": []},
    {"id": "s14", "name": "Black block heels", "category": "shoes", "color": "black", "formality": 0.8, "dept": "womenswear", "tags": ["heels"]},
    {"id": "s15", "name": "Green wrap dress", "category": "dress", "color": "green", "formality": 0.6, "dept": "womenswear", "tags": ["dresses", "bright_colors"]},
    {"id": "s16", "name": "Navy wool blazer", "category": "outerwear", "color": "navy", "formality": 0.8, "dept": "unisex", "tags": ["suits"]},
]  # fmt: skip
