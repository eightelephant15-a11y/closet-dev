from pydantic import BaseModel


class ConfigResponse(BaseModel):
    flags: dict[str, bool | str | int]
    policy_version: str
    privacy_policy_url: str
    terms_url: str
    min_age: int
    taxonomy_version: int
