from pathlib import Path

from core.state import ErrorTag, ProvisionError


def intel() -> tuple[str, ...]:
    cpu = Path("/proc/cpuinfo").read_text()
    groups = ["intel-cpu"] if "GenuineIntel" in cpu else []
    for device in Path("/sys/bus/pci/devices").glob("*"):
        try:
            vendor = (device / "vendor").read_text().strip()
            kind = (device / "class").read_text().strip()
        except OSError:
            continue
        if vendor != "0x8086":
            continue
        if kind.startswith("0x03"):
            groups.append("intel-gpu")
        elif kind.startswith("0x0280"):
            groups.append("intel-wifi")
        elif kind.startswith("0x0401") or kind.startswith("0x0403"):
            groups.append("intel-audio")
    if not groups:
        raise ProvisionError(
            ErrorTag.HOST,
            "OSYX supplies only Intel firmware; use your vendor's Debian instructions",
        )
    return tuple(dict.fromkeys(groups))
