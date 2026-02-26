# Deploy Firestore Rules

If you see **"The caller doesn't have permission to execute the specified operation"**, deploy the updated Firestore rules:

```bash
firebase deploy --only firestore:rules
```

Or deploy everything:
```bash
firebase deploy
```

The rules allow:
- `journeys` – anyone can read (browse), authenticated users can write
- `orders`, `payments` – authenticated users can read/write
