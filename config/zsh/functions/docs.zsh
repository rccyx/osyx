_docs_verify_pdfa() {
  local subtype=$(pdfinfo "$1" 2>/dev/null | grep "PDF subtype" | awk '{print $NF}')

  if [[ -n "$subtype" ]]; then
    _ok "Archival Verified: $subtype"
  else
    _warn "Standard PDF (No Archival Subtype Found)"
  fi
}

_docs_file_preview() {
  local file="$1"

  file "$file" 2>/dev/null

  if command -v exiftool >/dev/null 2>&1; then
    exiftool "$file" 2>/dev/null | head -80
  else
    head -80 "$file" 2>/dev/null
  fi
}

# ------- Renaming Core (The Naming Protocol) -------

docs.rename() {
  local file=$(fd -t f --no-ignore --hidden . | fzf --prompt="🏷️  Standardize File ⇢ " --preview '_docs_file_preview {}')
  [[ -z "$file" ]] && return 0

  local dir=$(dirname "$file")

  # 1. Date Selection
  local today=$(date +%Y-%m-%d)
  local date_sel=$(printf "Today ($today)\nManual Entry" | fzf --prompt="📅 Date ⇢ " | awk '{print $1}')
  local final_date=$today

  if [[ "$date_sel" == "Manual" ]]; then
    printf "📅 Enter Date (YYYY-MM-DD) ⇢ "
    read final_date
  fi

  final_date=$(echo "$final_date" | tr -d ' ')

  # 2. Name Selection (Mandatory, Non-Empty)
  local final_name=""

  while [[ -z "$final_name" ]]; do
    printf "📛 Document Name ⇢ "
    read raw_name

    final_name=$(echo "$raw_name" | tr '[:lower:]' '[:upper:]' | tr ' ' '_')

    if [[ -z "$final_name" ]]; then
      _err "Name cannot be empty. Try again."
    fi
  done

  # 3. Status (Hard-coded Schema)
  local final_status=$(printf "FINAL\nFILED\nPENDING\nDRAFT\nVERIFIED" | fzf --prompt="🚦 Status ⇢ ")
  [[ -z "$final_status" ]] && final_status="DRAFT"

  local extension="${file##*.}"
  local new_name="${final_date}-${final_name}-${final_status}.${extension}"
  local new_path="${dir}/${new_name}"

  _note "Target: $new_path"

  if [[ "$file" == "$new_path" ]]; then
    _warn "Names are identical. Skipping."
    return 0
  fi

  if mv -i "$file" "$new_path"; then
    _ok "Standardized: $new_path"
  else
    _err "Rename failed."
  fi
}

# ------- Open/View Core -------

docs.view() {
  local file=$(fd -e pdf -e PDF -t f --no-ignore --hidden . | fzf --prompt="📖 View PDF ⇢ " --preview 'exiftool {}')
  [[ -z "$file" ]] && return 0

  _note "Opening $file in Okular..."
  okular "$file" >/dev/null 2>&1 &!
}

# ------- OCR Core -------

docs.ocr() {
  local file=$(fd -e pdf -e PDF -t f --no-ignore --hidden . | fzf --prompt="⚖️ Pick Document ⇢ " --preview 'exiftool {}')
  [[ -z "$file" ]] && return 0

  local mode=$(printf "scan (Paper/Standard)\narchive (Digital Books/Legalize)\nforce (Nuke & Re-OCR)\nheavy (Forensic Clean)" | fzf --prompt="⚙️ Select Mode ⇢ " | awk '{print $1}')
  [[ -z "$mode" ]] && return 0

  local dir=$(dirname "$file")
  local base="${$(basename "$file")%.*}"
  local output="${dir}/${base}_ocr.pdf"
  local flags=("--output-type" "pdfa" "--optimize" "1" "--jobs" "4")

  case "$mode" in
    "scan")
      _note "Mode: Paper Scan (Deskew + Clean + Skip existing text)"
      flags+=("--deskew" "--clean" "--rotate-pages" "--skip-text")
      ;;

    "archive")
      _note "Mode: Digital Archiving (Ensures PDF/A without nuking vector text)"
      flags+=("--skip-text")
      ;;

    "force")
      _note "Mode: Forced Recovery (Nuking existing bad text layers)"
      flags+=("--force-ocr" "--deskew" "--clean")
      ;;

    "heavy")
      _note "Mode: Forensic (Maximum despeckle + Clean)"
      flags+=("--deskew" "--clean" "--clean-final" "--skip-text")
      ;;
  esac

  if ocrmypdf "${flags[@]}" "$file" "$output"; then
    _ok "Saved: $output"
    _docs_verify_pdfa "$output"

    printf "❓ Open in Okular now? (y/N) "
    read -k 1 resp
    echo

    [[ "$resp" =~ ^[Yy]$ ]] && okular "$output" >/dev/null 2>&1 &!
  else
    _err "OCR Aborted."
    return 1
  fi
}

# ------- Search Core -------

docs.search() {
  printf "🔍 Search Query ⇢ "
  read query

  [[ -z "$query" ]] && return 0

  _note "Searching PDFs..."

  local result=$(fd -e pdf -e PDF -t f --no-ignore --hidden . | xargs pdfgrep -inH "$query" 2>/dev/null | fzf --prompt="📄 Results ⇢ ")

  if [[ -n "$result" ]]; then
    local file=$(echo "$result" | cut -d: -f1)
    local page=$(echo "$result" | cut -d: -f2)

    _note "Opening $file to page $page..."
    okular "$file" -p "$page" >/dev/null 2>&1 &!
  fi
}

# ------- Info/Verify Core -------

docs.info() {
  local file=$(fd -e pdf -e PDF -t f --no-ignore --hidden . | fzf --prompt="ℹ️ Inspect PDF ⇢ ")
  [[ -z "$file" ]] && return 0

  _note "Forensic Details: $file"

  exiftool "$file" | grep -E "File Name|Page Count|Author|Create Date|Modify Date|Producer" || _warn "exiftool info failed."
  _docs_verify_pdfa "$file"
}

# ------- Dispatcher -------

docs() {
  local action=$(printf "view (Open PDF)\nocr (Digitize/Legalize)\nsearch (Inside PDFs)\ninfo (Inspect Metadata)\nrename (Standardize Name)\nhelp" | fzf --prompt="📚 Document Action ⇢ " | awk '{print $1}')

  case "$action" in
    "view")   docs.view ;;
    "ocr")    docs.ocr ;;
    "search") docs.search ;;
    "info")   docs.info ;;
    "rename") docs.rename ;;
    "help")   docs.help ;;
  esac
}

# ------- Documentation -------

docs.help() {
  cat << EOF
  DOCS SYSTEM
  --------------------------------------------------

  COMMANDS:
    docs view   : Pick a PDF and open in Okular.
    docs ocr    : Digitize scans or legalize digital books.
    docs search : Search PDF text and jump to specific pages.
    docs info   : View PDF metadata and verify PDF/A status.
    docs rename : Standardize any regular file name.

  BEHAVIOR:
    - Searches ALL depths, no max-depth cap.
    - Git-ignored and hidden files are fully visible.
    - Rename works on any regular file and keeps the original extension.
    - Rename keeps files in their original directory.
    - OCR output lands next to the source file.
    - No spaces. UPPER_CASE. Pure terminal efficiency.
  --------------------------------------------------
EOF
}
