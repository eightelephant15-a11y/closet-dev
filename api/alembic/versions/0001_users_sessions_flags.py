"""users, device_sessions, feature_flags

Revision ID: 0001
Revises:
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None

JSON = sa.JSON().with_variant(postgresql.JSONB(), "postgresql")


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("auth_uid", sa.String(128), nullable=False),
        sa.Column("email", sa.String(320)),
        sa.Column("display_name", sa.String(100)),
        sa.Column("is_anonymous", sa.Boolean(), nullable=False),
        sa.Column("locale", sa.String(16), nullable=False),
        sa.Column(
            "units",
            sa.Enum("imperial", "metric", name="units", native_enum=False, length=32),
            nullable=False,
        ),
        sa.Column("city", sa.String(120)),
        sa.Column(
            "clothing_department",
            sa.Enum(
                "menswear",
                "womenswear",
                "both",
                "everything",
                name="clothingdepartment",
                native_enum=False,
                length=32,
            ),
        ),
        sa.Column("age_confirmed_at", sa.DateTime(timezone=True)),
        sa.Column(
            "status",
            sa.Enum(
                "active",
                "pending_deletion",
                "deleted",
                name="userstatus",
                native_enum=False,
                length=32,
            ),
            nullable=False,
        ),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True)),
        sa.Column("purge_after", sa.DateTime(timezone=True)),
    )
    op.create_index("ix_users_auth_uid", "users", ["auth_uid"], unique=True)
    op.create_table(
        "device_sessions",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "user_id", sa.Uuid(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("device_id", sa.String(128), nullable=False),
        sa.Column("platform", sa.String(16), nullable=False),
        sa.Column("app_version", sa.String(32), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True)),
    )
    op.create_index("ix_device_sessions_user_id", "device_sessions", ["user_id"])
    op.create_table(
        "feature_flags",
        sa.Column("key", sa.String(100), primary_key=True),
        sa.Column("value", JSON, nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("feature_flags")
    op.drop_index("ix_device_sessions_user_id", "device_sessions")
    op.drop_table("device_sessions")
    op.drop_index("ix_users_auth_uid", "users")
    op.drop_table("users")
