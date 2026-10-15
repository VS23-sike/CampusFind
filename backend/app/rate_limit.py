from slowapi import Limiter
from slowapi.util import get_remote_address


# Central application rate limiter.
#
# Limits are based on the client's IP address.
# Individual endpoints can apply stricter limits
# where needed, such as login and registration.

limiter = Limiter(
    key_func=get_remote_address,
    default_limits=[],
)