# hex only
genpass_easy() {
    openssl rand -hex 16
}

# mid
genpass_mid() {
    openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 32
}

genpass_hard() {
    openssl rand -base64 48 | tr -dc 'A-Za-z0-9!@#$%^&*()_+[]{}<>?,.:;' | head -c 32
}
