"""run db test operations"""

import sys
from loguru import logger
from argparse import ArgumentParser, Namespace, RawDescriptionHelpFormatter

from database_operations import DatabaseOperations

def load_args_parser() -> ArgumentParser:

    parser = ArgumentParser(
        description=__doc__,
        formatter_class=RawDescriptionHelpFormatter)

    parser.add_argument('operation', choices=['drop', 'init', 'upgrade', 'load-sample', 'load-checks'],
        help='database actions')

    parser.add_argument(
        '--debug', dest='enable_debug', action='store_true', default=False,
        help='enable debug traces')

    parser.add_argument(
        '--alt', dest='use_alt_schema', action='store_true', default=False,
        help='use alternative schema')

    return parser

def main() -> None:

    # pylint: disable=no-member
    parser = load_args_parser()
    args = parser.parse_args(sys.argv[1:])

    if args.enable_debug:
        logger.info("DEBUG is on")
    if args.use_alt_schema:
        logger.info("USE ALT SCHEMA")

    db_ops = DatabaseOperations(args.use_alt_schema)

    op = args.operation
    if op == "init":
        db_ops.init_schema()
    elif op == "upgrade":
        db_ops.upgrade_schema()
    elif op == "drop":
        db_ops.drop_all()
    elif op == "load-sample":
        db_ops.load_sample()
    elif op == "load-checks":
        db_ops.load_checks()
    else:
        logger.error(f"Unimplemented command: {op}")

if __name__ == "__main__":
    main()
