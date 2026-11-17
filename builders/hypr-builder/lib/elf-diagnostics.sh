report_elf_dependency()
{
  local path="$1" library="$2" dependencies
  dependencies="$(ldd "$path" 2>&1 || true)"

  {
    printf '[diagnostic] dependency: %s -> %s\n' "$path" "$library"
    printf '[diagnostic] LD_LIBRARY_PATH=%s\n' "${LD_LIBRARY_PATH:-}"
    printf '%s\n' "$dependencies"
    _report_elf_dynamic_section "$path"
    _report_elf_requesters "$dependencies" "$library"
    printf '[diagnostic] loader trace (without starting the application)\n'
    LD_DEBUG=libs,files LD_TRACE_LOADED_OBJECTS=1 "$path" || true
  } >&2
}

_report_elf_dynamic_section()
{
  printf '[diagnostic] dynamic section: %s\n' "$1"
  readelf -d "$1" | sed -n '/(NEEDED)\|(RPATH)\|(RUNPATH)/p' || true
}

_report_elf_requesters()
{
  local dependencies="$1" library="$2" needed arrow resolved rest
  while read -r needed arrow resolved rest; do
    [ "$arrow" = '=>' ] && [ -f "$resolved" ] || continue
    if readelf -d "$resolved" 2>/dev/null | grep -Fq "[$library]"; then
      printf '[diagnostic] requester of %s: %s\n' "$library" "$resolved"
      _report_elf_dynamic_section "$resolved"
    fi
  done <<<"$dependencies"
}
