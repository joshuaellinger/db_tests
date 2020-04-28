"""run db test operations"""

import sys
from loguru import logger
from argparse import ArgumentParser, Namespace, RawDescriptionHelpFormatter

from database_operations import DatabaseOperations

def load_args_parser() -> ArgumentParser:

    parser = ArgumentParser(
        description=__doc__,
        formatter_class=RawDescriptionHelpFormatter)

    parser.add_argument('operation', choices=['drop', 'init', 'upgrade', 'load-sample', 'run-test', 'load-checks'],
        help='database actions')

    parser.add_argument(
        '--debug', dest='enable_debug', action='store_true', default=False,
        help='enable debug traces')

    parser.add_argument(
        '-a', dest='use_option_a', action='store_true', default=False,
        help='use option a')
    parser.add_argument(
        '-b', dest='use_option_b', action='store_true', default=False,
        help='use option b')
    parser.add_argument(
        '-c', dest='use_option_c', action='store_true', default=False,
        help='use option c')

    return parser

def main() -> None:

    # pylint: disable=no-member
    parser = load_args_parser()
    args = parser.parse_args(sys.argv[1:])

    if args.enable_debug:
        logger.info("DEBUG is on")

    option = "option-c"
    if args.use_option_a:
        option = "option-a"
        logger.info("USE OPTION A")
    if args.use_option_b:
        option = "option-b"
        logger.info("USE OPTION B")
    elif args.use_option_c:
        option = "option-c"
        logger.info("USE OPTION C")
    else:
        option = "option-c"
        logger.info("DEFAULT TO OPTION C")

    db_ops = DatabaseOperations(option)

    op = args.operation
    if op == "init":
        db_ops.init_schema()
    elif op == "upgrade":
        db_ops.upgrade_schema()
    elif op == "drop":
        db_ops.drop_all()
    elif op == "load-sample":
        db_ops.load_sample()
    elif op == "run-test":
        db_ops.run_test()
    elif op == "load-checks":
        db_ops.load_checks()
    else:
        logger.error(f"Unimplemented command: {op}")

if __name__ == "__main__":
    main()
