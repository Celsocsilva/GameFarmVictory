class GitHubAdapter:
    """Provider boundary. Authentication and writes must be supplied by the host."""
    def __init__(self, client=None):
        self.client = client

    def require_client(self):
        if self.client is None:
            raise RuntimeError("GitHub client not configured")
