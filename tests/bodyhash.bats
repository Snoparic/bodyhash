#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Эрик Гусейнов-Соболь <Snoparic.job@mail.ru> (@Snoparic)
# SPDX-License-Identifier: MIT

BINSRC="./bodyhash"

setup() {
    # 1. Обычный файл с шапкой
    cat > "$BATS_TMPDIR/sample.h" <<'SAMPLE'
/**
 * header
 */
int main(void) { return 0; }
SAMPLE

    # 2. Файл с CRLF
    printf '/**\r\n * header\r\n */\r\nint main(void) { return 0; }\r\n' > "$BATS_TMPDIR/sample_crlf.h"

    # 3. Файл с BOM (без маркеров — чтобы BOM реально попадал в вывод)
    printf '\xEF\xBB\xBF/**\n * header\n */\nint main(void) { return 0; }\n' > "$BATS_TMPDIR/sample_bom.h"
    printf '\xEF\xBB\xBFint main(void) { return 0; }\n' > "$BATS_TMPDIR/bom_plain.h"

    # 4. Файл без маркеров
    echo "int main(void) { return 0; }" > "$BATS_TMPDIR/nomarkers.h"

    # 5. Незакрытый блок: START есть, END отсутствует
    printf '/**\nint x = 1;\nint y = 2;\n' > "$BATS_TMPDIR/unterminated.h"

    # 6. Два блока с ОДНОЙ парой маркеров
    cat > "$BATS_TMPDIR/multi.h" <<'MULTI'
/**
 * header 1
 */
int a = 1;
/**
 * header 2
 */
int b = 2;
MULTI
    printf 'int a = 1;\nint b = 2;\n' > "$BATS_TMPDIR/multi_expected.h"

    # 7. Две РАЗНЫЕ пары маркеров
    cat > "$BATS_TMPDIR/twopairs.txt" <<'PAIRS'
[META]
generated: 2099-01-01
[/META]
body1
<volatile>
junk
</volatile>
body2
PAIRS
    printf 'body1\nbody2\n' > "$BATS_TMPDIR/twopairs_expected.txt"

    # 8. Однострочный блок (START и END на одной строке)
    printf '/* inline */\nint y;\n' > "$BATS_TMPDIR/singleline.h"

    # 9. Файл с пробелами/табуляцией в конце строк
    printf 'alpha  \tbeta\t\n' > "$BATS_TMPDIR/trailing.h"
    printf 'alpha  \tbeta\n' > "$BATS_TMPDIR/trailing_clean.h"

    # 10. Отступы: таб vs 4 пробела в начале строки
    printf '\tint x = 1;\n' > "$BATS_TMPDIR/indent_tab.h"
    printf '    int x = 1;\n' > "$BATS_TMPDIR/indent_4sp.h"

    # 11. Шапка перед маркером (для exclude-preamble и strict-start)
    cat > "$BATS_TMPDIR/preamble.h" <<'PRE'
VOLATILE-TIMESTAMP
[META]
x
[/META]
body
PRE
    printf 'x\nbody\n' > "$BATS_TMPDIR/preamble_body.h"
    printf 'body\n' > "$BATS_TMPDIR/only_body.h"
}

@test "hash ignores header between markers" {
    run $BINSRC hash "$BATS_TMPDIR/sample.h" -e '/**::*/'
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "hash without -e equals plain sha256sum" {
    HASH1=$($BINSRC hash "$BATS_TMPDIR/nomarkers.h")
    HASH2=$(sha256sum "$BATS_TMPDIR/nomarkers.h" | cut -d' ' -f1)
    [ "$HASH1" = "$HASH2" ]
}

@test "excludes MULTIPLE blocks between same markers" {
    HASH1=$($BINSRC hash "$BATS_TMPDIR/multi.h" -e '/**::*/')
    HASH2=$($BINSRC hash "$BATS_TMPDIR/multi_expected.h")
    [ "$HASH1" = "$HASH2" ]
}

@test "applies two different -e pairs" {
    HASH1=$($BINSRC hash "$BATS_TMPDIR/twopairs.txt" -e '[META::[/META]' -e '<volatile::</volatile>')
    HASH2=$($BINSRC hash "$BATS_TMPDIR/twopairs_expected.txt")
    [ "$HASH1" = "$HASH2" ]
}

@test "single-line block (START and END on one line) is excluded" {
    HASH1=$($BINSRC hash "$BATS_TMPDIR/singleline.h" -e '/*::*/')
    HASH2=$(printf 'int y;\n' | sha256sum | cut -d' ' -f1)
    [ "$HASH1" = "$HASH2" ]
}

@test "hash is stable across CRLF and LF" {
    HASH1=$($BINSRC hash "$BATS_TMPDIR/sample.h" -e '/**::*/')
    HASH2=$($BINSRC hash "$BATS_TMPDIR/sample_crlf.h" -e '/**::*/')
    [ "$HASH1" = "$HASH2" ]
}

@test "hash strips BOM by default" {
    HASH1=$($BINSRC hash "$BATS_TMPDIR/sample.h" -e '/**::*/')
    HASH2=$($BINSRC hash "$BATS_TMPDIR/sample_bom.h" -e '/**::*/')
    [ "$HASH1" = "$HASH2" ]
}

@test "--no-normalize-crlf keeps CRLF" {
    HASH1=$($BINSRC hash "$BATS_TMPDIR/sample.h" -e '/**::*/')
    HASH2=$($BINSRC hash "$BATS_TMPDIR/sample_crlf.h" -e '/**::*/' --no-normalize-crlf)
    [ "$HASH1" != "$HASH2" ]
}

@test "--no-strip-bom keeps BOM" {
    # с BOM: побайтово равен обычному sha256sum того же файла
    HASH1=$($BINSRC hash "$BATS_TMPDIR/bom_plain.h" --no-strip-bom)
    [ "$HASH1" = "$(sha256sum "$BATS_TMPDIR/bom_plain.h" | cut -d' ' -f1)" ]
    # без BOM: совпадает с эталонным файлом без BOM
    HASH2=$($BINSRC hash "$BATS_TMPDIR/nomarkers.h")
    HASH3=$($BINSRC hash "$BATS_TMPDIR/bom_plain.h")
    [ "$HASH3" = "$HASH2" ]
    [ "$HASH1" != "$HASH3" ]
}

@test "hash strips BOM under UTF-8 locale (multibyte awk)" {
    # gawk в UTF-8-локали считает BOM одним символом, и наивное байтовое
    # сравнение молча ломается. Скрипт обязан сам форсировать LC_ALL=C.
    # Тест ловит регрессию даже на машине разработчика с C-локалью.
    LOC=$(locale -a 2>/dev/null | grep -im1 -E '^C\.utf-?8$')
    [ -n "$LOC" ] || LOC=$(locale -a 2>/dev/null | grep -im1 -E '^(ru_RU|en_US)\.utf-?8$')
    if [ -z "$LOC" ]; then
        skip "no UTF-8 locale available"
    fi
    HASH1=$(LC_ALL="$LOC" $BINSRC hash "$BATS_TMPDIR/bom_plain.h")
    HASH2=$(LC_ALL="$LOC" $BINSRC hash "$BATS_TMPDIR/nomarkers.h")
    HASH3=$(LC_ALL="$LOC" $BINSRC hash "$BATS_TMPDIR/bom_plain.h" --no-strip-bom)
    [ "$HASH1" = "$HASH2" ]
    [ "$HASH3" != "$HASH2" ]
}

@test "--no-strip-trailing-ws keeps trailing whitespace" {
    HASH1=$($BINSRC hash "$BATS_TMPDIR/trailing.h" --no-strip-trailing-ws)
    HASH2=$($BINSRC hash "$BATS_TMPDIR/trailing_clean.h" --no-strip-trailing-ws)
    [ "$HASH1" != "$HASH2" ]
    HASH3=$($BINSRC hash "$BATS_TMPDIR/trailing.h")
    [ "$HASH3" = "$HASH2" ]
}

@test "--strip-leading-ws normalizes indentation" {
    HASH1=$($BINSRC hash "$BATS_TMPDIR/indent_tab.h" --strip-leading-ws)
    HASH2=$($BINSRC hash "$BATS_TMPDIR/indent_4sp.h" --strip-leading-ws)
    [ "$HASH1" = "$HASH2" ]
}

@test "--indent-tabs=4 makes tab and 4-space files equal" {
    HASH1=$($BINSRC hash "$BATS_TMPDIR/indent_tab.h" --indent-tabs=4)
    HASH2=$($BINSRC hash "$BATS_TMPDIR/indent_4sp.h")
    [ "$HASH1" = "$HASH2" ]
}

@test "--exclude-preamble skips content before first START" {
    HASH1=$($BINSRC hash "$BATS_TMPDIR/preamble.h" -e '[META::[/META]' --exclude-preamble)
    HASH2=$($BINSRC hash "$BATS_TMPDIR/only_body.h")
    [ "$HASH1" = "$HASH2" ]
}

@test "--exclude-epilogue skips content after last END" {
    # блок = строки 2–4, «body» после него отрезается, шапка до блока остаётся
    HASH1=$($BINSRC hash "$BATS_TMPDIR/preamble.h" -e '[META::[/META]' --exclude-epilogue)
    HASH2=$(printf 'VOLATILE-TIMESTAMP\n' | sha256sum | cut -d' ' -f1)
    [ "$HASH1" = "$HASH2" ]
}

@test "--strict-start fails when preamble is not empty" {
    run $BINSRC hash "$BATS_TMPDIR/preamble.h" -e '[META::[/META]' --strict-start
    [ "$status" -eq 2 ]
    run $BINSRC hash "$BATS_TMPDIR/sample.h" -e '/**::*/' --strict-start
    [ "$status" -eq 0 ]
}

@test "check exits 0 on match" {
    HASH=$($BINSRC hash "$BATS_TMPDIR/sample.h" -e '/**::*/')
    run $BINSRC check "$BATS_TMPDIR/sample.h" "$HASH" -e '/**::*/'
    [ "$status" -eq 0 ]
}

@test "check prints OK on match with -v and honors -q" {
    HASH=$($BINSRC hash "$BATS_TMPDIR/sample.h" -e '/**::*/')
    run $BINSRC check "$BATS_TMPDIR/sample.h" "$HASH" -e '/**::*/' -v
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
    run $BINSRC check "$BATS_TMPDIR/sample.h" "$HASH" -e '/**::*/' -v -q
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "check exits 1 on mismatch" {
    run $BINSRC check "$BATS_TMPDIR/sample.h" "deadbeef" -e '/**::*/'
    [ "$status" -eq 1 ]
}

@test "check compares hashes case-insensitively" {
    HASH=$($BINSRC hash "$BATS_TMPDIR/sample.h" -e '/**::*/')
    UPPER=$(printf '%s' "$HASH" | tr 'a-f' 'A-F')
    run $BINSRC check "$BATS_TMPDIR/sample.h" "$UPPER" -e '/**::*/'
    [ "$status" -eq 0 ]
}

@test "check exits 2 when hash argument is missing" {
    run $BINSRC check "$BATS_TMPDIR/sample.h"
    [ "$status" -eq 2 ]
}

@test "markers command finds correct lines" {
    run $BINSRC markers "$BATS_TMPDIR/sample.h" -e '/**::*/'
    [ "$status" -eq 0 ]
    [[ "$output" == *"START /** at 1"* ]]
    [[ "$output" == *"END   */ at 3"* ]]
}

@test "markers reports single-line block correctly" {
    run $BINSRC markers "$BATS_TMPDIR/singleline.h" -e '/*::*/'
    [ "$status" -eq 0 ]
    [[ "$output" == *"START /* at 1"* ]]
    [[ "$output" == *"END   */ at 1"* ]]
}

@test "exits 3 when markers are missing" {
    run $BINSRC hash "$BATS_TMPDIR/nomarkers.h" -e '/**::*/'
    [ "$status" -eq 3 ]
    [[ "$output" == *"marker not found"* ]]
}

@test "exits 3 when END marker is missing (unterminated block)" {
    run $BINSRC hash "$BATS_TMPDIR/unterminated.h" -e '/**::*/'
    [ "$status" -eq 3 ]
}

@test "exits 3 when second marker pair is missing" {
    run $BINSRC hash "$BATS_TMPDIR/sample.h" -e '/**::*/' -e 'NOPE::NOPE2'
    [ "$status" -eq 3 ]
}

@test "exits 3 when markers missing in markers command" {
    run $BINSRC markers "$BATS_TMPDIR/nomarkers.h" -e '/**::*/'
    [ "$status" -eq 3 ]
}

@test "exits 4 when file not found" {
    run $BINSRC hash "/nonexistent/file.h" -e '/**::*/'
    [ "$status" -eq 4 ]
}

@test "exits 6 on unsupported algorithm" {
    run $BINSRC hash "$BATS_TMPDIR/sample.h" -e '/**::*/' -a fake_algo
    [ "$status" -eq 6 ]
}

@test "exits 2 on unknown option and invalid -e" {
    run $BINSRC hash "$BATS_TMPDIR/sample.h" --bogus
    [ "$status" -eq 2 ]
    run $BINSRC hash "$BATS_TMPDIR/sample.h" -e 'no_separator'
    [ "$status" -eq 2 ]
    run $BINSRC hash "$BATS_TMPDIR/sample.h" -e 'START::MID::END'
    [ "$status" -eq 2 ]
    run $BINSRC hash "$BATS_TMPDIR/sample.h" --indent-tabs=abc
    [ "$status" -eq 2 ]
}

@test "alternatives: sha512, md5, blake2b, sha3-256 give valid distinct digests" {
    H256=$($BINSRC hash "$BATS_TMPDIR/nomarkers.h" -a sha256)
    H512=$($BINSRC hash "$BATS_TMPDIR/nomarkers.h" -a sha512)
    HMD5=$($BINSRC hash "$BATS_TMPDIR/nomarkers.h" -a md5)
    HB2=$($BINSRC hash "$BATS_TMPDIR/nomarkers.h" -a blake2b)
    H3=$($BINSRC hash "$BATS_TMPDIR/nomarkers.h" -a sha3-256)
    [ ${#H256} -eq 64 ]
    [ ${#H512} -eq 128 ]
    [ ${#HMD5} -eq 32 ]
    [ ${#HB2} -eq 128 ]
    [ ${#H3} -eq 64 ]
    # перекрёстная проверка с системными утилитами
    [ "$H256" = "$(sha256sum "$BATS_TMPDIR/nomarkers.h" | cut -d' ' -f1)" ]
    [ "$H512" = "$(sha512sum "$BATS_TMPDIR/nomarkers.h" | cut -d' ' -f1)" ]
    [ "$HMD5" = "$(md5sum "$BATS_TMPDIR/nomarkers.h" | cut -d' ' -f1)" ]
    [ "$HB2"  = "$(b2sum -l 512 "$BATS_TMPDIR/nomarkers.h" | cut -d' ' -f1)" ]
    [ "$H3"   = "$(openssl dgst -sha3-256 "$BATS_TMPDIR/nomarkers.h" | awk '{print $NF}')" ]
}
