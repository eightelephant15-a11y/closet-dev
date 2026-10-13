"""consents, export_jobs, audit_log

Revision ID: 0004
Revises: 0003
"""

import sqlalchemy as sa

from alembic import op

revision = "0004"
down_revision = "0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "consents",
        sa.Column(
            "user_id", sa.Uuid(), sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
        ),
        sa.Column("analytics_opt_in", sa.Boolean()),
        sa.Column("analytics_updated_at", sa.DateTime(timezone=True)),
        sa.Column("no_ai_training", sa.Boolean(), nullable=False),
        sa.Column("ai_training_updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("location_explained_at", sa.DateTime(timezone=True)),
        sa.Column("policy_version", sa.String(32), nullable=False),
    )
    op.create_table(
        "export_jobs",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "user_id", sa.Uuid(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column(
            "status",
            sa.Enum(
                "pending", "completed", "failed", name="exportstatus", native_enum=False, length=16
            ),
            nullable=False,
        ),
        sa.Column("file_key", sa.String(255)),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True)),
        sa.Column("expires_at", sa.DateTime(timezone=True)),
    )
    op.create_index("ix_export_jobs_user_id", "export_jobs", ["user_id"])
    op.create_table(
        "audit_log",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("event", sa.String(64), nullable=False),
        sa.Column("user_ref", sa.String(64), nullable=False),
        sa.Column("at", sa.DateTime(timezone=True), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("audit_log")
    op.drop_index("ix_export_jobs_user_id", "export_jobs")
    op.drop_table("export_jobs")
    op.drop_table("consents")
