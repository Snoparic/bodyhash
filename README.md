# bodyhash

[![Forgejo](https://img.shields.io/badge/Forgejo-main-blue)](https://git.snoparic.su/snoparic/bodyhash)
[![GitHub](https://img.shields.io/badge/GitHub-mirror-black)](https://github.com/Snoparic/bodyhash)
[![GitFlic](https://img.shields.io/badge/GitFlic-mirror-green)](https://gitflic.ru/project/snoparic/bodyhash)



Утилита для вычисления хеша тела файла с исключением заданных областей (например, шапок с метаданными).

По умолчанию `bodyhash` нормализует концы строк (CRLF -> LF), удаляет UTF-8 BOM и убирает пробелы в конце строк. Это гарантирует, что хеш не изменится при переносе репозитория между Windows и Linux.

## Установка

Требуются права root для записи в `/usr/local`:

    sudo make install PREFIX=/usr/local

## Использование

    bodyhash <команда> [аргументы] [опции]

### Команды:
*   `hash <file>` — вывести хеш тела файла.
*   `check <file> <hash>` — сравнить хеш тела файла с ожидаемым (код возврата 0, если совпадает).
*   `markers <file>` — показать номера строк, где найдены указанные маркеры.

### Основные опции:
*   `-e, --exclude "НАЧАЛО::КОНЕЦ"` — исключить блок (можно повторять).
*   `-a, --algo <algo>` — алгоритм (`sha256` по умолчанию, также `sha512`, `sha3-256`, `sha3-512`, `blake2b`, `blake2s`, `md5`).
*   `--no-normalize-crlf` — не трогать концы строк.
*   `--no-strip-bom` — оставить BOM.
*   `--no-strip-trailing-ws` — оставить пробелы в конце строк.
*   `--strip-leading-ws` — удалить пробелы в начале строк.
*   `--indent-tabs=N` — заменить табы на N пробелов.
*   `--exclude-preamble` — игнорировать всё до первого маркера.
*   `--exclude-epilogue` — игнорировать всё после последнего маркера.
*   `--strict-start` — требовать, чтобы маркер `START` был на первой строке.

### Примеры:

    # Хеш тела C-файла (игнорируя шапку между /** и */)
    bodyhash hash file.c -e '/**::*/'

    # Проверка
    bodyhash check file.c 1857616f15bd53f72c1733a1839421116c7bbb50579f2cdb9ceca9adfcd30fda -e '/**::*/'


---

## Зеркала

Основной репозиторий: [git.snoparic.su](https://git.snoparic.su/snoparic/bodyhash)

Зеркала:
- [GitHub](https://github.com/Snoparic/bodyhash)
- [GitFlic](https://gitflic.ru/project/snoparic/bodyhash)
