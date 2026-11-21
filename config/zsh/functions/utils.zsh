clr(){ printf "\e[%sm" "$1"; }
_err(){ clr 31; echo "❌ $1"; clr 0; }
_ok(){ clr 32; echo " $1"; clr 0; }
_note(){ clr 34; echo "ℹ️  $1"; clr 0; } 