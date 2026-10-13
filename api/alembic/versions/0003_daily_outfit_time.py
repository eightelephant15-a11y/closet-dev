"""users.daily_outfit_time

Revision ID: 0003
Revises: 0002
"""

import sqlalchemy as sa

from alembic import op

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("daily_outfit_time", sa.String(5)))


def downgrade() -> None:
    with op.batch_alter_table("users") as batch:
        batch.drop_column("daily_outfit_time")
