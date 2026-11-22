import sys
import traceback

COULD_NOT_RUN = 3


def guarded_main(argv: list[str]) -> int:
    try:
        import cli

        return cli.main(argv)
    except Exception:
        traceback.print_exc()
        print("ERROR: the audit engine failed unexpectedly; nothing was proven clean", file=sys.stderr)
        return COULD_NOT_RUN


if __name__ == "__main__":
    sys.exit(guarded_main(sys.argv[1:]))
