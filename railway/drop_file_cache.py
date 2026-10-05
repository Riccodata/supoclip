"""Evict this container's cached file pages after a worker burst.

Railway's memory metric counts the kernel page cache. After a job the cache
keeps hundreds of MB of model weights, source video and worker libraries
although nothing reads them until the next job. posix_fadvise(DONTNEED) drops
those clean pages without privileges; pages the running API still has mapped
are left in place by the kernel.
"""

import os
import sys

ROOTS = sys.argv[1:] or ["/data", "/app/.venv", "/usr/local/lib", "/usr/lib/x86_64-linux-gnu"]

for root in ROOTS:
    for dirpath, _dirnames, filenames in os.walk(root):
        for name in filenames:
            try:
                fd = os.open(os.path.join(dirpath, name), os.O_RDONLY | os.O_NOFOLLOW)
            except OSError:
                continue
            try:
                os.posix_fadvise(fd, 0, 0, os.POSIX_FADV_DONTNEED)
            except OSError:
                pass
            finally:
                os.close(fd)
