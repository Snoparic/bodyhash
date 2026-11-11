# SPDX-FileCopyrightText: 2026 Эрик Гусейнов-Соболь <Snoparic.job@mail.ru> (@Snoparic)
# SPDX-License-Identifier: MIT
#!/usr/bin/env bats

setup() {
    # 1. Обычный файл
    cat > "$BATS_TMPDIR/sample.h" <<'SAMPLE'
/**
 * header
 */
int main(void) { return 0; }
SAMPLE

    # 2. Файл с CRLF
    printf '/**\r\n * header\r\n */\r\nint main(void) { return 0; }\r\n' > "$BATS_TMPDIR/sample_crlf.h"

    # 3. Файл с BOM
    printf '\xEF\xBB\xBF/**\n * header\n */\nint main(void) { return 0; }\n' > "$BATS_TMPDIR/sample_bom.h"

    # 4. Файл без маркеров
    echo "int main(void) { return 0; }" > "$BATS_TMPDIR/nomarkers.h"
}

@test "hash ignores header between markers" {
    run bodyhash hash "$BATS_TMPDIR/sample.h" -e '/**::*/'
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "hash is stable across CRLF and LF" {
    HASH1=$(bodyhash hash "$BATS_TMPDIR/sample.h" -e '/**::*/')
    HASH2=$(bodyhash hash "$BATS_TMPDIR/sample_crlf.h" -e '/**::*/')
    [ "$HASH1" = "$HASH2" ]
}

@test "hash strips BOM by default" {
    HASH1=$(bodyhash hash "$BATS_TMPDIR/sample.h" -e '/**::*/')
    HASH2=$(bodyhash hash "$BATS_TMPDIR/sample_bom.h" -e '/**::*/')
    [ "$HASH1" = "$HASH2" ]
}

@test "--no-normalize-crlf keeps CRLF" {
    HASH1=$(bodyhash hash "$BATS_TMPDIR/sample.h" -e '/**::*/')
    HASH2=$(bodyhash hash "$BATS_TMPDIR/sample_crlf.h" -e '/**::*/' --no-normalize-crlf)
    [ "$HASH1" != "$HASH2" ]
}

@test "check exits 0 on match" {
    HASH=$(bodyhash hash "$BATS_TMPDIR/sample.h" -e '/**::*/')
    run bodyhash check "$BATS_TMPDIR/sample.h" "$HASH" -e '/**::*/'
    [ "$status" -eq 0 ]
}

@test "check exits 1 on mismatch" {
    run bodyhash check "$BATS_TMPDIR/sample.h" "deadbeef" -e '/**::*/'
    [ "$status" -eq 1 ]
}

@test "markers command finds correct lines" {
    run bodyhash markers "$BATS_TMPDIR/sample.h" -e '/**::*/'
    [ "$status" -eq 0 ]
    [[ "$output" == *"START /** at 1"* ]]
    [[ "$output" == *"END   */ at 3"* ]]
}

@test "exits 3 when markers are missing" {
    run bodyhash hash "$BATS_TMPDIR/nomarkers.h" -e '/**::*/'
    [ "$status" -eq 3 ]
}

@test "exits 6 on unsupported algorithm" {
    run bodyhash hash "$BATS_TMPDIR/sample.h" -e '/**::*/' -a fake_algo
    [ "$status" -eq 6 ]
}
