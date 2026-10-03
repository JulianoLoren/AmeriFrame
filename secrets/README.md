# Cloudflare Tunnel token

Create `cloudflare-tunnel-token.txt` here when the token is available. Store only
the token, not the complete `docker run` command. Use plain UTF-8 without BOM.
The real file is ignored by Git and excluded from the Docker build context.
Compose mounts it only into `cloudflared` at `/run/secrets/cloudflare_tunnel_token`.

On Linux, keep this directory accessible only to the deployment account
(`chmod 700 secrets`). The token file must be readable by cloudflared's non-root
container user (`chmod 644 secrets/cloudflare-tunnel-token.txt`); the enclosing
directory prevents other host accounts from traversing to it. Compose file-backed
secrets retain host file permissions, so `chmod 600` may prevent cloudflared from
reading it. On Windows, retain a private directory ACL for your account.

Do not commit the real token or paste it into the Dockerfile/Compose command.
