# Calling AI Agents from Backstage Templates

This demo shows how to use a Red Hat Developer Hub (RHDH) Software Template to invoke an AI Agent via HTTP. The Agent returns a synchronous reponse acknowledging the request, and later responds with the actual result using the [Backstage Notifications API](https://backstage.io/docs/notifications/).

## Contents
- `agent/`: Python FastAPI server with a Langchain agent (https://weatherapi.com lookup example)
- `Dockerfile`: Container build for the agent
- `requirements.txt`: Python dependencies
- `template.yaml`: RHDH Software Template using `http:backstage:request`
- `.env.example`: Sample environment variables

## Running the Agent Locally

1. **Create a `.env` file** in the root of the repo with valid values, e.g:
   ```sh
   OPENAI_API_KEY=sk-your-key-here
   NOTIFICATIONS_API_URL=http://localhost:7007/api/notifications
   NOTIFICATIONS_BEARER_TOKEN=your-notification-token
   WEATHER_API_KEY=replaceme
   ```
2. **Build the container:**
   ```sh
   podman build -t rhdh-agent-demo .
   ```
3. **Run the container:**
   ```sh
   podman run -p 8000:8000 \
    --env-file=.env \
    --name=agent \
    rhdh-agent-demo
   ```
   The agent will be available at `http://localhost:8000/invoke`.

**Note:**
For the agent to send notifications, your Red Hat Developer Hub (RHDH) or Backstage backend must be configured with a static token for external access. See the [Configuring Red Hat Developer Hub](#configuring-red-hat-developer-hub) section below for details.

## Configuring Red Hat Developer Hub

1. **Enable the dynamic HTTP request plugin** in your RHDH instance. See the [RHDH dynamic plugins documentation](https://docs.redhat.com/en/documentation/red_hat_developer_hub/1.6/html/dynamic_plugins_reference/con-preinstalled-dynamic-plugins#red-hat-supported-plugins) for details.
2. **Register `template.yaml`** in your RHDH instance.
3. **Configure proxy endpoints** in your RHDH `app-config.yaml` to allow the HTTP request plugin to reach the agent. The proxy endpoint should match the URL used in `template.yaml` and direct requests to the agent service.

Example proxy configuration:
```yaml
proxy:
  reviveConsumedRequestBodies: true
  endpoints:
    '/agents/weather':
      target: http://agent:8000/invoke
      # Backstage proxy appends a trailing slash to requests, and FastAPI
      # redirects trailing slashes, e.g /invoke/ => /invoke
      followRedirects: true
```
Then, in the _template.yaml_, use the proxied path:
```yaml
path: 'proxy/agents/weather'
```

4. **Configure backend authentication** to allow the agent to send notifications. Add the following to your RHDH `app-config.yaml`:
```yaml
backend:
  auth:
    externalAccess:
      - type: static
        options:
          token: your-notification-token
          subject: agent-notifications
```
The value of `token` should match the value you set for `NOTIFICATIONS_BEARER_TOKEN` in your agent's environment.

If testing locally with [Red Hat Developer Hub Local (rhdh-local)](https://github.com/redhat-developer/rhdh-local), you can have
the agent connect to the rhdh-local network. Assuming the agent is running in a
container named `agent` you can use the folllwing command:

```bash
podman network connect rhdh-local_default agent 
```

## Notification Format and Testing

- The agent requires both `NOTIFICATIONS_API_URL` and `NOTIFICATIONS_BEARER_TOKEN` to be set as environment variables. The service will not start if either is missing.
- The notification payload sent to RHDH is in the following format:
  ```json
  {
    "payload": {
      "title": "Weather for $CITY",
      "description": "$THE_WEATHER_FROM_TOOL"
    },
    "recipients": {
      "type": "entity",
      "entityRef": "$THE_USER"
    }
  }
  ```
- The bearer token is sent in the `Authorization` header as `Bearer <token>`.

### Sample request to trigger a notification
```sh
curl -X POST 'http://localhost:7007/api/notifications' \
  -H "Authorization: Bearer $BACKSTAGE_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
        "payload": {
          "title": "Hello"
        },
        "recipients": {
          "type": "entity",
          "entityRef": "user:default/valid-username"
        }
      }' \
  -v
```

## Customization
- Extend the agent logic in `agent/main.py`.
- Add more tools or change the notification logic as needed for your RHDH environment. 
