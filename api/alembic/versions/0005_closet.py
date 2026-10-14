"""closet: garments, garment_images, garment_corrections, analysis_jobs

Revision ID: 0005
Revises: 0004
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "0005"
down_revision = "0004"
branch_labels = None
depends_on = None

JSON = sa.JSON().with_variant(postgresql.JSONB(), "postgresql")


def _enum(name: str, *values: str) -> sa.Enum:
    return sa.Enum(*values, name=name, native_enum=False, length=24)


def upgrade() -> None:
    op.create_table(
        "garments",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "user_id", sa.Uuid(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("client_id", sa.String(64), nullable=False),
        sa.Column("category", sa.String(24)),
        sa.Column("subcategory", sa.String(32)),
        sa.Column("primary_color", sa.String(24)),
        sa.Column("secondary_color", sa.String(24)),
        sa.Column("pattern", sa.String(24)),
        sa.Column("formality", sa.Integer()),
        sa.Column("seasons", JSON),
        sa.Column("fit", sa.String(24)),
        sa.Column("material", sa.String(24)),
        sa.Column("brand", sa.String(60)),
        sa.Column("notes", sa.String(500)),
        sa.Column("favorite", sa.Boolean(), nullable=False),
        sa.Column(
            "availability",
            _enum("availability", "available", "laundry", "lent", "repair"),
            nullable=False,
        ),
        sa.Column("unavailable_until", sa.Date()),
        sa.Column("archived_at", sa.DateTime(timezone=True)),
        sa.Column("reviewed_at", sa.DateTime(timezone=True)),
        sa.Column(
            "analysis_status",
            _enum("analysisstatus", "pending", "processing", "analysing", "done", "needs_manual"),
            nullable=False,
        ),
        sa.Column("ai_fields", JSON),
        sa.Column("analysis_provider", sa.String(32)),
        sa.Column("analysis_model", sa.String(64)),
        sa.Column("analysis_version", sa.String(32)),
        sa.Column("taxonomy_version", sa.Integer(), nullable=False),
        sa.Column("is_sample", sa.Boolean(), nullable=False),
        sa.Column("sample_asset", sa.String(64)),
        sa.Column("cover_image_id", sa.Uuid()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("user_id", "client_id", name="uq_garments_user_client"),
    )
    op.create_index("ix_garments_user_category", "garments", ["user_id", "category"])
    op.create_index("ix_garments_user_color", "garments", ["user_id", "primary_color"])
    op.create_index("ix_garments_user_created", "garments", ["user_id", "created_at", "id"])
    op.create_index("ix_garments_user_updated", "garments", ["user_id", "updated_at", "id"])
    op.create_index("ix_garments_user_formality", "garments", ["user_id", "formality", "id"])

    op.create_table(
        "garment_images",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "garment_id",
            sa.Uuid(),
            sa.ForeignKey("garments.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "user_id", sa.Uuid(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column(
            "status",
            _enum("imagestatus", "awaiting_upload", "uploaded", "processing", "ready", "failed"),
            nullable=False,
        ),
        sa.Column("raw_key", sa.String(200)),
        sa.Column("full_key", sa.String(200)),
        sa.Column("thumb_s_key", sa.String(200)),
        sa.Column("thumb_m_key", sa.String(200)),
        sa.Column("thumb_l_key", sa.String(200)),
        sa.Column("width", sa.Integer()),
        sa.Column("height", sa.Integer()),
        sa.Column("bytes", sa.Integer()),
        sa.Column("content_type", sa.String(48)),
        sa.Column("source_name", sa.String(120)),
        sa.Column("sha256", sa.String(64)),
        sa.Column("error", sa.String(200)),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("uploaded_at", sa.DateTime(timezone=True)),
        sa.Column("processed_at", sa.DateTime(timezone=True)),
    )
    op.create_index("ix_garment_images_garment", "garment_images", ["garment_id"])
    op.create_index("ix_garment_images_user_id", "garment_images", ["user_id"])

    op.create_table(
        "garment_corrections",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "garment_id",
            sa.Uuid(),
            sa.ForeignKey("garments.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "user_id", sa.Uuid(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("field", sa.String(24), nullable=False),
        sa.Column("ai_value", JSON, nullable=False),
        sa.Column("user_value", JSON, nullable=False),
        sa.Column("taxonomy_version", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_garment_corrections_garment", "garment_corrections", ["garment_id"])
    op.create_index("ix_garment_corrections_user_id", "garment_corrections", ["user_id"])

    op.create_table(
        "analysis_jobs",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "garment_id",
            sa.Uuid(),
            sa.ForeignKey("garments.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "user_id", sa.Uuid(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("image_id", sa.Uuid()),
        sa.Column("kind", sa.String(16), nullable=False),
        sa.Column(
            "status",
            _enum("jobstatus", "queued", "running", "succeeded", "failed", "dead"),
            nullable=False,
        ),
        sa.Column("attempts", sa.Integer(), nullable=False),
        sa.Column("provider", sa.String(32)),
        sa.Column("model", sa.String(64)),
        sa.Column("latency_ms", sa.Integer()),
        sa.Column("input_tokens", sa.Integer()),
        sa.Column("output_tokens", sa.Integer()),
        sa.Column("cost_usd", sa.Float()),
        sa.Column("error", sa.String(300)),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("finished_at", sa.DateTime(timezone=True)),
    )
    op.create_index("ix_analysis_jobs_user_created", "analysis_jobs", ["user_id", "created_at"])


def downgrade() -> None:
    op.drop_index("ix_analysis_jobs_user_created", "analysis_jobs")
    op.drop_table("analysis_jobs")
    op.drop_index("ix_garment_corrections_user_id", "garment_corrections")
    op.drop_index("ix_garment_corrections_garment", "garment_corrections")
    op.drop_table("garment_corrections")
    op.drop_index("ix_garment_images_user_id", "garment_images")
    op.drop_index("ix_garment_images_garment", "garment_images")
    op.drop_table("garment_images")
    for ix in ("formality", "updated", "created", "color", "category"):
        op.drop_index(f"ix_garments_user_{ix}", "garments")
    op.drop_table("garments")
