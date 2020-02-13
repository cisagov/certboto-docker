#!/usr/bin/env python3

"""Rebuild the live certificate symlinks in a certbot configuration.

Usage:
  rebuild-symlinks.py [--log-level=LEVEL] <cerbot-config-dir>
  rebuild-symlinks.py (-h | --help)

Options:
  -h --help              Show this message.
  -l --log-level=LEVEL      If specified, then the log level will be set to
                         the specified value.  Valid values are "debug", "info",
                         "warning", "error", and "critical". [default: warning]
"""

# Standard Python Libraries
import hashlib
import logging
import os
import sys

# Third-Party Libraries
import docopt

LIVE_DIR = "live"
ARCHIVE_DIR = "archive"
PEM_EXT = ".pem"


def live_domains(config_root):
    """Yield directory entries for live domains."""
    live_dir = os.path.join(config_root, LIVE_DIR)
    with os.scandir(live_dir) as it:
        for entry in it:
            if entry.is_file():
                continue
            yield entry


def hash_archive(archive_domain_dir):
    """Create a map of hashes to directory entries."""
    hash_map = dict()
    with os.scandir(archive_domain_dir) as it:
        for entry in it:
            with open(entry.path, "rb") as f:
                hash = hashlib.sha256(f.read()).hexdigest()
            if hash not in hash_map or hash_map[hash].name < entry.name:
                # Expect chain.pem files to collide.
                # Save the highest numbered one.
                hash_map[hash] = entry
    return hash_map


def relink(config_root, live_domain_entry):
    """Replace files in the live directory with symlinks to the archive.

    Returns True if everything works, False if there is a warning.
    """
    everything_is_good = True
    logging.info(f"Re-linking files in {live_domain_entry.name}")
    # Calculate the location of the archived files from the live
    archive_domain_dir = os.path.join(config_root, ARCHIVE_DIR, live_domain_entry.name)
    # Get a map of hashes to archive file entries
    hash_map = hash_archive(archive_domain_dir)
    # Loop through all the files in the live/domain.name directory
    with os.scandir(live_domain_entry.path) as it:
        for live_entry in it:
            # Only process real files that end with the file extension
            if live_entry.is_symlink() or not live_entry.name.endswith(PEM_EXT):
                logging.debug(f"Skipping {live_entry.name}")
                continue
            logging.info(f"Re-linking {live_entry.name}")
            # Calculate the hash of the live file
            with open(live_entry.path, "rb") as f:
                live_hash = hashlib.sha256(f.read()).hexdigest()
            logging.debug(f"{live_entry.name} hash {live_hash}")
            # Try to find a matching hash in the archive map
            archive_entry = hash_map.get(live_hash)
            if archive_entry:
                logging.debug(f"Found hash match {archive_entry.name}")
                # Calculate the relative path between the files
                rel_path = os.path.relpath(
                    archive_entry.path, os.path.dirname(live_entry.path)
                )
                # Replace the live file with a symlink to the archive
                os.unlink(live_entry.path)
                os.symlink(rel_path, live_entry.path)
                logging.info(
                    f"Replaced file {live_entry.name} with symlink to {rel_path}"
                )
            else:
                logging.warning("Could not find a matching entry in the archive!")
                everything_is_good = False
    return everything_is_good


def main():
    """Relink live certificate files the way certbot expects."""
    args = docopt.docopt(__doc__, version="1.0.0")
    # Set up logging
    log_level = args["--log-level"]
    try:
        logging.basicConfig(
            format="%(asctime)-15s %(levelname)s %(message)s", level=log_level.upper()
        )
    except ValueError:
        logging.critical(
            f'"{log_level}" is not a valid logging level.  Possible values '
            "are debug, info, warning, and error."
        )
        return 1

    config_root = os.path.abspath(args["<cerbot-config-dir>"])

    # Check to see if we have an empty certbot directory
    if not os.path.exists(os.path.join(config_root, LIVE_DIR)):
        logging.warning(f"No symlinks need to be rebuilt in: {config_root}")
        sys.exit(0)

    everything_is_good = True
    for domain in live_domains(config_root):
        if not relink(config_root, domain):
            everything_is_good = False

    # Stop logging and clean up
    logging.shutdown()
    if everything_is_good:
        return 0
    else:
        return 1


if __name__ == "__main__":
    sys.exit(main())
