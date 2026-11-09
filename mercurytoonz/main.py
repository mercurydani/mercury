"""Точка входа MercuryToonz.

    MercuryToonz                     — обычный запуск
    MercuryToonz проект.mtoonz       — открыть проект
    MercuryToonz --self-test отчёт.txt — самопроверка сборки (без окон, пишет отчёт)
"""
import os
import sys


def main() -> int:
    if "--self-test" in sys.argv:
        i = sys.argv.index("--self-test")
        report = sys.argv[i + 1] if len(sys.argv) > i + 1 else None
        os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
        from mtoonz.selftest import run_selftest
        code = run_selftest(report)
        os._exit(code)  # быстрый выход без вопросов о сохранении
    from mtoonz.app import run
    return run(sys.argv)


if __name__ == "__main__":
    sys.exit(main())
