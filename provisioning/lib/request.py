from dataclasses import dataclass
from pathlib import Path
from typing import Literal

from system import Settings

REPOSITORY = Path(__file__).resolve().parents[2]
SYSTEM_RECEIPT = Path("/var/lib/osyx/provisioning/system.json")
Action = Literal["plan", "apply", "doctor", "reset"]


@dataclass(frozen=True)
class Request:
    action: Action
    module: str
    settings: Settings
    replace_home: bool
    remove: bool
    builders: bool
    replace_existing: bool
