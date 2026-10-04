On a fresh clone
You'll need to recreate the ignored files:
- app/env/production.json from app/env/production.example.json
- server/.env.production from server/.env.example
- Firebase configs by running ./app/update_firebase_config.sh from the app/ directory